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

az group create -g $RG_NAME -l $LOCATION

az deployment group create \
  --name deploy-gh-actions \
  --resource-group $RG_NAME \
  --template-file ./infra/sqlvm/main.bicep \
  --parameters vmUsername=$VM_USERNAME \
  vmPassword=$VM_PASSWORD \
  sqlUsername=$SQL_USERNAME \
  sqlPassword=$SQL_PASSWORD \
  kvSecretReaderSpAppObjId=$KEYVAULT_APP_OBJ_ID



//az keyvault secret set --vault-name $RG_NAME-kv --name "dbconnstr" --value "Server=tcp:gh-actions-20231204-sql.database.windows.net,1433;Initial Catalog=mydatabase;Persist Security Info=False;User ID=sqlsa;Password=XXXXXX;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# TODO: Add permissions to the service principal for the key vault

AZURE_CREDENTIALS=$(az ad sp create-for-rbac \
  --name $RG_NAME-sp \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME \
  --json-auth)

gh secret set AZURE_CREDENTIALS -a actions -b"$AZURE_CREDENTIALS"

# Cleanup
az group delete --name $RG_NAME

```
