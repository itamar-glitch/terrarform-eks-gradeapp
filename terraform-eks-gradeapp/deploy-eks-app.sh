#!/bin/bash
set -e

# Variables - update these as needed
CLUSTER_NAME="staging-demo"
REGION="us-east-2"
NAMESPACE="default"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Installing prerequisites ===${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found. Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found. Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "Helm not found. Installing Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
fi

echo -e "${YELLOW}=== Configuring kubectl for EKS cluster ===${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

echo -e "${YELLOW}=== Verifying cluster connection ===${NC}"
kubectl get nodes

echo -e "${YELLOW}=== Installing NGINX Ingress Controller ===${NC}"
# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install the ingress-nginx controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --set controller.service.type=LoadBalancer

# Wait for the ingress controller to be ready
echo "Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --namespace default \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo -e "${YELLOW}=== Deploying application ===${NC}"
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

echo -e "${YELLOW}=== Checking deployment status ===${NC}"
kubectl get pods
kubectl get svc
kubectl get ingress

# Get the load balancer URL
echo -e "${YELLOW}=== Load Balancer Details ===${NC}"
echo "NGINX Ingress Controller Load Balancer:"
kubectl get service nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo "Your application has been deployed to the EKS cluster!"
echo "Use the Load Balancer URL above to access your application." 