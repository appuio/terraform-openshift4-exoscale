terraform {
  required_version = ">= 0.14"
  // Use experimental feature to allow making object fields optional, cf.
  // https://www.terraform.io/docs/language/expressions/type-constraints.html#experimental-optional-object-type-attributes
  //
  // While there's no guarantee this feature doesn't see breaking changes even
  // in minor releases, I think the upsides to allow users to omit some
  // configurations for additional worker groups (e.g. node state, disk size)
  // outweigh potential changes that we need to make in the future.
  // -SG, 2021-07-29
  experiments = [module_variable_optional_attrs]
  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.27"
    }
    gitfile = {
      source  = "igal-s/gitfile"
      version = "1.0.0"
    }
  }
}
