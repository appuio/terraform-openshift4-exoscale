terraform {
  required_version = ">= 1.3.0"
  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "0.62.3"
    }
    gitfile = {
      source  = "igal-s/gitfile"
      version = "1.0.0"
    }
  }
}
