#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -g <resourceGroupName> -n <deploymentName> -u <adminUserId> -r <vaultResourceGroup> -v <vaultName> -s <secretName> 1>&2; exit 1; }

declare subscriptionId="7b13dc94-2b54-4cdf-a247-bbdebdb97f4f"
declare resourceGroupName=""
declare resourceGroupLocation=koreacentral
declare deploymentName=""
declare adminUserId=""
declare vaultResourceGroup=""
declare vaultName=""
declare secretName=""

# Initialize parameters specified from command line
while getopts ":g:n:u:r:v:s:" arg; do
    case "${arg}" in
        g)
            resourceGroupName=${OPTARG}
            ;;
        n)
            deploymentName=${OPTARG}
            ;;
        u)
            adminUserId=${OPTARG}
            ;;
        r)
            vaultResourceGroup=${OPTARG}
            ;;
        v)
            vaultName=${OPTARG}
            ;;
        s)
            secretName=${OPTARG}
            ;;
        esac
done
shift $((OPTIND-1))

#Prompt for parameters is some required parameters are missing
if [[ -z "$adminUserId" ]]; then
    echo "adminUserId :"
    read adminUserId
    [[ "${adminUserId:?}" ]]
fi

if [[ -z "$resourceGroupName" ]]; then
    echo "ResourceGroupName:"
    read resourceGroupName
    [[ "${resourceGroupName:?}" ]]
fi

if [[ -z "$deploymentName" ]]; then
    echo "deploymentName:"
    read deploymentName
    [[ "${deploymentName:?}" ]]
fi

if [[ -z "$vaultResourceGroup" ]]; then
    echo "Key Vault Resource Group:"
    read vaultResourceGroup
fi

if [[ -z "$vaultName" ]]; then
    echo "Vault Name:"
    read vaultName
fi

if [[ -z "$secretName" ]]; then
    echo "secretName in which public key resides :"
    read secretName
fi

#templateFile Path - template file to be used
templateFilePath="00.azuredeploy.json"

if [ ! -f "$templateFilePath" ]; then
    echo "$templateFilePath not found"
    exit 1
fi

#parameter file path
parametersFilePath="00.azuredeploy.parameters.json"

if [ ! -f "$parametersFilePath" ]; then
    echo "$parametersFilePath not found"
    exit 1
fi

if [ -z "$resourceGroupName" ] || [ -z "$adminUserId" ] || [ -z "$sshKeyData" ] || [ -z "$vaultResourceGroup" ] || [ -z "$vaultName" ] || [ -z "$secretName" ]; then
    echo "Some required parameters are missing"
    usage
fi

#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
    az login
fi

#set the default subscription id
az account set --subscription $subscriptionId

#Check for existing RG
if [ $(az group exists --name $resourceGroupName) == 'false' ]; then
    echo "Resource group with name" $resourceGroupName "could not be found. Creating new resource group.."
    (
        set -x
        az group create --name $resourceGroupName --location $resourceGroupLocation 1> /dev/null
    )
    else
    echo "Using existing resource group..."
fi

#Start deployment
echo "Starting deployment..."
(
    set -x
    az group deployment create --name $deploymentName --resource-group $resourceGroupName --template-file $templateFilePath --parameters @$parametersFilePath \
    --parameters adminUserId=$adminUserId \
    --parameters vaultResourceGroup=$vaultResourceGroup \
    --parameters vaultName=$vaultName \
    --parameters secretName=$secretName
)

if [ $?  == 0 ];
then
    echo "Template has been successfully deployed"
fi