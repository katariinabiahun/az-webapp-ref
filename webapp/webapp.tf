locals {

  resource_group_name_is_null = var.resource_group_name == null
  constructed_rg_name         = "${local.division_id}-${local.service_name}-network-${local.environment}-rg"
  resource_group_name         = local.resource_group_name_is_null ? azurerm_resource_group.rg[0].name : var.resource_group_name

  webapps = yamldecode(file("webapp.yaml"))

  webapp = { for k, v in flatten([for web_app_name, web_app_value in local.webapps :
    [for serv_plan_name, serv_plan_value in try(web_app_value.service_plan, {}) :
      {
        web_app_name    = web_app_name
        web_app_value   = web_app_value
        serv_plan_name  = serv_plan_name
        serv_plan_value = serv_plan_value
      }
    ]
  ]) : join("-", [v.web_app_name, v.serv_plan_name]) => v }

  serv_plan_id = { for k, v in azurerm_service_plan.example : v.name => v.id }
}

resource "azurerm_resource_group" "example" {
  count = local.resource_group_name_is_null ? 1 : 0

  name     = local.constructed_rg_name
  location = var.location
}

resource "azurerm_service_plan" "example" {
  for_each = local.webapp

  name                = each.value.serv_plan_value.name
  location            = var.location
  resource_group_name = local.resource_group_name
  os_type             = each.value.serv_plan_value.os_type
  sku_name            = each.value.serv_plan_value.sku_name
}

resource "azurerm_linux_web_app" "example" {
  for_each = local.webapp

  name                = each.value.web_app_value.name
  resource_group_name = local.resource_group_name
  location            = var.location
  service_plan_id     = local.serv_plan_id[each.value.serv_plan_value.name]

  site_config {}
}
