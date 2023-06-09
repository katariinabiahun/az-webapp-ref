locals {

  frontdoor = yamldecode(file("${path.module}/frontdoor.yaml"))

  fd_profile = { for v in flatten([for frontdoor_name, frontdoor_value in local.frontdoor :
    [for profile_name, profile_value in try(frontdoor_value.profile, {}) :
      [for db_name, db_value in try(frontdoor_value.endpoint, {}) :
        {
          frontdoor_name = frontdoor_name
          profile_name   = profile_name
          profile_value  = profile_value
        }
      ]
    ]
  ]) : v.profile_name => v }

  fd_endpoint = { for k, v in flatten([for frontdoor_name, frontdoor_value in local.frontdoor :
    [for endpoint_name, endpoint_value in try(frontdoor_value.endpoint, {}) :
      {
        frontdoor_name = frontdoor_name
        endpoint_name  = endpoint_name
        endpoint_value = endpoint_value
      }
    ]
  ]) : join("-", [v.frontdoor_name, v.endpoint_name]) => v }

  fd_origin_group = { for v in flatten([for frontdoor_name, frontdoor_value in local.frontdoor :
    [for orgr_name, orgr_value in try(frontdoor_value.origin_group, {}) :
      {
        frontdoor_name = frontdoor_name
        orgr_name      = orgr_name
        orgr_value     = orgr_value
      }
    ]
  ]) : join("-", [v.frontdoor_name, v.orgr_name]) => v }

  fd_origin = { for v in flatten([for frontdoor_name, frontdoor_value in local.frontdoor :
    [for origin_name, origin_value in try(frontdoor_value.origin, {}) :
      {
        frontdoor_name = frontdoor_name
        origin_name    = origin_name
        origin_value   = origin_value
      }
    ]
  ]) : v.origin_name => v }

  fd_route = { for v in flatten([for frontdoor_name, frontdoor_value in local.frontdoor :
    [for route_name, route_value in try(frontdoor_value.route, {}) :
      [for cache_name, cache_value in try(route_value.cache, {}) :
        {
          frontdoor_name = frontdoor_name
          route_name     = route_name
          route_value    = route_value
          cache_name     = cache_name
          cache_value    = cache_value
        }
      ]
    ]
  ]) : join("-", [v.frontdoor_name, v.route_name, v.cache_name]) => v }

  fd_firewall_policy = { for v in flatten([for frontdoor_name, frontdoor_value in local.frontdoor :
    [for fpol_name, fpol_value in try(frontdoor_value.firewall_policy, {}) :
      [for crule_name, crule_value in try(fpol_value.custom_rule, {}) :
        [for matchcond_name, matchcond_value in try(crule_value.match_condition, {}) :
          [for mrule_name, mrule_value in try(fpol_value.managed_rule, {}) :
            {
              frontdoor_name  = frontdoor_name
              frontdoor_value = frontdoor_value
              fpol_name       = fpol_name
              fpol_value      = fpol_value
              crule_name      = crule_name
              crule_value     = crule_value
              matchcond_name  = matchcond_name
              matchcond_value = matchcond_value
              mrule_name      = mrule_name
              mrule_value     = mrule_value
            }
          ]
        ]
      ]
    ]
  ]) : join("-", [v.fpol_name, v.crule_name, v.matchcond_name, v.mrule_name]) => v }

  fd_security_policy = { for v in flatten([for frontdoor_name, frontdoor_value in local.frontdoor :
    [for secpol_name, secpol_value in try(frontdoor_value.security_policy, {}) :
      {
        frontdoor_name = frontdoor_name
        secpol_name    = secpol_name
        secpol_value   = secpol_value
      }
    ]
  ]) : join("-", [v.frontdoor_name, v.secpol_name]) => v }

  origin_hosts = {
    "storage" = azurerm_storage_account.example[keys(local.blob_stor)[0]].primary_web_host
    "webapp"  = azurerm_linux_web_app.example[keys(local.webapp)[0]].default_hostname
  }
}

resource "azurerm_cdn_frontdoor_profile" "example" {
  for_each = local.fd_profile

  name                = each.key
  resource_group_name = var.common.resource_group_name
  sku_name            = each.value.profile_value.sku_name
}

resource "azurerm_cdn_frontdoor_endpoint" "example" {
  for_each = local.fd_endpoint

  name                     = each.key
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.example[keys(local.fd_profile)[0]].id
}

