#!/bin/bash

###############################################################################
# DevOps Interview Toolkit - Cleanup Script
# Two modes:
#   ./cleanup.sh        - Remove stale resources (fast re-setup)
#   ./cleanup.sh --full - Complete wipe (including base images & network)
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

# Parse arguments
FULL_CLEANUP=false
if [[ "$1" == "--full" ]]; then
    FULL_CLEANUP=true
fi

# Display mode
echo ""
echo "=========================================="
if [[ "$FULL_CLEANUP" == "true" ]]; then
    echo "  DevOps Toolkit Cleanup (FULL MODE)"
else
    echo "  DevOps Toolkit Cleanup (DEFAULT MODE)"
fi
echo "=========================================="
echo ""

if [[ "$FULL_CLEANUP" == "true" ]]; then
    log_warning "FULL CLEANUP MODE - Everything will be removed!"
    echo ""
    log_info "Removing:"
    echo "  • Jenkins & GitLab containers + volumes"
    echo "  • minikube cluster"
    echo "  • Custom Docker network (gitlab-jenkins-network)"
    echo "  • ALL Docker images (including base images)"
    echo "  • Generated files"
    echo ""
    log_info "Preserving:"
    echo "  • Installed software (Docker, kubectl, minikube, PHP, Git)"
else
    log_info "DEFAULT CLEANUP MODE - Removes stale resources only"
    echo ""
    log_info "Removing:"
    echo "  • Jenkins & GitLab containers + volumes (fresh start)"
    echo "  • Kubernetes resources (pods, services, deployments)"
    echo "  • Toolkit-built Docker images"
    echo "  • Generated files"
    echo ""
    log_info "Preserving:"
    echo "  • Installed software (Docker, kubectl, minikube, PHP, Git)"
    echo "  • minikube cluster (stopped, faster restart)"
    echo "  • Custom network (gitlab-jenkins-network) - faster re-setup"
    echo "  • Base images (gitlab/gitlab-ce, jenkins/jenkins, php:*) - faster re-setup"
    echo ""
    log_info "For complete wipe, use: ./cleanup.sh --full"
fi

echo ""
read -p "Continue? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-Y}
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log_warning "Cleanup cancelled"
    exit 0
fi

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

# 2. Remove Jenkins volume (ALWAYS in both modes - fresh start)
if docker volume ls | grep -q jenkins_home; then
    log_info "Removing Jenkins data volume..."
    docker volume rm jenkins_home 2>/dev/null || true
    log_success "Jenkins volume removed (fresh Jenkins on next setup)"
else
    log_info "No Jenkins volume found"
fi

# 3. Clean up GitLab
echo ""
log_info "Cleaning up GitLab..."

if docker ps -a | grep -q gitlab; then
    log_info "Stopping GitLab container..."
    docker stop gitlab 2>/dev/null || true
    log_info "Removing GitLab container..."
    docker rm gitlab 2>/dev/null || true
    log_success "GitLab container removed"
else
    log_info "No GitLab container found"
fi

# Remove GitLab volumes (ALWAYS in both modes - fresh start)
GITLAB_VOLUMES=$(docker volume ls | grep -E "gitlab_(config|logs|data)" | awk '{print $2}')
if [ -n "$GITLAB_VOLUMES" ]; then
    log_info "Removing GitLab data volumes (config, logs, data)..."
    echo "$GITLAB_VOLUMES" | xargs -r docker volume rm 2>/dev/null || true
    log_success "GitLab volumes removed (fresh GitLab on next setup)"
else
    log_info "No GitLab volumes found"
fi

# 4. Remove custom network (ONLY in --full mode)
if [[ "$FULL_CLEANUP" == "true" ]]; then
    if docker network ls | grep -q gitlab-jenkins-network; then
        log_info "Removing gitlab-jenkins-network..."
        docker network rm gitlab-jenkins-network 2>/dev/null || true
        log_success "Custom network removed"
    else
        log_info "No gitlab-jenkins-network found"
    fi
else
    if docker network ls | grep -q gitlab-jenkins-network; then
        log_info "Keeping gitlab-jenkins-network (faster re-setup)"
    fi
fi

# 5. Clean up Docker images
echo ""
log_info "Cleaning up Docker images..."

if [[ "$FULL_CLEANUP" == "true" ]]; then
    # FULL MODE: Remove ALL images
    log_warning "Removing ALL Docker images (including base images)..."

    # Clean from HOST Docker
    ALL_IMAGES=$(docker images -q)
    if [ -n "$ALL_IMAGES" ]; then
        log_info "Removing all images from host Docker..."
        docker rmi -f $(docker images -q) 2>/dev/null || true
        log_success "All host Docker images removed"
    else
        log_info "No images found in host Docker"
    fi

    # Clean from MINIKUBE Docker (before deleting cluster)
    if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
        log_info "Removing all images from minikube Docker..."
        eval $(minikube docker-env) 2>/dev/null || true
        MINIKUBE_ALL_IMAGES=$(docker images -q)
        if [ -n "$MINIKUBE_ALL_IMAGES" ]; then
            docker rmi -f $(docker images -q) 2>/dev/null || true
            log_success "All minikube Docker images removed"
        fi
        eval $(minikube docker-env -u) 2>/dev/null || true
    fi
