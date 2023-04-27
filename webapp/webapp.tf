locals {

  webapps = yamldecode(file("${path.module}/webapp.yaml"))

  webapp = { for k, v in flatten([for web_app_name, web_app_value in local.webapps :
    [for serv_plan_name, serv_plan_value in try(web_app_value.service_plan, {}) :
      [for connstr_name, connstr_value in try(serv_plan_value.connconnection_string, {}) :
        {
          web_app_name    = web_app_name
          web_app_value   = web_app_value
          serv_plan_name  = serv_plan_name
          serv_plan_value = serv_plan_value
          connstr_name    = connstr_name
          connstr_value   = connstr_value
        }
      ]
    ]
  ]) : join("-", [v.web_app_name, v.serv_plan_name, v.connstr_name]) => v }

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

  name                      = each.value.web_app_value.name
  resource_group_name       = var.common.resource_group_name
  location                  = var.common.location
  service_plan_id           = local.serv_plan_id[each.value.serv_plan_value.name]
  virtual_network_subnet_id = var.subnet_id_deleg

  https_only = true

  site_config {
    worker_count = try(each.value.web_app_value.worker_count, null)

    ftps_state          = "Disabled"
    minimum_tls_version = "1.2"
    ip_restriction {
      service_tag               = "AzureFrontDoor.Backend"
      ip_address                = null
      virtual_network_subnet_id = null
      action                    = "Allow"
      priority                  = 100
      headers = [{
        x_azure_fdid      = [azurerm_cdn_frontdoor_profile.example[keys(local.fd_profile)[0]].resource_guid]
        x_fd_health_probe = []
        x_forwarded_for   = []
        x_forwarded_host  = []
      }]
      name = "Allow traffic from Front Door"
    }
  }

  app_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.example[keys(local.insights)[0]].instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.example[keys(local.insights)[0]].connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = lookup(local.app_insights.application_insights.app_sett, "extension_version")
  }

  #service bus
  dynamic "connection_string" {
    for_each = local.webapp

    content {
      name  = connection_string.value.connstr_value.name
      type  = connection_string.value.connstr_value.type
      value = azurerm_servicebus_queue_authorization_rule.example[keys(local.srvbus_queue)[0]].primary_connection_string
    }
  }
}

resource "azurerm_app_service_connection" "example" {
  name               = "srvconnwebapptostorb" #Resource name can only contain letters, numbers (0-9), periods ('.'), and underscores ('_'). The length must not be more than 60 characters.
  app_service_id     = azurerm_linux_web_app.example[keys(local.webapp)[0]].id
  target_resource_id = azurerm_storage_account.example[keys(local.blob_stor)[0]].id
  authentication {
    type = "systemAssignedIdentity"
  }
}
