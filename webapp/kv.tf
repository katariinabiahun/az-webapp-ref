locals {

  kv = yamldecode(file("${path.module}/kv.yaml"))

  key_vault = { for k, v in flatten([for kv_name, kv_value in local.kv :
    {
      kv_name  = kv_name
      kv_value = kv_value
    }
  ]) : v.kv_name => v }

  kv_secret = { for k, v in flatten([for kv_name, kv_value in local.kv :
    [for secret_name, secret_value in try(kv_value.secret, {}) :
      {
        kv_name      = kv_name
        secret_name  = secret_name
        secret_value = secret_value
      }
    ]
  ]) : join("-", [v.kv_name, v.secret_name]) => v }
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "example" {
  for_each = local.key_vault

  name                       = each.value.kv_value.name
  location                   = var.common.location
  resource_group_name        = var.common.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = each.value.kv_value.sku_name
  soft_delete_retention_days = each.value.kv_value.soft_delete_retention_days

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions    = each.value.kv_value.key_permissions
    secret_permissions = each.value.kv_value.secret_permissions
  }
}

# resource "azurerm_key_vault_secret" "example" {
#   for_each = local.kv_secret

#   name         = each.value.secret_value.name
#   value        = each.value.secret_value.value
#   key_vault_id = azurerm_key_vault.example[keys(local.key_vault)[0]].id
# }
