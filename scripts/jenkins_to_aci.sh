#!/bin/bash

############################################################################################################################################
#- Purpose: Script is used to create a Azure Container Registry, upload the Jenkins image to the
#-          Azure Container Registry & deploys an Azure Container Instance with a Storage Account
#-          file share mount.
#- Parameters are:
#- [-s] azure subscription - The Azure subscription to use (required)
#- [-g] azure resource group - The name of the Azure resource group (required)
#- [-l] azure location - The location for the Azure Resource Group (required)
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
    echo -e "\t-p \t Unique prefix that will be added to the name of each Azure resource (required)"    
    echo -e "\t-l \t The location for the Azure Resource Group (required)"    
    echo -e "\t-h \t Help (optional)"    
    echo
    echo "Example:"
    echo -e "./jenkins_to_aci.sh -s <some_azure_subscription> -p cse -l eastus"
}

parent_path=$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd -P
)

cd "$parent_path"

# Include util
source helpers/utils.sh

declare ACI_FILE_SHARE_NAME=acishare

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
if [[ $# -eq 0 || -z $subscriptionId || -z $prefix || -z $location ]]; then
    error "Required parameters are missing"
    usage
    exit 1
fi

# create resource names
resourceGroup=$(createResourceName -t rg -p $prefix)
acrName=$(createResourceNameNoDashes -t acr -p $prefix)
aciName=$(createResourceName -t aci -p $prefix)
aciStorageAccountName=$(createResourceNameNoDashes -t saaci -p $prefix)

# set default account
az account set -s $subscriptionId -o none

#create the azure resource group
 az group create --l eastus \
    -n $resourceGroup \
    --tags "Project=Jenkins_Terraform_Azure_Example" \
    -o none

# create storage account for aci
az storage account create \
    -g $resourceGroup \
    -n $aciStorageAccountName \
    --location eastus \
    --sku Standard_LRS \
    -o none

# Create the file share
az storage share create \
  --name $ACI_FILE_SHARE_NAME \
  --account-name $aciStorageAccountName \
  -o none

# create acr
az acr create -n $acrName \
    -g $resourceGroup \
    --sku Standard \
    --admin-enabled \
    -o none

# get login server
acrLoginServer=$(az acr show --name $acrName --query loginServer -o tsv)

# build image
docker build -t jenkins/cse-sample:lts ../

# re-tag jenkins image
docker tag jenkins/cse-sample:lts "$acrLoginServer/cse-jenkins-sample:lts"

# get acr admin user
acrAdminUser=$(az acr credential show -n $acrName -g $resourceGroup --query username -o tsv)

# get acr admin password
acrAdminPassword=$(az acr credential show -n $acrName -g $resourceGroup --query passwords[0].value -o tsv)

# log into acr
az acr login --name $acrName

# push image to acr
echo "pushing the jenkins image to azure container registry"
docker push "$acrLoginServer/cse-jenkins-sample:lts"

# get aci storage account key
echo "getting aci storage account key"
aciStorageAccountKey=$(az storage account keys list --resource-group $resourceGroup --account-name $aciStorageAccountName --query "[0].value" --output tsv)

# deploy to aci
echo "deploying the jenkins image to azure container instances"
az container create --resource-group $resourceGroup \
    --name $aciName \
    --image "$acrLoginServer/cse-jenkins-sample:lts" \
    --cpu 1 --memory 5 \
    --registry-login-server $acrLoginServer \
    --registry-username $acrAdminUser \
    --registry-password $acrAdminPassword \
    --dns-name-label "$aciName-dns" \
    --ports 8080 5000 \
    -o none \
    --azure-file-volume-account-name $aciStorageAccountName \
    --azure-file-volume-account-key $aciStorageAccountKey \
    --azure-file-volume-share-name $ACI_FILE_SHARE_NAME \
    --azure-file-volume-mount-path /var/jenkins_home/
    

# get aci fdqn
aciFdqn=$(az container show --resource-group $resourceGroup --name $aciName --query ipAddress.fqdn -o tsv)

echo "Jenkins has been deployed to azure container instances.  To access, navigate to: $aciFdqn:8080"
echo
echo "Once you are connected to the container in the Azure Portal you can get the admin password in the file: /var/jenkins_home/secrets/initialAdminPassword"
echo
echo "Please note this script set your default Azure Subscription to $subscriptionId, please reset to previous Azure Subscription before running future azure-cli commands"