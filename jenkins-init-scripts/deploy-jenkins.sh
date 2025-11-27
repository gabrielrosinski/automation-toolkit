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

    # Get the directory containing this script (which is now jenkins-init-scripts/)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    INIT_SCRIPTS_DIR="$SCRIPT_DIR"

    # Verify init scripts exist
    if [ ! -f "$INIT_SCRIPTS_DIR/01-install-plugins.groovy" ]; then
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

    # Wait for Jenkins to restart (plugins trigger auto-restart)
    log_info "Waiting for Jenkins to restart and load plugins..."
    sleep 30

    # Wait for Jenkins to be fully ready after restart
    local max_attempts=30
    local attempt=0
    log_info "Waiting for Jenkins to be ready after restart..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:8080/login | grep -q "Sign in" 2>/dev/null; then
            log_success "Jenkins is ready after restart"
            break
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    if [ $attempt -eq $max_attempts ]; then
        log_warning "Jenkins took longer than expected to restart"
    fi

    # Install Docker CLI and PHP in Jenkins container
    log_info "Installing Docker CLI and PHP in Jenkins container..."
    if docker exec -u root jenkins bash -c "
        apt-get update -qq >/dev/null 2>&1 && \
        apt-get install -y -qq curl php-cli >/dev/null 2>&1 && \
        curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
    "; then
        log_success "Docker CLI and PHP installed"
    else
        log_warning "Installation had issues (may still work)"
    fi

    # Configure Docker socket permissions
    log_info "Configuring Docker socket permissions..."

    # Get Docker group ID from host
    if [[ "$OS" == "macos" ]]; then
        DOCKER_GID=$(stat -f '%g' /var/run/docker.sock 2>/dev/null || echo "0")
    else
        DOCKER_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "0")
    fi

    log_info "Host Docker socket GID: $DOCKER_GID"

    # Create docker group in Jenkins with same GID
    docker exec -u root jenkins groupadd -g "$DOCKER_GID" docker 2>/dev/null || \
    docker exec -u root jenkins groupmod -g "$DOCKER_GID" docker 2>/dev/null || true

    # Add jenkins user to docker group
    docker exec -u root jenkins usermod -aG docker jenkins || true

    # Ensure jenkins user's groups are reloaded by restarting the container
    # This is necessary for group membership to take effect
    log_info "Restarting Jenkins to apply Docker group membership..."
    docker restart jenkins >/dev/null 2>&1
    sleep 15

    # Wait for Jenkins to be ready after restart
    local restart_attempts=30
    local restart_attempt=0
    log_info "Waiting for Jenkins to be ready after restart..."
    while [ $restart_attempt -lt $restart_attempts ]; do
        if curl -s http://localhost:8080/login | grep -q "Sign in" 2>/dev/null; then
            log_success "Jenkins is ready after restart"
            break
        fi
        echo -n "."
        sleep 2
        restart_attempt=$((restart_attempt + 1))
    done

    # Verify Docker works in Jenkins
    if docker exec jenkins docker ps >/dev/null 2>&1; then
        log_success "Docker CLI configured in Jenkins"
    else
        log_error "Docker CLI verification failed"
        log_info "Jenkins user groups: $(docker exec jenkins id jenkins)"
        log_info "Docker socket permissions: $(ls -la /var/run/docker.sock)"
        return 1
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

    # Copy kubeconfig and minikube certificates to Jenkins
    log_info "Configuring kubectl access..."
    if [ -f ~/.kube/config ]; then
        docker exec jenkins mkdir -p /var/jenkins_home/.kube 2>/dev/null || true
        docker exec jenkins mkdir -p /var/jenkins_home/.minikube 2>/dev/null || true

        # Copy kubeconfig
        if docker cp ~/.kube/config jenkins:/var/jenkins_home/.kube/config 2>/dev/null; then
            log_success "Kubeconfig copied to Jenkins"
        fi

        # Copy minikube certificates
        if [ -d ~/.minikube ]; then
            log_info "Copying minikube certificates..."
            docker cp ~/.minikube/ca.crt jenkins:/var/jenkins_home/.minikube/ca.crt 2>/dev/null || true
            docker cp ~/.minikube/profiles jenkins:/var/jenkins_home/.minikube/ 2>/dev/null || true
            log_success "Minikube certificates copied"
        fi

        # Fix ownership
        docker exec jenkins chown -R jenkins:jenkins /var/jenkins_home/.kube 2>/dev/null || true
        docker exec jenkins chown -R jenkins:jenkins /var/jenkins_home/.minikube 2>/dev/null || true

        # Connect Jenkins to minikube network for direct access
        log_info "Connecting Jenkins to minikube network..."
        if docker network connect minikube jenkins 2>/dev/null; then
            log_success "Jenkins connected to minikube network"
        else
            log_info "Jenkins already connected to minikube network"
        fi

        # Fix kubeconfig certificate paths (host paths → container paths)
        log_info "Fixing kubeconfig certificate paths..."
        docker exec jenkins sed -i "s|$HOME/.minikube|/var/jenkins_home/.minikube|g" /var/jenkins_home/.kube/config 2>/dev/null || true

        # Update kubeconfig to use minikube IP instead of 127.0.0.1
        MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "192.168.49.2")
        log_info "Updating kubeconfig to use minikube IP: $MINIKUBE_IP"
        docker exec jenkins sed -i "s|https://127.0.0.1:[0-9]*|https://$MINIKUBE_IP:8443|g" /var/jenkins_home/.kube/config 2>/dev/null || true

        # Verify kubectl works
        if docker exec jenkins kubectl get nodes >/dev/null 2>&1; then
            log_success "kubectl configured and working"
        else
            log_warning "kubectl verification failed - may need manual configuration"
        fi
    else
        log_warning "Kubeconfig not found at ~/.kube/config"
        log_info "Run later: docker cp ~/.kube/config jenkins:/var/jenkins_home/.kube/config"
    fi

    # Configure Jenkins to use minikube's Docker daemon
    log_info "Configuring Jenkins to use minikube Docker daemon..."

    # Get minikube docker-env variables
    MINIKUBE_DOCKER_HOST=$(minikube docker-env | grep DOCKER_HOST | cut -d'=' -f2 | tr -d '"')
    MINIKUBE_DOCKER_CERT_PATH=$(minikube docker-env | grep DOCKER_CERT_PATH | cut -d'=' -f2 | tr -d '"')

    if [ -n "$MINIKUBE_DOCKER_HOST" ] && [ -n "$MINIKUBE_DOCKER_CERT_PATH" ]; then
        log_info "Minikube Docker host: $MINIKUBE_DOCKER_HOST"

        # Copy minikube Docker certificates to Jenkins
        docker exec jenkins mkdir -p /var/jenkins_home/.minikube-docker 2>/dev/null || true
        docker cp "$MINIKUBE_DOCKER_CERT_PATH/." jenkins:/var/jenkins_home/.minikube-docker/ 2>/dev/null || true
        docker exec jenkins chown -R jenkins:jenkins /var/jenkins_home/.minikube-docker 2>/dev/null || true

        # Create environment file for Jenkins to source
        docker exec jenkins bash -c "cat > /var/jenkins_home/minikube-docker-env.sh <<EOF
export DOCKER_TLS_VERIFY=1
export DOCKER_HOST=$MINIKUBE_DOCKER_HOST
export DOCKER_CERT_PATH=/var/jenkins_home/.minikube-docker
export MINIKUBE_ACTIVE_DOCKERD=minikube
EOF"

        docker exec jenkins chown jenkins:jenkins /var/jenkins_home/minikube-docker-env.sh

        log_success "Minikube Docker environment configured"
        log_info "Jenkins can now build images in minikube's Docker"
    else
        log_warning "Could not get minikube docker-env - images may build in wrong Docker"
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
    echo "Pipeline Job Setup:"
    echo "  After running ./2-generate-project.sh, you can auto-create the pipeline job"
    echo "  Or create it manually at: http://localhost:8080/newJob"
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
