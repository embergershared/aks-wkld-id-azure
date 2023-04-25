# AKS Workload Identity - Azure repo

## Overview

This terraform repository contains the code to deploy an application Workload Identity in both Azure and Kubernetes.

It is inspired by the tutorial [Use a workload identity with an application on Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/learn/tutorial-kubernetes-workload-identity)

## Description

The `terraform` folder contains `azurerm` resources that will be used for the Workload Identity, outside of any `kubernetes` dependencies or link.

It mainly deploys:

- A **Resource Group**,
- An Azure resource the App in Kubernetes will connect to. Here, an Azure **Key vault** with a **secret**,
- An **User Assigned Identity** that will be the authentication context for the App in Kubernetes,
- An Azure **Container Registry** that will store the iterative versions of the docker image the App in Kubernetes,
- The required **Role Assignments** to authorize the various identities used.

The `k8s` folder contains `kubernetes` and `azurerm` resources that will be use the Workload Identity in AKS. The `azurerm` that are in this folder either uses the `data` source to access the previously created resources or create resources that require `kubernetes` or `AKS` related inputs, like the `namespace` name.

It mainly deploys:

- A **Role Assignment** to allow the target AKS cluster to pull images from the ACR,
- A **Federated Identity Credential** in the User Assigned Identity used, to allow AKS `OIDC Issuer` to be trusted when using the Workload Identity,
- A **namespace**,
- A **Service Account**,
- A **pod**.

## References

- [Use Azure AD workload identity with Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)

- [Use a workload identity with an application on Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/learn/tutorial-kubernetes-workload-identity)
