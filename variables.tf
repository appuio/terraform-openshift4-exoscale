variable "cluster_id" {
  type = string
}

variable "region" {
  default = "ch-dk-2"
}

variable "rhcos_template" {
  type = string
}

variable "base_domain" {
  default = "ocp4-poc.appuio-beta.ch"
}

variable "ssh_key" {
  type    = string
}

variable "privnet_cidr" {
  default = "172.18.200.0/24"
}

variable "bootstrap_count" {
  type    = number
  default = 0
}

variable "worker_count" {
  type    = number
  default = 3
}
