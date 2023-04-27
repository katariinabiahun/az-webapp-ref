locals {

  kv = yamldecode(file("${path.module}/kv.yaml"))

  key_vault = { for k, v in flatten([for kv_name, kv_value in local.kv :
    {
      kv_name  = kv_name
      kv_value = kv_value
    }
  ]) : v.kv_name => v }

  # kv_secret = { for k, v in flatten([for kv_name, kv_value in local.kv :
  #   [for secret_name, secret_value in try(kv_value.secret, {}) :
  #     {
  #       kv_name      = kv_name
  #       secret_name  = secret_name
  #       secret_value = secret_value
  #     }
  #   ]
  # ]) : join("-", [v.kv_name, v.secret_name]) => v }
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
  purge_protection_enabled   = true

  #public_network_access_enabled = false

  # access_policy {
  #   tenant_id = data.azurerm_client_config.current.tenant_id
  #   object_id = data.azurerm_client_config.current.object_id

  #   key_permissions    = each.value.kv_value.key_permissions
  #   secret_permissions = each.value.kv_value.secret_permissions
  # }
}

# resource "azurerm_key_vault_secret" "example" {
#   for_each = local.kv_secret

#   name         = each.value.secret_value.name
#   value        = each.value.secret_value.value
#   key_vault_id = azurerm_key_vault.example[keys(local.key_vault)[0]].id
# }

#customer-managed keys
resource "azurerm_key_vault_access_policy" "storage" {
  key_vault_id = azurerm_key_vault.example[keys(local.key_vault)[0]].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_storage_account.example[keys(local.blob_stor)[0]].identity.0.principal_id

  key_permissions    = ["Get", "Create", "List", "Restore", "Recover", "UnwrapKey", "WrapKey", "Purge", "Encrypt", "Decrypt", "Sign", "Verify"]
  secret_permissions = ["Get"]
}

data "azurerm_client_config" "currenttwo" {}

# resource "azurerm_key_vault_access_policy" "client" {
#   key_vault_id = azurerm_key_vault.example[keys(local.key_vault)[0]].id
#   tenant_id    = data.azurerm_client_config.current.tenant_id
#   object_id    = data.azurerm_client_config.currenttwo.object_id

#   key_permissions    = ["Get", "Create", "Delete", "List", "Restore", "Recover", "UnwrapKey", "WrapKey", "Purge", "Encrypt", "Decrypt", "Sign", "Verify", "GetRotationPolicy"]
#   secret_permissions = ["Get"]
# }

#Key Vault Crypto Officer
data "azurerm_subscription" "primary" {
}

data "azurerm_client_config" "currentthree" {
}

resource "azurerm_role_assignment" "example" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Key Vault Crypto Officer" #"Key Vault Administrator"
  principal_id         = data.azurerm_client_config.currentthree.object_id
}
##

resource "azurerm_key_vault_key" "example" {
  name         = "tfex-key"
  key_vault_id = azurerm_key_vault.example[keys(local.key_vault)[0]].id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  depends_on = [
    # azurerm_key_vault_access_policy.client,
    azurerm_key_vault_access_policy.storage,
  ]
}
