resource "exoscale_ipaddress" "api" {
  zone        = var.region
  description = "${var.cluster_id} elastic IP for API"
}
resource "exoscale_domain_record" "api" {
  domain      = exoscale_domain.cluster.id
  name        = "api"
  ttl         = 60
  record_type = "A"
  content     = exoscale_ipaddress.api.ip_address
}

resource "exoscale_ipaddress" "ingress" {
  zone        = var.region
  description = "${var.cluster_id} elastic IP for ingress controller"
}
resource "exoscale_domain_record" "ingress" {
  domain      = exoscale_domain.cluster.id
  name        = "*.apps"
  ttl         = 60
  record_type = "A"
  content     = exoscale_ipaddress.ingress.ip_address
}

resource "random_id" "lb" {
  count       = var.lb_count
  prefix      = "lb-"
  byte_length = 1
}

locals {
  instance_fqdns = formatlist("%s.${var.cluster_id}.${var.base_domain}", random_id.lb[*].hex)
}

resource "exoscale_affinity" "lb" {
  name        = "${var.cluster_id}_lb"
  description = "${var.cluster_id} lb nodes"
  type        = "host anti-affinity"
}

data "exoscale_compute_template" "ubuntu2004" {
  zone = var.region
  name = "Linux Ubuntu 20.04 LTS 64-bit"
}

resource "null_resource" "register_lb" {
  triggers = {
    # Refresh resource when script changes -- this is probaby not required for production
    script_sha1 = filesha1("${path.module}/files/register-server.sh")
    # Refresh resource when lb fqdn changes
    lb_id       = local.instance_fqdns[count.index]
  }

  count = var.lb_count

  provisioner "local-exec" {
    command = "${path.module}/files/register-server.sh"
    environment = {
      CONTROL_VSHN_NET_TOKEN = var.control_vshn_net_token
      SERVER_FQDN            = local.instance_fqdns[count.index]
      # This assumes that the first part of var.region is the encdata region
      # (country code for Exoscale).
      SERVER_REGION          = split("-", var.region)[0]
      # The encdata service doesn't allow dashes, so we replace them with
      # underscores.
      # This assumes that any zone configurations already exist in Puppet
      # hieradata.
      SERVER_ZONE            = replace(var.region, "-", "_")
      # Cluster id is used as encdata stage
      CLUSTER_ID             = var.cluster_id
    }
  }
}

resource "gitfile_checkout" "appuio_hieradata" {
  repo   = "https://${var.hieradata_repo_user}@git.vshn.net/appuio/appuio_hieradata.git"
  path   = "${path.root}/appuio_hieradata"

  lifecycle {
    ignore_changes = [
      branch
    ]
  }
}

resource "local_file" "lb_hieradata" {
  content = templatefile(
    "${path.module}/templates/hieradata.yaml.tmpl",
    {
      "cluster_id" = var.cluster_id
      "api_ip"     = exoscale_ipaddress.api.ip_address
      "router_ip"  = exoscale_ipaddress.ingress.ip_address
      "api_key"    = var.lb_exoscale_api_key
      "api_secret" = var.lb_exoscale_api_secret
      "nodes"      = local.instance_fqdns
      "backends"   = {
        "api"    = exoscale_domain_record.etcd[*].hostname,
        "router" = module.infra.ip_address[*],
      }
      "bootstrap_node" = var.bootstrap_count > 0 ? module.bootstrap.ip_address[0] : ""
    })

  filename             = "${path.cwd}/appuio_hieradata/lbaas/${var.cluster_id}.yaml"
  file_permission      = "0644"
  directory_permission = "0755"

  depends_on = [
    gitfile_checkout.appuio_hieradata
  ]

  provisioner "local-exec" {
    command     = "${path.module}/files/commit-hieradata.sh ${var.cluster_id}"
  }
}

