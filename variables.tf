variable "cluster_id" {
  type        = string
  description = "The cluster's Project Syn ID"
}

variable "cluster_name" {
  type        = string
  description = "The cluster's display name. If this is not set, cluster_id is used"
  default     = ""
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
  default = 4
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

variable "worker_type" {
  type    = string
  default = "standard.extra-large"
}

variable "infra_type" {
  type    = string
  default = "standard.extra-large"
}

variable "storage_type" {
  type    = string
  default = "cpu.extra-large"
}

variable "master_type" {
  type    = string
  default = "standard.extra-large"
}

variable "bootstrap_state" {
  type    = string
  default = "running"
}

variable "master_state" {
  type    = string
  default = "running"
}

variable "worker_state" {
  type    = string
  default = "running"
}

variable "infra_state" {
  type    = string
  default = "running"
}

variable "storage_state" {
  type    = string
  default = "running"
}

variable "root_disk_size" {
  type    = number
  default = 100

  validation {
    condition     = var.root_disk_size >= 100
    error_message = "The minimum supported root disk size is 100GB."
  }
}

variable "infra_data_disk_size" {
  type    = number
  default = 0

  validation {
    condition     = var.infra_data_disk_size >= 0
    error_message = "The infra data disk size cannot be negative."
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
  type    = map(object({ type = string, count = number, data_disk_size = optional(number), state = optional(string), affinity_group_ids = optional(list(string)) }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.additional_worker_groups :
      !contains(["worker", "master", "infra", "storage"], k) &&
      v.count >= 0 &&
      (v.data_disk_size != null ? v.data_disk_size >= 0 : true) &&
      (v.state != null ? lower(v.state) == "running" || lower(v.state) == "stopped" : true)
    ])
    // Cannot use any of the nicer string formatting options because
    // error_message validation is dumb, cf.
    // https://github.com/hashicorp/terraform/issues/24123
    error_message = "Your configuration of `additional_worker_groups` violates one of the following constraints:\n * The worker data disk size cannot be negative.\n * Additional worker group names cannot be 'worker', 'master', 'infra', or 'storage'.\n * The only valid worker states are 'running' or 'stopped'.\n * The worker count cannot be less than 0."
  }
}

variable "additional_affinity_group_ids" {
  type        = list(string)
  default     = []
  description = "List of additional affinity group IDs to configure on all nodes"
}

variable "additional_security_group_ids" {
  type        = list(string)
  default     = []
  description = "List of additional security group IDs to configure on worker nodes"
}

variable "deploy_target_id" {
  type        = string
  default     = ""
  description = "ID of special deployment target, e.g. dedicated hypervisors"
}

variable "ignition_ca" {
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

variable "team" {
  type        = string
  description = "Team to assign the load balancers to in Icinga. All lower case."
  default     = ""
}

variable "lb_enable_proxy_protocol" {
  type        = bool
  description = "Enable the PROXY protocol on the loadbalancers. WARNING: Connections will fail until you enable the same on the OpenShift router as well"
  default     = false
}

variable "additional_lb_networks" {
  type        = list(string)
  description = "List of UUIDs of additional Exoscale private networks to attach"
  default     = []
}
