#!/bin/bash
# Quick deployment script

set -e

echo "Building Docker image..."
eval $(minikube docker-env)
docker build -t php-app:latest .

echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/

echo "Waiting for deployment..."
kubectl wait --for=condition=available --timeout=120s deployment/php-app -n default

echo "Deployment complete!"
echo "Access app: minikube service php-app -n default --url"
