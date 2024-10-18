Here is an updated **`README.md`** in **Markdown** format based on the latest information from the OSDU Helm charts repository on GitLab. This guide assumes you're deploying OSDU on **Azure** using Helm, and it includes steps to set up and deploy the OSDU platform using AKS (Azure Kubernetes Service), Ingress, and other related resources.

---

# OSDU Deployment on Azure with Helm

This document provides a step-by-step guide for deploying the **Open Subsurface Data Universe (OSDU)** platform on **Azure** using **Helm charts** from the [OSDU Helm charts repository](https://community.opengroup.org/osdu/platform/deployment-and-operations/helm-charts-azure/-/blob/master/osdu-azure/README.md). 

## Prerequisites

Ensure that you have the following installed:

- **Azure CLI**: To interact with Azure resources.
- **kubectl**: To manage your Kubernetes cluster.
- **Helm**: Kubernetes package manager for installing the OSDU charts.
- **A Kubernetes Cluster**: You should have access to an AKS cluster.

## Step-by-Step Guide

### 1. Clone the OSDU Helm Charts Repository

First, clone the OSDU Helm charts repository from GitLab. This contains the necessary Helm charts for deploying OSDU on Azure.

```bash
git clone https://community.opengroup.org/osdu/platform/deployment-and-operations/helm-charts-azure.git
cd helm-charts-azure/osdu-azure
```

### 2. Create a Resource Group and AKS Cluster

You'll need to create a **Resource Group** and an **Azure Kubernetes Service (AKS)** cluster for your OSDU deployment. Ensure you replace the placeholders with your actual values.

```bash
# Create a Resource Group
az group create --name <RESOURCE_GROUP> --location <REGION>

# Create an AKS Cluster
az aks create --resource-group <RESOURCE_GROUP> --name <AKS_CLUSTER> --node-count 3 --enable-addons monitoring --generate-ssh-keys
```

### 3. Get AKS Credentials

Configure `kubectl` to use your AKS cluster by fetching the cluster credentials.

```bash
az aks get-credentials --resource-group <RESOURCE_GROUP> --name <AKS_CLUSTER>
```

### 4. Install the NGINX Ingress Controller

Deploy the **NGINX Ingress Controller** to manage external traffic to the OSDU services.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx --namespace ingress-controller --create-namespace
```

### 5. Deploy OSDU Services

Now, navigate to the directory with the OSDU Helm charts and deploy the core OSDU services.

```bash
cd helm-charts-azure/osdu-azure
helm install osdu-core ./ --namespace osdu --create-namespace
```

### 6. Configure Ingress (Optional: Separate File)

If you want to separate the **Ingress** configuration, you can create an **Ingress YAML file** (e.g., `ingress-osdu.yaml`) and then apply it using `kubectl`. Here's an example of the Ingress file:

#### Example `ingress-osdu.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: osdu-ingress
  namespace: osdu
spec:
  rules:
  - host: {{DOMAIN}}  # Replace with your actual domain
    http:
      paths:
      - path: /entitlements
        pathType: Prefix
        backend:
          service:
            name: entitlements-service
            port:
              number: 80
      - path: /storage
        pathType: Prefix
        backend:
          service:
            name: storage-service
            port:
              number: 80
```

#### Apply the Ingress

If you want to use dynamic values for the domain, you can use the `sed` command in your script to replace `{{DOMAIN}}` with the actual domain name.

```bash
sed "s/{{DOMAIN}}/$DOMAIN/g" ingress-osdu.yaml | kubectl apply -f -
```

### 7. Verify Deployment

Once the OSDU services and Ingress are deployed, verify the status of the services and check that the Ingress is working.

```bash
# Verify Pods
kubectl get pods -n osdu

# Verify Ingress
kubectl get ingress -n osdu
```

### 8. Additional Setup (Monitoring and Logs)

To monitor the AKS cluster and OSDU services, you can use **Azure Monitor** and **Log Analytics**. You can enable monitoring for AKS by running:

```bash
az monitor log-analytics workspace create --resource-group <RESOURCE_GROUP> --workspace-name <LOG_ANALYTICS_WORKSPACE>
```

### 9. Clean-up (Optional)

If you're running a test deployment and want to clean up the resources afterward:

```bash
# Delete the AKS cluster
az aks delete --resource-group <RESOURCE_GROUP> --name <AKS_CLUSTER> --yes --no-wait

# Delete the resource group
az group delete --name <RESOURCE_GROUP> --yes --no-wait
```

---

## Conclusion

This guide provides the steps required to deploy the OSDU platform on Azure using Helm and AKS. For more information or to troubleshoot issues, refer to the [official OSDU Helm charts repository](https://community.opengroup.org/osdu/platform/deployment-and-operations/helm-charts-azure/-/blob/master/osdu-azure/README.md).

