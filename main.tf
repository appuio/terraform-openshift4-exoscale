locals {
  master_count      = 3
  ignition_template = "./templates/ignition.tmpl"
}

resource "random_id" "master" {
  count       = local.master_count
  prefix      = "master-"
  byte_length = 1
}
resource "random_id" "worker" {
  count       = var.worker_count
  prefix      = "node-"
  byte_length = 2
}

resource "exoscale_ssh_keypair" "admin" {
  name       = var.cluster_id
  public_key = var.ssh_key
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
resource "exoscale_compute" "bootstrap" {
  count        = var.bootstrap_count
  display_name = "bootstrap.${var.cluster_id}.${var.base_domain}"
  hostname     = "bootstrap"
  key_pair     = exoscale_ssh_keypair.admin.name
  zone         = var.region
  template_id  = data.exoscale_compute_template.rhcos.id
  size         = "Extra-large"
  disk_size    = 128
  security_groups = [
    exoscale_security_group.all_machines.name,
    exoscale_security_group.control_plane.name,
  ]
  user_data = base64encode(templatefile(local.ignition_template, {
    role       = "bootstrap"
    cluster_id = var.cluster_id
    region     = var.region
    hostname   = "bootstrap"
  }))
  depends_on = [
    exoscale_security_group_rules.all_machines,
    exoscale_security_group_rules.control_plane,
    exoscale_security_group_rules.worker,
  ]
}
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
