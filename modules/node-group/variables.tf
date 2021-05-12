variable "node_count" {
  type = number
}

variable "role" {
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
  default = 120

  validation {
    condition     = var.disk_size >= 120
    error_message = "The minimum supported disk size for OCP4 is 120GB."
  }
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

variable "use_privnet" {
  type    = bool
  default = false
}

variable "privnet_id" {
  type    = string
  default = ""
}

variable "privnet_gw" {
  type    = string
  default = ""
}

variable "api_int" {
  type = string
}

variable "ignition_ca" {
  type = string
}

variable "bootstrap_bucket" {
  type = string
}

variable "privnet_dhcp_reservation" {
  type    = string
  default = ""
}

variable "node_state" {
  type    = string
  default = "Running"
}

variable "storage_disk_size" {
  type    = number
  default = 0

  validation {
    # minimum TBD
    condition     = var.storage_disk_size == 0 || var.storage_disk_size >= 180
    error_message = "The minimum supported storage disk size is 180GB."
  }
}
