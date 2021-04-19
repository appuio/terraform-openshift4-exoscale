
# LBs
#resource "exoscale_ipaddress" "api" {
#  zone                     = var.region
#  description              = "${var.cluster_id} elastic IP for API"
#  healthcheck_mode         = "tcp" # HTTPS is not supported yet
#  healthcheck_port         = 6443
#  healthcheck_interval     = 5
#  healthcheck_timeout      = 3
#  healthcheck_strikes_ok   = 1
#  healthcheck_strikes_fail = 2
#}
#resource "exoscale_domain_record" "api" {
#  domain      = exoscale_domain.cluster.id
#  name        = "api"
#  ttl         = 60
#  record_type = "A"
#  content     = exoscale_ipaddress.api.ip_address
#}

#resource "exoscale_ipaddress" "ingress" {
#  zone                     = var.region
#  description              = "${var.cluster_id} elastic IP for ingress controller"
#  healthcheck_mode         = "tcp" # HTTPS is not supported yet
#  healthcheck_port         = 80
#  healthcheck_interval     = 5
#  healthcheck_timeout      = 3
#  healthcheck_strikes_ok   = 1
#  healthcheck_strikes_fail = 2
#}
#resource "exoscale_domain_record" "ingress" {
#  domain      = exoscale_domain.cluster.id
#  name        = "*.apps"
#  ttl         = 60
#  record_type = "A"
#  content     = exoscale_ipaddress.ingress.ip_address
#}
