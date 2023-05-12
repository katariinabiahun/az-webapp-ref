locals {

  functionapp = yamldecode(file("${path.module}/functionapp.yaml"))

  func = { for k, v in flatten([for func_name, func_value in local.functionapp :
    {
      func_name  = func_name
      func_value = func_value
    }
  ]) : v.func_name => v }

  srvplan = { for k, v in flatten([for func_name, func_value in local.functionapp :
    [for srvplan_name, srvplan_value in try(func_value.service_plan, {}) :
      [for connstr_name, connstr_value in try(srvplan_value.connconnection_string, {}) :
        {
          func_name     = func_name
          srvplan_name  = srvplan_name
          srvplan_value = srvplan_value
          connstr_name  = connstr_name
          connstr_value = connstr_value
        }
      ]
    ]
  ]) : join("-", [v.func_name, v.srvplan_name, v.connstr_name]) => v }

  srv_conn = { for k, v in flatten([for func_name, func_value in local.functionapp :
    [for conn_name, conn_value in try(func_value.app_service_connection, {}) :
      {
        func_name  = func_name
        conn_name  = conn_name
        conn_value = conn_value
      }
    ]
  ]) : v.conn_name => v }
}

resource "azurerm_service_plan" "example" {
  for_each = local.srvplan

  name                = each.key
  location            = var.common.location
  resource_group_name = var.common.resource_group_name
  os_type             = each.value.srvplan_value.os_type
  sku_name            = each.value.srvplan_value.sku_name

  worker_count             = try(each.value.srvplan_value.worker_count, null)
  per_site_scaling_enabled = try(each.value.srvplan_value.per_site_scaling_enabled, null)
}

resource "azurerm_linux_function_app" "example" {
  for_each = local.func

  name                = each.value.func_value.name
  resource_group_name = var.common.resource_group_name
  location            = var.common.location

  storage_account_name       = azurerm_storage_account.example[keys(local.blob_stor)[0]].name
  storage_account_access_key = azurerm_storage_account.example[keys(local.blob_stor)[0]].primary_access_key
  service_plan_id            = azurerm_service_plan.example[keys(local.srvplan)[0]].id
  virtual_network_subnet_id  = var.subnet_id_deleg

  https_only = true

  site_config {
    worker_count = try(each.value.func_value.site_config.worker_count, null)

    ftps_state          = each.value.func_value.site_config.ftps_state
    minimum_tls_version = each.value.func_value.site_config.minimum_tls_version
    ip_restriction {
      service_tag               = each.value.func_value.site_config.ip_restriction.service_tag
      ip_address                = each.value.func_value.site_config.ip_restriction.ip_address
      virtual_network_subnet_id = each.value.func_value.site_config.ip_restriction.virtual_network_subnet_id
      action                    = each.value.func_value.site_config.ip_restriction.action
      priority                  = each.value.func_value.site_config.ip_restriction.priority
      headers = [{
        x_azure_fdid      = [azurerm_cdn_frontdoor_profile.example[keys(local.fd_profile)[0]].resource_guid]
        x_fd_health_probe = []
        x_forwarded_for   = []
        x_forwarded_host  = []
      }]
      name = each.value.func_value.site_config.ip_restriction.name
    }
  }

  identity {
    type = each.value.func_value.identity.type
  }

  app_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.example[keys(local.insights)[0]].instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.example[keys(local.insights)[0]].connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = lookup(local.app_insights.application_insights.app_sett, "extension_version")

    #for stor acc
    #WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.example[keys(local.blob_stor)[0]].primary_access_key
    #AzureWebJobsStorage = storage_account_access_key,
  }

  dynamic "connection_string" {
    for_each = local.srvplan

    content {
      name  = connection_string.value.connstr_value.name
      type  = connection_string.value.connstr_value.type
      value = azurerm_servicebus_queue_authorization_rule.example[keys(local.srvbus_queue)[0]].primary_connection_string
    }
  }
}
