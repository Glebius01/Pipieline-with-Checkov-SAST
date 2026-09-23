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

# 1. Resource Group
resource "azurerm_resource_group" "lab" {
  name     = "devsecops-lab-rg"
  location = "Western Europe"
}

# ---------------------------------------------------------
# CLOUD GOVERNANCE: CIS INITIATIVE ASSIGNMENT
# ---------------------------------------------------------

data "azurerm_subscription" "current" {}

data "azurerm_policy_set_definition" "cis" {
  display_name = "CIS Microsoft Azure Foundations Benchmark v2.0.0"
}

resource "azurerm_subscription_policy_assignment" "cis" {
  name                 = "lab-cis-benchmark"
  display_name         = "Lab CIS Azure Foundations Benchmark"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = data.azurerm_policy_set_definition.cis.id
  location             = "Western Europe"

  identity {
    type = "SystemAssigned"
  }
}

# ---------------------------------------------------------
# ---------------------------------------------------------
# INFRASTRUCTURE HARDENING: COMPLIANT STORAGE ACCOUNT
# ---------------------------------------------------------

resource "azurerm_storage_account" "lab" {
#checkov:skip=CKV2_AZURE_1: "Managed by Azure platform-managed keys for standalone lab scope."
#checkov:skip=CKV2_AZURE_33: "Private endpoints omitted for standalone lab environment without VNet."
#checkov:skip=CKV_AZURE_33: "Queue logging handled via subscription-level Azure Monitor diagnostic settings."

  name                     = "securelabstorage9988"
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