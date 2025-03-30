terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.23.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}
}

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-core"
    storage_account_name = "sacoreinfrastate"
    container_name       = "terraform"
    key                  = "mlops/data/connections.terraform.tfstate"
  }
}
