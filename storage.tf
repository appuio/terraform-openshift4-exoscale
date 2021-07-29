module "storage" {
  source = "./modules/node-group"

  cluster_id    = var.cluster_id
  role          = "storage"
  node_count    = var.storage_count
  region        = var.region
  template_id   = data.exoscale_compute_template.rhcos.id
  base_domain   = var.base_domain
  instance_size = var.storage_size
  node_state    = var.storage_state
  ssh_key_pair  = local.ssh_key_name

  root_disk_size = var.root_disk_size

  // We never configure a data disk for storage cluster nodes
  // Instead, we keep the `storage_disk_size` special case to provision
  // dedicated storage cluster nodes for now.
  storage_disk_size = var.storage_cluster_disk_size

  use_privnet = var.use_privnet
  privnet_id  = var.use_privnet ? exoscale_network.clusternet.id : ""
  privnet_gw  = local.privnet_gw

  api_int     = exoscale_domain_record.api_int.hostname
  ignition_ca = var.ignition_ca

  security_group_ids = [
    exoscale_security_group.all_machines.id,
    exoscale_security_group.storage.id,
  ]

  bootstrap_bucket = var.bootstrap_bucket
}
