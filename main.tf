locals {
  master_count = 3
  api_int_ip   = "172.18.200.100"
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
  zone         = var.region
  name         = "${var.cluster_id}_clusternet"
  display_text = "${var.cluster_id} private network"
  start_ip     = "172.18.200.101"
  end_ip       = "172.18.200.253"
  netmask      = "255.255.255.0"
}

resource "exoscale_domain_record" "api_int" {
  domain      = exoscale_domain.cluster.id
  name        = "api-int"
  ttl         = 60
  record_type = "A"
  content     = local.api_int_ip
}
