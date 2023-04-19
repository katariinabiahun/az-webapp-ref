locals {

  postgre = yamldecode(file("${path.module}/postgre.yaml"))

  postgresql = { for k, v in flatten([for postgre_name, postgre_value in local.postgre :
    [for server_name, server_value in try(postgre_value.server, {}) :
      [for db_name, db_value in try(postgre_value.database, {}) :
        [for frule_name, frule_value in try(postgre_value.firewall_rule, {}) :
          {
            postgre_name  = postgre_name
            postgre_value = postgre_value
            server_name   = server_name
            server_value  = server_value
            db_name       = db_name
            db_value      = db_value
            frule_name    = frule_name
            frule_value   = frule_value
          }
        ]
      ]
    ]
  ]) : join("-", [v.postgre_name, v.server_name, v.db_name, v.frule_name]) => v }
}

resource "azurerm_postgresql_server" "example" {
  for_each = local.postgresql

  name                         = each.value.server_name
  location                     = var.common.location
  resource_group_name          = var.common.resource_group_name
  sku_name                     = each.value.server_value.sku_name
  storage_mb                   = try(each.value.server_value.storage_mb, null)
  backup_retention_days        = try(each.value.server_value.backup_retention_days, null)
  geo_redundant_backup_enabled = try(each.value.server_value.geo_redundant_backup_enabled, null)
  auto_grow_enabled            = try(each.value.server_value.auto_grow_enabled, null)
  administrator_login          = try(each.value.server_value.administrator_login, null)
  administrator_login_password = try(each.value.server_value.administrator_login_password, null)
  version                      = each.value.server_value.version
  ssl_enforcement_enabled      = each.value.server_value.ssl_enforcement_enabled
}

resource "azurerm_postgresql_database" "example" {
  for_each = local.postgresql

  name                = each.value.db_name
  resource_group_name = var.common.resource_group_name
  server_name         = azurerm_postgresql_server.example[keys(local.postgresql)[0]].name
  charset             = each.value.db_value.charset
  collation           = each.value.db_value.collation
}

#1
resource "azurerm_postgresql_firewall_rule" "example" {
  for_each = local.postgresql

  name                = each.value.frule_name
  resource_group_name = var.common.resource_group_name
  server_name         = azurerm_postgresql_server.example[keys(local.postgresql)[0]].name
  start_ip_address    = each.value.frule_value.start_ip_address
  end_ip_address      = each.value.frule_value.end_ip_address
}
