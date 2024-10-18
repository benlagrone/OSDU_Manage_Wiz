#!/bin/bash

# Read credentials from JSON file
credentials=$(cat osdu_credentials.json)
client_id=$(echo $credentials | jq -r .clientId)
client_secret=$(echo $credentials | jq -r .clientSecret)
tenant_id=$(echo $credentials | jq -r .tenantId)
subscription_id=$(echo $credentials | jq -r .subscriptionId)

# Log in to Azure using service principal credentials
az login --service-principal -u $client_id -p $client_secret --tenant $tenant_id

# Set the subscription
az account set --subscription $subscription_id

# Query Azure for resource group
RESOURCE_GROUP=$(az group list --query "[?contains(name, 'osdu')].name" -o tsv)

if [ -z "$RESOURCE_GROUP" ]; then
    echo "No OSDU resource group found. Exiting."
    exit 1
fi

# Query Azure for other resources
AKS_CLUSTER=$(az aks list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)
OSDU_NAMESPACE="osdu-azure"
AZURE_ACR=$(az acr list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)
ENV_VAULT=$(az keyvault list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)
STORAGE_ACCOUNT=$(az storage account list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)

# Delete AKS Cluster
echo "Deleting AKS Cluster: $AKS_CLUSTER"
az aks delete --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP --yes

# Delete NGINX Ingress Controller
echo "Deleting NGINX Ingress Controller"
helm delete nginx-ingress --namespace ingress-controller

# Delete OSDU Components
echo "Deleting OSDU Components..."
helm delete osdu-azure --namespace $OSDU_NAMESPACE
helm delete osdu-istio --namespace $OSDU_NAMESPACE
helm delete osdu-base --namespace $OSDU_NAMESPACE
helm delete osdu-airflow2 --namespace $OSDU_NAMESPACE

# Delete DDMS Services
for service in wellbore seismic well-delivery reservoir rafs; do
    echo "Deleting DDMS service: $service"
    helm delete $service-services --namespace ddms-$service
done

# Delete namespaces
echo "Deleting namespaces"
kubectl delete namespace $OSDU_NAMESPACE
kubectl delete namespace ingress-controller
for service in wellbore seismic well-delivery reservoir rafs; do
    kubectl delete namespace ddms-$service
done

# Delete Azure Key Vault
echo "Deleting Azure Key Vault: $ENV_VAULT"
az keyvault delete --name $ENV_VAULT --resource-group $RESOURCE_GROUP

# Delete Azure Container Registry
echo "Deleting Azure Container Registry: $AZURE_ACR"
az acr delete --name $AZURE_ACR --resource-group $RESOURCE_GROUP --yes

# Delete Storage Account
echo "Deleting Storage Account: $STORAGE_ACCOUNT"
az storage account delete --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --yes

# Delete the entire resource group
echo "Deleting resource group: $RESOURCE_GROUP"
az group delete --name $RESOURCE_GROUP --yes --no-wait

echo "Resource group deletion initiated. This process may take some time to complete."

# Clean up local environment
rm -f osdu_credentials.json
rm -rf .azure

echo "Local cleanup completed."