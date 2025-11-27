#!/bin/bash
# Quick deployment script

set -e

echo "Building Docker image..."
eval $(minikube docker-env)
docker build -t buged-php:latest .

echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/

echo "Waiting for deployment..."
kubectl wait --for=condition=available --timeout=120s deployment/buged-php -n default

echo "Deployment complete!"
echo "Access app: minikube service buged-php -n default --url"
