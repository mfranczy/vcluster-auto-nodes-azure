# vCluster Auto Nodes Azure

**td;dr**: I just need a `vcluster.yaml` to get started:

```yaml
# vcluster.yaml
controlPlane:
  service:
    spec:
     type: LoadBalancer

privateNodes:
  enabled: true
  autoNodes:
    dynamic:
    - name: az-cpu-nodes
      provider: ms-azure
      requirements:
      - property: instance-type
        value: ["Standard_D2s_v5", "Standard_D4s_v5", "Standard_D8s_v5"]
```

## Overview

Terraform modules for Auto Nodes on Azure to dynamically provision VMs for vCluster Private Nodes using Karpenter.

- Dynamic provisioning - Nodes scale up/down based on pod requirements
- Multi-cloud support: Works across public clouds, on-premises, and bare metal
- Cost optimization - Only provision the exact resources needed
- Simplified configuration - Define node requirements in your vcluster.yaml

This quickstart NodeProvider isolates all nodes into separate VPCs by default.

Per virtual cluster, it'll create (see [Environment](./environment/)):

- A VNet
- A public subnet in 2 AZs
- A private subnet in 2 AZs
- One NAT gateway attached to the private subnets
- A network security group for the worker nodes

Per virtual cluster, it'll create (see [Node](./node/)):

- An EC2 instance with the selected `instance-type`, attached to one of the private Subnets

## Getting started

### Prerequisites

1. Access to an Azure account
2. A host kubernetes cluster, preferrably on AKS to use Workload Identity
3. vCluster Platform running in the host cluster. [Get started](https://www.vcluster.com/docs/platform/install/quick-start-guide)
4. (optional) The [vCluster CLI](https://www.vcluster.com/docs/vcluster/#deploy-vcluster)
5. (optional) Authenticate the vCluster CLI `vcluster platform login $YOUR_PLATFORM_HOST`

### Setup

#### Step 1: Configure Node Provider

Define your Azure Node Provider in the vCluster Platform. This provider manages the lifecycle of EC2 instances.

In the vCluster Platform UI, navigate to "Infra > Nodes", click on "Create Node Provider" and then use "Microsoft Azure".
Specify a subscription ID in which all resources will be created. You can optionally set a default region and default resource group. This can still be changed on a per virtual cluster basis later on.

#### Step 2: Authenticate the Node Provider

Auto Nodes supports two authentication methods for Azure resources. **Workload Identity is strongly recommended** for production use.

##### Option A: Workload Identity (Recommended)

[Configure AKS Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview?tabs=dotnet) to grant the vCluster control plane permissions to manage Azure VMs.
Then, assign the [the quickstart role](./docs/auto_nodes_role.json) to your Workload Identity Service Principal to authenticate the terraform provider to create environments and nodes. Please adjust the `assignableScopes` section to match your subscription or resource group before creating the role.

##### Option B: Manual secrets

If Workload Identity is not available, use a kubernetes secret with static credentials to authenticate against Azure.
You can create this secret from the vCluster Platform UI by choosing "specify credentials inline" in the Quickstart setup, or manually later on:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ms-azure-credentials
  namespace: vcluster-platform
  labels:
    terraform.vcluster.com/provider: "ms-azure" # This has to match your provider name
stringData:
    ARM_CLIENT_ID: ''
    ARM_CLIENT_SECRET: ''
    ARM_TENANT_ID: ''
    ARM_SUBSCRIPTION_ID: ''
EOF
```

This secret uses a Service Principal with Client Secret to authenticate agains Azure. Please consult the [terraform provider docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#authenticating-to-azure) for alternative authentication methods.

Ensure the Service Principal has at least the permissions outlined in [the auto nodes role](./docs/auto_nodes_role.json).

#### Step 3: Create virtual cluster

This vcluster.yaml file defines a Private Node Virtual Cluster with Auto Nodes enabled. It exposes the control plane through a LoadBalancer on the AKS host cluster. This is required for individual Azure VMs to join the cluster.

```yaml
# vcluster.yaml
controlPlane:
  service:
    spec:
     type: LoadBalancer

privateNodes:
  enabled: true
  autoNodes:
    dynamic:
    - name: az-cpu-nodes
      provider: ms-azure
      requirements:
      - property: instance-type
        value: ["Standard_D2s_v5", "Standard_D4s_v5", "Standard_D8s_v5"]
      limits:
        cpu: "100"
        memory: "200Gi"
```

Create the virtual cluster through the vCluster Platform UI or the vCluster CLI:

 `vcluster platform create vcluster az-private-nodes -f ./vcluster.yaml --project default`
