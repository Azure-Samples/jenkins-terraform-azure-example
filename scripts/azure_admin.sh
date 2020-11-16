#!/bin/bash

############################################################################################################################################
#- Purpose: Script is used to create a Service Principal, Azure Storage Account and KeyVault.
#-          The Service Principal will be granted read access to the KeyVault and will be used by Jenkins.
#- Parameters are:
#- [-s] azure subscription - The Azure subscription to use (required)
#- [-p] prefix - Unique prefix that will be added to the name of each Azure resource (required)
#- [-l] azure location - The location for the Azure Resource Group (required)
#- [-h] help - Help (optional)
############################################################################################################################################

set -eu

###############################################################
#- function used to print out script usage
###############################################################
function usage() {
    echo
    echo "Arguments:"
    echo -e "\t-s \t The Azure Subscription ID (required)"
    echo -e "\t-p \t Unique prefix that will be added to the name of each Azure resource (required)"    
    echo -e "\t-l \t The location for the Azure Resource Group (required)"    
    echo -e "\t-h \t Help (optional)"
    echo
    echo "Example:"
    echo -e "./azure_admin.sh -s <some_azure_subscription> -p cse -l eastus"
}

parent_path=$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd -P
)

cd "$parent_path"

# Include util
source helpers/utils.sh

# Loop, get parameters & remove any spaces from input
while getopts "s:p:l:h" opt; do
    case $opt in
        s)
            # resource group
            subscriptionId=$OPTARG
        ;;    
        p)
            # prefix
            prefix=$OPTARG
        ;;
        l)
            # location
            location=$OPTARG
        ;;        
        :)
          echo "Error: -${OPTARG} requires a value"
          exit 1
        ;;
        *)
          usage
          exit 1
        ;;
    esac
done

