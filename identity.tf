# This block creates a User-Assigned Managed Identity (workload identity not a human) according to Zero Trust principles.

# 1. Secretless authentication: By using a User-Assigned Managed Identity, the application can authenticate to Azure services without the need for storing credentials or secrets in the code or configuration files.

# 2. Micro-segmentation: The identity is isolated and has limited access, reducing the potential impact of a security breach.

# 3. Role-based access control (RBAC): The identity can be assigned specific roles and permissions, allowing for fine-grained access control to Azure resources.

# -------------------------------------------------------------------------------------------------------------------------------

# This block assigns the "Storage Blob Data Reader" role to the User-Assigned Managed Identity created above. This allows the identity to read data from Azure Storage blobs, which is necessary for applications that need to access storage resources securely.

resource "azurerm_user_assigned_identity" "app_identity" {
  name                = "lab-app-identity"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
}

# Resource block Creates the permission bridge.
# Scope restricts the identity's permissions only to this specific storage account, limiting the "blast radius" in case of a security breach.
# Role definition specifies the exact permissions granted to the identity, in this case, read-only access to blob data.
# Principal ID links the role assignment to the specific User-Assigned Managed Identity created earlier, ensuring that only this identity has the specified access rights.
# Skip service principal is specfied to avoid potential crashes during the role assignment process, especially in scenarios where the identity might not yet be fully propagated in Azure's backend systems.

resource "azurerm_role_assignment" "storage_reader" { 
  scope                            = azurerm_storage_account.lab.id 
  role_definition_name             = "Storage Blob Data Reader"
  principal_id                     = azurerm_user_assigned_identity.app_identity.principal_id
  skip_service_principal_aad_check = true 
}

# -------------------------------------------------------------------------------------------------------------------------------

# 1. Fetch the identity of a human currently logged into Azure CLI
data "azurerm_client_config" "current" {}

# 2. Grant the human Data Plane access to upload/delete files
resource "azurerm_role_assignment" "human_contributor" {
  scope                = azurerm_storage_account.lab.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}