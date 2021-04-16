module "worker" {
  source = "./modules/node-group"

  cluster_id      = var.cluster_id
  node_group_name = "worker"
  node_count      = var.worker_count
  region          = var.region
  template_id     = data.exoscale_compute_template.rhcos.id
  base_domain     = var.base_domain
  instance_size   = var.worker_size

  security_group_ids = [
    exoscale_security_group.all_machines.id,
    exoscale_security_group.worker.id,
  ]
}
