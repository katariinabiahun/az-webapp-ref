locals {
  webapps = yamldecode(file("webapp/webapp.yaml"))
}

module "terraform_azure_vnet" {
  source = "../../"

  webapps = local.webapps

}
