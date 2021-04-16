locals {
  master_count      = 1
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

# LBs
resource "exoscale_ipaddress" "api" {
  zone                     = var.region
  description              = "${var.cluster_id} elastic IP for API"
  healthcheck_mode         = "tcp" # HTTPS is not supported yet
  healthcheck_port         = 6443
  healthcheck_interval     = 5
  healthcheck_timeout      = 3
  healthcheck_strikes_ok   = 1
  healthcheck_strikes_fail = 2
}
resource "exoscale_domain_record" "api" {
  domain      = exoscale_domain.cluster.id
  name        = "api"
  ttl         = 60
  record_type = "A"
  content     = exoscale_ipaddress.api.ip_address
}

resource "exoscale_ipaddress" "ingress" {
  zone                     = var.region
  description              = "${var.cluster_id} elastic IP for ingress controller"
  healthcheck_mode         = "tcp" # HTTPS is not supported yet
  healthcheck_port         = 80
  healthcheck_interval     = 5
  healthcheck_timeout      = 3
  healthcheck_strikes_ok   = 1
  healthcheck_strikes_fail = 2
}
resource "exoscale_domain_record" "ingress" {
  domain      = exoscale_domain.cluster.id
  name        = "*.apps"
  ttl         = 60
  record_type = "A"
  content     = exoscale_ipaddress.ingress.ip_address
}

# Bootstrap
resource "exoscale_domain_record" "api_int_bootstrap" {
  count       = var.bootstrap_count
  domain      = exoscale_domain.cluster.id
  name        = "api-int"
  ttl         = 10
  record_type = "A"
  content     = exoscale_compute.bootstrap[count.index].ip_address
}
resource "exoscale_secondary_ipaddress" "bootstrap" {
  count      = var.bootstrap_count
  compute_id = exoscale_compute.bootstrap[0].id
  ip_address = exoscale_ipaddress.api.ip_address
}
