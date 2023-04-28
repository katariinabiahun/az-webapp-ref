locals {

  kv = yamldecode(file("${path.module}/kv.yaml"))

  key_vault = { for k, v in flatten([for kv_name, kv_value in local.kv :
    [for access_name, access_value in try(kv_value.access_policy, {}) :
      {
        kv_name      = kv_name
        kv_value     = kv_value
        access_name  = access_name
        access_value = access_value
      }
    ]
  ]) : join("-", [v.kv_name, v.access_name]) => v }

  key = { for k, v in flatten([for kv_name, kv_value in local.kv :
    [for key_name, key_value in try(kv_value.key, {}) :
      {
        kv_name   = kv_name
        key_name  = key_name
        key_value = key_value
      }
    ]
  ]) : join("-", [v.kv_name, v.key_name]) => v }

  # kv_secret = { for k, v in flatten([for kv_name, kv_value in local.kv :
  #   [for secret_name, secret_value in try(kv_value.secret, {}) :
  #     {
  #       kv_name      = kv_name
  #       secret_name  = secret_name
  #       secret_value = secret_value
  #     }
  #   ]
  # ]) : join("-", [v.kv_name, v.secret_name]) => v }

  #stor_obj_id = azurerm_storage_account.example[keys(local.blob_stor)[0]].identity.0.principal_id
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
  purge_protection_enabled   = each.value.kv_value.purge_protection_enabled

  # dynamic "access_policy" {
  #   for_each = local.key_vault

  #   content {
  #     tenant_id = data.azurerm_client_config.current.tenant_id
  #     object_id = each.value.access_name == "storage" ? azurerm_storage_account.example[keys(local.blob_stor)[0]].identity.0.principal_id : data.azurerm_client_config.current.object_id

  #     key_permissions    = each.value.access_value.key_permissions
  #     secret_permissions = each.value.access_value.secret_permissions
  #   }
  # }
}

# resource "azurerm_key_vault_secret" "example" {
#   for_each = local.kv_secret

#   name         = each.value.secret_value.name
#   value        = each.value.secret_value.value
#   key_vault_id = azurerm_key_vault.example[keys(local.key_vault)[0]].id
# }


# resource "azurerm_key_vault_access_policy" "storage" {
#   key_vault_id = azurerm_key_vault.example[keys(local.key_vault)[0]].id
#   tenant_id    = data.azurerm_client_config.current.tenant_id
#   object_id    = azurerm_storage_account.example[keys(local.blob_stor)[0]].identity.0.principal_id

#   key_permissions    = ["Get", "Create", "List", "Restore", "Recover", "UnwrapKey", "WrapKey", "Purge", "Encrypt", "Decrypt", "Sign", "Verify"]
#   secret_permissions = ["Get"]
# }

# data "azurerm_client_config" "currenttwo" {}

# resource "azurerm_key_vault_access_policy" "client" {
#   key_vault_id = azurerm_key_vault.example[keys(local.key_vault)[0]].id
#   tenant_id    = data.azurerm_client_config.current.tenant_id
#   object_id    = data.azurerm_client_config.currenttwo.object_id

#   key_permissions    = ["Get", "Create", "Delete", "List", "Restore", "Recover", "UnwrapKey", "WrapKey", "Purge", "Encrypt", "Decrypt", "Sign", "Verify", "GetRotationPolicy"]
#   secret_permissions = ["Get"]
# }

#customer-managed keys
#Key Vault Crypto Officer
data "azurerm_subscription" "primary" {}

resource "azurerm_role_assignment" "example" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Key Vault Crypto Officer" #"Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_key" "example" {
  for_each = local.key

  name         = each.value.key_name
  key_vault_id = azurerm_key_vault.example[keys(local.key_vault)[0]].id
  key_type     = each.value.key_value.key_type
  key_size     = each.value.key_value.key_size
  key_opts     = each.value.key_value.key_opts

  depends_on = [
    # azurerm_key_vault_access_policy.client,

    azurerm_key_vault.example #azurerm_key_vault_access_policy.storage
  ]
}
