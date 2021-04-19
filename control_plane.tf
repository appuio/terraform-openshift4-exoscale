module "master" {
  source = "./modules/node-group/"

  cluster_id      = var.cluster_id
  node_group_name = "master"
  node_count      = local.master_count
  region          = var.region
  template_id     = data.exoscale_compute_template.rhcos.id
  base_domain     = var.base_domain
  instance_size   = "Extra-large"

  cluster_network_id = exoscale_network.clusternet.id

  api_int     = exoscale_domain_record.api_int.hostname
  ignition_ca = var.ignition_ca

  security_group_ids = [
    exoscale_security_group.all_machines.id,
    exoscale_security_group.control_plane.id,
  ]
}

resource "exoscale_domain_record" "master_api_member" {
  count       = local.master_count
  domain      = exoscale_domain.cluster.id
  name        = "api-member"
  ttl         = 60
  record_type = "A"
  content     = module.master.ip_address[count.index]
}

resource "exoscale_domain_record" "etcd" {
  count       = local.master_count
  domain      = exoscale_domain.cluster.id
  name        = "etcd-${count.index}"
  ttl         = 60
  record_type = "A"
  content     = module.master.ip_address[count.index]
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
