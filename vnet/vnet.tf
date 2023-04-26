locals {

  vnets = yamldecode(file("${path.module}/vnet.yaml"))

  vnet = { for k, v in flatten([for vnet_name, vnet_value in local.vnets :
    {
      vnet_name  = vnet_name
      vnet_value = vnet_value
    }
  ]) : v.vnet_name => v }

  snet = { for v in flatten([for vnet_name, vnet_value in local.vnets :
    [for snet_name, snet_value in try(vnet_value.snet, {}) :
      {
        vnet_name  = vnet_name
        vnet_value = vnet_value
        snet_name  = snet_name
        snet_value = snet_value
      }
    ]
  ]) : v.snet_name => v }

  pip = { for v in flatten([for vnet_name, vnet_value in local.vnets :
    [for pip_name, pip_value in try(vnet_value.public_ip, {}) :
      {
        vnet_name  = vnet_name
        vnet_value = vnet_value
        pip_name   = pip_name
        pip_value  = pip_value
      }
    ]
  ]) : v.pip_name => v }

  # lb = { for v in flatten([for vnet_name, vnet_value in local.vnets :
  #   [for lb_name, lb_value in try(vnet_value.lb, {}) :
  #     {
  #       vnet_name  = vnet_name
  #       vnet_value = vnet_value
  #       lb_name    = lb_name
  #       lb_value   = lb_value
  #     }
  #   ]
  # ]) : v.lb_name => v }

  # pvt_link_svc = { for v in flatten([for vnet_name, vnet_value in local.vnets :
  #   [for pvt_link_svc_name, pvt_link_svc_value in try(vnet_value.private_link_service, {}) :
  #     {
  #       vnet_name          = vnet_name
  #       vnet_value         = vnet_value
  #       pvt_link_svc_name  = pvt_link_svc_name
  #       pvt_link_svc_value = pvt_link_svc_value
  #     }
  #   ]
  # ]) : v.pvt_link_svc_name => v }

  # nat = { for v in flatten([for vnet_name, vnet_value in local.vnets :
  #   [for pvt_link_svc_name, pvt_link_svc_value in try(vnet_value.private_link_service, {}) :
  #     [for nat_name, nat_value in try(pvt_link_svc_value.nat_ip_configuration, {}) :
  #       {
  #         nat_name  = nat_name
  #         nat_value = nat_value
  #       }
  #     ]
  #   ]
  # ]) : v.nat_name => v }

  mon_scope = { for v in flatten([for vnet_name, vnet_value in local.vnets :
    [for scope_name, scope_value in try(vnet_value.monitor_private_link_scope, {}) :
      {
        scope_name  = scope_name
        scope_value = scope_value
      }
    ]
  ]) : v.scope_name => v }

  pvt_endps = { for v in flatten([for vnet_name, vnet_value in local.vnets :
    [for endpoint_name, endpoint_value in try(vnet_value.private_endpoint, {}) :
      {
        endpoint_name  = endpoint_name
        endpoint_value = endpoint_value
      }
    ]
  ]) : v.endpoint_name => v }

  pvt_conn_ids = {
    "insights"   = azurerm_monitor_private_link_scope.example[keys(local.mon_scope)[0]].id
    "keyvault"   = var.kv
    "servicebus" = var.srvbus
    "postgresql" = var.pg
  }
}

resource "azurerm_virtual_network" "example" {
  for_each = local.vnet

  name                = each.value.vnet_value.name
  resource_group_name = var.common.resource_group_name
  location            = var.common.location
  address_space       = each.value.vnet_value.address_space
}

