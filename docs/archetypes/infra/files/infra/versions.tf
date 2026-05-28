terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # TODO({{REPO_NAME}}): configurar el backend remoto (azurerm) del BC {{BC_KEY}}.
  # backend "azurerm" {
  #   resource_group_name  = "rg-{{BC_KEY}}-tfstate-eus2-001"
  #   storage_account_name = "st{{BC_KEY}}tfstateeus2001"
  #   container_name       = "tfstate"
  #   key                  = "{{BC_KEY}}.tfstate"
  # }
}

provider "azurerm" {
  features {}
}
