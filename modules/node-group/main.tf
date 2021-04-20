locals {
  ignition_source = {
    "bootstrap" : "https://sos-${var.region}.exo.io/${var.cluster_id}-bootstrap-ignition/bootstrap.ign"
    "master" : "https://${var.api_int}:22623/config/master"
    "worker" : "https://${var.api_int}:22623/config/worker"
  }

  user_data = base64encode(jsonencode({
    "ignition" : {
      "version" : "3.1.0",
      "config" : {
        "merge" : [
          {
            "source" : local.ignition_source[var.node_group_name]
          }
        ]
      },
      "security" : {
        "tls" : {
          "certificateAuthorities" : [{
            "source" : "data:text/plain;charset=utf-8;base64,${base64encode(var.ignition_ca)}"
          }]
        }
      }
    },
    "storage" : var.privnet_id != "" ? local.privnet_config : {}
  }))

  # TODO: can we do something smarter than this?
  dns_servers = <<-EOF
  DNS1=159.100.247.115
  DNS2=159.100.253.158
  EOF
  privnet_config = {
    "files" : [
      {
        "filesystem" : "root",
        "path" : "/etc/sysconfig/network-scripts/ifcfg-ens3",
        "mode" : 420,
        "contents" : {
          "source" : "data:text/plain;charset=utf-8;base64,${base64encode(templatefile("${path.module}/templates/ifcfg.tmpl", { device = "ens3", enabled = "no", custom_dns = "" }))}"
        }
      },
      {
        "filesystem" : "root",
        "path" : "/etc/sysconfig/network-scripts/ifcfg-ens6",
        "mode" : 420,
        "contents" : {
          "source" : "data:text/plain;charset=utf-8;base64,${base64encode(templatefile("${path.module}/templates/ifcfg.tmpl", { device = "ens6", enabled = "yes", custom_dns = local.dns_servers }))}"
        }
      },
      {
        "filesystem" : "root",
        "path" : "/etc/sysconfig/network-scripts/route-ens6",
        "mode" : 420,
        "contents" : {
          "source" : "data:text/plain;charset=utf-8;base64,${base64encode("default via ${var.privnet_gw}")}"
        }
      }
    ]
  }
}

resource "random_id" "node_id" {
  count       = var.node_count
  prefix      = "${var.node_group_name}-"
  byte_length = 2
}

resource "exoscale_affinity" "anti_affinity_group" {
  name        = "${var.cluster_id}_${var.node_group_name}"
  description = "${var.cluster_id} ${var.node_group_name} nodes"
  type        = "host anti-affinity"
}

resource "exoscale_compute" "nodes" {
  count              = var.node_count
  display_name       = "${random_id.node_id[count.index].hex}.${var.cluster_id}.${var.base_domain}"
  hostname           = random_id.node_id[count.index].hex
  key_pair           = var.ssh_key_pair
  zone               = var.region
  affinity_group_ids = [exoscale_affinity.anti_affinity_group.id]
  template_id        = var.template_id
  size               = var.instance_size
  disk_size          = var.disk_size
  security_group_ids = var.security_group_ids
  user_data          = local.user_data
}

resource "exoscale_nic" "nodes" {
  count      = var.privnet_id != "" ? var.node_count : 0
  compute_id = exoscale_compute.nodes[count.index].id
  network_id = var.privnet_id
  ip_address = var.privnet_dhcp_reservation != "" ? var.privnet_dhcp_reservation : null
}
