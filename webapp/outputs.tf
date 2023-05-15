output "mywebapp" {
  value = azurerm_linux_web_app.example[keys(local.webapp)[0]].default_hostname
}

output "srvbus_connstr" {
  value = nonsensitive(azurerm_servicebus_queue_authorization_rule.example[keys(local.srvbus_queue)[0]].primary_connection_string)
}

output "waf_policy" {
  value = local.fd_firewall_policy
}

output "instrumentation_key" {
  value = azurerm_application_insights.example[keys(local.insights)[0]].instrumentation_key
}

output "app_id" {
  value = azurerm_application_insights.example[keys(local.insights)[0]].app_id
}

output "static_api_key" {
  value = nonsensitive(azurerm_static_site.example[keys(local.staticwebapp)[0]].api_key)
}

# The following values is used to set the private endpoints in the vnet module.

output "app_insights" {
  value = azurerm_application_insights.example[keys(local.insights)[0]].id
}

output "kv" {
  value = azurerm_key_vault.example[keys(local.key_vault)[0]].id
}

output "srvbus" {
  value = azurerm_servicebus_namespace.example[keys(local.srvbus_queue)[0]].id
}

output "pg" {
  value = azurerm_postgresql_server.example[keys(local.postgresql)[0]].id
}
