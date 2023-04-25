#--------------------------------------------------------------
#   Locals
#--------------------------------------------------------------
locals {
  prefix = "use2-ccl-aks-poc"
  image  = "acruse2cclakspoc.azurecr.io/akvdotnet"
  tag    = "v94"
}

#--------------------------------------------------------------
#   Data
#--------------------------------------------------------------
data "azurerm_client_config" "this" {}
data "azurerm_resource_group" "this" {
  name = "rg-${local.prefix}"
}
#   / User Managed Identity
data "azurerm_user_assigned_identity" "this" {
  name                = "uaid-${local.prefix}-wkload-identity"
  resource_group_name = data.azurerm_resource_group.this.name
}
#   / AKS Cluster
data "azurerm_kubernetes_cluster" "this" {
  name                = split("/", var.aks_cluster_id)[8]
  resource_group_name = split("/", var.aks_cluster_id)[4]

  #   Note: update the cluster to use AKS Managed Identities: 
  #   az aks update -g rg-cae-mngenv-aks-sevrier-01 -n aks-cae-mngenv-sevrier --enable-oidc-issuer --enable-workload-identity
  #   az aks show -g rg-cae-mngenv-aks-sevrier-01 -n aks-cae-mngenv-sevrier
  #   To disable Workload Identity: az aks update -g myResourceGroup -n myAKSCluster --enable-workload-identity false
}
#   / Key vault
data "azurerm_key_vault" "this" {
  name                = "kv-${local.prefix}"
  resource_group_name = data.azurerm_resource_group.this.name
}
#   / Key vault secret
data "azurerm_key_vault_secret" "this" {
  key_vault_id = data.azurerm_key_vault.this.id
  name         = "my-secret"
}
#   / Container Registry
data "azurerm_container_registry" "this" {
  name                = replace("acr-${local.prefix}", "-", "")
  resource_group_name = data.azurerm_resource_group.this.name
}

#--------------------------------------------------------------
#   Azure Resources
#--------------------------------------------------------------
resource "azurerm_role_assignment" "aks_acr_acrpull" {
  principal_id         = data.azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id # kubelet identity
  role_definition_name = "AcrPull"
  scope                = data.azurerm_container_registry.this.id
}

# Ref: https://learn.microsoft.com/en-us/azure/aks/learn/tutorial-kubernetes-workload-identity#establish-federated-identity-credential
resource "azurerm_federated_identity_credential" "poc" {
  name                = "fedidcred-azurerm-wkldid-poc"
  resource_group_name = data.azurerm_resource_group.this.name

  audience  = ["api://AzureADTokenExchange"]
  issuer    = data.azurerm_kubernetes_cluster.this.oidc_issuer_url
  parent_id = data.azurerm_user_assigned_identity.this.id
  subject   = "system:serviceaccount:${kubernetes_namespace_v1.poc.metadata[0].name}:${kubernetes_service_account_v1.poc.metadata[0].name}"
}

resource "azurerm_federated_identity_credential" "test" {
  name                = "fedidcred-azurerm-wkldid-test"
  resource_group_name = data.azurerm_resource_group.this.name

  audience  = ["api://AzureADTokenExchange"]
  issuer    = data.azurerm_kubernetes_cluster.this.oidc_issuer_url
  parent_id = data.azurerm_user_assigned_identity.this.id
  subject   = "system:serviceaccount:${kubernetes_namespace_v1.test.metadata[0].name}:${kubernetes_service_account_v1.test.metadata[0].name}"
}

#--------------------------------------------------------------
#   Kubernetes Resources
#--------------------------------------------------------------
# / PoC with Tutorial article
resource "kubernetes_namespace_v1" "poc" {
  metadata {
    name = "wkldid-poc"
  }
}
resource "kubernetes_service_account_v1" "poc" {
  metadata {
    name      = "wkldid-poc-sa"
    namespace = kubernetes_namespace_v1.poc.metadata[0].name
    annotations = {
      "azure.workload.identity/client-id" = data.azurerm_user_assigned_identity.this.client_id
    }
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }
  # Result can be checked with "kubectl get serviceaccounts"
}
resource "kubernetes_pod_v1" "poc" {
  metadata {
    name      = "quick-start"
    namespace = kubernetes_namespace_v1.poc.metadata[0].name
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }

  spec {
    service_account_name = kubernetes_service_account_v1.poc.metadata[0].name
    container {
      image = "ghcr.io/azure/azure-workload-identity/msal-go"
      name  = "oidc"

      env {
        name  = "KEYVAULT_URL"
        value = data.azurerm_key_vault.this.vault_uri
      }
      env {
        name  = "SECRET_NAME"
        value = data.azurerm_key_vault_secret.this.name
      }
    }
    node_selector = {
      "kubernetes.io/os" = "linux"
    }
  }
  # Check results with:
  #   kubectl describe pod quick-start
  #   kubectl logs quick-start
}

# / Test with akvdotnet
resource "kubernetes_namespace_v1" "test" {
  metadata {
    name = "wkldid-test"
  }
}
resource "kubernetes_service_account_v1" "test" {
  metadata {
    name      = "wkldid-test-sa"
    namespace = kubernetes_namespace_v1.test.metadata[0].name
    annotations = {
      "azure.workload.identity/client-id" = data.azurerm_user_assigned_identity.this.client_id
    }
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }
  # Result can be checked with "kubectl get serviceaccounts"
}
resource "kubernetes_pod_v1" "test" {
  metadata {
    name      = "akvdotnet"
    namespace = kubernetes_namespace_v1.test.metadata[0].name
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }

  spec {
    service_account_name = kubernetes_service_account_v1.test.metadata[0].name
    container {
      image = "${local.image}:${local.tag}"
      name  = "akvdotnet"

      env {
        name  = "KEYVAULT_URL"
        value = data.azurerm_key_vault.this.vault_uri
      }
      env {
        name  = "SECRET_NAME"
        value = data.azurerm_key_vault_secret.this.name
      }
    }
    node_selector = {
      "kubernetes.io/os" = "linux"
    }
  }
  # Check results with:
  #   kubectl describe pod quick-start
  #   kubectl logs quick-start
}
#*/
