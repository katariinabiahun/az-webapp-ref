variable "common" {
  type = object({
    location            = string
    resource_group_name = string
  })
}

variable "app_insights" {}
variable "kv" {}
variable "srvbus" {}
variable "pg" {}

variable "func" {}
