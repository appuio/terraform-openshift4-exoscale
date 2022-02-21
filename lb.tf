module "lb" {
  source = "git::https://github.com/appuio/terraform-modules.git//modules/vshn-lbaas-exoscale?ref=v2.4.0"

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

  api_backends           = exoscale_domain_record.etcd[*].hostname
  router_backends        = module.infra.ip_address[*]
  bootstrap_node         = var.bootstrap_count > 0 ? module.bootstrap.ip_address[0] : ""
  lb_exoscale_api_key    = var.lb_exoscale_api_key
  lb_exoscale_api_secret = var.lb_exoscale_api_secret
  hieradata_repo_user    = var.hieradata_repo_user
  enable_proxy_protocol  = var.lb_enable_proxy_protocol
  additional_networks    = var.additional_lb_networks

  cluster_security_group_names = [
    exoscale_security_group.all_machines.name
  ]

  depends_on = [
    exoscale_domain.cluster,
  ]
}
