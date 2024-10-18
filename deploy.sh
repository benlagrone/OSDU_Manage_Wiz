#!/bin/bash

# Load environment variables from .env file
set -a
source .env
set +a

wait_for_providers() {
    echo "Waiting for resource providers to register..."
    az provider show -n Microsoft.Insights -o table
    az provider show -n Microsoft.ContainerService -o table
    while [[ $(az provider show -n Microsoft.Insights --query registrationState -o tsv) != "Registered" || \
              $(az provider show -n Microsoft.ContainerService --query registrationState -o tsv) != "Registered" ]]; do
        echo "Waiting for providers to register..."
        sleep 10
    done
    echo "Resource providers registered successfully."
}

# Azure login
echo "Logging in to Azure..."
az login

# Register necessary resource providers
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.ContainerService
wait_for_providers

# Step 1: Create Azure Resource Group
echo "Creating Resource Group: $RESOURCE_GROUP"
az group create --name $RESOURCE_GROUP --location $REGION

# Create a managed identity for AKS
identity_name="${RESOURCE_GROUP}_Identity"
az identity create --name $identity_name --resource-group $RESOURCE_GROUP

# Get the resource ID of the managed identity
identity_id=$(az identity show --name $identity_name --resource-group $RESOURCE_GROUP --query id -o tsv)



# Create the AKS cluster with the managed identity
echo "Creating AKS Cluster: $AKS_CLUSTER"
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_CLUSTER \
    --node-count 1 \
    --node-vm-size Standard_D4pds_v5 \
    --enable-addons monitoring \
    --generate-ssh-keys \
    --enable-managed-identity \
    --assign-identity $identity_id

# Assign the AKS-managed identity Contributor role to the resource group
AKS_IDENTITY=$(az aks show -g $RESOURCE_GROUP -n $AKS_CLUSTER --query identity.principalId -o tsv)
az role assignment create --assignee $AKS_IDENTITY --role Contributor --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP

# Step 3: Get AKS Cluster Credentials
echo "Fetching AKS credentials for cluster: $AKS_CLUSTER"
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER


# Step 4: Create and retrieve Storage Account
echo "Creating Storage Account"
STORAGE_ACCOUNT_PREFIX="osdu"
STORAGE_ACCOUNT="${STORAGE_ACCOUNT_PREFIX}${UNIQUE}"

# Create the storage account
az storage account create --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --location $REGION --sku Standard_LRS

# Verify the storage account was created and output its name
if az storage account show --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP &>/dev/null; then
    echo "Created Storage Account: $STORAGE_ACCOUNT"
else
    echo "Failed to create Storage Account"
    exit 1
fi

# Create Azure Container Registry
echo "Creating Azure Container Registry: ${AZURE_ACR}"
az acr create --resource-group $RESOURCE_GROUP --name $AZURE_ACR --sku Basic

# Verify ACR creation
if az acr show --name $AZURE_ACR --resource-group $RESOURCE_GROUP &>/dev/null; then
    echo "Created Azure Container Registry: ${AZURE_ACR}.azurecr.io"
else
    echo "Failed to create Azure Container Registry"
    exit 1
fi

# Generate ENV_VAULT name
ENV_VAULT="kv-osdu-${UNIQUE}"
echo "Generated Key Vault name: $ENV_VAULT"

# Create Azure Key Vault
echo "Creating Azure Key Vault: $ENV_VAULT"
az keyvault create --name $ENV_VAULT --resource-group $RESOURCE_GROUP --location $REGION

# Step 7: skipped
# Query Azure for Key Vault details
KEYVAULT_URI=$(az keyvault show --name $ENV_VAULT --query properties.vaultUri -o tsv)
echo "Key Vault URI: $KEYVAULT_URI"

# Step 8: Install NGINX Ingress Controller
echo "Installing NGINX Ingress Controller"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx --namespace ingress-controller --create-namespace

# Step 9: Clone the OSDU Helm Charts Repository
echo "Cloning the OSDU Helm Charts repository"
git clone https://community.opengroup.org/osdu/platform/deployment-and-operations/helm-charts-azure.git
# cd helm-charts-azure/osdu-azure

#!/bin/bash
#!/bin/bash

# Generate a unique name for the service principal
sp_name="osdu-sp-$(date +%s)"

# Create the service principal and capture the output
sp_output=$(az ad sp create-for-rbac --name "$sp_name" --role contributor --scopes /subscriptions/$SUBSCRIPTION_ID --output json)

# Extract the necessary values
client_id=$(echo $sp_output | jq -r .appId)
client_secret=$(echo $sp_output | jq -r .password)
tenant_id=$(echo $sp_output | jq -r .tenant)

# Create a JSON object with the credentials
credentials_json=$(cat <<EOF
{
  "clientId": "$client_id",
  "clientSecret": "$client_secret",
  "tenantId": "$tenant_id",
  "subscriptionId": "$SUBSCRIPTION_ID"
}
EOF
)

# Save the credentials to a local file
echo $credentials_json > osdu_credentials.json

echo "Service principal created and credentials saved to osdu_credentials.json"

# Log in to Azure using service principal credentials
az login --service-principal -u $client_id -p $client_secret --tenant $tenant_id

# Set the subscription
az account set --subscription $SUBSCRIPTION_ID

echo "Logged in to Azure and set subscription"

# Step 11: Setup common variables
GROUP=$(az group list --query "[?contains(name, 'cr${UNIQUE}')].name" -otsv)
ENV_VAULT=$(az keyvault list --resource-group $GROUP --query [].name -otsv)

