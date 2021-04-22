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
  type = string
}

variable "ssh_key" {
  type = string
}

variable "existing_keypair" {
  type    = string
  default = ""
}

variable "privnet_cidr" {
  type    = string
  default = "172.18.200.0/24"
}

variable "use_privnet" {
  type    = bool
  default = false
}

variable "bootstrap_count" {
  type    = number
  default = 0
}

variable "worker_count" {
  type    = number
  default = 3
}

variable "master_count" {
  type    = number
  default = 3
}

variable "lb_count" {
  type    = number
  default = 2
}

variable "worker_size" {
  type    = string
  default = "Extra-large"
}

variable "bootstrap_state" {
  type    = string
  default = "Running"
}

variable "master_state" {
  type    = string
  default = "Running"
}

variable "worker_state" {
  type    = string
  default = "Running"
}

variable "ignition_ca" {
  type = string
}

variable "lb_exoscale_api_key" {
  type = string
}
variable "lb_exoscale_api_secret" {
  type = string
}

variable "bootstrap_bucket" {
  type = string
}
