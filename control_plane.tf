module "master" {
  source = "./modules/node-group/"

  cluster_id      = var.cluster_id
  node_group_name = "master"
  node_count      = local.master_count
  region          = var.region
  template_id     = data.exoscale_compute_template.rhcos.id
  base_domain     = var.base_domain
  instance_size   = "Extra-large"

  security_group_ids = [
    exoscale_security_group.all_machines.id,
    exoscale_security_group.control_plane.id,
  ]
}
