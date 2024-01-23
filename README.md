# GitHub Actions Miscellaneous Tests

A repo for testing miscellaneous GitHub Actions functionality.

## Create Azure Credentials

```bash

# Set variable (or use an .env file)
TENANT_ID=YOUR_TENANT_ID
SUBSCRIPTION_ID=YOUR_SUBSCRIPTION_ID
RG_NAME=gh-actions-20240121
LOCATION=westus3

# From GH Codespaces terminal running in VS Code
az login --tenant $TENANT_ID

# Confirm Azure Account
az account show

# Create the Resource Group
az group create -g $RG_NAME -l $LOCATION

# Create an SP that has the permissions to contribute to the Resource Group
AZURE_CREDENTIALS=$(az ad sp create-for-rbac \
  --name $RG_NAME-sp \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME \
  --json-auth)

# Echo out the credentials
ECHO $AZURE_CREDENTIALS

# Execute the Bicep file to stand up the Infra
az deployment group create \
  --name deploy-gh-actions \
  --resource-group $RG_NAME \
  --template-file ./infra/sqlvm/main.bicep \
  --parameters vmUsername=$VM_USERNAME \
  vmPassword=$VM_PASSWORD \
  sqlUsername=$SQL_USERNAME \
  sqlPassword=$SQL_PASSWORD \
  kvSecretReaderSpAppObjId=$KEYVAULT_APP_OBJ_ID

# Set the credentials into the GitHub Secrets
gh secret set AZURE_CREDENTIALS -a actions -b"$AZURE_CREDENTIALS"

# Cleanup
az group delete --name $RG_NAME

```
