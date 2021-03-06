locals {
  master_count   = 3
  privnet_api    = cidrhost(var.privnet_cidr, 100)
  privnet_gw     = cidrhost(var.privnet_cidr, 1)
  cluster_domain = "${var.cluster_id}.${var.base_domain}"
  ssh_key_name   = var.existing_keypair != "" ? var.existing_keypair : exoscale_ssh_keypair.admin[0].name
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

data "exoscale_compute_template" "rhcos" {
  zone   = var.region
  name   = var.rhcos_template
  filter = "mine"
}

resource "exoscale_ssh_keypair" "admin" {
  count      = var.existing_keypair != "" ? 0 : 1
  name       = "${var.cluster_id}-admin"
  public_key = var.ssh_key
}

resource "exoscale_network" "clusternet" {
  zone         = var.region
  name         = "${var.cluster_id}_clusternet"
  display_text = "${var.cluster_id} private network"
  start_ip     = cidrhost(var.privnet_cidr, 101)
  end_ip       = cidrhost(var.privnet_cidr, 253)
  netmask      = cidrnetmask(var.privnet_cidr)
}

resource "exoscale_domain_record" "api_int" {
  domain      = exoscale_domain.cluster.id
  name        = "api-int"
  ttl         = 60
  record_type = var.use_privnet ? "A" : "CNAME"
  content     = var.use_privnet ? local.privnet_api : "api.${var.cluster_id}.${var.base_domain}"
}
