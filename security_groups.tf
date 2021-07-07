# https://docs.openshift.com/container-platform/4.7/installing/installing_bare_metal/installing-bare-metal.html#installation-network-user-infra_installing-bare-metal
resource "exoscale_security_group" "all_machines" {
  name        = "${var.cluster_id}_all_machines"
  description = "${var.cluster_id} all machines"
}
resource "exoscale_security_group_rules" "all_machines" {
  security_group = exoscale_security_group.all_machines.name

  ingress {
    description              = "Ingress Router metrics"
    protocol                 = "TCP"
    ports                    = ["1936"]
    user_security_group_list = [exoscale_security_group.all_machines.name]
  }
  ingress {
    description              = "Host level services, including the node exporter on ports 9100-9101 and the Cluster Version Operator on port 9099"
    protocol                 = "TCP"
    ports                    = ["9000-9999"]
    user_security_group_list = [exoscale_security_group.all_machines.name]
  }
  ingress {
    description              = "The default ports that Kubernetes reserves"
    protocol                 = "TCP"
    ports                    = ["10250-10259"]
    user_security_group_list = [exoscale_security_group.all_machines.name]
  }
  ingress {
    description              = "openshift-sdn"
    protocol                 = "TCP"
    ports                    = ["10256"]
    user_security_group_list = [exoscale_security_group.all_machines.name]
  }

  ingress {
    description              = "VXLAN and GENEVE"
    protocol                 = "UDP"
    ports                    = ["4789", "6081"]
    user_security_group_list = [exoscale_security_group.all_machines.name]
  }
  ingress {
    description              = "Host level services, including the node exporter on ports 9100-9101"
    protocol                 = "UDP"
    ports                    = ["9000-9999"]
    user_security_group_list = [exoscale_security_group.all_machines.name]
  }

  ingress {
    description              = "Kubernetes NodePort TCP"
    protocol                 = "TCP"
    ports                    = ["30000-32767"]
    user_security_group_list = [exoscale_security_group.all_machines.name]
  }
  ingress {
    description              = "Kubernetes NodePort UDP"
    protocol                 = "UDP"
    ports                    = ["30000-32767"]
    user_security_group_list = [exoscale_security_group.all_machines.name]
  }

  ingress {
    description = "ICMP Ping"
    protocol    = "ICMP"
    icmp_type   = 8
    cidr_list   = ["0.0.0.0/0"]
  }
  # TODO: Keep or jump via LBs?
  ingress {
    description = "SSH Access"
    protocol    = "TCP"
    ports       = ["22"]
    cidr_list   = ["0.0.0.0/0", "::/0"]
  }
}

resource "exoscale_security_group" "load_balancers" {
  name        = "${var.cluster_id}_load_balancers"
  description = "${var.cluster_id} load balancer VMs"
}
resource "exoscale_security_group_rules" "load_balancers" {
  security_group = exoscale_security_group.load_balancers.name
  ingress {
    description = "Kubernetes API"
    protocol    = "TCP"
    ports       = ["6443"]
    cidr_list   = ["0.0.0.0/0", "::/0"]
  }
  ingress {
    description = "Ingress controller TCP"
    protocol    = "TCP"
    ports       = ["80", "443"]
    cidr_list   = ["0.0.0.0/0", "::/0"]
  }
  ingress {
    description = "Ingress controller UDP"
    protocol    = "UDP"
    ports       = ["80", "443"]
    cidr_list   = ["0.0.0.0/0", "::/0"]
  }
  ingress {
    description              = "Machine Config server"
    protocol                 = "TCP"
    ports                    = ["22623"]
    user_security_group_list = [exoscale_security_group.all_machines.name]
  }
}

resource "exoscale_security_group" "control_plane" {
  name        = "${var.cluster_id}_control_plane"
  description = "${var.cluster_id} control plane nodes"
}
resource "exoscale_security_group_rules" "control_plane" {
  security_group = exoscale_security_group.control_plane.name
  ingress {
    description              = "etcd server, peer, and metrics ports"
    protocol                 = "TCP"
    ports                    = ["2379-2380"]
    user_security_group_list = [exoscale_security_group.all_machines.name]
  }
  ingress {
    description              = "Machine Config server"
    protocol                 = "TCP"
    ports                    = ["22623"]
    user_security_group_list = [exoscale_security_group.load_balancers.name]
  }

  ingress {
    description              = "Kubernetes API"
    protocol                 = "TCP"
    ports                    = ["6443"]
    user_security_group_list = [exoscale_security_group.all_machines.name]
  }
}

resource "exoscale_security_group" "infra" {
  name        = "${var.cluster_id}_infra"
  description = "${var.cluster_id} infra nodes"
}
resource "exoscale_security_group_rules" "infra" {
  security_group = exoscale_security_group.infra.name
  ingress {
    description              = "Ingress controller TCP"
    protocol                 = "TCP"
    ports                    = ["80", "443"]
    user_security_group_list = [exoscale_security_group.load_balancers.name]
  }
}

resource "exoscale_security_group" "storage" {
  name        = "${var.cluster_id}_storage"
  description = "${var.cluster_id} storage nodes"
}

resource "exoscale_security_group_rules" "storage" {
  security_group = exoscale_security_group.storage.name

  ingress {
    # Ceph ingress.
    # MONs listen on
    #  * 3300->Ceph Messenger v2
    #  * 6789->Ceph Messenger v1
    # Other Ceph daemons pick a port from 6800-7300
    description              = "Ceph host-network traffic"
    protocol                 = "TCP"
    ports                    = ["3300", "6789", "6800-7300"]
    user_security_group_list = [exoscale_security_group.all_machines.name]
  }
}
