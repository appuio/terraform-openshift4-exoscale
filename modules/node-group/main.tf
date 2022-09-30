locals {
  disk_size = var.root_disk_size + var.data_disk_size + var.storage_disk_size

  ignition_source = {
    "bootstrap" = "${trimsuffix(var.bootstrap_bucket, "/")}/bootstrap.ign"
    "master"    = "https://${var.api_int}:22623/config/master"
    "worker"    = "https://${var.api_int}:22623/config/worker"
  }

  is_storage_cluster = var.storage_disk_size > 0

  user_data = {
    "ignition" : {
      "version" : "3.1.0",
      "config" : {
        "merge" : [
          {
            "source" : lookup(local.ignition_source, var.role, local.ignition_source["worker"])
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
    "storage" : merge(
      var.use_privnet ? local.privnet_config : {},
      // We create a custom partition layout if data_disk_size or
      // storage_disk_size are > 0. This is primarily to avoid issues with sector
      // rounding during partitioning if the user didn't request extra disk space.
      var.data_disk_size + var.storage_disk_size > 0 ? local.disks_config : {},
    ),
    // For storage cluster nodes we zero the extra partition on first boot to
    // ensure deploying the storage cluster succeeds.
    // We don't do this for other nodes where users request extra disk space via
    // data_disk_size.
    "systemd" : local.is_storage_cluster ? local.storage_cluster_firstboot_unit : {},
  }

  # TODO: can we do something smarter than this?
  dns_servers = <<-EOF
  DNS1=159.100.247.115
  DNS2=159.100.253.158
  EOF

  privnet_iface = "ens4"
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
        "path" : "/etc/sysconfig/network-scripts/ifcfg-${local.privnet_iface}",
        "mode" : 420,
        "contents" : {
          "source" : "data:text/plain;charset=utf-8;base64,${base64encode(templatefile(
            "${path.module}/templates/ifcfg.tmpl",
            {
              device     = local.privnet_iface
              enabled    = "yes"
              custom_dns = local.dns_servers
            }
          ))}"
        }
      },
      {
        "filesystem" : "root",
        "path" : "/etc/sysconfig/network-scripts/route-${local.privnet_iface}",
        "mode" : 420,
        "contents" : {
          "source" : "data:text/plain;charset=utf-8;base64,${base64encode("default via ${var.privnet_gw}")}"
        }
      }
    ]
  }

  disks_config = {
    "disks" : [
      {
        "device" : "/dev/vda",
        "partitions" : [
          {
            "label" : "root",
            "number" : 4,
            "shouldExist" : true,
            "sizeMiB" : var.root_disk_size * 1024,
            "wipePartitionEntry" : true
          },
          {
            "label" : "data",
            "number" : 0,
            "shouldExist" : true,
            "sizeMiB" : 0,
            "startMiB" : 0
          }
        ]
      }
    ]
  }

  storage_cluster_firstboot_unit = {
    "units" : [
      {
        "name" : "exoscale-zero-storagepool.service"
        "enabled" : true,
        "contents" : templatefile(
          "${path.module}/templates/zero_storagepool.service.tmpl",
          {
            "partition" : "/dev/vda5",
            // Intentionally use 1GB = 1000MB when calculating the partition
            // size in MB to avoid having `dd` fail due to the partition being
            // slightly smaller than requested in GiB.
            "size_mb" : var.storage_disk_size * 1000
          }
        )
      }
    ]
  }

  privnet_interface = var.use_privnet ? {
    "clusternet" : {
      network_id = var.privnet_id
      ip_address = var.privnet_dhcp_reservation != "" ? var.privnet_dhcp_reservation : null
    }
    } : {
  }
}

resource "random_id" "node_id" {
  count       = var.node_count
  prefix      = "${var.role}-"
  byte_length = 2
}

resource "exoscale_anti_affinity_group" "anti_affinity_group" {
  count       = var.node_count > 0 ? 1 : 0
  name        = "${var.cluster_id}_${var.role}"
  description = "${var.cluster_id} ${var.role} nodes"
}

resource "exoscale_compute_instance" "nodes" {
  count       = var.node_count
  name        = "${random_id.node_id[count.index].hex}.${var.cluster_domain}"
  ssh_key     = var.ssh_key_pair
  zone        = var.region
  template_id = var.template_id
  type        = var.instance_type
  disk_size   = local.disk_size
  user_data = base64encode(jsonencode(
    merge(
      local.user_data,
      // override /etc/hostname with short hostname, this works around the
      // fact that we can't set a separate `name` and `display_name` for
      // compute instances anymore.
      {
        "storage" : {
          "files" : [{
            "filesystem" : "root",
            "path" : "/etc/hostname",
            "mode" : 420,
            "overwrite" : true,
            "contents" : {
              "source" : "data:,${random_id.node_id[count.index].hex}"
            }
          }]
        }
      }
    )
  ))

  # Always lowercase the provided state
  state = lower(var.node_state)

  security_group_ids = var.security_group_ids
  anti_affinity_group_ids = concat(
    [exoscale_anti_affinity_group.anti_affinity_group[0].id],
    var.additional_affinity_group_ids
  )

  dynamic "network_interface" {
    for_each = local.privnet_interface

    content {
      network_id = network_interface.value["network_id"]
      ip_address = network_interface.value["ip_address"]
    }
  }

  lifecycle {
    ignore_changes = [
      template_id,
      user_data
    ]
  }
}
