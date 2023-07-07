locals {
  master_count = 3

  privnet_id = var.use_privnet ? exoscale_private_network.clusternet[0].id : ""
  privnet_gw = cidrhost(var.privnet_cidr, 1)

  ssh_key_name = var.existing_keypair != "" ? var.existing_keypair : exoscale_ssh_key.admin[0].name

  cluster_name   = var.cluster_name != "" ? var.cluster_name : var.cluster_id
  cluster_domain = "${local.cluster_name}.${var.base_domain}"
}

resource "exoscale_domain" "cluster" {
  name = local.cluster_domain
}

data "exoscale_domain_record" "exo_nameservers" {
  domain = exoscale_domain.cluster.name
  filter {
    record_type = "NS"
  }
}

data "exoscale_template" "rhcos" {
  zone       = var.region
  name       = var.rhcos_template
  visibility = "private"
}

resource "exoscale_ssh_key" "admin" {
  count      = var.existing_keypair != "" ? 0 : 1
  name       = "${var.cluster_id}-admin"
  public_key = var.ssh_key
}

resource "exoscale_private_network" "clusternet" {
  count       = var.use_privnet ? 1 : 0
  zone        = var.region
  name        = "${var.cluster_id}_clusternet"
  description = "${var.cluster_id} private network"
  start_ip    = cidrhost(var.privnet_cidr, 101)
  end_ip      = cidrhost(var.privnet_cidr, 253)
  netmask     = cidrnetmask(var.privnet_cidr)
}

resource "exoscale_domain_record" "api_int" {
  domain      = exoscale_domain.cluster.id
  name        = "api-int"
  ttl         = 60
  record_type = var.use_privnet ? "A" : "CNAME"
  content     = var.use_privnet ? module.lb.internal_vip : "api.${local.cluster_domain}"
}
