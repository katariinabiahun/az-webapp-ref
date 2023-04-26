locals {

  app_insights = yamldecode(file("${path.module}/insights.yaml"))

  insights = { for v in flatten([for insights_name, insights_value in local.app_insights :
    {
      insights_name  = insights_name
      insights_value = insights_value
    }
  ]) : v.insights_name => v }

  log = { for v in flatten([for insights_name, insights_value in local.app_insights :
    [for log_name, log_value in try(insights_value.log_analytics_workspace, {}) :
      {
        insights_name  = insights_name
        insights_value = insights_value
        log_name       = log_name
        log_value      = log_value
      }
    ]
  ]) : v.log_name => v }
}

resource "azurerm_log_analytics_workspace" "example" {
  for_each = local.log

  name                = each.key
  location            = var.common.location
  resource_group_name = var.common.resource_group_name
  sku                 = try(each.value.log_value.sku, null)
  retention_in_days   = try(each.value.log_value.retention_in_days, null)
}

resource "azurerm_application_insights" "example" {
  for_each = local.insights

  name                = each.value.insights_value.name
  location            = var.common.location
  resource_group_name = var.common.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.example[keys(local.log)[0]].id
  application_type    = each.value.insights_value.application_type
}

# resource "azurerm_monitor_private_link_scope" "example" {
#   name                = "example-ampls"
#   resource_group_name = var.common.resource_group_name
# }

# resource "azurerm_monitor_private_link_scoped_service" "log" {
#   name                = azurerm_application_insights.example[keys(local.insights)[0]].name
#   resource_group_name = var.common.resource_group_name
#   scope_name          = azurerm_monitor_private_link_scope.example.name
#   linked_resource_id  = azurerm_application_insights.example[keys(local.insights)[0]].id
# }

# # resource "azurerm_monitor_private_link_scoped_service" "ins" {
# #   name                = azurerm_log_analytics_workspace.example[keys(local.insights)[0]].name
# #   resource_group_name = var.common.resource_group_name
# #   scope_name          = azurerm_monitor_private_link_scope.example.name
# #   linked_resource_id  = azurerm_application_insights.example[keys(local.insights)[0]].id
# # }

# resource "azurerm_private_endpoint" "example" {
#   name                = "appinstomonendpoint"
#   location            = var.common.location
#   resource_group_name = var.common.resource_group_name
#   subnet_id           = var.subnet_id_privlink

#   private_service_connection {
#     name                           = "example-privateserviceconnection"
#     private_connection_resource_id = azurerm_monitor_private_link_scope.example.id
#     is_manual_connection           = false
#     subresource_names              = ["azuremonitor"]
#   }
# }

# ####

# resource "azurerm_private_endpoint" "kv" {
#   name                = "kvprvendp"
#   location            = var.common.location
#   resource_group_name = var.common.resource_group_name
#   subnet_id           = var.subnet_id_privlink

#   private_service_connection {
#     name                           = "kvprvendp-srvconn"
#     private_connection_resource_id = azurerm_key_vault.example[keys(local.key_vault)[0]].id
#     is_manual_connection           = false
#     subresource_names              = ["vault"]
#   }
# }

# resource "azurerm_private_endpoint" "srvbus" {
#   name                = "srvbusprvendp"
#   location            = var.common.location
#   resource_group_name = var.common.resource_group_name
#   subnet_id           = var.subnet_id_privlink

#   private_service_connection {
#     name                           = "srvbusprvendp-srvconn"
#     private_connection_resource_id = azurerm_servicebus_namespace.example[keys(local.srvbus_queue)[0]].id
#     is_manual_connection           = false
#     subresource_names              = ["namespace"]
#   }
# }

# resource "azurerm_private_endpoint" "pg" {
#   name                = "postgreprvendp"
#   location            = var.common.location
#   resource_group_name = var.common.resource_group_name
#   subnet_id           = var.subnet_id_privlink

#   private_service_connection {
#     name                           = "postgreprvendp-srvconn"
#     private_connection_resource_id = azurerm_postgresql_server.example[keys(local.postgresql)[0]].id
#     is_manual_connection           = false
#     subresource_names              = ["postgresqlServer"]
#   }
# }
