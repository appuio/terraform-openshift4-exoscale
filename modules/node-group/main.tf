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
  user_data = base64encode(<<-EOF
  {
      "ignition": {
          "version": "3.1.0",
          "config": {
              "merge": [
                  {
                      "source": "https://sos-${var.region}.exo.io/${var.cluster_id}-bootstrap-ignition/${var.node_group_name}.ign"
                  }
              ]
          }
      }
  }
  EOF
  )
}
