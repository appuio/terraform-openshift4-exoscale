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

variable "root_disk_size" {
  type    = number
  default = 120

  validation {
    condition     = var.root_disk_size >= 120
    error_message = "The minimum supported root disk size is 120GB."
  }
}

variable "worker_data_disk_size" {
  type    = number
  default = 0

  validation {
    condition     = var.worker_data_disk_size >= 0
    error_message = "The worker data disk size cannot be negative."
  }
}

variable "storage_cluster_disk_size" {
  type    = number
  default = 180

  validation {
    condition     = var.storage_cluster_disk_size >= 180
    error_message = "The minimum supported storage cluster disk size is 180GB."
  }
}

variable "additional_worker_groups" {
  type    = map(object({ size = string, count = number, data_disk_size = optional(number), state = optional(string), affinity_group_ids = optional(list(string)) }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.additional_worker_groups :
      !contains(["worker", "master", "infra", "storage"], k) &&
      v.count > 0 &&
      (v.data_disk_size != null ? v.data_disk_size >= 0 : true) &&
      (v.state == null || v.state == "Running" || v.state == "Stopped")
    ])
    // Cannot use any of the nicer string formatting options because
    // error_message validation is dumb, cf.
    // https://github.com/hashicorp/terraform/issues/24123
    error_message = "Your configuration of `additional_worker_groups` violates one of the following constraints:\n * The worker data disk size cannot be negative.\n * Additional worker group names cannot be 'worker', 'master', 'infra', or 'storage'.\n * The only valid worker states are 'Running' or 'Stopped'.\n * The worker count cannot be less than 0."
  }
}

variable "additional_affinity_group_ids" {
  type        = list(string)
  default     = []
  description = "List of additional affinity group IDs to configure on all nodes"
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
