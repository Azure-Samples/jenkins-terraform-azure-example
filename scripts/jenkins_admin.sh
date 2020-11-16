#!/bin/bash

#################################################################################################################################
#- Purpose: Script is used by a Jenkins Admin to connect to the KeyVault created in the azure_admin.sh script,
#-          fetch Azure Service Principal information and store this information in Jenkins
#-          using jenkins-cli.
#- Parameters are:
#- [-s] azure subscription - The Azure subscription to use (required)
#- [-p] prefix - Unique prefix that will be added to the name of each Azure resource (required)
#- [-u] jenkins username - The jenkins username (required)
#- [-t] jenkins user apitoken - The generated api token of the jenkins user (required)
#  [-j] jenkins url - The jenkins url ie http(s)://{domain}:{port} (required)
#- [-h] help - Help (optional)
#################################################################################################################################

set -eu

OUTPUT_GREEN=`tput setaf 2`
OUTPUT_BOLD=`tput bold`
OUTPUT_RESET=`tput sgr0`

###############################################################
#- function used to print out script usage
###############################################################
function usage() {
    echo
    echo "Arguments:"
    echo -e "\t-s \t The Azure subscription to use (required)"
    echo -e "\t-p \t Unique prefix that will be added to the name of each Azure resource (required)"    
    echo -e "\t-u \t jenkins username - The jenkins username (required)"
    echo -e "\t-t \t jenkins user apitoken - The generated api token tied to the jenkins user (required)"
    echo -e "\t-j \t jenkins url - The jenkins url ie http(s)://{domain}:{port} (required)"
    echo -e "\t-h \t Help (optional)"
    echo
    echo "Example:"
    echo -e "./jenkins_admin.sh -s <some_azure_subscription> -p cse -u {username} -t {apitoken} -j https://{domain}:{port}"
}

#######################################################
#- function used to print messages
#######################################################
function print() {
    echo "${OUTPUT_GREEN}$1${OUTPUT_RESET}"
}

# Loop, get parameters & remove any spaces from input
while getopts "s:p:u:t:j:h" opt; do
    case $opt in
        s)
            # subscription id
            subscriptionId=$OPTARG
        ;;
        p)
            # prefix
            prefix=$OPTARG
        ;;        
        u)
            # resource group
            jenkinsUsername=$OPTARG
        ;;
        t)
            # site name
            jenkinsApiToken=$OPTARG
        ;;
        j)
            # site name
            jenkinsUrl=$OPTARG
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

parent_path=$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd -P
)

cd "$parent_path"

# Include util
source helpers/utils.sh

# validate parameters
if [[ $# -eq 0 || -z $subscriptionId || -z $jenkinsUsername || -z $jenkinsApiToken || -z $jenkinsUrl || -z $prefix  ]]; then
    error "Required parameters are missing"
    usage
    exit 1
fi

az account set -s $subscriptionId -o none

# create resource names
keyVaultName=$(createResourceName -t kv -p $prefix)

declare KV_SCT_NAME_SERVICE_PRINCIPAL_APP_ID="SERVICE-PRINCIPAL-APP-ID"
declare KV_SCT_NAME_SERVICE_PRINCIPAL_TENANT_ID="SERVICE-PRINCIPAL-TENANT-ID"
declare KV_SCT_NAME_SERVICE_PRINCIPAL_APP_SECRET="SERVICE-PRINCIPAL-APP-SECRET"
declare JENKINS_CREDENTIAL_ID="azure_service_principal"
declare SIGNEDIN_USER_PRINCIPAL_NAME=$(az ad signed-in-user show --query 'userPrincipalName' -o tsv)
declare KEYVAULT_URL="https://${keyVaultName}.vault.azure.net"

# retrieve secrets from keyvault
print "Retrieving secrets from KeyVault..."
appId=$(az keyvault secret show -n $KV_SCT_NAME_SERVICE_PRINCIPAL_APP_ID --vault-name $keyVaultName --query 'value' -o tsv)
tenantId=$(az keyvault secret show -n $KV_SCT_NAME_SERVICE_PRINCIPAL_TENANT_ID --vault-name $keyVaultName --query 'value' -o tsv)
appSecret=$(az keyvault secret show -n $KV_SCT_NAME_SERVICE_PRINCIPAL_APP_SECRET --vault-name $keyVaultName --query 'value' -o tsv)

# download jenkins-cli
curl -o jenkins-cli.jar "$jenkinsUrl/jnlpJars/jenkins-cli.jar"

# create azure service principal credential in jenkins
print "Creating the azure service princiapl credential in jenkins..."
echo "<com.microsoft.azure.util.AzureCredentials plugin='azure-credentials@4.0.2'>
<scope>GLOBAL</scope>
<id>${JENKINS_CREDENTIAL_ID}</id>
<description>The Azure Service Principal for the CSE Jenkins Example</description>
<data>
<subscriptionId>${subscriptionId}</subscriptionId>
<clientId>${appId}</clientId>
<clientSecret>${appSecret}</clientSecret>
<certificateId></certificateId>
<tenant>${tenantId}</tenant>
<azureEnvironmentName>Azure</azureEnvironmentName>
</data>
</com.microsoft.azure.util.AzureCredentials>" \
| java -jar jenkins-cli.jar \
-auth $jenkinsUsername:$jenkinsApiToken \
-s $jenkinsUrl \
-webSocket create-credentials-by-xml system::system::jenkins _

# creating the azure keyvault url credential in jenkins...
print "Creating the azure keyvault url credential in jenkins..."
echo "<org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl plugin='plain-credentials@1.7'>
<scope>GLOBAL</scope>
<id>azure_keyvault_url</id>
<description>The Azure Keyvault url for the CSE Jenkins Example</description>
<secret>${KEYVAULT_URL}</secret>
</org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl>" \
| java -jar jenkins-cli.jar \
-auth $jenkinsUsername:$jenkinsApiToken \
-s $jenkinsUrl \
-webSocket create-credentials-by-xml system::system::jenkins _

# output
print "#######################---OUTPUT---##################################"
print "Signed-In User: $SIGNEDIN_USER_PRINCIPAL_NAME"
print "App Secret: $appSecret"
print "App AppId: $appId"
print "TenantId: $tenantId"
print "Keyvault Url: $KEYVAULT_URL"
print "#####################################################################"
echo
echo "Please note this script set your default Azure Subscription to $subscriptionId, please reset to previous Azure Subscription before running future azure-cli commands"