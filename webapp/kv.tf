locals {

  kv = yamldecode(file("${path.module}/kv.yaml"))

  key_vault = { for k, v in flatten([for kv_name, kv_value in local.kv :
    {
      kv_name  = kv_name
      kv_value = kv_value
    }
  ]) : v.kv_name => v }

  kv_accpol = { for k, v in flatten([for kv_name, kv_value in local.kv :
    [for access_name, access_value in try(kv_value.access_policy, {}) :
      {
        kv_name      = kv_name
        kv_value     = kv_value
        access_name  = access_name
        access_value = access_value
      }
    ]
  ]) : v.access_name => v }

  key = { for k, v in flatten([for kv_name, kv_value in local.kv :
    [for key_name, key_value in try(kv_value.key, {}) :
      {
        kv_name   = kv_name
        key_name  = key_name
        key_value = key_value
      }
    ]
  ]) : join("-", [v.kv_name, v.key_name]) => v }

  object_ids = {
    "storage" = azurerm_storage_account.example[keys(local.blob_stor)[0]].identity.0.principal_id
    "user"    = data.azurerm_client_config.current.object_id
    "webapp"  = azurerm_linux_function_app.example[keys(local.func)[0]].identity.0.principal_id
  }
}

data "azurerm_client_config" "current" {}
data "azurerm_subscription" "primary" {}

resource "azurerm_key_vault" "example" {
  for_each = local.key_vault

  name                       = each.value.kv_value.name
  location                   = var.common.location
  resource_group_name        = var.common.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = each.value.kv_value.sku_name
  soft_delete_retention_days = each.value.kv_value.soft_delete_retention_days
  purge_protection_enabled   = each.value.kv_value.purge_protection_enabled
}

resource "azurerm_key_vault_access_policy" "example" {
  for_each = local.kv_accpol

  key_vault_id = azurerm_key_vault.example[keys(local.key_vault)[0]].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = lookup(local.object_ids, each.key)

  key_permissions    = each.value.access_value.key_permissions
  secret_permissions = each.value.access_value.secret_permissions
}

# resource "azurerm_role_assignment" "example" {
#   scope                = data.azurerm_subscription.primary.id
#   role_definition_name = "Key Vault Crypto Officer"
#   principal_id         = data.azurerm_client_config.current.object_id
# }

resource "azurerm_key_vault_key" "example" {
  for_each = local.key

  name         = each.value.key_name
  key_vault_id = azurerm_key_vault.example[keys(local.key_vault)[0]].id
  key_type     = each.value.key_value.key_type
  key_size     = each.value.key_value.key_size
  key_opts     = each.value.key_value.key_opts

  depends_on = [
    azurerm_key_vault_access_policy.example
  ]
}
