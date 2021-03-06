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

variable "infra_count" {
  type    = number
  default = 3
}

variable "storage_count" {
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

variable "infra_size" {
  type    = string
  default = "Extra-large"
}

variable "storage_size" {
  type    = string
  default = "CPU-extra-large"
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

variable "infra_state" {
  type    = string
  default = "Running"
}

variable "storage_state" {
  type    = string
  default = "Running"
}

variable "storage_disk_size" {
  type    = number
  default = 180

  validation {
    condition     = var.storage_disk_size >= 180
    error_message = "The minimum supported storage disk size is 180GB."
  }
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

variable "hieradata_repo_user" {
  type = string
}

variable "control_vshn_net_token" {
  type = string
}
