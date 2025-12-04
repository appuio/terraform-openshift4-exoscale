module "lb" {
  source = "git::https://github.com/appuio/terraform-modules.git//modules/vshn-lbaas-exoscale?ref=v6.8.1"

  exoscale_domain_name = exoscale_domain.cluster.name
  cluster_network = {
    enabled           = var.use_privnet
    name              = local.privnet_id
    internal_vip_host = "100"
  }
  cluster_id             = var.cluster_id
  region                 = var.region
  ssh_key_name           = local.ssh_key_name
  lb_count               = var.lb_count
  control_vshn_net_token = var.control_vshn_net_token
  team                   = var.team
  disk_size              = var.lb_disk_size

  api_backends          = exoscale_domain_record.etcd[*].hostname
  router_backends       = var.infra_count > 0 ? module.infra.ip_address[*] : module.worker.ip_address[*]
  bootstrap_node        = var.bootstrap_count > 0 ? module.bootstrap.ip_address[0] : ""
  hieradata_repo_user   = var.hieradata_repo_user
  enable_proxy_protocol = var.lb_enable_proxy_protocol
  additional_networks   = var.additional_lb_networks

  cluster_security_group_ids = concat(
    [exoscale_security_group.all_machines.id],
    var.additional_lb_security_group_ids
  )

  additional_affinity_group_ids = var.additional_affinity_group_ids

  deploy_target_id = var.deploy_target_id

  depends_on = [
    exoscale_domain.cluster,
    exoscale_security_group.all_machines,
  ]
}
