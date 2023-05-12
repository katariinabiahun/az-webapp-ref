output "mywebapp" {
  value = module.tf_az_api.mywebapp
}

output "vnet" {
  value = module.vnet.vnet
}

output "snet" {
  value = module.vnet.snet
}

output "storage" {
  value = module.tf_az_api.storage
}

output "srvbus_connstr" {
  value = module.tf_az_api.srvbus_connstr
}

output "waf_policy" {
  value = module.tf_az_api.waf_policy
}
