Here are updated markdown-formatted instructions for deploying and removing OSDU on Azure using the deploy.sh and delete.sh scripts:

# Deploying and Removing OSDU on Azure

## Prerequisites

1. An Azure account with an active subscription
2. Azure CLI installed and configured
3. kubectl installed
4. Helm installed
5. Git installed

## Deployment Steps

1. Clone the repository:
   ```bash
   git clone 
   cd 
   ```

2. Set up the required environment variables and Azure resources:
   ```bash
   az login
   az account set --subscription <your_subscription_id>
   ```

3. Create a service principal for OSDU:
   ```bash
   az ad sp create-for-rbac --name "osdu-sp" --role contributor --scopes /subscriptions/<your-subscription-id>
   ```
   Save the output JSON, you'll need it for the next step.

4. Create a file named `osdu_credentials.json` in the root directory with the service principal details:
   ```json
   {
     "clientId": "<appId from previous step>",
     "clientSecret": "<password from previous step>",
     "tenantId": "<tenant from previous step>",
     "subscriptionId": "<your-subscription-id>"
   }
   ```

5. Run the deployment script:
   ```bash
   ./deploy.sh
   ```

   This script will:
   - Create necessary Azure resources
   - Deploy OSDU services using Helm charts
   - Configure ingress and other settings

6. After deployment, access the OSDU platform using the DNS host provided in the script output.

## Removal Steps

To remove the OSDU deployment and associated Azure resources:

1. Run the deletion script:
   ```bash
   ./delete.sh
   ```

   This script will:
   - Remove OSDU services and Helm releases
   - Delete Azure resources created during deployment
   - Clean up local configuration files

2. After the script completes, verify in the Azure portal that all resources have been removed.

## Notes

- The deployment process may take up to 2 hours to complete.
- Ensure you have the necessary permissions in your Azure subscription to create and manage resources.
- For troubleshooting, refer to the logs output by the scripts and check the Azure portal for more detailed error messages.

[Source: https://github.com/Azure/osdu-developer]
[Source: https://community.opengroup.org/osdu/platform/deployment-and-operations/helm-charts-azure]