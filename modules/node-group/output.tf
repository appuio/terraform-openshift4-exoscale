output "ip_address" {
  value = var.use_privnet ? exoscale_nic.nodes[*].ip_address : exoscale_compute.nodes[*].ip_address
}
