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
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Fetch current connection context (needed for Key Vault permissions)
data "azurerm_client_config" "current" {}

# The required Resource Group
resource "azurerm_resource_group" "lab" {
  name     = "devsecops-lab-rg"
  location = "Western Europe"
}

# ---------------------------------------------------------
# SUPPORTING RESOURCES FOR CUSTOMER MANAGED KEYS (CKV2_AZURE_1)
# ---------------------------------------------------------

# Identity to allow the Storage Account to read the Key Vault
resource "azurerm_user_assigned_identity" "lab" {
  name                = "storage-cmk-identity"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
}

# Key Vault to hold the encryption key
resource "azurerm_key_vault" "lab" {
  name                       = "devsecopskv9988" # Must be globally unique
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 7

  # Grant Terraform access to create the key
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = ["Create", "Get", "List", "Purge", "Recover", "Delete", "UnwrapKey", "WrapKey"]
  }

  # Grant Storage Account access to use the key for encryption
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.lab.principal_id
    key_permissions = ["Get", "UnwrapKey", "WrapKey"]
  }
}

# The actual Customer Managed Key
resource "azurerm_key_vault_key" "lab" {
  name         = "storage-cmk"
  key_vault_id = azurerm_key_vault.lab.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
  
  depends_on = [azurerm_key_vault.lab]
}

# ---------------------------------------------------------
# SUPPORTING RESOURCES FOR PRIVATE ENDPOINT (CKV2_AZURE_33)
# ---------------------------------------------------------

# Virtual Network & Subnet
resource "azurerm_virtual_network" "lab" {
  name                = "devsecops-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_subnet" "lab" {
  name                 = "devsecops-subnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.0.1.0/24"]
}


# ---------------------------------------------------------
# FULLY REMEDIATED STORAGE ACCOUNT
# ---------------------------------------------------------

resource "azurerm_storage_account" "lab" {
  name                     = "securelabstorage9988" 
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  
  # REMEDIATION: CKV_AZURE_206 (Use replication)
  account_replication_type = "GRS"

  # REMEDIATION: CKV_AZURE_59 (Disallow public network access entirely)
  public_network_access_enabled = false

  # REMEDIATION: CKV_AZURE_44 (Latest TLS version)
  min_tls_version = "TLS1_2"

  # REMEDIATION: CKV_AZURE_190 & CKV2_AZURE_47 (Restrict anonymous blob access)
  allow_nested_items_to_be_public = false

  # REMEDIATION: CKV2_AZURE_40 (Disable Shared Key Auth, force Entra ID)
  shared_access_key_enabled = false

  # REMEDIATION: CKV2_AZURE_41 (Require SAS Token expiration limits)
  sas_policy {
    expiration_period = "90.00:00:00" # 90 Days
    expiration_action = "Log"
  }

  # REMEDIATION: CKV_AZURE_33 (Enable Queue Logging)
  queue_properties {
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 7
    }
  }

  # REMEDIATION: CKV2_AZURE_38 (Enable Soft Delete)
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  # Attach identity so it can access the Key Vault
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.lab.id]
  }

  # REMEDIATION: CKV2_AZURE_1 (Customer Managed Key)
  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.lab.id
    user_assigned_identity_id = azurerm_user_assigned_identity.lab.id
  }
  
  depends_on = [azurerm_key_vault_key.lab]
}

# ---------------------------------------------------------
# PRIVATE ENDPOINT ATTACHMENT
# ---------------------------------------------------------

# REMEDIATION: CKV2_AZURE_33 (Configure Private Endpoint)
resource "azurerm_private_endpoint" "lab" {
  name                = "storage-pe"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.lab.id

  private_service_connection {
    name                           = "storage-psc"
    private_connection_resource_id = azurerm_storage_account.lab.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}