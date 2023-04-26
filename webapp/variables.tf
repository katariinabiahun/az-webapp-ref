variable "common" {
  type = object({
    location            = string
    resource_group_name = string
  })
}

variable "subnet_id_deleg" {}
variable "subnet_id_privlink" {}
