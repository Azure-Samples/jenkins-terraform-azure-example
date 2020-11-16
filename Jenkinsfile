pipeline{
    agent any 
    environment {
        TF_IN_AUTOMATION = "true"
        // KEYVAULT_URL = credentials('azure_keyvault_url') # keyVaultURL not able to be dereferenced with ${env.KEYVAULT_URL}, keeping for future reference
    }
    parameters {
        string(name: 'AZURE_KEYVAULT_URL', defaultValue: 'https://kv-cse-jenkins-example.vault.azure.net')
    }

    stages {
    
        stage('Terraform Init'){
            
            options {
              azureKeyVault(
                credentialID: "azure_service_principal",
                keyVaultURL: "${params.AZURE_KEYVAULT_URL}",
                secrets: [
                    [envVariable: 'BACKEND_STORAGE_ACCOUNT_NAME', name: 'BACKEND-STORAGE-ACCOUNT-NAME', secretType: 'Secret'],
                    [envVariable: 'BACKEND_STORAGE_ACCOUNT_CONTAINER_NAME', name: 'BACKEND-STORAGE-ACCOUNT-CONTAINER-NAME', secretType: 'Secret'],
                    [envVariable: 'BACKEND_KEY', name: 'BACKEND-KEY', secretType: 'Secret'],
                    [envVariable: 'RG_NAME', name: 'RG-NAME', secretType: 'Secret'],
                    [envVariable: 'ARM_ACCESS_KEY', name: 'BACKEND-ACCESS-KEY', secretType: 'Secret']
                ]
              )
            }

            steps {
                    ansiColor('xterm') {
                    withCredentials([azureServicePrincipal(
                    credentialsId: 'azure_service_principal',
                    subscriptionIdVariable: 'ARM_SUBSCRIPTION_ID',
                    clientIdVariable: 'ARM_CLIENT_ID',
                    clientSecretVariable: 'ARM_CLIENT_SECRET',
                    tenantIdVariable: 'ARM_TENANT_ID'
                )]) {
                        dir("src") {
                        sh """
                        echo "Initialising Terraform"
                        terraform init -backend-config="access_key=$ARM_ACCESS_KEY" -backend-config="storage_account_name=$BACKEND_STORAGE_ACCOUNT_NAME" -backend-config="container_name=$BACKEND_STORAGE_ACCOUNT_CONTAINER_NAME" -backend-config="key=$BACKEND_KEY" -backend-config="resource_group_name=$RG_NAME"
                        """
                        }
                     }
                }
             }
        }

        stage('Terraform Plan'){
            
            options {
              azureKeyVault(
                credentialID: "azure_service_principal",
                keyVaultURL: "${params.AZURE_KEYVAULT_URL}",
                secrets: [
                    [envVariable: 'BACKEND_STORAGE_ACCOUNT_NAME', name: 'BACKEND-STORAGE-ACCOUNT-NAME', secretType: 'Secret'],
                    [envVariable: 'BACKEND_STORAGE_ACCOUNT_CONTAINER_NAME', name: 'BACKEND-STORAGE-ACCOUNT-CONTAINER-NAME', secretType: 'Secret'],
                    [envVariable: 'BACKEND_KEY', name: 'BACKEND-KEY', secretType: 'Secret'],
                    [envVariable: 'RG_NAME', name: 'RG-NAME', secretType: 'Secret'],
                    [envVariable: 'ARM_ACCESS_KEY', name: 'BACKEND-ACCESS-KEY', secretType: 'Secret'],
                    [envVariable: 'EGVB_APP_SERVICE_NAME', name: 'EGVB-APP-SERVICE-NAME', secretType: 'Secret'],
                    [envVariable: 'EGVB_APP_SERVICE_PLAN_NAME', name: 'EGVB-APP-SERVICE-PLAN-NAME', secretType: 'Secret'],
                    [envVariable: 'LOCATION', name: 'LOCATION', secretType: 'Secret']
                ]
              )
            }

            steps {
                    ansiColor('xterm') {
                    withCredentials([azureServicePrincipal(
                    credentialsId: 'azure_service_principal',
                    subscriptionIdVariable: 'ARM_SUBSCRIPTION_ID',
                    clientIdVariable: 'ARM_CLIENT_ID',
                    clientSecretVariable: 'ARM_CLIENT_SECRET',
                    tenantIdVariable: 'ARM_TENANT_ID'
                )]) {
                        dir("src") {
                        sh """
                        echo "Creating Terraform Plan"
                        terraform plan -var "resource_group_name=$RG_NAME" -var "resource_group_region=$LOCATION" -var "web_app_name=$EGVB_APP_SERVICE_NAME" -var "app_service_plan_name=$EGVB_APP_SERVICE_PLAN_NAME"
                        """
                        }
                     }
                }
             }
        } 

        stage('Waiting for Approval'){
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    input (message: "Deploy the infrastructure?")
                }
            }
        }

        stage('Terraform Apply'){
            
            options {
              azureKeyVault(
                credentialID: "azure_service_principal",
                keyVaultURL: "${params.AZURE_KEYVAULT_URL}",
                secrets: [
                    [envVariable: 'BACKEND_STORAGE_ACCOUNT_NAME', name: 'BACKEND-STORAGE-ACCOUNT-NAME', secretType: 'Secret'],
                    [envVariable: 'BACKEND_STORAGE_ACCOUNT_CONTAINER_NAME', name: 'BACKEND-STORAGE-ACCOUNT-CONTAINER-NAME', secretType: 'Secret'],
                    [envVariable: 'BACKEND_KEY', name: 'BACKEND-KEY', secretType: 'Secret'],
                    [envVariable: 'RG_NAME', name: 'RG-NAME', secretType: 'Secret'],
                    [envVariable: 'ARM_ACCESS_KEY', name: 'BACKEND-ACCESS-KEY', secretType: 'Secret'],
                    [envVariable: 'EGVB_APP_SERVICE_NAME', name: 'EGVB-APP-SERVICE-NAME', secretType: 'Secret'],
                    [envVariable: 'EGVB_APP_SERVICE_PLAN_NAME', name: 'EGVB-APP-SERVICE-PLAN-NAME', secretType: 'Secret'],
                    [envVariable: 'LOCATION', name: 'LOCATION', secretType: 'Secret']
                ]
              )
            }

            steps {
                    ansiColor('xterm') {
                    withCredentials([azureServicePrincipal(
                    credentialsId: 'azure_service_principal',
                    subscriptionIdVariable: 'ARM_SUBSCRIPTION_ID',
                    clientIdVariable: 'ARM_CLIENT_ID',
                    clientSecretVariable: 'ARM_CLIENT_SECRET',
                    tenantIdVariable: 'ARM_TENANT_ID'
                )]) {
                        dir("src") {
                        sh """
                        echo "Applying the plan"
                        terraform apply -auto-approve -var "resource_group_name=$RG_NAME" -var "resource_group_region=$LOCATION" -var "web_app_name=$EGVB_APP_SERVICE_NAME" -var "app_service_plan_name=$EGVB_APP_SERVICE_PLAN_NAME"
                        """
                        }
                     }
                }
             }
        } 
    }
}