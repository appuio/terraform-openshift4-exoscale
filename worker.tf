resource "exoscale_affinity" "worker" {
  name        = "${var.cluster_id}_worker"
  description = "${var.cluster_id} worker nodes"
  type        = "host anti-affinity"
}

resource "exoscale_compute" "worker" {
  count              = var.worker_count
  display_name       = "${random_id.worker[count.index].hex}.${var.cluster_id}.${var.base_domain}"
  hostname           = random_id.worker[count.index].hex
  key_pair           = try(exoscale_ssh_keypair.admin[0].name, var.existing_keypair)
  zone               = var.region
  affinity_group_ids = [exoscale_affinity.worker.id]
  template_id        = data.exoscale_compute_template.rhcos.id
  size               = "Extra-large"
  disk_size          = 128
  security_group_ids = [
    exoscale_security_group.all_machines.id,
    exoscale_security_group.worker.id,
  ]
  user_data = base64encode(templatefile(local.ignition_template, {
    role       = "worker"
    cluster_id = var.cluster_id
    region     = var.region
    hostname   = random_id.worker[count.index].hex
  }))

  depends_on = [
    exoscale_secondary_ipaddress.master,
  ]
}

resource "exoscale_secondary_ipaddress" "ingress" {
  count      = var.worker_count
  compute_id = exoscale_compute.worker[count.index].id
  ip_address = exoscale_ipaddress.ingress.ip_address
}
