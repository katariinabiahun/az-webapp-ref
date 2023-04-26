output "vnet" {
  value = local.vnet
}

output "snet" {
  value = local.snet
}

# output "pvt_link_svc" {
#   value = local.pvt_link_svc
# }

output "subnet_id_deleg" {
  value = azurerm_subnet.example[keys(local.snet)[1]].id
}

output "subnet_id_privlink" {
  value = azurerm_subnet.example[keys(local.snet)[0]].id
}
