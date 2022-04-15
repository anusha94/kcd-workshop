# Create a Management Cluster
```shell
kind create cluster
```

# Install the BYOH provider

```shell
# see what providers are available
clusterctl config repositories

# install the byoh provider
clusterctl init --infrastructure byoh

# verify the provider is installed
kubectl get pods -A
```

# Creating a BYOH workload cluster
We need to have the hosts in place. For that, we will be using docker container as hosts.
```shell
# Build the image using the make task in the repo
make prepare-byoh-docker-host-image
```

Let us now create 2 docker containers, because we will need one for the control plane and another for worker
```shell
for i in {1..2}
do
  echo "Creating docker container named host$i"
  docker run --detach --tty --hostname host$i --name host$i --privileged --security-opt seccomp=unconfined --tmpfs /tmp --tmpfs /run --volume /var --volume /lib/modules:/lib/modules:ro --network kind byoh/node:e2e
done
```

# Prepare the hosts
## Download the byoh agent
```shell
wget https://github.com/vmware-tanzu/cluster-api-provider-bringyourownhost/releases/download/v0.2.0/byoh-hostagent-linux-amd64
```

Add kind container IP to the kubeconfig
```shell
cp ~/.kube/config ~/.kube/management-cluster.conf
export KIND_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kind-control-plane)
sed -i 's/    server\:.*/    server\: https\:\/\/'"$KIND_IP"'\:6443/g' ~/.kube/management-cluster.conf
```

## Copy the agent and kubeconfig on to the hosts
```shell
for i in {1..2}
do
echo "Copy agent binary to host $i"
docker cp byoh-hostagent-linux-amd64 host$i:/byoh-hostagent
echo "Copy kubeconfig to host $i"
docker cp ~/.kube/management-cluster.conf host$i:/management-cluster.conf
done
```

## Registering the BYOH hosts
Ideally open 2 new tabs so that you can see the logs and inspect if something goes wrong.
```shell
export HOST_NAME=host1
docker exec -it $HOST_NAME sh -c "chmod +x byoh-hostagent && ./byoh-hostagent --kubeconfig management-cluster.conf"

# do the same for host2 in a separate tab
export HOST_NAME=host2
docker exec -it $HOST_NAME sh -c "chmod +x byoh-hostagent && ./byoh-hostagent --kubeconfig management-cluster.conf"
```

You should be able to view your registered hosts using
```shell
kubectl get byohosts
```

## Creating the workload cluster
First, we need to assign a value for the `CONTROL_PLANE_ENDPOINT_IP`. This is an IP that must be an IP on the same subnet as the control plane machines, it should be also an IP that is not part of your DHCP range.

```shell
# find the control plane machine's network subnet
docker network inspect kind | jq -r 'map(.IPAM.Config[].Subnet) []'

# see what IPs are in use already
docker network inspect kind | jq -r 'map(.Containers[].IPv4Address) []'
```

Now it is time to generate and apply the cluster template
```shell
# generate cluster.yaml
BUNDLE_LOOKUP_TAG=v1.23.5 CONTROL_PLANE_ENDPOINT_IP=10.10.10.10 clusterctl generate cluster byoh-cluster \
    --infrastructure byoh \
    --kubernetes-version v1.23.5 \
    --control-plane-machine-count 1 \
    --worker-machine-count 1 \
    --flavor docker > cluster.yaml

# inspect and make any changes
vi cluster.yaml

# apply the cluster template
kubectl apply -f cluster.yaml
```

# Accessing the workload cluster
The `kubeconfig` for the workload cluster will be stored in a secret, which can be retrieved using:
```shell
kubectl get secret/byoh-cluster-kubeconfig -o json \
  | jq -r .data.value \
  | base64 --decode \
  > ./byoh-cluster.kubeconfig
```

The kubeconfig can then be used to apply a CNI for networking, for example, Calico:
```shell
KUBECONFIG=byoh-cluster.kubeconfig kubectl apply -f https://docs.projectcalico.org/v3.20/manifests/calico.yaml
```

After that you should see your nodes turn into ready:
```shell
$ KUBECONFIG=byoh-cluster.kubeconfig kubectl get nodes
NAME                                                          STATUS     ROLES    AGE   VERSION
byoh-cluster-8siai8                                           Ready      master   5m   v1.23.5
```