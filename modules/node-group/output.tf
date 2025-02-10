locals {
  instance_pool_ips = var.use_instancepool ? flatten(exoscale_instance_pool.nodes[*].instances[*].public_ip_address) : []
  instance_ips      = var.use_privnet ? exoscale_compute_instance.nodes[*].network_interface[0].ip_address : exoscale_compute_instance.nodes[*].public_ip_address
}
output "ip_address" {
  value = var.use_instancepool ? local.instance_pool_ips : local.instance_ips
}
