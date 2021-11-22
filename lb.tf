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

  common_user_data = {
    "package_update"  = true,
    "package_upgrade" = true,
    "runcmd" = [
      "sleep '5'",
      "wget -O /tmp/puppet-source.deb https://apt.puppetlabs.com/puppet6-release-focal.deb",
      "dpkg -i /tmp/puppet-source.deb",
      "rm /tmp/puppet-source.deb",
      "apt-get update",
      "apt-get -y install puppet-agent",
      "apt-get -y purge snapd",
      "mkdir -p /etc/puppetlabs/facter/facts.d",
      "mv /run/tmp/ec2_userdata_override.yaml /etc/puppetlabs/facter/facts.d/",
      "netplan apply",
      ["bash", "-c",
      "set +e -x; for ((i=0; i < 3; ++i)); do /opt/puppetlabs/bin/puppet facts && break; done; for ((i=0; i < 3; ++i)); do /opt/puppetlabs/bin/puppet agent -t --server master.puppet.vshn.net --environment AppuioLbaas && break; done"],
      "sleep 5",
      "shutdown --reboot +1 'Reboot for system setup'",
    ],
  }
  common_write_files = [
    {
      path       = "/etc/netplan/60-eth1.yaml"
      "encoding" = "b64"
      "content" = base64encode(yamlencode({
        "network" = {
          "ethernets" = {
            "eth1" = {
              "dhcp4" = true,
            },
          },
          "version" = 2,
        }
      }))
    }
  ]
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
    # Refresh resource when the script changes -- this is probaby not required for production
    # Uncomment this trigger if you want to test changes to `files/register-server.sh`
    # script_sha1 = filesha1("${path.module}/files/register-server.sh")
    # Refresh resource when lb fqdn changes
    lb_id = local.instance_fqdns[count.index]
  }

  count = var.lb_count

  provisioner "local-exec" {
    command = "${path.module}/files/register-server.sh"
    environment = {
      CONTROL_VSHN_NET_TOKEN = var.control_vshn_net_token
      SERVER_FQDN            = local.instance_fqdns[count.index]
      # This assumes that the first part of var.region is the encdata region
      # (country code for Exoscale).
      SERVER_REGION = split("-", var.region)[0]
      # The encdata service doesn't allow dashes, so we replace them with
      # underscores.
      # This assumes that any zone configurations already exist in Puppet
      # hieradata.
      SERVER_ZONE = replace(var.region, "-", "_")
      # Cluster id is used as encdata stage
      CLUSTER_ID = var.cluster_id
    }
  }
}

resource "gitfile_checkout" "appuio_hieradata" {
  repo = "https://${var.hieradata_repo_user}@git.vshn.net/appuio/appuio_hieradata.git"
  path = "${path.root}/appuio_hieradata"

  count = var.lb_count > 0 ? 1 : 0

  lifecycle {
    ignore_changes = [
      branch
    ]
  }
}

resource "local_file" "lb_hieradata" {
  count = var.lb_count > 0 ? 1 : 0

  content = templatefile(
    "${path.module}/templates/hieradata.yaml.tmpl",
    {
      "cluster_id" = var.cluster_id
      "api_ip"     = exoscale_ipaddress.api.ip_address
      "router_ip"  = exoscale_ipaddress.ingress.ip_address
      "api_key"    = var.lb_exoscale_api_key
      "api_secret" = var.lb_exoscale_api_secret
      "nodes"      = local.instance_fqdns
      "backends" = {
        "api"    = exoscale_domain_record.etcd[*].hostname,
        "router" = module.infra.ip_address[*],
      }
      "bootstrap_node" = var.bootstrap_count > 0 ? module.bootstrap.ip_address[0] : ""
      "team"           = var.team
  })

  filename             = "${path.cwd}/appuio_hieradata/lbaas/${var.cluster_id}.yaml"
  file_permission      = "0644"
  directory_permission = "0755"

  depends_on = [
    gitfile_checkout.appuio_hieradata[0]
  ]

  provisioner "local-exec" {
    command = "${path.module}/files/commit-hieradata.sh ${var.cluster_id} ${path.cwd}/.mr_url.txt"
  }
}

data "local_file" "hieradata_mr_url" {
  filename = "${path.cwd}/.mr_url.txt"

  depends_on = [
    local_file.lb_hieradata
  ]
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

  user_data = format("#cloud-config\n%s", yamlencode(merge(
    local.common_user_data,
    {
      "fqdn"             = local.instance_fqdns[count.index],
      "hostname"         = random_id.lb[count.index].hex,
      "manage_etc_hosts" = true,
    },
    // Override ec2_userdata fact with a clean copy of the userdata, as
    // Exoscale presents userdata gzipped which confuses facter completely.
    // TODO: check how we do this using server-up.
    {
      "write_files" = concat(local.common_write_files, [
        {
          path       = "/run/tmp/ec2_userdata_override.yaml"
          "encoding" = "b64"
          "content" = base64encode(yamlencode({
            "ec2_userdata" = format("#cloud-config\n%s", yamlencode(merge(
              local.common_user_data,
              {
                "fqdn"             = local.instance_fqdns[count.index],
                "hostname"         = random_id.lb[count.index].hex,
                "manage_etc_hosts" = true,
                "write_files"      = local.common_write_files,
              }
            )))
          }))
        }
      ])
    }
  )))

  lifecycle {
    ignore_changes = [
      template_id,
      user_data,
    ]
  }

  depends_on = [
    null_resource.register_lb,
    local_file.lb_hieradata[0]
  ]
}

resource "exoscale_nic" "lb" {
  count      = var.lb_count
  compute_id = exoscale_compute.lb[count.index].id
  # Use cluster network if it's provisioned, lb_vrrp network otherwise
  network_id = exoscale_network.clusternet.id
  # Privnet CIDR IPs starting from .21
  # (IPs .1,.2,.3 will be assigned by Puppet profile_openshift4_gateway)
  ip_address = cidrhost(var.privnet_cidr, 21 + count.index)
}

resource "exoscale_domain_record" "lb" {
  count       = var.lb_count
  domain      = exoscale_domain.cluster.id
  name        = random_id.lb[count.index].hex
  ttl         = 600
  record_type = "A"
  content     = exoscale_compute.lb[count.index].ip_address
}
