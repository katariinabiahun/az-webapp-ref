locals {

  # storage = yamldecode(file("${path.module}/storage.yaml"))

  # blob_stor = { for v in flatten([for stor_name, stor_value in local.storage :
  #   [for stat_name, stat_value in try(stor_value.static_website, {}) :
  #     {
  #       stor_name  = stor_name
  #       stor_value = stor_value
  #       stat_name  = stat_name
  #       stat_value = stat_value
  #     }
  #   ]
  # ]) : join("-", [v.stor_name, v.stat_name]) => v }

  # blob = { for v in flatten([for stor_name, stor_value in local.storage :
  #   [for blob_name, blob_value in try(stor_value.storage_blob, {}) :
  #     {
  #       stor_name  = stor_name
  #       stor_value = stor_value
  #       blob_name  = blob_name
  #       blob_value = blob_value
  #     }
  #   ]
  # ]) : v.blob_name => v }
}

resource "azurerm_static_site" "example" {
  name                = "staticwebsite"
  location            = var.common.location
  resource_group_name = var.common.resource_group_name
}
