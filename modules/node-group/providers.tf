terraform {
  required_version = ">= 0.14"
  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.30"
    }
  }
}
