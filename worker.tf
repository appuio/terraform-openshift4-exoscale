// Default worker group.
// Configured from var.worker_{count,size,state,disk_size}
module "worker" {
  source = "./modules/node-group"

  cluster_id     = var.cluster_id
  cluster_domain = local.cluster_domain
  role           = "worker"
  node_count     = var.worker_count
  region         = var.region
  template_id    = data.exoscale_template.rhcos.id
  base_domain    = var.base_domain
  instance_type  = var.worker_type
  node_state     = var.worker_state
  ssh_key_pair   = local.ssh_key_name

  root_disk_size = var.root_disk_size
  data_disk_size = var.worker_data_disk_size

  use_privnet = var.use_privnet
  privnet_id  = local.privnet_id
  privnet_gw  = local.privnet_gw

  api_int     = exoscale_domain_record.api_int.hostname
  ignition_ca = var.ignition_ca

  security_group_ids = concat(
    var.additional_security_group_ids,
    [exoscale_security_group.all_machines.id],
    var.infra_count == 0 ? [exoscale_security_group.infra.id] : [],
    var.use_instancepools ? [exoscale_security_group.worker.id] : []
  )

  affinity_group_capacity       = var.affinity_group_capacity
  additional_affinity_group_ids = var.additional_affinity_group_ids

  deploy_target_id = var.deploy_target_id

  bootstrap_bucket = var.bootstrap_bucket

  use_instancepool = var.use_instancepools
}

// Additional worker groups.
// Configured from var.additional_worker_groups
module "additional_worker" {
  for_each = var.additional_worker_groups

  source = "./modules/node-group"

  cluster_id     = var.cluster_id
  cluster_domain = local.cluster_domain

  role          = each.key
  node_count    = each.value.count
  instance_type = each.value.type
  // Default node_state to "running" if not specified in map entry
  node_state = each.value.state != null ? each.value.state : "running"

  root_disk_size = var.root_disk_size
  // Default data disk size to 0 if map entry doesn't have field disk_size
  data_disk_size = each.value.data_disk_size != null ? each.value.data_disk_size : 0

  region       = var.region
  template_id  = data.exoscale_template.rhcos.id
  base_domain  = var.base_domain
  ssh_key_pair = local.ssh_key_name

  use_privnet = var.use_privnet
  privnet_id  = local.privnet_id
  privnet_gw  = local.privnet_gw

  api_int     = exoscale_domain_record.api_int.hostname
  ignition_ca = var.ignition_ca

  security_group_ids = concat(
    var.additional_security_group_ids,
    [exoscale_security_group.all_machines.id],
    var.use_instancepools ? [exoscale_security_group.worker.id] : []
  )

  affinity_group_capacity = var.affinity_group_capacity
  additional_affinity_group_ids = concat(
    each.value.affinity_group_ids != null ? each.value.affinity_group_ids : [],
    var.additional_affinity_group_ids
  )

  deploy_target_id = var.deploy_target_id

  bootstrap_bucket = var.bootstrap_bucket

  use_instancepool = each.value.use_instancepool != null ? each.value.use_instancepool : var.use_instancepools
}
