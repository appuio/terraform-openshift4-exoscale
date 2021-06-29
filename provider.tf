terraform {
  required_version = ">= 0.14"
  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.23"
    }
    gitfile = {
      source  = "igal-s/gitfile"
      version = "1.0.0"
    }
  }
}