resource "azurerm_subnet" "example" {
  for_each = local.snet

  name                                          = each.key
  resource_group_name                           = var.common.resource_group_name
  virtual_network_name                          = each.value.vnet_value.name
  address_prefixes                              = each.value.snet_value.address_prefixes
  private_link_service_network_policies_enabled = try(each.value.snet_value.private_link_service_network_policies_enabled, null)
  service_endpoints                             = try(each.value.snet_value.service_endpoints, null)

  #for webapp
  dynamic "delegation" {
    for_each = can(each.value.snet_value.delegation) ? toset([1]) : toset([])

    content {
      name = try(each.value.snet_value.delegation.name, null)

      service_delegation {
        name    = try(each.value.snet_value.delegation.service_delegation.name, null)
        actions = try(each.value.snet_value.delegation.service_delegation.actions, null)
      }
    }
  }

  depends_on = [
    azurerm_virtual_network.example
  ]
}

resource "azurerm_public_ip" "example" {
  for_each = local.pip

  name                = each.key
  sku                 = try(each.value.pip_value.sku, null)
  location            = var.common.location
  resource_group_name = var.common.resource_group_name
  allocation_method   = each.value.pip_value.allocation_method
}

# resource "azurerm_lb" "example" {
#   for_each = local.lb

#   name                = each.key
#   sku                 = try(each.value.lb_value.sku, null)
#   location            = var.common.location
#   resource_group_name = var.common.resource_group_name

#   dynamic "frontend_ip_configuration" {
#     for_each = try(local.pip, {})

#     content {
#       name                 = frontend_ip_configuration.value.pip_name
#       public_ip_address_id = azurerm_public_ip.example[frontend_ip_configuration.value.pip_name].id #local.pip_id[each.value.pip_value.name]
#     }
#   }
# }

# resource "azurerm_private_link_service" "example" {
#   for_each = local.pvt_link_svc

#   name                = each.key
#   resource_group_name = var.common.resource_group_name
#   location            = var.common.location

#   auto_approval_subscription_ids              = try(each.value.pvt_link_svc_value.auto_approval_subscription_ids, [])
#   visibility_subscription_ids                 = try(each.value.pvt_link_svc_value.visibility_subscription_ids, [])
#   load_balancer_frontend_ip_configuration_ids = [azurerm_lb.example[keys(local.lb)[0]].frontend_ip_configuration.0.id]

#   dynamic "nat_ip_configuration" {
#     for_each = local.nat

#     content {
#       name                       = nat_ip_configuration.key
#       private_ip_address         = nat_ip_configuration.value.nat_value.private_ip_address
#       private_ip_address_version = nat_ip_configuration.value.nat_value.private_ip_address_version
#       subnet_id                  = azurerm_subnet.example[keys(local.snet)[0]].id
#       primary                    = nat_ip_configuration.value.nat_value.primary
#     }
#   }
# }

# resource "azurerm_private_endpoint" "example" {
#   name                = "example-endpoint"
#   location            = var.common.location
#   resource_group_name = var.common.resource_group_name
#   subnet_id           = azurerm_subnet.example[keys(local.snet)[0]].id

#   private_service_connection {
#     name                           = "example-privateserviceconnection"
#     private_connection_resource_id = azurerm_private_link_service.example[keys(local.pvt_link_svc)[0]].id
#     is_manual_connection           = false
#   }
# }

resource "azurerm_monitor_private_link_scope" "example" {
  for_each = local.mon_scope

  name                = each.value.scope_value.name
  resource_group_name = var.common.resource_group_name
}

resource "azurerm_monitor_private_link_scoped_service" "example" {
  name                = "isgnameforscopesrv"
  resource_group_name = var.common.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.example[keys(local.mon_scope)[0]].name
  linked_resource_id  = var.app_insights
}

resource "azurerm_private_endpoint" "example" {
  for_each = local.pvt_endps

  name                = each.value.endpoint_value.name
  location            = var.common.location
  resource_group_name = var.common.resource_group_name
  subnet_id           = azurerm_subnet.example[keys(local.snet)[0]].id

  private_service_connection {
    name                           = each.value.endpoint_value.private_service_connection_name
    private_connection_resource_id = lookup(local.pvt_conn_ids, each.key)
    is_manual_connection           = each.value.endpoint_value.is_manual_connection
    subresource_names              = each.value.endpoint_value.subresource_names
  }
}
