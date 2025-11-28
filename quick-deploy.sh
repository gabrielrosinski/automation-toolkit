#!/bin/bash
# Quick deployment script

set -e

echo "Building Docker image..."
eval $(minikube docker-env)
docker build -t automation-toolkit:latest .

echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/

echo "Waiting for deployment..."
kubectl wait --for=condition=available --timeout=120s deployment/automation-toolkit -n default

echo "Deployment complete!"
echo "Access app: minikube service automation-toolkit -n default --url"