resource "azurerm_cdn_frontdoor_origin_group" "example" {
  for_each = local.fd_origin_group

  name                     = each.key
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.example[keys(local.fd_profile)[0]].id
  session_affinity_enabled = each.value.orgr_value.session_affinity_enabled

  load_balancing {
    additional_latency_in_milliseconds = try(each.value.orgr_value.additional_latency_in_milliseconds, null)
    sample_size                        = try(each.value.orgr_value.sample_size, null)
    successful_samples_required        = try(each.value.orgr_value.successful_samples_required, null)
  }
}

resource "azurerm_cdn_frontdoor_origin" "example" {
  for_each = local.fd_origin

  name                           = each.value.origin_value.name
  enabled                        = try(each.value.origin_value.enabled, true)
  certificate_name_check_enabled = each.value.origin_value.certificate_name_check_enabled
  http_port                      = try(each.value.origin_value.http_port, null)
  https_port                     = try(each.value.origin_value.https_port, null)
  priority                       = try(each.value.origin_value.priority, null)
  weight                         = try(each.value.origin_value.weight, null)

  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.example[keys(local.fd_origin_group)[0]].id

  host_name          = lookup(local.origin_hosts, each.key)
  origin_host_header = try(lookup(local.origin_hosts, each.key), null)
}

resource "azurerm_cdn_frontdoor_route" "example" {
  for_each = local.fd_route

  name                          = each.key
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.example[keys(local.fd_endpoint)[0]].id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.example[keys(local.fd_origin_group)[0]].id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.example[keys(local.fd_origin)[0]].id, azurerm_cdn_frontdoor_origin.example[keys(local.fd_origin)[1]].id]

  enabled                = try(each.value.route_value.enabled, true)
  forwarding_protocol    = try(each.value.route_value.forwarding_protocol, null)
  https_redirect_enabled = try(each.value.route_value.https_redirect_enabled, true)
  patterns_to_match      = each.value.route_value.patterns_to_match
  supported_protocols    = each.value.route_value.supported_protocols

  link_to_default_domain = each.value.route_value.link_to_default_domain

  cache {
    query_string_caching_behavior = try(each.value.cache_value.query_string_caching_behavior, null)
    query_strings                 = try(each.value.cache_value.query_strings, null)
    compression_enabled           = try(each.value.cache_value.compression_enabled, null)
    content_types_to_compress     = try(each.value.cache_value.content_types_to_compress, null)
  }
}

resource "azurerm_cdn_frontdoor_firewall_policy" "example" {
  for_each = local.fd_firewall_policy

  name                              = each.value.fpol_name
  resource_group_name               = var.common.resource_group_name
  sku_name                          = azurerm_cdn_frontdoor_profile.example[keys(local.fd_profile)[0]].sku_name
  enabled                           = try(each.value.fpol_value.enabled, true)
  mode                              = each.value.fpol_value.mode
  redirect_url                      = try(each.value.fpol_value.redirect_url, null)
  custom_block_response_status_code = try(each.value.fpol_value.custom_block_response_status_code, null)
  custom_block_response_body        = try(each.value.fpol_value.custom_block_response_body, null)

  dynamic "custom_rule" {
    for_each = can(each.value.fpol_value.custom_rule) ? toset([1]) : toset([])

    content {
      name                           = each.value.crule_name
      enabled                        = try(each.value.crule_value.enabled, null)
      priority                       = try(each.value.crule_value.priority, null)
      rate_limit_duration_in_minutes = try(each.value.crule_value.rate_limit_duration_in_minutes, null)
      rate_limit_threshold           = try(each.value.crule_value.rate_limit_threshold, null)
      type                           = each.value.crule_value.type
      action                         = each.value.crule_value.action

      dynamic "match_condition" {
        for_each = can(each.value.crule_value.match_condition) ? toset([1]) : toset([])

        content {
          match_variable     = each.value.matchcond_value.match_variable
          selector           = try(each.value.matchcond_value.selector, null)
          operator           = each.value.matchcond_value.operator
          negation_condition = try(each.value.matchcond_value.negation_condition, null)
          match_values       = each.value.matchcond_value.match_values
          transforms         = try(each.value.matchcond_value.transforms, null)
        }
      }
    }
  }

  dynamic "managed_rule" {
    for_each = can(each.value.fpol_value.managed_rule) ? toset([1]) : toset([])

    content {
      type    = each.value.mrule_value.type
      version = each.value.mrule_value.version
      action  = each.value.mrule_value.action
    }
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "example" {
  for_each = local.fd_security_policy

  name                     = each.key
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.example[keys(local.fd_profile)[0]].id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.example[keys(local.fd_firewall_policy)[0]].id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.example[keys(local.fd_endpoint)[0]].id
        }
        patterns_to_match = each.value.secpol_value.patterns_to_match
      }
    }
  }
}
