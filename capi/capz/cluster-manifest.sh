#!/bin/bash

# this should be an Azure region that your subscription has quota for.
export AZURE_LOCATION="eastasia" 

# Select VM types.
export AZURE_CONTROL_PLANE_MACHINE_TYPE="Standard_B2s"
export AZURE_NODE_MACHINE_TYPE="Standard_B2s"

# Kubernetes version
export KUBERNETES_VERSION=v1.21.0

# Machine counts
export CONTROL_PLANE_MACHINE_COUNT=1
export WORKER_MACHINE_COUNT=1
