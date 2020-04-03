
az login
az account set -s 'c5005658-b0f7-4a31-90e3-85aa2cafcc0d'
az account show

#
#https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tutorial-quick-task
#
#Build in Azure with ACR Tasks
$ACR_NAME="acruksjb"
#$RES_GROUP=rg-uks-cdf-shared-assets
$RES_GROUP=$ACR_NAME # Resource Group name
$REGION="uksouth"
az group create --resource-group $RES_GROUP --location $REGION
az acr create --resource-group $RES_GROUP --name $ACR_NAME --sku Standard --location $REGION

az acr build --registry $ACR_NAME --image helloacrtasks:v1 .

#Deploy to Azure Container Instances
$AKV_NAME="$ACR_NAME-vault"

az keyvault create --resource-group $RES_GROUP --name $AKV_NAME

# Create service principal, store its password in AKV (the registry *password*)
az keyvault secret set `
  --vault-name $AKV_NAME `
  --name $ACR_NAME-pull-pwd `
  --value $(az ad sp create-for-rbac `
                --name $ACR_NAME-pull `
                --scopes $(az acr show --name $ACR_NAME --query id --output tsv) `
                --role acrpull `
                --query password `
                --output tsv)

# Store service principal ID in AKV (the registry *username*)
az keyvault secret set `
    --vault-name $AKV_NAME `
    --name $ACR_NAME-pull-usr `
    --value $(az ad sp show --id http://$ACR_NAME-pull --query appId --output tsv)

#Deploy a container with Azure CLI
az container create `
    --resource-group $RES_GROUP `
    --name acr-tasks `
    --image $ACR_NAME.azurecr.io/helloacrtasks:v1 `
    --registry-login-server "$ACR_NAME.azurecr.io" `
    --registry-username $(az keyvault secret show --vault-name $AKV_NAME --name $ACR_NAME-pull-usr --query value -o tsv) `
    --registry-password $(az keyvault secret show --vault-name $AKV_NAME --name $ACR_NAME-pull-pwd --query value -o tsv) `
    --dns-name-label acr-tasks-$ACR_NAME-rand0m1 `
    --query "{FQDN:ipAddress.fqdn}" `
    --output table
   

ERROR    The image cannot be empty for container 'acr-tasks1' in container group 'acr-tasks1'.

##
#docker pull hello-world
#above didint work the below did work
$ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RES_GROUP --query "loginServer" --output tsv)
$RANDOM="23328948234"
--image $ACR_LOGIN_SERVER/aci-helloworld:v1 `
az container create `
    --resource-group $RES_GROUP `
    --name acr-tasks `
    --image $ACR_LOGIN_SERVER/helloacrtasks:v1 `
    --registry-login-server $ACR_LOGIN_SERVER `
    --registry-username $(az keyvault secret show --vault-name $AKV_NAME -n $ACR_NAME-pull-usr --query value -o tsv) `
    --registry-password $(az keyvault secret show --vault-name $AKV_NAME -n $ACR_NAME-pull-pwd --query value -o tsv) `
    --dns-name-label acr-tasks-$RANDOM `
    --query ipAddress.fqdn

    --name acr-tasks `

"acr-tasks-23328948234.uksouth.azurecontainer.io"
az container attach --resource-group $RES_GROUP --name acr-tasks
az container delete --resource-group $RES_GROUP --name acr-tasks

az group delete --resource-group $RES_GROUP
az ad sp delete --id http://$ACR_NAME-pull

#Tutorial: Automate container image builds in the cloud when you commit source code
#https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tutorial-build-task
#ACR_NAME=<registry-name>        # The name of your Azure container registry
$GIT_USER="JBiasillo"      # Your GitHub user account name
$GIT_PAT="772a066741ca87aa42c32dd279b66b4213d64d2a" # The PAT you generated in the previous section

az acr task create `
    --registry $ACR_NAME `
    --name taskhelloworld `
    --image "helloworld:{{.Run.ID}}" `
    --context https://github.com/$GIT_USER/acr-build-helloworld-node.git `
    --file Dockerfile `
    --git-access-token $GIT_PAT

az acr task show --registry $ACR_NAME --name taskhelloworld
az acr task run --registry $ACR_NAME --name taskhelloworld

echo "Hello World!" > hello.txt
git add hello.txt
git commit -m "Testing ACR Tasks"
git push origin master

az acr task logs --registry $ACR_NAME

az acr task list-runs --registry $ACR_NAME --output table

git add setup.ps1
git commit -m "setup helper"
git push origin master
