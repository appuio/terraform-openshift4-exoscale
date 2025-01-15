locals {
  disk_size = var.root_disk_size + var.data_disk_size + var.storage_disk_size

  anti_affinity_group_capacity = var.affinity_group_capacity > 0 ? var.affinity_group_capacity : 999999
  anti_affinity_group_count    = var.affinity_group_capacity > 0 ? ceil(var.node_count / var.affinity_group_capacity) : 1

  ignition_source = {
    "bootstrap" = "${trimsuffix(var.bootstrap_bucket, "/")}/bootstrap.ign"
    "master"    = "https://${var.api_int}:22623/config/master"
    "worker"    = "https://${var.api_int}:22623/config/worker"
  }

  is_storage_cluster = var.storage_disk_size > 0

  // Generate instance-specific user-data based on `random_id.node_id` This
  // allows us to construct the complete ignition config here, instead of
  // having to work around merge() being a shallow merge in the compute
  // instance resource.
  user_data = [
    for hostname in(var.use_instancepool ? ["dummy"] : random_id.node_id[*].hex) :
    {
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
      // NOTE: merge doesn't deep-merge args, but instead overwrites existing
      // top-level keys with the contents of the latest argument which has a
      // top-level key.
      "storage" : {
        // concatenate the private network config (if requested) with the
        // `/etc/hostname` override.
        "files" : var.use_instancepool ? [] : concat(
          var.use_privnet ? local.privnet_config_files : [],
          // override /etc/hostname with short hostname, this works around the
          // fact that we can't set a separate `name` and `display_name` for
          // compute instances anymore.
          [{
            "path" : "/etc/hostname",
            "mode" : 420,
            "overwrite" : true,
            "contents" : {
              "source" : "data:,${hostname}"
            }
          }]
        ),
        // We create a custom partition layout if data_disk_size or
        // storage_disk_size are > 0. This is primarily to avoid issues with sector
        // rounding during partitioning if the user didn't request extra disk space.
        "disks" : var.data_disk_size + var.storage_disk_size > 0 ? local.disks_config : [],
      },
      // For storage cluster nodes we zero the extra partition on first boot to
      // ensure deploying the storage cluster succeeds.
      // We don't do this for other nodes where users request extra disk space via
      // data_disk_size.
      "systemd" : local.is_storage_cluster ? local.storage_cluster_firstboot_unit : {},
    }
  ]

  # TODO: can we do something smarter than this?
  dns_servers = <<-EOF
  DNS1=159.100.247.115
  DNS2=159.100.253.158
  EOF

  privnet_iface = "ens4"
  privnet_config_files = [
    {
      "path" : "/etc/sysconfig/network-scripts/ifcfg-ens3",
      "mode" : 420,
      "contents" : {
        "source" : "data:text/plain;charset=utf-8;base64,${base64encode(templatefile("${path.module}/templates/ifcfg.tmpl", { device = "ens3", enabled = "no", custom_dns = "" }))}"
      }
    },
    {
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
      "path" : "/etc/sysconfig/network-scripts/route-${local.privnet_iface}",
      "mode" : 420,
      "contents" : {
        "source" : "data:text/plain;charset=utf-8;base64,${base64encode("default via ${var.privnet_gw}")}"
      }
    }
  ]

  disks_config = [
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
  count       = var.use_instancepool ? 0 : var.node_count
  prefix      = "${var.role}-"
  byte_length = 2
}

resource "exoscale_anti_affinity_group" "anti_affinity_group" {
  count       = var.node_count != 0 ? local.anti_affinity_group_count : 0
  name        = count.index > 0 ? "${var.cluster_id}_${var.role}_${count.index}" : "${var.cluster_id}_${var.role}"
  description = "${var.cluster_id} ${var.role} nodes"
}

resource "exoscale_compute_instance" "nodes" {
  count       = var.use_instancepool ? 0 : var.node_count
  name        = "${random_id.node_id[count.index].hex}.${var.cluster_domain}"
  ssh_key     = var.ssh_key_pair
  zone        = var.region
  template_id = var.template_id
  type        = var.instance_type
  disk_size   = local.disk_size
  user_data   = base64encode(jsonencode(local.user_data[count.index]))

  # Always lowercase the provided state
  state = lower(var.node_state)

  security_group_ids = var.security_group_ids
  anti_affinity_group_ids = concat(
    [exoscale_anti_affinity_group.anti_affinity_group[floor(count.index / local.anti_affinity_group_capacity)].id],
    var.additional_affinity_group_ids
  )

  deploy_target_id = var.deploy_target_id

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
      user_data,
      elastic_ip_ids,
    ]
  }
}

resource "exoscale_instance_pool" "nodes" {
  count       = var.use_instancepool ? local.anti_affinity_group_count : 0
  name        = "${var.role}-${count.index}"
  size        = var.node_count
  zone        = var.region
  key_pair    = var.ssh_key_pair
  template_id = var.template_id

  instance_prefix = var.role
  instance_type   = var.instance_type

  disk_size = local.disk_size
  user_data = jsonencode(local.user_data[0])

  deploy_target_id = var.deploy_target_id

  security_group_ids = var.security_group_ids

  anti_affinity_group_ids = concat(
    [exoscale_anti_affinity_group.anti_affinity_group[count.index].id],
    var.additional_affinity_group_ids
  )
}
