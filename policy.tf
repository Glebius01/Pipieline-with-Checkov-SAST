# This block is responsible for assigning the CIS Microsoft Azure Foundations Benchmark v2.0.0 policy set to the current subscription. The CIS benchmark is a widely recognized set of best practices for securing cloud environments, and applying this policy set helps ensure that the Azure resources in the subscription adhere to these security standards.


# Data block is for looking up existing things. In this instance it fetches the current subscription ID and the CIS benchmark policy set definition.

data "azurerm_subscription" "current" {}
data "azurerm_policy_set_definition" "cis" {
  display_name = "CIS Microsoft Azure Foundations Benchmark v2.0.0"
}

resource "azurerm_subscription_policy_assignment" "cis" {
  name                 = "lab-cis-benchmark"
  subscription_id      = data.azurerm_subscription.current.id #instructs where to assign the policy set (current subscription)
  policy_definition_id = data.azurerm_policy_set_definition.cis.id #instructs which policy set to assign (CIS benchmark)
  location             = azurerm_resource_group.lab.location

  identity {
    type = "SystemAssigned"
  }
}