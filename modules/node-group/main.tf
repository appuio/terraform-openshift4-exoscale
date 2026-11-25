check "ignition_set_for_bootstrap" {
  assert {
    condition     = (var.role == "bootstrap" && var.ignition_bootstrap != "") || true
    error_message = "variable ignition_bootstrap must be set for the bootstrap node"
  }
}

locals {
  disk_size = var.root_disk_size + var.data_disk_size + var.storage_disk_size

  anti_affinity_group_capacity = var.affinity_group_capacity > 0 ? var.affinity_group_capacity : 999999
  anti_affinity_group_count    = var.affinity_group_capacity > 0 ? ceil(var.node_count / var.affinity_group_capacity) : 1

  ignition_source = {
    "bootstrap" = var.ignition_bootstrap
    "master"    = "https://${var.api_int}:22623/config/master"
    "worker"    = "https://${var.api_int}:22623/config/worker"
  }

  is_storage_cluster = var.storage_disk_size > 0

  // Generate instance-specific user-data based on `random_id.node_id` This
  // allows us to construct the complete ignition config here, instead of
  // having to work around merge() being a shallow merge in the compute
  // instance resource.
  user_data = [
    // NOTE(sg): we only need to patch each node's user-data to have a custom
    // /etc/hosts for non-instancepool setups. For instancepool setups, we
    // only need a single user-data and we don't actually use the value of
    // `hostname`.
    for hostname in(var.use_instancepool ? ["pool_member"] : random_id.node_id[*].hex) :
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
        // configure the `etc/hostname` override if we're not using an
        // instancepool.
        "files" : var.use_instancepool ? [] : [{
          "path" : "/etc/hostname",
          "mode" : 420,
          "overwrite" : true,
          "contents" : {
            "source" : "data:,${hostname}"
          }
        }],
        // We create a custom partition layout if data_disk_size or
        // storage_disk_size are > 0. This is primarily to avoid issues with sector
        // rounding during partitioning if the user didn't request extra disk space.
        "disks" : var.data_disk_size + var.storage_disk_size > 0 ? local.disks_config : [],
      },
      // For storage cluster nodes we zero the extra partition on first boot to
      // ensure deploying the storage cluster succeeds.
      // We don't do this for other nodes where users request extra disk space via
      // data_disk_size.
      "systemd" : local.is_storage_cluster ? local.storage_cluster_firstboot_unit : (var.initialize_topolvm_vg ? local.topolvm_partition_firstboot_unit : {}),
    }
  ]

  # TODO: can we do something smarter than this?
  dns_servers = <<-EOF
  DNS1=159.100.247.115
  DNS2=159.100.253.158
  EOF

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

  topolvm_partition_firstboot_unit = {
    "units" : [
      {
        "name" : "exoscale-initialize-topolvm-vg.service"
        "enabled" : true,
        "contents" : templatefile(
          "${path.module}/templates/initialize-topolvm-vg.service.tmpl",
          {
            "partition" : "/dev/vda5",
          }
        )
      }
    ]
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
  ssh_keys    = [var.ssh_key_pair]
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

  lifecycle {
    ignore_changes = [
      template_id,
      user_data,
      elastic_ip_ids,
      ssh_keys,
    ]
  }
}

resource "exoscale_instance_pool" "nodes" {
  count       = var.use_instancepool && var.node_count > 0 ? local.anti_affinity_group_count : 0
  name        = "${var.cluster_id}_${var.role}-${count.index}"
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