else
    # DEFAULT MODE: Remove ONLY toolkit-built images
    log_info "Removing toolkit-built images only..."

    # Clean from HOST Docker
    IMAGES_TO_REMOVE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "localhost:5000/|automation-toolkit|test-|php-app|demo-|^<none>" || true)
    if [ -n "$IMAGES_TO_REMOVE" ]; then
        log_info "Removing toolkit-generated images from host Docker..."
        echo "$IMAGES_TO_REMOVE" | xargs -r docker rmi -f 2>/dev/null || true
        log_success "Toolkit images removed from host Docker"
    else
        log_info "No toolkit-generated images found in host Docker"
    fi

    # Clean from MINIKUBE Docker (before deleting cluster)
    if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
        log_info "Removing toolkit images from minikube Docker..."
        eval $(minikube docker-env) 2>/dev/null || true
        MINIKUBE_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "localhost:5000/|automation-toolkit|test-|php-app|demo-|^<none>" || true)
        if [ -n "$MINIKUBE_IMAGES" ]; then
            echo "$MINIKUBE_IMAGES" | xargs -r docker rmi -f 2>/dev/null || true
            log_success "Toolkit images removed from minikube Docker"
        else
            log_info "No toolkit images found in minikube Docker"
        fi
        eval $(minikube docker-env -u) 2>/dev/null || true
    fi

    log_info "Keeping base images (gitlab/gitlab-ce, jenkins/jenkins, php:*)"
fi

# 6. Clean up minikube (stop in default mode, delete in full mode)
echo ""
log_info "Cleaning up minikube..."
if command -v minikube >/dev/null 2>&1; then
    if [[ "$FULL_CLEANUP" == "true" ]]; then
        # FULL MODE: Complete deletion with purge
        if minikube status >/dev/null 2>&1; then
            log_info "Deleting minikube cluster (with purge)..."
            minikube delete --all --purge 2>/dev/null || true
            log_success "minikube cluster deleted"
        else
            # Try delete anyway in case profile exists but container is missing
            log_info "Attempting minikube cleanup..."
            minikube delete --all --purge 2>/dev/null || true
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
        # DEFAULT MODE: Stop minikube (faster restart)
        if minikube status >/dev/null 2>&1; then
            log_info "Stopping minikube cluster (preserving for fast restart)..."
            minikube stop 2>/dev/null || true
            log_success "minikube cluster stopped (use 'minikube start' to restart)"
        else
            log_info "minikube cluster not running"
        fi

        # Delete all Kubernetes resources to ensure clean state
        log_info "Cleaning Kubernetes resources..."
        kubectl delete all --all --all-namespaces 2>/dev/null || true
        kubectl delete pvc --all --all-namespaces 2>/dev/null || true
        log_success "Kubernetes resources cleaned"
    fi
else
    log_info "minikube not installed (skipping)"
fi

# 7. Docker system prune (ONLY in --full mode)
echo ""
if [[ "$FULL_CLEANUP" == "true" ]]; then
    log_info "Running Docker system prune (--full mode)..."
    docker system prune -f
    log_success "Docker system pruned"
else
    log_info "Skipping Docker system prune (use --full for complete cleanup)"
fi

# 8. Clean up generated files in current directory
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

# 9. Clean up init scripts temp files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "/tmp/jenkins-init-scripts" ]; then
    log_info "Removing temporary Jenkins init scripts..."
    sudo rm -rf /tmp/jenkins-init-scripts 2>/dev/null || true
    log_success "Temp files removed"
fi

# 10. Clean up .env.interview in toolkit directory
if [ -f "${SCRIPT_DIR}/.env.interview" ]; then
    log_info "Removing .env.interview from toolkit directory..."
    rm -f "${SCRIPT_DIR}/.env.interview"
    log_success ".env.interview removed"
fi

# Summary
echo ""
echo "=========================================="
log_success "Cleanup Complete!"
echo "=========================================="
echo ""

if [[ "$FULL_CLEANUP" == "true" ]]; then
    log_info "FULL CLEANUP - What was removed:"
    echo "  ✓ Jenkins & GitLab containers + volumes"
    echo "  ✓ Custom Docker network (gitlab-jenkins-network)"
    echo "  ✓ minikube cluster"
    echo "  ✓ ALL Docker images (including base images)"
    echo "  ✓ Generated files"
    echo "  ✓ Docker system pruned"
    echo ""
    log_info "What was preserved:"
    echo "  ✓ Installed software (Docker, kubectl, minikube, PHP, Git)"
    echo ""
    log_warning "Next setup will download all base images (~2GB)"
else
    log_info "DEFAULT CLEANUP - What was removed:"
    echo "  ✓ Jenkins & GitLab containers + volumes (fresh start)"
    echo "  ✓ Kubernetes resources (pods, services, deployments)"
    echo "  ✓ Toolkit-built Docker images"
    echo "  ✓ Generated files"
    echo ""
    log_info "What was preserved:"
    echo "  ✓ Installed software (Docker, kubectl, minikube, PHP, Git)"
    echo "  ✓ minikube cluster (stopped, use 'minikube start' to restart)"
    echo "  ✓ Custom network (gitlab-jenkins-network) - re-used on next setup"
    echo "  ✓ Base images (gitlab/gitlab-ce, jenkins/jenkins, php:*) - faster re-setup"
    echo ""
    log_info "For complete wipe: ./cleanup.sh --full"
fi

echo ""
log_info "To start fresh:"
echo "  1. Run: ./1-infra-setup.sh"
echo "  2. Test with your project"
echo ""
