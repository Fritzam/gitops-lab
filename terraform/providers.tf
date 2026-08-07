terraform {
	required_providers {
    azurerm = {
			source = "hashicorp/azurerm"
			version = "5.0.1"
    }
  }
}

provider "azurerm" {
	features {}
	subscription_id = var.subscription_id
}