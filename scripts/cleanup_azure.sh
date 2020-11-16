#!/bin/bash

############################################################################################################################################
#- Purpose: Script is used to delete Azure resources created by the scripts during the tutorial.
#- Parameters are:
#- [-s] azure subscription - The Azure subscription to use (required)
#- [-g] azure resource group - The Azure resource group (required)
#- [-p] prefix - Unique prefix that will be added to the name of each Azure resource (required)
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
    echo -e "\t-g \t The Azure Resource Group (required)"
    echo -e "\t-p \t Unique prefix that will be added to the name of each Azure resource (required)"
    echo -e "\t-h \t Help (optional)"    
    echo
    echo "Example:"
    echo -e "./cleanup_azure.sh -s <some_azure_subscription> -g rg-cse-jenkins-example -p cse"
}

parent_path=$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd -P
)

cd "$parent_path"

# Include util
source helpers/utils.sh

# Loop, get parameters & remove any spaces from input
while getopts "s:g:p:h" opt; do
    case $opt in
        s)
            # subscription
            subscriptionId=$OPTARG
        ;;    
        p)
            # prefix
            prefix=$OPTARG
        ;;
        g)
            # resource group
            resourceGroup=$OPTARG
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
if [[ $# -eq 0 || -z $subscriptionId || -z $prefix || -z $resourceGroup ]]; then
    error "Required parameters are missing"
    usage
    exit 1
fi

# set default account
az account set -s $subscriptionId -o none

# delete resource group
 az group delete -n $resourceGroup \
    --subscription $subscriptionId \
    -y

# get sp name
spName="http://$(createResourceName -t sp -p $prefix)"

# delete service principal
az ad sp delete --id $spName \
    -o none

# purge the keyvault
keyVaultName=$(createResourceName -t kv -p $prefix)
az keyvault purge --name $keyVaultName

printf "Cleanup Script is done.\n\n"

echo "Please note this script set your default Azure Subscription to $subscriptionId, please reset to previous Azure Subscription before running future azure-cli commands"    