resource "exoscale_compute" "lb" {
  count              = var.lb_count
  display_name       = local.instance_fqdns[count.index]
  hostname           = random_id.lb[count.index].hex
  key_pair           = local.ssh_key_name
  zone               = var.region
  affinity_group_ids = [exoscale_affinity.lb.id]
  template_id        = data.exoscale_compute_template.ubuntu2004.id
  size               = "Medium"
  disk_size          = 20
  security_group_ids = [
    exoscale_security_group.all_machines.id,
    exoscale_security_group.load_balancers.id
  ]

  user_data = format("%s\n%s", "#cloud-config", yamlencode({
    "package_update"  = true,
    "package_upgrade" = true,
    "packages" = [
      "haproxy",
      "keepalived"
    ],
    "bootcmd" = [
      "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE",
      "iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT",
      "iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT",
      "sysctl -w net.ipv4.ip_forward=1",
      "sysctl -w net.ipv4.ip_nonlocal_bind=1",
      "ip link set eth1 up",
      "ip address add ${cidrhost(var.privnet_cidr, 2 + count.index)}/24 dev eth1"
    ],
    "write_files" = [
      {
        "path"     = "/etc/keepalived/keepalived.conf",
        "encoding" = "b64",
        "content" = base64encode(templatefile(
          "${path.module}/templates/keepalived.conf.tmpl",
          {
            "api_ip"     = exoscale_ipaddress.api.ip_address
            "router_ip"  = exoscale_ipaddress.ingress.ip_address
            "api_int"    = var.use_privnet
            "api_int_ip" = local.privnet_api
            "gw_int_ip"  = local.privnet_gw
            "peer_ip"    = count.index == 0 ? cidrhost(var.privnet_cidr, 3) : cidrhost(var.privnet_cidr, 2)
            "prio"       = (var.lb_count - count.index) * 10
          }
        ))
      },
      {
        "path"        = "/etc/floaty/eth1.wrapper",
        "encoding"    = "b64",
        "content"     = filebase64("${path.module}/files/keepalived-notify-script"),
        "permissions" = "0755"
      },
      {
        "path"     = "/etc/floaty/config.yaml",
        "encoding" = "b64",
        "content" = base64encode(templatefile(
          "${path.module}/templates/floaty.yaml.tmpl",
          {
            "api_key"    = var.lb_exoscale_api_key
            "api_secret" = var.lb_exoscale_api_secret
            "managed_addrs" = [
              exoscale_ipaddress.api.ip_address,
              exoscale_ipaddress.ingress.ip_address
            ]
          }
        )),
        "permissions" = "0600"
      },
      {
        "path"     = "/etc/haproxy/haproxy.cfg",
        "encoding" = "b64",
        "content" = base64encode(templatefile(
          "${path.module}/templates/haproxy.cfg.tmpl",
          {
            "api_ip"         = exoscale_ipaddress.api.ip_address
            "router_ip"      = exoscale_ipaddress.ingress.ip_address
            "api_int"        = var.use_privnet
            "api_int_ip"     = local.privnet_api
            "cluster_domain" = local.cluster_domain
          }
        ))
      }
    ],
    "runcmd" = [
      "while lsof -F p /var/lib/dpkg/lock 2>/dev/null; do echo \"Waiting for dpkg lock...\"; sleep 15; done",
      "curl -Lo /tmp/floaty.deb https://github.com/vshn/floaty/releases/latest/download/floaty_linux_amd64.deb",
      "dpkg -i /tmp/floaty.deb",
      "systemctl restart keepalived",
      "shutdown --reboot +1 'Reboot for system setup'"
    ]
  }))

  lifecycle {
    ignore_changes = [
      template_id
    ]
  }

  depends_on = [
    null_resource.register_lb,
    local_file.lb_hieradata
  ]
}

resource "exoscale_network" "lb_vrrp" {
  # only create the lb-vrrp network when we're not deploying the cluster into
  # a private network anyway.
  count        = var.use_privnet ? 0 : 1
  zone         = var.region
  name         = "${var.cluster_id}_lb_vrrp"
  display_text = "${var.cluster_id} LB VRRP network"
}

resource "exoscale_nic" "lb" {
  count      = var.lb_count
  compute_id = exoscale_compute.lb[count.index].id
  # Use cluster network if it's provisioned, lb_vrrp network otherwise
  network_id = var.use_privnet ? exoscale_network.clusternet[0].id : exoscale_network.lb_vrrp[0].id
  # Privnet CIDR IPs starting from .2 when using clusternet
  ip_address = var.use_privnet ? cidrhost(var.privnet_cidr, 2 + count.index) : null
}
