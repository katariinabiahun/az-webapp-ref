locals {

  storage = yamldecode(file("${path.module}/storage.yaml"))

  blob_stor = { for v in flatten([for stor_name, stor_value in local.storage :
    [for stat_name, stat_value in try(stor_value.static_website, {}) :
      {
        stor_name  = stor_name
        stor_value = stor_value
        stat_name  = stat_name
        stat_value = stat_value
      }
    ]
  ]) : join("-", [v.stor_name, v.stat_name]) => v }

  blob = { for v in flatten([for stor_name, stor_value in local.storage :
    [for blob_name, blob_value in try(stor_value.storage_blob, {}) :
      {
        stor_name  = stor_name
        stor_value = stor_value
        blob_name  = blob_name
        blob_value = blob_value
      }
    ]
  ]) : v.blob_name => v }
}

resource "azurerm_storage_account" "example" {
  for_each = local.blob_stor

  name                     = trimspace(lower(each.value.stor_value.name)) #unique
  location                 = var.common.location
  resource_group_name      = var.common.resource_group_name
  account_tier             = each.value.stor_value.account_tier
  account_replication_type = each.value.stor_value.account_replication_type
  account_kind             = each.value.stor_value.account_kind #static_website can only be set when the account_kind is set to StorageV2 or BlockBlobStorage.

  static_website {
    index_document     = each.value.stat_value.index_document
    error_404_document = each.value.stat_value.error_404_document
  }
}

resource "azurerm_storage_blob" "example" {
  for_each = local.blob

  name                   = each.key
  storage_account_name   = trimspace(lower(each.value.stor_value.name)) #azurerm_storage_account.example[each.value.stor_name].name
  storage_container_name = each.value.blob_value.storage_container_name
  type                   = each.value.blob_value.type
  source                 = each.value.blob_value.source
  content_type           = each.value.blob_value.content_type

  depends_on = [
    azurerm_storage_account.example
  ]
}