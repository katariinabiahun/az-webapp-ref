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

# resource "azurerm_application_insights" "example" {
#   for_each = local.log

#   name                = each.value.insights_value.name
#   location            = var.common.location
#   resource_group_name = var.common.resource_group_name
#   workspace_id        = azurerm_log_analytics_workspace.example[each.value.log_name].id
#   application_type    = each.value.insights_value.application_type
# }

resource "azurerm_application_insights" "example" {
  for_each = local.insights

  name                = each.value.insights_value.name
  location            = var.common.location
  resource_group_name = var.common.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.example[keys(local.log)[0]].id
  application_type    = each.value.insights_value.application_type
}
