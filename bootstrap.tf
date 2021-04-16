resource "exoscale_compute" "bootstrap" {
  count        = var.bootstrap_count
  display_name = "bootstrap.${var.cluster_id}.${var.base_domain}"
  hostname     = "bootstrap"
  zone         = var.region
  template_id  = data.exoscale_compute_template.rhcos.id
  size         = "Extra-large"
  disk_size    = 128
  security_groups = [
    exoscale_security_group.all_machines.name,
    exoscale_security_group.control_plane.name,
  ]
  user_data = base64encode(<<-EOF
  {
      "ignition": {
          "version": "3.1.0",
          "config": {
              "merge": [
                  {
                      "source": "https://sos-${var.region}.exo.io/${var.cluster_id}-bootstrap-ignition/bootstrap.ign"
                  }
              ]
          }
      }
  }
  EOF
  )
  depends_on = [
    exoscale_security_group_rules.all_machines,
    exoscale_security_group_rules.control_plane,
    exoscale_security_group_rules.worker,
  ]
}
