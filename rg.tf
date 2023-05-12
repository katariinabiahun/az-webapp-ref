resource "azurerm_resource_group" "example" {
  count = can(var.resource_group_name) ? 0 : 1

  name     = var.resource_group_name
  location = var.location
}
