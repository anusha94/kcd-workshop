# Introduction

This is a hand on session on cluster api provider azure. The session will cover the following excercises

- Create a bootstrap cluster on Kind.
- Create a management cluster on Azure cloud. (1 Control Plane, 1 Worker, K8s Version:1.22)
- Perform following day-2 operations
    - Upgrade k8s version
    - Add worker nodes
    - Operations via clusterctl cli 

# Prerequisites

A Ubuntu/MacOS machine with the following tools installed:
 - Kind (https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries)
This tutorial uses version v0.11.1
 - Kubectl (https://kubernetes.io/docs/tasks/tools/)
 This tutorial uses version v1.21.0

 - Docker (https://docs.docker.com/engine/install/)

 - Clusterctl (https://cluster-api.sigs.k8s.io/user/quick-start.html)
 This tutorial use version v1.1.3

 - Azure Cli (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

 - Azure cloud account. If you do not have one, you can sign up for a free credit, which will require you to enter your credit/debit card details. But they won't charge you until you accept to continue to use services after the free credit expires. Use the following link to create a free Azure credit account. 
 https://azure.microsoft.com/en-in/free/


 # Register Resource Provider

 If you are using a new sunscription, register the following resource providers:
 - Microsoft.Compute
 - Microsoft.Network
 - Mcrosoft.ContainerService
 - Microsoft.ManagedIdentity
 - Microsoft.Authorization

Follow the steps from the following link to register:

https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types

 # Create A Bootstrap Kind Cluster

Create a Kind cluster by running the following command

```shell
kind create cluster

```

# Login And Set Up Azure Credentials 

Login with the azure cli

```shell
az login
```

Capture the value of "id" to "AZURE_SUBSCRIPTION_ID" in the env-vars.sh file from the output.
Run the following command

```shell
export AZURE_SUBSCRIPTION_ID="<your-sub-id>" 
az ad sp create-for-rbac --role contributor --scopes="/subscriptions/${AZURE_SUBSCRIPTION_ID}"
```

Capture the output and put the value in the env-vars.sh file. The output will be like the following: 

```shell
{
  "appId": "<your-app-id>", # paste the value to AZURE_CLIENT_ID
  "displayName": "your-display-name",
  "name": "random-string",
  "password": "your-password", # paste the value to AZURE_CLIENT_SECRET
  "tenant": "your-tenant-id" # paste the value to AZURE_TENANT_ID
}
```

Once you have put the appropriate values to the env-vars.sh file. Run the following commands:

```shell
chmod +x env-vars.sh
source ./env-vars.sh
```

Create a secret to include the password of the Service Principal identity created in Azure.
This secret will be referenced by the AzureClusterIdentity used by the AzureCluster.

Run the following command to create the secret:

```shell
kubectl create secret generic "${AZURE_CLUSTER_IDENTITY_SECRET_NAME}" --from-literal=clientSecret="${AZURE_CLIENT_SECRET}"
```

# Install CAPI and CAPZ component on Kind Cluster

Run the following command

```shell
clusterctl init --infrastructure=azure:v1.2.1
```

# Generate Cluster Manifest

Run the following command that sets up couple of env variables for cluster configuration.

Go to your azure portal and check what azure region you have the quota for!
Set the correct region in the cluster-manifest.sh

```shell
chmod +x cluster-manifest.sh
source ./cluster-manifest.sh
```

Generate the cluster manifest using the following command

```shell
clusterctl generate cluster kcd-demo > kcd-demo.yaml
```

# Create a Kubernetes Cluster

Apply the above generated YAML file

```shell
kubectl apply -f kcd-demo.yaml
```

## Few Commands For Analysing the State

See the created cluster

```shell
kubectl get clusters
```

See the state of the cluster

```shell
clusterctl describe cluster kcd-demo
```

See if the VMs got successfully created

```shell
kubectl get azuremachines
```

Note: It can take a little while for the VMs and cloud resource to get up an running.


Awesome! We created a k8s cluster having 1 control plane and 1 worker node. In general practice, a kubernetes cluster that is created using the kind cluster(bootstrap cluster) is called `management cluster` and then
this `management cluster` is used to create and manage mutiple kubernetes cluster on different providers.  

# Fetching KubeConfig And Configuring CNI

Run the following command to see if the mahcines got successfully created

```shell
kubectl get azuremachines
```

For successful creation, you should see a output similar to the following:

```shell
NAME                           READY   REASON   STATE
kcd-demo-control-plane-jjgww   True             Succeeded
kcd-demo-md-0-9nl2l            True             Succeeded
```

After that, run the following command to get the kubeconfig

```shell
clusterctl get kubeconfig kcd-demo > kcd-demo.kubeconfig
```

See the nodes of the created cluster

```shell
kubectl get node --kubeconfig kcd-demo.kubeconfig
```

You can see the nodes are `NotReady` and the reason is CNI is not configured. Next section we will conifgure the CNI.

To install CNI, run the following command

```shell
kubectl --kubeconfig=kcd-demo.kubeconfig apply -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/templates/addons/calico.yaml
```

The nodes should become ready now!

# Upgrade k8s version(Free version will not have quota to do this)

In this section, we will upgrade the k8s version to v1.22.0

Run the following command to get KCP

```shell
kubectl get kcp
```

Edit it by running the following command

```shell
kubectl edit kcp kcd-demo-control-plane
```
In there, change the version to `v1.22.0` and save it.

After sometime, the control plane should get upgraded and version `v1.22.0` should appear.

```shell
kubectl get node --kubeconfig kcd-demo.kubeconfig
```

Now, let us upgrade the worker machine

Run the following command to get the machine deployment

```shell
kubectl get md
```

Edit it by running the following command

```shell
kubectl edit md kcd-demo-md-0
```

In there, change the version to `v1.22.0` and save it.

After sometime, the worker node should get upgraded and version `v1.22.0` should appear.

```shell
kubectl get node --kubeconfig kcd-demo.kubeconfig
```

# Scale the worker node count

Edit the md by chaning the replicas value to 2

```shell
kubectl edit md kcd-demo-md-0
```

# Cleanup

```shell
kubectl delete cluster kcd-demo
```
