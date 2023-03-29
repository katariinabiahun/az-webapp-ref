# variable "location" {
#   type        = string
#   description = "location"

# }

# variable "resource_group_name" {
#   type        = string
#   description = "Resource group name. Optional"

# }

variable "common" {
  type = object({
    location            = string
    resource_group_name = string
  })
}
