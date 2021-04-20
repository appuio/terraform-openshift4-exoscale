locals {
  master_count = 3
  privnet_api  = cidrhost(var.privnet_cidr, 100)
  privnet_gw   = cidrhost(var.privnet_cidr, 1)
}

resource "exoscale_domain" "cluster" {
  name = "${var.cluster_id}.${var.base_domain}"
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

resource "exoscale_network" "clusternet" {
  count        = var.use_privnet ? 1 : 0
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
  # TODO: fix when LBs are terraformed
  record_type = var.use_privnet ? "A" : "CNAME"
  content     = var.use_privnet ? local.privnet_api : "api.${var.cluster_id}.${var.base_domain}"
}
