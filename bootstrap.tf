locals {
  bootstrap_ip = cidrhost(var.privnet_cidr, 10)
}

module "bootstrap" {
  source = "./modules/node-group/"

  cluster_id    = var.cluster_id
  role          = "bootstrap"
  node_count    = var.bootstrap_count
  region        = var.region
  template_id   = data.exoscale_compute_template.rhcos.id
  base_domain   = var.base_domain
  instance_size = "Extra-large"
  disk_size     = 128
  node_state    = var.bootstrap_state

  use_privnet              = var.use_privnet
  privnet_id               = var.use_privnet ? exoscale_network.clusternet[0].id : ""
  privnet_gw               = local.privnet_gw
  privnet_dhcp_reservation = local.bootstrap_ip

  api_int     = exoscale_domain_record.api_int.hostname
  ignition_ca = var.ignition_ca

  security_group_ids = [
    exoscale_security_group.all_machines.id,
    exoscale_security_group.control_plane.id,
  ]

  bootstrap_bucket = var.bootstrap_bucket
}

resource "exoscale_domain_record" "bootstrap_api_member" {
  count       = var.bootstrap_count
  domain      = exoscale_domain.cluster.id
  name        = "api-member"
  ttl         = 60
  record_type = "A"
  content     = module.bootstrap.ip_address[0]
}
