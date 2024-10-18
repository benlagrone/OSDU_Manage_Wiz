Here is the updated **Tools Needed** in **Markdown** format to complement the OSDU deployment process on **Azure** using the Helm charts from the repository.

---

# Tools Needed for OSDU Deployment on Azure

This document outlines the required tools to successfully deploy an **OSDU instance** on **Azure** using **Helm**, **AKS**, and related utilities. All commands assume usage within the **VS Code** terminal on a **MacBook**.

## Required Tools

### 1. **Azure CLI**
The **Azure CLI** allows you to manage Azure resources from the command line, including creating resource groups, deploying AKS clusters, and managing storage accounts.

#### Installation:
```bash
brew update && brew install azure-cli
```

#### Verify Installation:
```bash
az --version
```

#### Sign in to Azure:
```bash
az login
```

### 2. **kubectl**
`kubectl` is the Kubernetes command-line tool that allows you to interact with the AKS cluster. You will use this to manage Kubernetes resources, such as deploying OSDU services.

#### Installation:
```bash
brew install kubectl
```

#### Verify Installation:
```bash
kubectl version --client
```

### 3. **Helm**
Helm is a package manager for Kubernetes that simplifies the deployment and management of Kubernetes applications. You will use Helm to deploy the OSDU services.

#### Installation:
```bash
brew install helm
```

#### Verify Installation:
```bash
helm version
```

### 4. **Git**
`git` is needed to clone the OSDU Helm charts repository from GitLab.

#### Installation:
```bash
brew install git
```

#### Verify Installation:
```bash
git --version
```

### 5. **jq (For JSON Parsing, Optional)**
`jq` is useful for parsing JSON outputs from `kubectl` and `az` commands, particularly if you're writing complex deployment scripts.

#### Installation:
```bash
brew install jq
```

#### Verify Installation:
```bash
jq --version
```

### 6. **VS Code**
**Visual Studio Code** is a powerful code editor that will be your main development environment for writing and running scripts. You can install it via `brew`:

#### Installation:
```bash
brew install --cask visual-studio-code
```

### 7. **Node.js (Optional for VS Code Extensions)**
Some VS Code extensions may require **Node.js**. It's not required for deployment but useful if you plan to use specific VS Code extensions.

#### Installation:
```bash
brew install node
```

#### Verify Installation:
```bash
node --version
```

### 8. **yq (For YAML Parsing, Optional)**
`yq` is a tool for parsing and querying YAML files, useful if you are working with complex YAML configurations.

#### Installation:
```bash
brew install yq
```

#### Verify Installation:
```bash
yq --version
```

---

## Additional Setup Steps

### **Configure Azure Kubernetes Service (AKS)**
Once you've installed the tools, you'll need to set up **Azure Kubernetes Service (AKS)** and connect `kubectl` to your cluster using the Azure CLI.

#### Connect to AKS:
```bash
az aks get-credentials --resource-group <RESOURCE_GROUP> --name <AKS_CLUSTER>
```

---

## Summary

| **Tool**       | **Purpose**                                      | **Installation Command**                      |
|----------------|--------------------------------------------------|----------------------------------------------|
| **Azure CLI**  | Manage Azure resources from the command line      | `brew install azure-cli`                     |
| **kubectl**    | Manage Kubernetes resources and AKS               | `brew install kubectl`                       |
| **Helm**       | Package manager for Kubernetes, deploy OSDU charts| `brew install helm`                          |
| **Git**        | Clone the OSDU Helm charts repository             | `brew install git`                           |
| **jq**         | Parse JSON outputs from CLI tools (optional)      | `brew install jq`                            |
| **VS Code**    | Code editor and terminal                          | `brew install --cask visual-studio-code`     |
| **Node.js**    | Required for some VS Code extensions (optional)   | `brew install node`                          |
| **yq**         | Parse and query YAML files (optional)             | `brew install yq`                            |

---

## Next Steps

1. Install the necessary tools using the above commands.
2. Configure your **Azure Kubernetes Service (AKS)** and deploy the OSDU instance using Helm charts as outlined in the deployment guide.

This ensures that all required tools are available to deploy and manage OSDU on **Azure** using a **MacBook** via **VS Code**. Let me know if you need further assistance or adjustments!