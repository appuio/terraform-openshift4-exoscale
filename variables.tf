variable "cluster_id" {
  type = string
}

variable "region" {
  type    = string
  default = "ch-dk-2"
}

variable "rhcos_template" {
  type = string
}

variable "base_domain" {
  default = "appuio-beta.ch"
}

variable "ssh_key" {
  type = string
}

variable "existing_keypair" {
  type    = string
  default = ""
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

variable "worker_size" {
  type    = string
  default = "Extra-large"
}

variable "ignition_ca" {
  type = string
}
