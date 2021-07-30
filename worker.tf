// Default worker group.
// Configured from var.worker_{count,size,state}
module "worker" {
  source = "./modules/node-group"

  cluster_id    = var.cluster_id
  role          = "worker"
  node_count    = var.worker_count
  region        = var.region
  template_id   = data.exoscale_compute_template.rhcos.id
  base_domain   = var.base_domain
  instance_size = var.worker_size
  node_state    = var.worker_state
  ssh_key_pair  = local.ssh_key_name

  use_privnet = var.use_privnet
  privnet_id  = var.use_privnet ? exoscale_network.clusternet.id : ""
  privnet_gw  = local.privnet_gw

  api_int     = exoscale_domain_record.api_int.hostname
  ignition_ca = var.ignition_ca

  security_group_ids = [
    exoscale_security_group.all_machines.id,
  ]

  bootstrap_bucket = var.bootstrap_bucket
}

// Additional worker groups.
// Configured from var.additional_worker_groups
module "additional_worker" {
  for_each = var.additional_worker_groups

  source = "./modules/node-group"

  cluster_id = var.cluster_id

  role          = each.key
  node_count    = each.value.count
  instance_size = each.value.size
  // Default node_state to "Running" if not specified in map entry
  node_state = each.value.state != null ? each.value.state : "Running"
  // Default disk size to 120GB if map entry doesn't have field disk_size
  disk_size = each.value.disk_size != null ? each.value.disk_size : 120

  region       = var.region
  template_id  = data.exoscale_compute_template.rhcos.id
  base_domain  = var.base_domain
  ssh_key_pair = local.ssh_key_name

  use_privnet = var.use_privnet
  privnet_id  = var.use_privnet ? exoscale_network.clusternet.id : ""
  privnet_gw  = local.privnet_gw

  api_int     = exoscale_domain_record.api_int.hostname
  ignition_ca = var.ignition_ca

  security_group_ids = [
    exoscale_security_group.all_machines.id,
  ]

  bootstrap_bucket = var.bootstrap_bucket
}
