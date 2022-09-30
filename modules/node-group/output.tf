output "ip_address" {
  value = var.use_privnet ? exoscale_compute_instance.nodes[*].network_interface[0].ip_address : exoscale_compute_instance.nodes[*].public_ip_address
}