# validate parameters
if [[ $# -eq 0 || -z $subscriptionId || -z $location || -z $prefix ]]; then
    error "Required parameters are missing"
    usage
    exit 1
fi

# set default account
az account set -s $subscriptionId -o none

# create resource names
spName="http://$(createResourceName -t sp -p $prefix)"
resourceGroup=$(createResourceName -t rg -p $prefix)
keyVaultName=$(createResourceName -t kv -p $prefix)
storageAccountName=$(createResourceNameNoDashes -t satf -p $prefix)
appServicePlan=$(createResourceName -t asp -p $prefix)
appServiceName=$(createResourceName -t as -p $prefix)


# Check if client secret exists in key vault. If not, create new service principal or allow Azure to 
# patch existing service principal with updated password.
printf "Checking for existing Service Principal ...\n\n"
if ! az keyvault secret show --vault-name $keyVaultName --name "SERVICE-PRINCIPAL-APP-SECRET" --query name -o tsv; then
    # create service principal; store password
    printf "Creating Service Principal and storing client secret...\n\n"
    CLIENT_SECRET=$(az ad sp create-for-rbac -n $spName --query password -o tsv)
else
    CLIENT_SECRET=$(az keyvault secret show --vault-name $keyVaultName --name "SERVICE-PRINCIPAL-APP-SECRET" --query value -o tsv)
    echo "Retrieving client secret from key vault."
fi

if [[ -z $CLIENT_SECRET ]]
then
  echo "ERROR: failed to create the service principal"
  exit 1
fi

# retrieve service principal id
CLIENT_ID=$(az ad sp show --id $spName --query appId -o tsv)

if [[ -z $CLIENT_ID ]]
then
  echo "ERROR: failed to retrieve the service principal id"
  exit 1
fi

# retrieve subscription id
SUBSCR_ID=$(az account show -o tsv --query id)
# retrieve tenant id
TENANT_ID=$(az account show -o tsv --query tenantId)

echo "Checking if resource group $resourceGroup exists with location $location."
if [[ -n $resourceGroup ]] && [[ -n $location ]]; then
    if az group show -n $resourceGroup --query name -o tsv; then
        LOCATION=$(az group show -n $resourceGroup --query location -o tsv)
        printf "Using existing resource group: $resourceGroup in $location.\n\n"
    elif ! az group create --name $resourceGroup --location $location --tags "Project=Jenkins_Terraform_Azure_Example" -o table; then
        echo "ERROR: Failed to create the resource group."
        exit 1
    else
        printf "Created resource group: $resourceGroup in $location.\n\n"
    fi
fi

printf "Setting up Key Vault now...\n\n"
echo "Checking if key vault $keyVaultName already exists."

if [[ -n $keyVaultName ]]; then
    if az keyvault show --name $keyVaultName --resource-group $resourceGroup --query name -o tsv; then
        printf "Using existing key vault: $keyVaultName.\n\n"
    elif ! az keyvault create --name $keyVaultName --resource-group $resourceGroup -o table; then
        echo "ERROR: Failed to create key vault."
        exit 1
    else
        printf "Key vault created.\n\n"
    fi
fi  

# assigning service principal access to keyvault
printf "Assigning read access for the service to key vault via access policy...\n\n"
az keyvault set-policy --name $keyVaultName  --spn $spName --secret-permissions get list \
--subscription $SUBSCR_ID

printf "Creating Terraform Backend Storage Account...\n\n"
echo "Checking if storage account $storageAccountName already exists"
if [[ -n ${SUBSCR_ID} ]]; then
    if az storage account show --name $storageAccountName --resource-group $resourceGroup --query name -o tsv; then
        printf "Using existing storage account: $storageAccountName.\n\n"
    elif ! az storage account create --resource-group $resourceGroup --name $storageAccountName --sku Standard_LRS --encryption-services blob -o table; then
        echo "ERROR: Failed to create storage account."
        exit 1
    else
        printf "Pipeline Storage Account created. Name = $storageAccountName.\n\n"
    fi
fi

# retrieve storage account access key
if [[ -n $resourceGroup ]]; then
    if ! ARM_ACCESS_KEY=$(az storage account keys list --resource-group $resourceGroup --account-name $storageAccountName --query [0].value -o tsv); then
        echo "ERROR: Failed to Retrieve Storage Account Access Key."
        exit 1
    fi
    printf "Pipeline Storage Account Access Key = ${ARM_ACCESS_KEY}.\n\n"
fi

# create storage container
if [[ -n $resourceGroup ]]; then
    if ! az storage container create --name "container$storageAccountName" --public-access off --account-name $storageAccountName --account-key $ARM_ACCESS_KEY -o table; then
        echo "ERROR: Failed to Retrieve Storage Container."
        exit 1
    fi
    echo "TF State Storage Account Container created."
    export TFSA_CONTAINER=$(az storage container show --name "container$storageAccountName" --account-name $storageAccountName --account-key ${ARM_ACCESS_KEY} --query name -o tsv)
    echo "TF Storage Container name = ${TFSA_CONTAINER}"
fi

## KEYVAULT SECRETS ##

# service principal variables
if ! az keyvault secret show --vault-name $keyVaultName --name "SERVICE-PRINCIPAL-SUB-ID" --query name -o tsv; then
    az keyvault secret set -o table --vault-name $keyVaultName --name "SERVICE-PRINCIPAL-SUB-ID"     --value $SUBSCR_ID
else
    printf "SERVICE-PRINCIPAL-SUB-ID already exists in key vault.\n\n"
fi

if ! az keyvault secret show --vault-name $keyVaultName --name "SERVICE-PRINCIPAL-TENANT-ID" --query name -o tsv; then
    az keyvault secret set -o table --vault-name $keyVaultName --name "SERVICE-PRINCIPAL-TENANT-ID"  --value $TENANT_ID
else
    printf "SERVICE-PRINCIPAL-TENANT-ID already exists in key vault.\n\n"
fi

if ! az keyvault secret show --vault-name $keyVaultName --name "SERVICE-PRINCIPAL-APP-ID" --query name -o tsv; then
    az keyvault secret set -o table --vault-name $keyVaultName --name "SERVICE-PRINCIPAL-APP-ID"     --value $CLIENT_ID
else
    printf "SERVICE-PRINCIPAL-APP-ID already exists in key vault.\n\n"
fi

if ! az keyvault secret show --vault-name $keyVaultName --name "SERVICE-PRINCIPAL-APP-SECRET" --query name -o tsv; then
    az keyvault secret set -o table --vault-name $keyVaultName --name "SERVICE-PRINCIPAL-APP-SECRET" --value $CLIENT_SECRET
else
    printf "SERVICE-PRINCIPAL-APP-SECRET already exists in key vault.\n\n"
fi

# storage variables
az keyvault secret set -o table --vault-name $keyVaultName --name "BACKEND-STORAGE-ACCOUNT-NAME"             --value $storageAccountName
az keyvault secret set -o table --vault-name $keyVaultName --name "BACKEND-STORAGE-ACCOUNT-CONTAINER-NAME"   --value $TFSA_CONTAINER
az keyvault secret set -o table --vault-name $keyVaultName --name "BACKEND-ACCESS-KEY"                       --value $ARM_ACCESS_KEY
az keyvault secret set -o table --vault-name $keyVaultName --name "BACKEND-KEY"                              --value "terraform.tfstate"

# other variables
if ! az keyvault secret show --vault-name $keyVaultName --name "LOCATION" --query name -o tsv; then
    az keyvault secret set -o table --vault-name $keyVaultName --name "LOCATION" --value $location
else
    printf "LOCATION already exists in key vault.\n\n"
fi

if ! az keyvault secret show --vault-name $keyVaultName --name "RG-NAME" --query name -o tsv; then
    az keyvault secret set -o table --vault-name $keyVaultName --name "RG-NAME"  --value $resourceGroup
else
    printf "RG-NAME already exists in key vault.\n\n"
fi

if ! az keyvault secret show --vault-name $keyVaultName --name "KV-NAME" --query name -o tsv; then
    az keyvault secret set -o table --vault-name $keyVaultName --name "KV-NAME"  --value $keyVaultName
else
    printf "INFRA-KV-NAME already exists in key vault.\n\n"
fi

# eventgrid viewer blazor variables
az keyvault secret set -o table --vault-name $keyVaultName --name "EGVB-APP-SERVICE-PLAN-NAME" --value $appServicePlan
az keyvault secret set -o table --vault-name $keyVaultName --name "EGVB-APP-SERVICE-NAME" --value $appServiceName

printf "Azure Admin Script is done.\n\n"

echo "Please note this script set your default Azure Subscription to $subscriptionId, please reset to previous Azure Subscription before running future azure-cli commands"