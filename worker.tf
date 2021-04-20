module "worker" {
  source = "./modules/node-group"

  cluster_id    = var.cluster_id
  role          = "worker"
  node_count    = var.worker_count
  region        = var.region
  template_id   = data.exoscale_compute_template.rhcos.id
  base_domain   = var.base_domain
  instance_size = var.worker_size

  use_privnet = var.use_privnet
  privnet_id  = var.use_privnet ? exoscale_network.clusternet[0].id : ""
  privnet_gw  = local.privnet_gw

  api_int     = exoscale_domain_record.api_int.hostname
  ignition_ca = var.ignition_ca

  security_group_ids = [
    exoscale_security_group.all_machines.id,
    exoscale_security_group.worker.id,
  ]
}

resource "exoscale_domain_record" "router_member" {
  count       = var.worker_count
  domain      = exoscale_domain.cluster.id
  name        = "router-member"
  ttl         = 60
  record_type = "A"
  content     = module.worker.ip_address[count.index]
}
