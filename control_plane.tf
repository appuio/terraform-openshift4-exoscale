resource "exoscale_affinity" "master" {
  name        = "${var.cluster_id}_master"
  description = "${var.cluster_id} master nodes"
  type        = "host anti-affinity"
}

resource "exoscale_compute" "master" {
  count              = local.master_count
  display_name       = "${random_id.master[count.index].hex}.${var.cluster_id}.${var.base_domain}"
  hostname           = random_id.master[count.index].hex
  key_pair           = exoscale_ssh_keypair.admin.name
  zone               = var.region
  affinity_group_ids = [exoscale_affinity.master.id]
  template_id        = data.exoscale_compute_template.rhcos.id
  size               = "Extra-large"
  disk_size          = 128
  security_group_ids = [
    exoscale_security_group.all_machines.id,
    exoscale_security_group.control_plane.id,
  ]
  user_data = base64encode(templatefile(local.ignition_template, {
    role       = "master"
    cluster_id = var.cluster_id
    region     = var.region
    hostname   = random_id.master[count.index].hex
  }))

  depends_on = [
    exoscale_secondary_ipaddress.bootstrap,
  ]
}

resource "exoscale_domain_record" "api_int" {
  count       = local.master_count
  domain      = exoscale_domain.cluster.id
  name        = "api-int"
  ttl         = 10
  record_type = "A"
  content     = exoscale_compute.master[count.index].ip_address
}

resource "exoscale_secondary_ipaddress" "master" {
  count      = local.master_count
  compute_id = exoscale_compute.master[count.index].id
  ip_address = exoscale_ipaddress.api.ip_address
}

resource "exoscale_domain_record" "etcd" {
  count       = local.master_count
  domain      = exoscale_domain.cluster.id
  name        = "etcd-${count.index}"
  ttl         = 60
  record_type = "A"
  content     = exoscale_compute.master[count.index].ip_address
}

resource "exoscale_domain_record" "etcd_srv" {
  count       = local.master_count
  domain      = exoscale_domain.cluster.id
  name        = "_etcd-server-ssl._tcp"
  ttl         = 60
  record_type = "SRV"
  prio        = 0
  content     = "10 2380 ${exoscale_domain_record.etcd[count.index].hostname}"
}
