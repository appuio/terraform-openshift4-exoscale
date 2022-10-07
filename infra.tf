module "infra" {
  source = "./modules/node-group"

  cluster_id     = var.cluster_id
  cluster_domain = local.cluster_domain
  role           = "infra"
  node_count     = var.infra_count
  region         = var.region
  template_id    = data.exoscale_compute_template.rhcos.id
  base_domain    = var.base_domain
  instance_type  = var.infra_type
  node_state     = var.infra_state
  ssh_key_pair   = local.ssh_key_name

  root_disk_size = var.root_disk_size
  data_disk_size = var.infra_data_disk_size

  use_privnet = var.use_privnet
  privnet_id  = local.privnet_id
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
