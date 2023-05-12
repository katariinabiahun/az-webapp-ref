locals {

  srv_bus = yamldecode(file("${path.module}/servicebus.yaml"))

  srvbus_queue = { for k, v in flatten([for srvbus_name, srvbus_value in local.srv_bus :
    [for namespace_name, namespace_value in try(srvbus_value.namespace, {}) :
      [for queue_name, queue_value in try(srvbus_value.queue, {}) :
        [for auth_rule_name, auth_rule_value in try(srvbus_value.auth_rule, {}) :
          {
            srvbus_name     = srvbus_name
            srvbus_value    = srvbus_value
            namespace_name  = namespace_name
            namespace_value = namespace_value
            queue_name      = queue_name
            queue_value     = queue_value
            auth_rule_name  = auth_rule_name
            auth_rule_value = auth_rule_value
          }
        ]
      ]
    ]
  ]) : join("-", [v.srvbus_name, v.namespace_name, v.queue_name, v.auth_rule_name]) => v }

  net_rset = { for k, v in flatten([for srvbus_name, srvbus_value in local.srv_bus :
    [for rset_name, rset_value in try(srvbus_value.network_rule_set, {}) :
      {
        srvbus_name = srvbus_name
        rset_name   = rset_name
        rset_value  = rset_value
      }
    ]
  ]) : join("-", [v.srvbus_name, v.rset_name]) => v }
}

resource "azurerm_servicebus_namespace" "example" {
  for_each = local.srvbus_queue

  name                = each.value.namespace_name
  location            = var.common.location
  resource_group_name = var.common.resource_group_name
  sku                 = each.value.namespace_value.sku
  capacity            = each.value.namespace_value.capacity
}

resource "azurerm_servicebus_queue" "example" {
  for_each = local.srvbus_queue

  name         = each.value.queue_name
  namespace_id = azurerm_servicebus_namespace.example[keys(local.srvbus_queue)[0]].id

  enable_partitioning = try(each.value.queue_value.enable_partitioning, null)
}

resource "azurerm_servicebus_queue_authorization_rule" "example" {
  for_each = local.srvbus_queue

  name     = each.value.auth_rule_name
  queue_id = azurerm_servicebus_queue.example[keys(local.srvbus_queue)[0]].id

  listen = try(each.value.auth_rule_value.listen, null)
  send   = try(each.value.auth_rule_value.send, null)
  manage = try(each.value.auth_rule_value.manage, null)
}

resource "azurerm_servicebus_namespace_network_rule_set" "example" {
  for_each = local.net_rset

  namespace_id = azurerm_servicebus_namespace.example[keys(local.srvbus_queue)[0]].id

  default_action                = each.value.rset_value.default_action
  public_network_access_enabled = each.value.rset_value.public_network_access_enabled

  network_rules {
    subnet_id                            = var.subnet_id_privlink
    ignore_missing_vnet_service_endpoint = each.value.rset_value.ignore_missing_vnet_service_endpoint
  }
}
