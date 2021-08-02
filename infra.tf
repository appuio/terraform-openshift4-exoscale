module "infra" {
  source = "./modules/node-group"

  cluster_id    = var.cluster_id
  role          = "infra"
  node_count    = var.infra_count
  region        = var.region
  template_id   = data.exoscale_compute_template.rhcos.id
  base_domain   = var.base_domain
  instance_size = var.infra_size
  node_state    = var.infra_state
  ssh_key_pair  = local.ssh_key_name

  root_disk_size = var.root_disk_size

  use_privnet = var.use_privnet
  privnet_id  = var.use_privnet ? exoscale_network.clusternet.id : ""
  privnet_gw  = local.privnet_gw

  api_int     = exoscale_domain_record.api_int.hostname
  ignition_ca = var.ignition_ca

  security_group_ids = [
    exoscale_security_group.all_machines.id,
    exoscale_security_group.infra.id,
  ]

  additional_affinity_group_ids = var.additional_affinity_group_ids

  bootstrap_bucket = var.bootstrap_bucket
}

resource "exoscale_domain_record" "router_member" {
  count       = var.infra_state == "Running" ? var.infra_count : 0
  domain      = exoscale_domain.cluster.id
  name        = "router-member"
  ttl         = 60
  record_type = "A"
  content     = module.infra.ip_address[count.index]
}
