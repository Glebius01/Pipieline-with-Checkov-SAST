# 🛡️ DevSecOps CI/CD Pipeline with Terraform & Checkov

## Lab Overview:
The purpose of this lab is to gain hands-on experience with Terraform to declaratively design Azure cloud resources, implement a CI/CD pipeline, and establish SAST guardrails using Checkov to prevent the deployment of insecure infrastructure code.

---
🧰 Tool Set:
- VS Code
- Git
- Terraform
- Azure CLI
- Checkov
- Documentation for each product
- Gemini as a tutor
---
### Part 1. Preparation
Installing VS Code and all necessary extensions. Creating the "Dev-sec-ops-lab" folder, initializing tools, authenticating, and verifying everything works:

```
# Installing Terraform extension in VS Code via GUI and verifying it works

terraform init
terraform -help
```
```
# Installing Azure CLI via PowerShell  

Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi`
 
az login

# Setting the active subscription with Azure CLI
 
az account set --subscription "subscription-id"

#  Creating a Service Principal (an application within Azure Active Directory/Entra ID containing the authentication tokens Terraform needs to perform actions on your behalf)

az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/<SUBSCRIPTION_ID>"

# Setting environment variables. HashiCorp recommends setting these values as environment variables rather than saving them directly in your Terraform configuration

  $Env:ARM_CLIENT_ID = "<APPID_VALUE>"
  $Env:ARM_CLIENT_SECRET = "<PASSWORD_VALUE>"
  $Env:ARM_SUBSCRIPTION_ID = "<SUBSCRIPTION_ID>"
  $Env:ARM_TENANT_ID = "<TENANT_VALUE>"
```
---
### Part 2. Writing Insecure Infrastructure Code & Initial Commit
Creating the main.tf file and making the initial Git commit. The main.tf file is the primary configuration file used in Terraform to define core infrastructure resources, data sources, and module calls.

Taking the Terraform configuration from the tutorial as a base, modifying the location, name, and provider version, and introducing two explicit security vulnerabilities into the configuration:

```
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

# The required Resource Group
resource "azurerm_resource_group" "lab" {
  name     = "devsecops-lab-rg"
  location = "Western Europe"
}

# The vulnerable Storage Account
resource "azurerm_storage_account" "lab" {
  name                     = "insecurelabstorage9988" 
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # VULNERABILITY 1: Allowing public access
  public_network_access_enabled = true
  
  # VULNERABILITY 2: Forcing minimum TLS to an outdated version
  min_tls_version = "TLS1_0"
}
```
```
# Making the initial commit using Git:
git init
git add main.tf
git commit -m "Initial commit with vulnerable storage account"
git remote add origin https://github.com/Glebius01/Lab
git branch -M main
git push -u origin main
```
### Part 3. Creating the GitHub Actions Pipeline
Creating a hidden folder structure and file at this path: .github/workflows/security-scan.yml

This workflow uses actions/checkout@v4 to pull the repository code and runs the scanner directly inside Checkov's official Docker container to prevent unnecessary compute overhead:
```
    name: Checkov Security Scan
    
    on:
      push:
        branches: [ "master", "main" ]
    
    jobs:
      scan-infrastructure:
        runs-on: ubuntu-latest
        # Run directly inside the lightweight Checkov container
        container:
          image: bridgecrew/checkov:latest
    
    steps:
        - name: Checkout Code
          uses: actions/checkout@v4
        - name: Run Checkov
          run: checkov -d . --framework terraform
```

### Part 4. Validating SAST Guardrails & Troubleshooting
The aim of this step is to validate that SAST works and prevents the deployment of vulnerable code. However, here I had an issue - because Terraform I initialised Terraform locally, it created provider binaries that exceeded GitHub's file size limit (100MB+). Additionally, while I was trying to resolve the issue, I piled up unpushed commits.

I managed to resolve the issues using these commands:

```
# 1. Force-delete the hidden .terraform folder from disk
Remove-Item -Recurse -Force .terraform -ErrorAction SilentlyContinue

# 2. Reset local Git branch history to start completely fresh
git reset --hard

# 3. Create a .gitignore file so Git never tracks .terraform again
Set-Content .gitignore ".terraform/`n*.tfstate`n*.tfstate.backup"
```

Repeating the attempt - commit, push, and in GitHub Actions we can observe that Checkov failes the deployment:
<img width="1896" height="1026" alt="Pasted image 20260922184919" src="https://github.com/user-attachments/assets/0a10caa1-3266-47eb-b184-b7a70edaf60a" />


```
Check: CKV_AZURE_190: "Ensure that Storage blobs restrict public access"
FAILED for resource: azurerm_storage_account.lab
File: /main.tf:21-35

Check: CKV_AZURE_44: "Ensure Storage Account is using the latest version of TLS encryption"
FAILED for resource: azurerm_storage_account.lab
File: /main.tf:21-35
```
Besides the 2 vulnerabilities I deliberately left in the code, Checkov conducted 9 more checks signalling logging & data protection issues, and insecure credentials access. Each of these checks have a URL with detailed remediation guidance to configure secure version of the container should we need it.

In real enterprise environments, passing all 11 of those checks requires building a web of interdependent Azure resources (Virtual Networks, Subnets, Key Vaults, Private Endpoints, Managed Identities, Access Policies) which is out-of-scope of this lab.

Thus, we successfully built a "Shift-Left" pipeline that intercepted misconfigured IaC code and blocked deployment before cloud execution.
