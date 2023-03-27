locals {
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
  name     = "ice"
  location = "West Europe"
}

resource "azurerm_service_plan" "example" {
  for_each = local.webapp

  name                = each.value.serv_plan_value.name
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name
  os_type             = each.value.serv_plan_value.os_type
  sku_name            = each.value.serv_plan_value.sku_name
}

resource "azurerm_linux_web_app" "example" {
  for_each = local.webapp

  name                = each.value.web_app_value.name
  resource_group_name = azurerm_resource_group.example.name
  location            = var.location
  service_plan_id     = local.serv_plan_id[each.value.serv_plan_value.name]

  site_config {}
}
