variable "node_count" {
  type = number
}

variable "role" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "cluster_domain" {
  type = string
}

variable "ssh_key_pair" {
  type    = string
  default = ""
}

variable "region" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "standard.extra-large"
}

variable "root_disk_size" {
  type    = number
  default = 120

  validation {
    condition     = var.root_disk_size >= 120
    error_message = "The minimum supported root disk size for OCP4 is 120GB."
  }
}

variable "data_disk_size" {
  type    = number
  default = 0

  validation {
    condition     = var.data_disk_size >= 0
    error_message = "Creating a data disk with size < 0 is not possible."
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
  default = "running"
}

variable "storage_disk_size" {
  type    = number
  default = 0

  validation {
    # minimum TBD
    condition     = var.storage_disk_size == 0 || var.storage_disk_size >= 180
    error_message = "The minimum supported storage cluster disk size is 180GB."
  }
}

variable "additional_affinity_group_ids" {
  type        = list(string)
  default     = []
  description = "List of additional affinity group IDs to configure on all nodes"
}

variable "deploy_target_id" {
  type        = string
  default     = ""
  description = "ID of special deployment target, e.g. dedicated hypervisors"
}
