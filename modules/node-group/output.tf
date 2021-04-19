output "ip_address" {
  value = var.privnet_id != "" ? exoscale_nic.nodes[*].ip_address : exoscale_compute.nodes[*].ip_address
}