# Function to fetch Azure Key Vault secrets
get_secret() {
    az keyvault secret show --id https://${ENV_VAULT}.vault.azure.net/secrets/$1 --query value -otsv
}


# Step 8: Deploy osdu-base
cat > osdu_base_custom_values.yaml << EOF
ingress:
  admin: $CERT_EMAIL
EOF

echo "Deploying osdu-base Helm Chart"
helm install osdu-base ./helm-charts-azure/osdu-base --namespace $OSDU_NAMESPACE --create-namespace -f osdu_base_custom_values.yaml

# Step 9: Deploy osdu-istio
ISTIO_DNS_HOST=$(az network public-ip list --query "[?contains(id,'istio')].dnsSettings.fqdn" \
  --resource-group $(az group list --query "[?contains(name, 'sr${UNIQUE}-')].name" -otsv |grep -v MC) -otsv)

cat > osdu_istio_custom_values.yaml << EOF
global:
  namespace: ${OSDU_NAMESPACE}
EOF

echo "Deploying osdu-istio Helm Chart"
ls -l
helm install osdu-istio ./helm-charts-azure/osdu-istio --namespace $OSDU_NAMESPACE -f osdu_istio_custom_values.yaml

# Step 10: Deploy osdu-airflow2
cat > osdu_airflow2_custom_values.yaml << EOF
azure:
  tenant: $(get_secret tenant-id)
  subscription: $(get_secret subscription-id)
  resourcegroup: $(get_secret base-name-cr)-rg
  identity: $(get_secret base-name-cr)-osdu-identity
  identity_id: $(get_secret osdu-identity-id)
  keyvault: $ENV_VAULT
  appid: $(get_secret aad-client-id)

airflow:
  version_1_Installed: false
  image:
    repository: $AZURE_ACR.azurecr.io/airflow2-docker-image
    tag: $AIRFLOW_IMAGE_TAG
  config:
    AIRFLOW__SCHEDULER__STATSD_HOST: "${STATSD_HOST}"
    AIRFLOW__SCHEDULER__STATSD_PORT: $STATSD_PORT
    AIRFLOW__WEBSERVER__BASE_URL: https://$DNS_HOST/airflow2
EOF

echo "Deploying osdu-airflow2 Helm Chart"
helm install osdu-airflow2 ./helm-charts-azure/osdu-airflow2 --namespace $OSDU_NAMESPACE -f osdu_airflow2_custom_values.yaml

# Step 11: Deploy osdu-azure
cat > osdu_azure_custom_values.yaml << EOF
global:
  replicaCount: 2
  azure:
    tenant: $(get_secret tenant-id)
    subscription: $(get_secret subscription-id)
    resourcegroup: $(get_secret base-name-cr)-rg
    identity: $(get_secret base-name-cr)-osdu-identity
    identity_id: $(get_secret osdu-identity-id)
    keyvault: $ENV_VAULT
    appid: $(get_secret aad-client-id)
    podIdentityAuthEnabled: false
    oidAuthEnabled: true
    corsEnabled: $CORS_ENABLED
    suthEnabled: false
    service_account_id: $(get_secret app-dev-sp-username)
    service_account_oid: $(get_secret app-dev-sp-id)

  ingestion:
    airflowVersion2Enabled: true
    osduAirflowURL: $OSDU_AIRFLOW_URL
    airflowDbName: $AIRFLOW_DB
EOF

echo "Deploying osdu-azure Helm Chart"
helm install osdu-azure ./helm-charts-azure/osdu-azure --namespace $OSDU_NAMESPACE -f osdu_azure_custom_values.yaml

# Step 12: Deploy DDMS services
echo "Pulling DDMS Helm chart from ACR: $AZURE_ACR"
helm pull "oci://$AZURE_ACR.azurecr.io/helm/$CHART" --version $VERSION --untar

deploy_ddms() {
  local ddms=$1
  local base_dir="./standard-ddms/"
  local helm_release="$ddms-services"
  local helm_value_file="${base_dir}${ddms}.values.yaml"
  local k8s_namespace="ddms-$ddms"
  local chart_app_version

  if [ "${!ddms^^}_PATCH" -ne 0 ]; then    
    chart_app_version="${APP_VERSION%.*}.${!ddms^^}_PATCH"
    echo "Applying patch version for $ddms: $chart_app_version"
  else
    chart_app_version=$APP_VERSION
  fi

  echo "Deploying DDMS service $ddms with appVersion $chart_app_version"

  kubectl create namespace $k8s_namespace || true
  kubectl label namespace $k8s_namespace istio-injection=enabled --overwrite

  helm upgrade --install \
    $helm_release $base_dir \
    --namespace $k8s_namespace \
    -f $helm_value_file \
    --set azure.tenant=$(get_secret tenant-id) \
    --set azure.subscription=$(get_secret subscription-id) \
    --set azure.resourcegroup=$(get_secret base-name-cr)-rg \
    --set azure.identity=$(get_secret base-name-cr)-osdu-identity \
    --set azure.identity_id=$(get_secret osdu-identity-id) \
    --set azure.keyvault.name=$ENV_VAULT \
    --set azure.acr=${AZURE_ACR}.azurecr.io \
    --set ingress.dns=$DNS_HOST \
    --set azure.service_account_id=$(get_secret app-dev-sp-username) \
    --set appVersion=$chart_app_version
}

for service in wellbore seismic well-delivery reservoir rafs; do
  deploy_ddms "$service"
done

echo "OSDU deployment completed successfully!"