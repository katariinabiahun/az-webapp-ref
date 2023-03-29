locals {
  common = {
    location            = var.location
    resource_group_name = var.resource_group_name
  }
}

module "tf_az_api" {
  source = "./webapp"

  # location            = var.location
  # resource_group_name = var.resource_group_name
  common = local.common
}

module "vnet" {
  source = "./vnet"

  common = local.common
}
