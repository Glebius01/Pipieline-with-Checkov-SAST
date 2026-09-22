# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.6.0"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "lab" {
  name     = "devsecops-lab-rg"
  location = "Western Europe"
}

resource "azurerm_storage_account" "lab" {
  name                     = "insecurelabstorage9988" 
  
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Vuln 1
  public_network_access_enabled = true
  
  # Vuln 2
  min_tls_version = "TLS1_0"
}