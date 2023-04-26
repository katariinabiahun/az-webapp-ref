locals {
  common = {
    location            = var.location
    resource_group_name = var.resource_group_name
  }
}

module "tf_az_api" {
  source = "./webapp"

  common             = local.common
  subnet_id_deleg    = module.vnet.subnet_id_deleg
  subnet_id_privlink = module.vnet.subnet_id_privlink
}

module "vnet" {
  source = "./vnet"

  common       = local.common
  app_insights = module.tf_az_api.app_insights
  kv           = module.tf_az_api.kv
  srvbus       = module.tf_az_api.srvbus
  pg           = module.tf_az_api.pg
}
