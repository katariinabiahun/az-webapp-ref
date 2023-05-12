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
    "storage" = azurerm_static_site.example.identity.0.principal_id #storage >> static web site
    "user"    = data.azurerm_client_config.current.object_id
    "webapp"  = azurerm_linux_web_app.example[keys(local.webapp)[0]].identity.0.principal_id
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
