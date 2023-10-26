# Redgate Clone Infrastructure Terraform 
Sample terraform to provision Redgate Clone infrastructure on Azure.

## Prerequisites

* An [Azure](https://azure.microsoft.com/) subscription.
* A shell with both [the `terraform` CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) and [Azure's `az` CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed.

## Getting Started

1. Log in to Azure and set your account to the [the appropriate subscription ID](https://learn.microsoft.com/en-us/azure/azure-portal/get-subscription-tenant-id):
    ```bash
    az login
    az account set --subscription <your-azure-subscription-id>
    ```
   
2. Create a [resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/overview#resource-groups) in an appropriate region to hold all of the infrastructure for Redgate Clone.
    ```bash
    az group create --name redgate-clone --location <your-region>
    ```
    If you'd like to see what regions are available you can run the following:
    ```bash
    az account list-locations --query "[*].name"
    ```

3. Create a [storage account](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview).
    ```bash
    az storage account create --name rgclonestorageaccount --resource-group redgate-clone
    ```

4. Create a [container](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction#containers) to hold the Terraform state.
    ```bash
    az storage container create --name terraform-state --resource-group redgate-clone --account-name rgclonestorageaccount
    ```

5. Get the access key for the storage account that holds the Terraform state. You can get the key from the following command, from the `value` field:
    ```bash
    az storage account keys list --resource-group redgate-clone --account-name rgclonestorageaccount
    ```
   
    Then store the key in the `ARM_ACCESS_KEY` environment variable so that the `terraform` CLI can read it:  
    
    On Linux/MacOS:
    ```bash
    export ARM_ACCESS_KEY=<key>  
    ```
    On Windows (Powershell):
    ```pwsh
    $env:ARM_ACCESS_KEY="<key>"
    ```


6. Open the `main.tf` file.
   * Set the `subscription_id` in the `azurerm` provider with your [Azure subscription ID](https://learn.microsoft.com/en-us/azure/azure-portal/get-subscription-tenant-id).
   * Set the `vm_password` in the `dev` module with an [Azure VM compliant password.](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/faq#what-are-the-password-requirements-when-creating-a-vm-)

7. Prepare and validate your files and working directory via the `terraform` command:
    ```bash
    terraform fmt
    terraform init
    terraform validate
    ```

8. Check what infrastructure `terraform` will produce:
    ```bash
    terraform plan
    ```

9. If you're happy with the output of the previous command, generate the infrastructure:
    ```bash
    terraform apply
    ```

10. After the infrastructure has finished deploying, you should be able to follow the [Redgate Clone installation documentation](https://documentation.red-gate.com/x/mQARCQ) to continue.
