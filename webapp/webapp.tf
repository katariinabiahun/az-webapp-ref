locals {

  webapps = yamldecode(file("${path.module}/webapp.yaml"))

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

resource "azurerm_service_plan" "example" {
  for_each = local.webapp

  name                = each.value.serv_plan_value.name
  location            = var.common.location
  resource_group_name = var.common.resource_group_name
  os_type             = each.value.serv_plan_value.os_type
  sku_name            = each.value.serv_plan_value.sku_name

  worker_count             = try(each.value.serv_plan_value.worker_count, null)
  per_site_scaling_enabled = try(each.value.serv_plan_value.per_site_scaling_enabled, null)
}

resource "azurerm_linux_web_app" "example" {
  for_each = local.webapp

  name                = each.value.web_app_value.name
  resource_group_name = var.common.resource_group_name
  location            = var.common.location
  service_plan_id     = local.serv_plan_id[each.value.serv_plan_value.name]

  site_config {
    worker_count = try(each.value.web_app_value.worker_count, null)
  }
}
