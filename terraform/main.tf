#--------------------------------------------------------------
#   Locals
#--------------------------------------------------------------
locals {
  prefix = "use2-ccl-aks-poc"
}

#--------------------------------------------------------------
#   Data
#--------------------------------------------------------------
data "http" "icanhazip" {
  url = "http://icanhazip.com"
}
data "azurerm_client_config" "this" {}


#--------------------------------------------------------------
#   Azure Resources
#--------------------------------------------------------------
#   / Resource Group
resource "azurerm_resource_group" "this" {
  name     = "rg-${local.prefix}"
  location = "East US 2"
}

#   / Key vault
resource "azurerm_key_vault" "this" {
  name                      = "kv-${local.prefix}"
  resource_group_name       = azurerm_resource_group.this.name
  location                  = azurerm_resource_group.this.location
  tenant_id                 = var.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true
  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Allow" # "Deny" - Doing that to allow access from AKS cluster
    ip_rules                   = ["${chomp(data.http.icanhazip.response_body)}"]
    virtual_network_subnet_ids = []
  }
}
resource "azurerm_key_vault_secret" "this" {
  key_vault_id = azurerm_key_vault.this.id
  name         = "my-secret"
  value        = "Say hello to AKS Workload Identity!"
}

#   / Managed Identity
resource "azurerm_user_assigned_identity" "this" {
  name                = "uaid-${local.prefix}-wkload-identity"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}
resource "azurerm_role_assignment" "uai_kv_secretuser" {
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.this.id
}

#   / Container Registry
resource "azurerm_container_registry" "this" {
  name                = replace("acr-${local.prefix}", "-", "")
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
}
resource "azurerm_role_assignment" "spn-ado_acr_acrpush" {
  principal_id         = "8cf2f167-2675-4b46-9af0-d5655f1ddcdd" # sp-mngenv-cclakspoc-ado-pipelines Enterprise App Object Id
  role_definition_name = "AcrPush"
  scope                = azurerm_container_registry.this.id
}
#*/
