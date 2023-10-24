terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.58.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "redgate-clone"
    storage_account_name = "rgclonestorageaccount"
    container_name       = "terraform-state"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = "<your-subscription-id>"
}

module "dev" {
  source              = "./modules/services/embedded"
  resource_group_name = "redgate-clone"
  vm_size             = "Standard_D8ls_v5"
  vm_password         = 
}
