locals {
  bootstrap_ip = cidrhost(var.privnet_cidr, 10)
}

module "bootstrap" {
  source = "./modules/node-group/"

  cluster_id     = var.cluster_id
  cluster_domain = local.cluster_domain
  role           = "bootstrap"
  node_count     = var.bootstrap_count
  region         = var.region
  template_id    = data.exoscale_compute_template.rhcos.id
  base_domain    = var.base_domain
  instance_type  = "standard.extra-large"
  node_state     = var.bootstrap_state
  ssh_key_pair   = local.ssh_key_name

  use_privnet              = var.use_privnet
  privnet_id               = local.privnet_id
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
