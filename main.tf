# The engine - fetches azurerm plugin and sets up the required version of Terraform.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.1.0"
}
# Authentication to Azure is handled via the azurerm provider, which uses the Azure CLI or environment variables for credentials.
provider "azurerm" {
  features {}
}

# Creates a resource group in Azure to contain all resources for the lab environment.
resource "azurerm_resource_group" "lab" {
  name     = "devsecops-lab-rg"
  location = "ukwest"
}

# The following resource block creates a storage account in Azure with specific security configurations.

resource "azurerm_storage_account" "lab" {
#checkov:skip=CKV2_AZURE_1: "Managed by Azure platform-managed keys for standalone lab scope."
#checkov:skip=CKV2_AZURE_33: "Private endpoints omitted for standalone lab environment without VNet."
#checkov:skip=CKV_AZURE_33: "Queue logging handled via subscription-level Azure Monitor diagnostic settings."

  name                     = "secure1lab2storage"
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  public_network_access_enabled   = false
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
  shared_access_key_enabled       = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  infrastructure_encryption_enabled = true
}

# Attaching a child container to the storage account, where all the data will be stored.

resource "azurerm_storage_container" "lab_container" {
  name                  = "test-data"
  storage_account_name  = azurerm_storage_account.lab.name
  container_access_type = "private"
}