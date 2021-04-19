variable "node_count" {
  type = number
}

variable "node_group_name" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "ssh_key_pair" {
  type    = string
  default = ""
}

variable "region" {
  type = string
}

variable "instance_size" {
  type    = string
  default = "Extra-large"
}

variable "disk_size" {
  type    = number
  default = 128
}

variable "template_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "base_domain" {
  type = string
}

variable "cluster_network_id" {
  type    = string
  default = "" # don't attach to private network
}

variable "api_int" {
  type = string
}

variable "ignition_ca" {
  type = string
}

variable "cluster_network_dhcp_reservation" {
  type    = string
  default = ""
}
