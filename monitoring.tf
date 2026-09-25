# This block is responsible for creating a Log Analytics workspace and configuring diagnostic settings for an Azure Storage account to send logs and metrics to the workspace. This setup is essential for monitoring and auditing storage activities, which is a key aspect of Zero Trust and SecOps.

resource "azurerm_log_analytics_workspace" "secops" {
  name                = "secure1lab2storage"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "blob_logs" {
  name                       = "blob-audit-logging"
  target_resource_id         = "${azurerm_storage_account.lab.id}/blobServices/default" # Specfies the resource for monitoring.
  log_analytics_workspace_id = azurerm_log_analytics_workspace.secops.id

# This section enables logging for specific event types.

  enabled_log {
    category = "StorageRead"
  }
  
  enabled_log {
    category = "StorageWrite"
  }
  
  enabled_log {
    category = "StorageDelete"
  }
  
# This section enables metrics for the storage account, allowing for performance and usage monitoring.

  metric { 
    category = "Transaction"
    enabled  = true
  }
}