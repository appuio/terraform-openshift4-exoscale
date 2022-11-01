# https://docs.openshift.com/container-platform/4.7/installing/installing_bare_metal/installing-bare-metal.html#installation-network-user-infra_installing-bare-metal
resource "exoscale_security_group" "all_machines" {
  name        = "${var.cluster_id}_all_machines"
  description = "${var.cluster_id} all machines"
}
resource "exoscale_security_group_rule" "all_machines_tcp" {
  for_each = {
    "Ingress Router metrics"                                                                                            = "1936,1936",
    "Host level services, including the node exporter on ports 9100-9101 and the Cluster Version Operator on port 9099" = "9000,9999",
    "The default ports that Kubernetes reserves, including the openshift-sdn port"                                      = "10250,10259",
    "Cilium health checks"                                                                                              = "4240,4240",
    "Cilium Hubble Server"                                                                                              = "4244,4244",
    "Cilium Hubble Relay"                                                                                               = "4245,4245",
    "Cilium Operator Prometheus metrics"                                                                                = "6942,6942",
    "Cilium Hubble Enterprise metrics"                                                                                  = "2112,2112",
    "Kubernetes NodePort TCP"                                                                                           = "30000,32767",
  }

  security_group_id = exoscale_security_group.all_machines.id

  type       = "INGRESS"
  protocol   = "TCP"
  start_port = split(",", each.value)[0]
  end_port   = split(",", each.value)[1]

  # This generates descriptions which match the descriptions used in module
  # version v2.4.0 and earlier. Please note that changing the description
  # recreates the rule.
  description = startswith(each.key, "The default ports that Kubernetes reserves") ? "The default ports that Kubernetes reserves" : each.key

  user_security_group_id = exoscale_security_group.all_machines.id
}

resource "exoscale_security_group_rule" "all_machines_udp" {
  for_each = {
    "openshift-sdn/OVNKubernetes VXLAN"                                   = "4789,4789",
    "openshift-sdn/OVNKubernetes GENEVE"                                  = "6081,6081",
    "Cilium VXLAN"                                                        = "8472,8472",
    "Host level services, including the node exporter on ports 9100-9101" = "9000,9999",
    "Kubernetes NodePort UDP"                                             = "30000,32767",
  }

  security_group_id = exoscale_security_group.all_machines.id

  type       = "INGRESS"
  protocol   = "UDP"
  start_port = split(",", each.value)[0]
  end_port   = split(",", each.value)[1]

  # This generates descriptions which match the descriptions used in module
  # version v2.4.0 and earlier. Please note that changing the description
  # recreates the rule.
  description = startswith(each.key, "openshift-sdn/OVNKubernetes") ? "VXLAN and GENEVE" : each.key

  user_security_group_id = exoscale_security_group.all_machines.id
}

resource "exoscale_security_group_rule" "all_machines_icmp" {
  security_group_id = exoscale_security_group.all_machines.id

  description = "ICMP Ping"
  type        = "INGRESS"
  protocol    = "ICMP"
  icmp_type   = 8
  cidr        = "0.0.0.0/0"
}

resource "exoscale_security_group_rule" "all_machines_ssh_v4" {
  security_group_id = exoscale_security_group.all_machines.id

  description = "SSH Access"
  type        = "INGRESS"
  protocol    = "TCP"
  start_port  = "22"
  end_port    = "22"
  cidr        = "0.0.0.0/0"
}

resource "exoscale_security_group_rule" "all_machines_ssh_v6" {
  security_group_id = exoscale_security_group.all_machines.id

  description = "SSH Access"
  type        = "INGRESS"
  protocol    = "TCP"
  start_port  = "22"
  end_port    = "22"
  cidr        = "::/0"
}

resource "exoscale_security_group" "control_plane" {
  name        = "${var.cluster_id}_control_plane"
  description = "${var.cluster_id} control plane nodes"
}

resource "exoscale_security_group_rule" "control_plane_etcd" {
  security_group_id = exoscale_security_group.control_plane.id

  description = "etcd server, peer, and metrics ports"
  type        = "INGRESS"
  protocol    = "TCP"
  start_port  = "2379"
  end_port    = "2380"

  user_security_group_id = exoscale_security_group.all_machines.id
}

resource "exoscale_security_group_rule" "control_plane_machine_config_server" {
  security_group_id = exoscale_security_group.control_plane.id

  description = "Machine Config server"
  type        = "INGRESS"
  protocol    = "TCP"
  start_port  = "22623"
  end_port    = "22623"

  user_security_group_id = module.lb.security_group_id
}
resource "exoscale_security_group_rule" "control_plane_kubernetes_api" {
  security_group_id = exoscale_security_group.control_plane.id

  description = "Kubernetes API"
  type        = "INGRESS"
  protocol    = "TCP"
  start_port  = "6443"
  end_port    = "6443"

  user_security_group_id = exoscale_security_group.all_machines.id
}

resource "exoscale_security_group" "infra" {
  name        = "${var.cluster_id}_infra"
  description = "${var.cluster_id} infra nodes"
}
resource "exoscale_security_group_rule" "infra" {
  for_each = {
    HTTP  = "80"
    HTTPS = "443"
  }

  security_group_id = exoscale_security_group.infra.id

  type        = "INGRESS"
  description = "Ingress controller TCP"
  protocol    = "TCP"
  start_port  = each.value
  end_port    = each.value

  user_security_group_id = module.lb.security_group_id
}

resource "exoscale_security_group" "storage" {
  name        = "${var.cluster_id}_storage"
  description = "${var.cluster_id} storage nodes"
}

resource "exoscale_security_group_rule" "storage" {
  for_each = {
    "Ceph Messenger v1" = "3300,3300",
    "Ceph Messenger v2" = "6789,6789",
    "Ceph daemons"      = "6800,7300",
  }

  security_group_id = exoscale_security_group.storage.id

  type        = "INGRESS"
  protocol    = "TCP"
  description = "Ceph host-network traffic"
  start_port  = split(",", each.value)[0]
  end_port    = split(",", each.value)[1]

  user_security_group_id = exoscale_security_group.all_machines.id
}
