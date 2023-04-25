#--------------------------------------------------------------
#   Terraform
#--------------------------------------------------------------

terraform {
  required_version = ">=1.0"

  required_providers {
    azurerm = {
      # https://registry.terraform.io/providers/hashicorp/azurerm/latest
      source  = "hashicorp/azurerm"
      version = ">=3.0"
    }
  }
}