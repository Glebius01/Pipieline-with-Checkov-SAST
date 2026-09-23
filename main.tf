# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
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

# 1. PARENT MODULE: Creates and Hardens the Storage Account
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.2.0" # Use a stable parent module version

  name                = "securelabstorage9988"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  account_tier             = "Standard"
  account_replication_type = "GRS"

  # CIS / Security Baseline Inputs
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  enable_https_traffic_only       = true
}

# 2. SUB-MODULE (Optional): Creates a Container inside the Storage Account
module "storage_container" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm//modules/container"
  version = "0.2.0"

  name                  = "secure-data-container"
  storage_account_name  = module.storage_account.name
  container_access_type = "private" # Ensures container is private
}