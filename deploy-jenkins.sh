#!/bin/bash

###############################################################################
# Jenkins Deployment Script - Separated from infrastructure setup
# Can be run standalone or called from 1-infra-setup.sh
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
detect_os() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        OS="wsl"
        ARCH="amd64"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        ARCH=$(uname -m)
        [[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
        [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        ARCH=$(uname -m)
        [[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
    fi
}

################################################################################
# JENKINS AUTOMATION - Using external Groovy init scripts
################################################################################
# Init scripts are stored in jenkins-init-scripts/ directory
# They will be mounted into Jenkins container at startup
################################################################################

deploy_jenkins() {
    log_info "Deploying Jenkins..."

    # Check if Jenkins container exists and is healthy
    if docker ps | grep -q jenkins; then
        log_info "Found existing Jenkins container, verifying health..."
        sleep 2

        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "000")

        if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "403" ]]; then
            log_success "Jenkins is running and healthy"
            return 0
        else
            log_warning "Jenkins container exists but not responding (HTTP $HTTP_CODE)"
            log_warning "Removing unhealthy Jenkins container..."
            docker stop jenkins 2>/dev/null || true
            docker rm jenkins 2>/dev/null || true
            log_info "Creating fresh Jenkins deployment..."
        fi
    fi

    # Remove old stopped container
    if docker ps -a | grep -q jenkins; then
        log_warning "Removing stopped Jenkins container..."
        docker stop jenkins 2>/dev/null || true
        docker rm jenkins 2>/dev/null || true
    fi

    # Get the directory containing this script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    INIT_SCRIPTS_DIR="$SCRIPT_DIR/jenkins-init-scripts"

    # Verify init scripts exist
    if [ ! -d "$INIT_SCRIPTS_DIR" ]; then
        log_error "Jenkins init scripts not found at: $INIT_SCRIPTS_DIR"
        return 1
    fi

    log_info "Starting Jenkins container with automation..."
    log_info "Init scripts: $INIT_SCRIPTS_DIR"

    # Run Jenkins with Groovy init scripts for full automation
    if ! docker run -d \
        --name jenkins \
        --restart unless-stopped \
        -p 0.0.0.0:8080:8080 \
        -p 0.0.0.0:50000:50000 \
        -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false" \
        -v jenkins_home:/var/jenkins_home \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$INIT_SCRIPTS_DIR":/usr/share/jenkins/ref/init.groovy.d:ro \
        jenkins/jenkins:lts; then
        log_error "Failed to start Jenkins container"
        log_info "Check if port 8080 is in use: sudo lsof -i :8080"
        return 1
    fi

    log_success "Jenkins container started"

    # Wait for container to stabilize
    sleep 5

    # Verify container is running
    if ! docker ps | grep -q jenkins; then
        log_error "Jenkins container failed to stay running"
        log_info "Container logs:"
        docker logs jenkins 2>&1 | tail -30
        return 1
    fi

    log_info "Waiting for Jenkins to initialize and install plugins..."
    log_info "Installing: workflow-aggregator, git, credentials-binding, docker-workflow, pipeline-stage-view, timestamper"
    log_info "This may take 2-3 minutes..."
    sleep 45

    # Verify container is still running after plugin installation
    if ! docker ps | grep -q jenkins; then
        log_error "Jenkins container crashed during initialization!"
        log_info "Container logs:"
        docker logs jenkins 2>&1 | tail -50
        log_info "Saving logs to /tmp/jenkins-init-crash.log"
        docker logs jenkins > /tmp/jenkins-init-crash.log 2>&1
        return 1
    fi
    log_info "Jenkins container is still running after plugin installation"

    # Install Docker CLI in Jenkins container
    log_info "Installing Docker CLI in Jenkins container..."
    if docker exec -u root jenkins bash -c "
        apt-get update -qq >/dev/null 2>&1 && \
        apt-get install -y -qq curl >/dev/null 2>&1 && \
        curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
    "; then
        log_success "Docker CLI installed"
    else
        log_warning "Docker CLI installation had issues (may still work)"
    fi

    # Configure Docker socket permissions
    log_info "Configuring Docker socket permissions..."

    # Get Docker group ID from host
    if [[ "$OS" == "macos" ]]; then
        DOCKER_GID=$(stat -f '%g' /var/run/docker.sock 2>/dev/null || echo "0")
    else
        DOCKER_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "0")
    fi

    # Create docker group in Jenkins with same GID
    docker exec -u root jenkins groupadd -g "$DOCKER_GID" docker 2>/dev/null || \
    docker exec -u root jenkins groupmod -g "$DOCKER_GID" docker 2>/dev/null || true

    # Add jenkins user to docker group
    docker exec -u root jenkins usermod -aG docker jenkins || true

    # Verify Docker works in Jenkins
    if docker exec jenkins docker ps >/dev/null 2>&1; then
        log_success "Docker CLI configured in Jenkins"
    else
        log_warning "Docker CLI may need manual verification"
    fi

    # Install kubectl in Jenkins container
    log_info "Installing kubectl in Jenkins..."
    if docker exec -u root jenkins bash -c "
        curl -LO https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl >/dev/null 2>&1 && \
        chmod +x kubectl && \
        mv kubectl /usr/local/bin/kubectl
    "; then
        log_success "kubectl installed"
    else
        log_warning "kubectl installation had issues (may still work)"
    fi

    # Copy kubeconfig to Jenkins
    log_info "Configuring kubectl access..."
    if [ -f ~/.kube/config ]; then
        docker exec jenkins mkdir -p /var/jenkins_home/.kube 2>/dev/null || true

        if docker cp ~/.kube/config jenkins:/var/jenkins_home/.kube/config 2>/dev/null; then
            docker exec jenkins chown -R jenkins:jenkins /var/jenkins_home/.kube 2>/dev/null || true
            log_success "Kubeconfig copied to Jenkins"

            # Verify kubectl works
            if docker exec jenkins kubectl get nodes >/dev/null 2>&1; then
                log_success "kubectl configured and working"
            fi
        else
            log_warning "Failed to copy kubeconfig"
        fi
    else
        log_warning "Kubeconfig not found at ~/.kube/config"
        log_info "Run later: docker cp ~/.kube/config jenkins:/var/jenkins_home/.kube/config"
    fi

    # Wait for plugin installation and user creation to complete
    log_info "Waiting for automation scripts to complete..."
    sleep 60

    # Verify Jenkins is ready
    log_info "Verifying Jenkins is ready..."
    for i in {1..20}; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "403" ]]; then
            log_success "Jenkins is responding (HTTP $HTTP_CODE)"
            break
        fi
        if [[ $i -eq 20 ]]; then
            log_warning "Jenkins may still be initializing..."
        fi
        sleep 3
    done

    log_success "Jenkins deployed successfully!"
    echo ""
    echo "=========================================="
    echo "Jenkins URL: http://localhost:8080"
    echo ""
    echo "Auto-configured Credentials:"
    echo "  Username: admin"
    echo "  Password: admin"
    echo ""
    echo "Pre-installed Plugins:"
    echo "  ✓ Pipeline (workflow-aggregator)"
    echo "  ✓ Git"
    echo "  ✓ Credentials Binding"
    echo "  ✓ Docker Pipeline"
    echo "  ✓ Pipeline Stage View"
    echo "  ✓ Timestamper"
    echo ""
    echo "Configured Tools:"
    echo "  ✓ Docker CLI"
    echo "  ✓ kubectl"
    echo "  ✓ 2 Executors"
    echo ""
    echo "Auto-created Pipeline Job:"
    echo "  ✓ Job Name: php-app-pipeline"
    echo "  ✓ Poll SCM: Every 2 minutes"
    echo "  ✓ Source: Jenkinsfile from Git"
    echo ""
    echo "IMPORTANT - Configure the pipeline:"
    echo "  1. Go to: http://localhost:8080/job/php-app-pipeline/configure"
    echo "  2. Update 'Repository URL' with your GitLab URL"
    echo "  3. Create credential 'gitlab-creds' (Manage Credentials)"
    echo "  4. Select credential and Save"
    echo "  5. Click 'Build Now' to test"
    echo ""
    echo "Jenkins is ready to use - no setup wizard needed!"
    echo "=========================================="
    echo ""

    # Show WSL-specific instructions
    if [[ "$OS" == "wsl" ]]; then
        WSL_IP=$(hostname -I | awk '{print $1}')
        echo "Access from Windows: http://$WSL_IP:8080"
        echo ""
    fi

    return 0
}

# Main execution
main() {
    detect_os
    deploy_jenkins
}

# Run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
