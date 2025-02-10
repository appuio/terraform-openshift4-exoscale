module "master" {
  source = "./modules/node-group/"

  cluster_id     = var.cluster_id
  cluster_domain = local.cluster_domain
  role           = "master"
  node_count     = var.master_count
  region         = var.region
  template_id    = data.exoscale_template.rhcos.id
  base_domain    = var.base_domain
  instance_type  = var.master_type
  node_state     = var.master_state
  ssh_key_pair   = local.ssh_key_name

  root_disk_size = var.root_disk_size

  use_privnet = var.use_privnet
  privnet_id  = local.privnet_id
  privnet_gw  = local.privnet_gw

  api_int     = exoscale_domain_record.api_int.hostname
  ignition_ca = var.ignition_ca

  security_group_ids = [
    exoscale_security_group.all_machines.id,
    exoscale_security_group.control_plane.id,
  ]

  affinity_group_capacity       = var.affinity_group_capacity
  additional_affinity_group_ids = var.additional_affinity_group_ids

  deploy_target_id = var.deploy_target_id

  bootstrap_bucket = var.bootstrap_bucket

  # Don't use instance pool for control plane nodes, since scaling them is
  # much easier without an instance pool by just stopping/scaling/starting the
  # same VM.
  use_instancepool = false
}

resource "exoscale_domain_record" "etcd" {
  count       = lower(var.master_state) == "running" ? var.master_count : 0
  domain      = exoscale_domain.cluster.id
  name        = "etcd-${count.index}"
  ttl         = 60
  record_type = "A"
  content     = module.master.ip_address[count.index]
}
