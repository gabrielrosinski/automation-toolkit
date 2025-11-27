#!/bin/bash

###############################################################################
# DevOps Interview Toolkit - Cleanup Script
# Removes all toolkit-generated artifacts for fresh testing/debugging
# NOTE: Does NOT remove installed software (Docker, kubectl, minikube, PHP, Git)
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=========================================="
echo "  DevOps Toolkit Cleanup"
echo "=========================================="
echo ""
log_info "Removing:"
echo "  • Jenkins container and data volume"
echo "  • minikube cluster and data"
echo "  • Docker images built by toolkit"
echo "  • Generated files (Dockerfile, Jenkinsfile, k8s/, .env.interview)"
echo ""
log_info "Preserving:"
echo "  • Installed software (Docker, kubectl, minikube, PHP, Git)"
echo "  • Base images (jenkins/jenkins:lts, php:*, etc.)"
echo ""
log_info "Starting cleanup..."

# 0. Reset Docker environment (in case minikube docker-env is active)
log_info "Resetting Docker environment to host..."
unset DOCKER_TLS_VERIFY
unset DOCKER_HOST
unset DOCKER_CERT_PATH
unset MINIKUBE_ACTIVE_DOCKERD
log_success "Docker environment reset to host"
echo ""

# 1. Stop and remove Jenkins container
log_info "Cleaning up Jenkins..."
if docker ps -a | grep -q jenkins; then
    log_info "Stopping Jenkins container..."
    docker stop jenkins 2>/dev/null || true
    log_info "Removing Jenkins container..."
    docker rm jenkins 2>/dev/null || true
    log_success "Jenkins container removed"
else
    log_info "No Jenkins container found"
fi

# 2. Remove Jenkins volume
if docker volume ls | grep -q jenkins_home; then
    log_info "Removing Jenkins data volume..."
    docker volume rm jenkins_home 2>/dev/null || true
    log_success "Jenkins volume removed"
else
    log_info "No Jenkins volume found"
fi

# 3. Clean up Docker images from minikube BEFORE deleting cluster
log_info "Cleaning up Docker images..."

# Clean up images from HOST Docker first
IMAGES_TO_REMOVE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "localhost:5000/|automation-toolkit|test-|php-app|demo-" || true)

if [ -n "$IMAGES_TO_REMOVE" ]; then
    log_info "Removing toolkit-generated images from host Docker..."
    echo "$IMAGES_TO_REMOVE" | xargs -r docker rmi -f 2>/dev/null || true
    log_success "Host Docker images removed"
else
    log_info "No toolkit-generated images found in host Docker"
fi

# Clean up images from MINIKUBE Docker (BEFORE deleting cluster!)
if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
    log_info "Cleaning up images from minikube Docker (before cluster deletion)..."

    # Switch to minikube Docker context and remove images
    eval $(minikube docker-env) 2>/dev/null || true
    MINIKUBE_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "localhost:5000/|automation-toolkit" || true)

    if [ -n "$MINIKUBE_IMAGES" ]; then
        log_info "Removing toolkit images from minikube Docker..."
        echo "$MINIKUBE_IMAGES" | xargs -r docker rmi -f 2>/dev/null || true
        log_success "Minikube Docker images removed"
    else
        log_info "No toolkit images found in minikube Docker"
    fi

    # Reset to host Docker context
    eval $(minikube docker-env -u) 2>/dev/null || true
fi

# 4. Delete minikube cluster and configuration (AFTER cleaning images)
echo ""
log_info "Cleaning up minikube..."
if command -v minikube >/dev/null 2>&1; then
    # Delete cluster
    if minikube status >/dev/null 2>&1; then
        log_info "Deleting minikube cluster..."
        minikube delete
        log_success "minikube cluster deleted"
    else
        log_info "No minikube cluster running"
    fi

    # Clean up minikube configuration
    echo ""
    log_info "Cleaning minikube configuration..."
    if [ -d ~/.minikube ]; then
        MINIKUBE_SIZE=$(du -sh ~/.minikube 2>/dev/null | cut -f1)
        log_info "Removing ~/.minikube directory (${MINIKUBE_SIZE})..."
        rm -rf ~/.minikube
        log_success "minikube config removed"
    fi

    if [ -f ~/.kube/config ]; then
        log_info "Backing up and cleaning kubectl config..."
        # Backup current kubeconfig
        cp ~/.kube/config ~/.kube/config.backup.$(date +%Y%m%d_%H%M%S)

        # Remove minikube context and cluster
        kubectl config delete-context minikube 2>/dev/null || true
        kubectl config delete-cluster minikube 2>/dev/null || true
        kubectl config delete-user minikube 2>/dev/null || true

        log_success "minikube context removed from kubectl config"
        log_info "Backup saved to ~/.kube/config.backup.*"
    fi
else
    log_info "minikube not installed (skipping)"
fi

# 5. Docker system prune (dangling images, stopped containers, unused networks)
echo ""
log_info "Running Docker system prune..."
docker system prune -f
log_success "Docker system pruned"

# 6. Clean up generated files in current directory (if in a project)
echo ""
log_info "Checking for generated files in current directory..."

GENERATED_FILES=()
[ -f Dockerfile ] && GENERATED_FILES+=("Dockerfile")
[ -f Jenkinsfile ] && GENERATED_FILES+=("Jenkinsfile")
[ -f .dockerignore ] && GENERATED_FILES+=(".dockerignore")
[ -f quick-deploy.sh ] && GENERATED_FILES+=("quick-deploy.sh")
[ -f .env.interview ] && GENERATED_FILES+=(".env.interview")
[ -d k8s ] && GENERATED_FILES+=("k8s/")

if [ ${#GENERATED_FILES[@]} -gt 0 ]; then
    log_info "Removing generated files from $(pwd)..."
    for file in "${GENERATED_FILES[@]}"; do
        rm -rf "$file" 2>/dev/null || true
    done
    log_success "Generated files removed"
else
    log_info "No generated files found in current directory"
fi

# 7. Clean up init scripts (if running from toolkit directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "/tmp/jenkins-init-scripts" ]; then
    log_info "Removing temporary Jenkins init scripts..."
    sudo rm -rf /tmp/jenkins-init-scripts 2>/dev/null || true
    log_success "Temp files removed"
fi

# 8. Clean up .env.interview in toolkit directory
if [ -f "${SCRIPT_DIR}/.env.interview" ]; then
    log_info "Removing .env.interview from toolkit directory..."
    rm -f "${SCRIPT_DIR}/.env.interview"
    log_success ".env.interview removed"
fi

echo ""
echo "=========================================="
log_success "Cleanup Complete!"
echo "=========================================="
echo ""
log_info "What was cleaned:"
echo "  ✓ Jenkins container and data"
echo "  ✓ minikube cluster (if existed)"
echo "  ✓ Docker images (if confirmed)"
echo "  ✓ Generated files (if confirmed)"
echo ""
log_info "What was preserved:"
echo "  ✓ Docker installation"
echo "  ✓ kubectl binary"
echo "  ✓ minikube binary"
echo "  ✓ PHP installation"
echo "  ✓ Git installation"
echo "  ✓ Base Docker images (jenkins/jenkins:lts, php:*, etc.)"
echo ""
log_info "To start fresh:"
echo "  1. Run: ./1-infra-setup.sh"
echo "  2. Test with your project"
echo ""
