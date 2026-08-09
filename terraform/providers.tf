terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
  backend "azurerm" {
    use_azuread_auth     = true
    resource_group_name  = "rg-azuregitops-tfstate"
    storage_account_name = "aksgitops"
    container_name       = "tfstate"
    key                  = "gitops-lab/platform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  resource_provider_registrations = "core"
}