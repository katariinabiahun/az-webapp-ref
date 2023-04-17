output "mywebapp" {
  value = azurerm_linux_web_app.example[keys(local.webapp)[0]].default_hostname #"icelabwebapp.azurewebsites.net"
}

output "storage" {
  value = azurerm_storage_account.example[keys(local.blob_stor)[0]].primary_web_host #"stormewbappice.z6.web.core.windows.net/"
}
