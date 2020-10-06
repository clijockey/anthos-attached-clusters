#!/usr/bin/env bash

set -e # bail out early if any command fails
set -u # fail if we hit unset variables
set -o pipefail # fail if any component of any pipe fails


# Based on https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough
# Create resource Group (logical group of Azure resources)
az group create --name myResourceGroup --location eastus

# Azure monitor for continers
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.OperationalInsights

# Create Cluster
az aks create --resource-group myResourceGroup --name myAKSCluster --node-count 1 --enable-addons monitoring --generate-ssh-keys --kubernetes-version 1.16.15

# Connect to cluster
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster

gcloud container hub memberships register myakscluster --context=myAKSCluster --service-account-key-file='/home/robedwards/Downloads/big-rob-2d1cee4c0a1b.json' --kubeconfig=~/.kube/config --project=big-rob

# Create k8s service account and RBAC bindings
kubectl create sa sa-anthos  
kubectl get sa sa-anthos -o json

kubectl create clusterrolebinding sa-anthos-admin-bind --clusterrole cluster-admin --serviceaccount default:sa-anthos
# Get token to be entered into Anthos Cluster login
kubectl get secret sa-anthos-token-g7sbr -o json | jq -r .data.token | base64 -d | xargs


# Get the demo app
sudo apt-get install google-cloud-sdk-kpt  


# Install ASM
curl -LO https://storage.googleapis.com/gke-release/asm/istio-1.6.11-asm.1-linux-amd64.tar.gz 
curl -LO https://storage.googleapis.com/gke-release/asm/istio-1.6.11-asm.1-linux-amd64.tar.gz.1.sig                     ─╯
openssl dgst -verify /dev/stdin -signature istio-1.6.11-asm.1-linux-amd64.tar.gz.1.sig istio-1.6.11-asm.1-linux-amd64.tar.gz <<'EOF'
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEWZrGCUaJJr1H8a36sG4UUoXvlXvZ
wQfk16sxprI2gOJ2vFFggdq3ixF2h4qNBt0kI7ciDhgpwS8t+/960IsIgw==
-----END PUBLIC KEY-----
EOF

tar xzf istio-1.6.11-asm.1-linux-amd64.tar.gz 

cd is.....
export PATH=$PWD/bin:$PATH
kubectl create namespace istio-system

istioctl install --set profile=asm-multicloud  
kubectl label namespace default istio-injection- istio.io/rev=asm-1611-1 --overwrite

# Deploy the demo app
kpt pkg get https://github.com/GoogleCloudPlatform/microservices-demo.git/release microservices-demo

export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].'"$HOST_KEY"'}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')  

cd microservices-demo 
kubectl apply -f microservices-demo 


# Setup creds for Kiali