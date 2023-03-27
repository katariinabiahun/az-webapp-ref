terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.49.0"
    }
  }

  cloud {
    organization = "pipeline-with-github-actions"

    workspaces {
      name = "github-actions"
    }
  }
}

provider "azurerm" {
  features {}
}
