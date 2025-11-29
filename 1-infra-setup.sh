#!/bin/bash

###############################################################################
# DevOps Interview Toolkit - Infrastructure Setup
# Detects OS and installs: Docker, kubectl, minikube, Jenkins, PHP
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Version pinning for reproducibility
KUBECTL_VERSION="v1.28.0"
MINIKUBE_VERSION="v1.32.0"
JENKINS_VERSION="lts"

# Rollback flag
ROLLBACK_NEEDED=false

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

# Detect OS and Architecture
detect_os() {
    log_info "Detecting operating system..."

    if grep -qi microsoft /proc/version 2>/dev/null; then
        OS="wsl"
        ARCH="amd64"
        log_info "Detected: WSL (Windows Subsystem for Linux)"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            ARCH="amd64"
        elif [[ "$ARCH" == "aarch64" ]]; then
            ARCH="arm64"
        fi
        log_info "Detected: Linux ($ARCH)"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            ARCH="amd64"
        elif [[ "$ARCH" == "arm64" ]]; then
            ARCH="arm64"
        fi
        log_info "Detected: macOS ($ARCH)"
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check and install Homebrew on macOS
ensure_homebrew() {
    if [[ "$OS" != "macos" ]]; then
        return 0
    fi

    if command_exists brew; then
        log_success "Homebrew already installed"
        return 0
    fi

    log_warning "Homebrew not found. Installing Homebrew..."
    log_info "This may take a few minutes and will require your password..."

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for current session
    if [[ "$ARCH" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if command_exists brew; then
        log_success "Homebrew installed successfully"
    else
        log_error "Homebrew installation failed"
        exit 1
    fi
}

# Fix Docker credential helper issue in WSL2
fix_docker_credentials() {
    # Only needed for WSL
    if [[ "$OS" != "wsl" ]]; then
        return 0
    fi

    log_info "Checking Docker credential configuration..."

    # Check if config file exists and has the problematic credsStore
    if [ -f ~/.docker/config.json ]; then
        if grep -q '"credsStore".*"desktop.exe"' ~/.docker/config.json 2>/dev/null; then
            log_warning "Found WSL2 credential helper issue (desktop.exe)"
            log_info "Fixing Docker config..."

            # Backup original
            cp ~/.docker/config.json ~/.docker/config.json.backup 2>/dev/null || true

            # Remove credsStore line
            if command -v jq >/dev/null 2>&1; then
                # Use jq if available
                jq 'del(.credsStore)' ~/.docker/config.json > ~/.docker/config.json.tmp
                mv ~/.docker/config.json.tmp ~/.docker/config.json
            else
                # Fallback: use sed
                sed -i '/"credsStore"/d' ~/.docker/config.json
                # Clean up trailing commas
                sed -i 's/,\s*}/\n}/g' ~/.docker/config.json
            fi

            log_success "Docker credential config fixed"
            log_info "Backup saved to ~/.docker/config.json.backup"
        fi
    fi

    return 0
}

# Check if Docker is actually functional (not just command exists)
is_docker_functional() {
    docker ps >/dev/null 2>&1
}

# Check if docker command is Docker Desktop WSL2 stub (not functional)
is_docker_desktop_stub() {
    if [[ "$OS" != "wsl" ]]; then
        return 1
    fi
    # Docker Desktop stub outputs specific messages when not running
    docker 2>&1 | grep -qi "docker desktop\|wsl 2 distro\|wsl integration\|could not be found"
}

# Check if native Docker is installed in WSL/Linux
is_native_docker_installed() {
    # Check for dockerd binary (native Docker installation)
    command -v dockerd >/dev/null 2>&1 || \
    [[ -f /usr/bin/dockerd ]] || \
    [[ -f /usr/local/bin/dockerd ]]
}

# Wait for Docker Desktop to start (user must start it manually on Windows/macOS)
wait_for_docker_desktop() {
    local max_wait=${1:-120}  # Default 2 minutes
    log_warning "Please start Docker Desktop manually"
    log_info "Waiting for Docker Desktop to start (max ${max_wait}s)..."

    local elapsed=0
    while [ $elapsed -lt $max_wait ]; do
        if is_docker_functional; then
            echo ""
            log_success "Docker Desktop is now running"
            fix_docker_credentials
            return 0
        fi
        echo -n "."
        sleep 2
        elapsed=$((elapsed + 2))
    done
    echo ""
    log_error "Docker Desktop did not start within ${max_wait} seconds"
    return 1
}

# Start native Docker daemon (Linux/WSL with native Docker)
start_native_docker() {
    log_info "Starting native Docker daemon..."

    # Try multiple methods in order of preference
    if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files docker.service >/dev/null 2>&1; then
        log_info "Using systemctl..."
        sudo systemctl start docker
        sleep 3
    elif command -v service >/dev/null 2>&1 && [ -f /etc/init.d/docker ]; then
        log_info "Using service command..."
        sudo service docker start
        sleep 3
    else
        log_info "Starting dockerd directly..."
        sudo dockerd > /tmp/dockerd.log 2>&1 &
        sleep 5
    fi

    # Verify it started
    if is_docker_functional; then
        log_success "Native Docker daemon started successfully"
        fix_docker_credentials
        return 0
    else
        log_error "Failed to start native Docker daemon"
        [ -f /tmp/dockerd.log ] && log_info "Check /tmp/dockerd.log for details"
        return 1
    fi
}

# Install native Docker in Linux/WSL
install_native_docker() {
    log_info "Installing native Docker..."

    # Download and run Docker install script
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh

    # Add current user to docker group
    sudo usermod -aG docker $USER

    # Enable and start Docker
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl enable docker 2>/dev/null || true
    fi

    # Start Docker
    start_native_docker
}

# Main Docker setup function
install_docker() {
    log_info "Checking Docker installation..."

    # Step 1: Check if Docker is already functional
    if is_docker_functional; then
        log_success "Docker is already running: $(docker --version)"
        fix_docker_credentials
        return 0
    fi

    # Step 2: Docker not running - figure out what we have and start/install it
    case $OS in
        wsl)
            if is_docker_desktop_stub; then
                # Docker Desktop integration exists but not running
                log_info "Docker Desktop WSL2 integration detected"

                # Ask user: start Docker Desktop or install native Docker?
                echo ""
                echo "Docker Desktop is configured but not running."
                echo "Options:"
                echo "  1) Start Docker Desktop on Windows (recommended if installed)"
                echo "  2) Install native Docker in WSL2 (independent of Windows)"
                echo ""
                read -p "Choose option [1/2]: " docker_choice

                case $docker_choice in
                    2)
                        log_info "Installing native Docker in WSL2..."
                        install_native_docker
                        ;;
                    *)
                        wait_for_docker_desktop 120
                        ;;
                esac
            elif is_native_docker_installed; then
                # Native Docker installed but not running
                log_info "Native Docker found but not running"
                start_native_docker
            else
                # No Docker at all - install native Docker
                log_info "No Docker installation found"
                install_native_docker
            fi
            ;;

        linux)
            if is_native_docker_installed; then
                # Docker installed but not running
                log_info "Docker found but not running"
                start_native_docker
            else
                # No Docker - install it
                log_info "No Docker installation found"
                install_native_docker
            fi
            ;;

        macos)
            if command_exists docker; then
                # Docker Desktop installed but not running
                log_info "Docker Desktop found but not running"
                wait_for_docker_desktop 120
            else
                # No Docker - must install Docker Desktop manually
                log_warning "Docker Desktop not found"
                log_warning "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
                log_warning "Press Enter after Docker Desktop is installed..."
                read
                wait_for_docker_desktop 120
            fi
            ;;
    esac
    
    # Verify Docker
    if docker ps >/dev/null 2>&1; then
        log_success "Docker installed and running"
    else
        log_error "Docker installation failed or not running"
        exit 1
    fi
}

# Install kubectl
install_kubectl() {
    log_info "Checking kubectl installation..."

    if command_exists kubectl; then
        log_success "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        return 0
    fi

    log_info "Installing kubectl..."

    case $OS in
        linux|wsl)
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm kubectl
            ;;
        macos)
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/${ARCH}/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/kubectl
            ;;
    esac

    log_success "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# Install minikube
install_minikube() {
    log_info "Checking minikube installation..."

    if command_exists minikube; then
        log_success "minikube already installed: $(minikube version --short)"
        return 0
    fi

    log_info "Installing minikube..."

    case $OS in
        linux|wsl)
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${ARCH}
            sudo install minikube-linux-${ARCH} /usr/local/bin/minikube
            rm minikube-linux-${ARCH}
            ;;
        macos)
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-${ARCH}
            sudo install minikube-darwin-${ARCH} /usr/local/bin/minikube
            rm minikube-darwin-${ARCH}
            ;;
    esac

    log_success "minikube installed: $(minikube version --short)"
}

# Install PHP
install_php() {
    log_info "Checking PHP installation..."

    if command_exists php; then
        log_success "PHP already installed: $(php --version | head -n1)"
        return 0
    fi

    log_info "Installing PHP..."

    case $OS in
        linux|wsl)
            sudo apt-get update
            sudo apt-get install -y php php-cli php-curl php-mbstring php-xml
            ;;
        macos)
            ensure_homebrew
            brew install php
            ;;
    esac

    log_success "PHP installed: $(php --version | head -n1)"
}

# Install Git
install_git() {
    log_info "Checking Git installation..."

    if command_exists git; then
        log_success "Git already installed: $(git --version)"
        return 0
    fi

    log_info "Installing Git..."

    case $OS in
        linux|wsl)
            sudo apt-get update
            sudo apt-get install -y git
            ;;
        macos)
            ensure_homebrew
            brew install git
            ;;
    esac

    log_success "Git installed: $(git --version)"
}

# Check for corrupted minikube installation
check_minikube_health() {
    log_info "Checking for existing minikube installation..."

    # Check if minikube profile exists
    if ! minikube profile list 2>/dev/null | grep -q "minikube"; then
        log_info "No existing minikube profile found (fresh install)"
        return 0
    fi

    # Profile exists, check if it's healthy
    if minikube status 2>&1 | grep -q "host: Running"; then
        log_success "Existing minikube cluster is healthy"
        return 0
    fi

    # Profile exists but not healthy - check for common issues
    log_warning "Found existing minikube profile that may be corrupted"

    # Check if Docker daemon is accessible
    if ! docker ps >/dev/null 2>&1; then
        log_error "Docker daemon is not accessible - cannot check minikube"
        return 1
    fi

    # Check if minikube container exists but is broken
    if docker ps -a | grep -q minikube; then
        log_warning "Found minikube container. Checking Kubernetes health..."

        # Try to get cluster info (will fail if Kubernetes is broken)
        if ! kubectl cluster-info 2>&1 | grep -q "Kubernetes control plane is running"; then
            log_error "Minikube container exists but Kubernetes is not responding"
            log_warning "This usually indicates a corrupted installation"

            echo ""
            read -p "Delete and recreate minikube cluster? [Y/n]: " DELETE_MINIKUBE
            if [[ "$DELETE_MINIKUBE" =~ ^[Yy]?$ ]]; then
                log_info "Deleting corrupted minikube installation..."
                minikube delete --all --purge
                rm -rf ~/.minikube ~/.kube/config 2>/dev/null || true
                log_success "Corrupted installation cleaned up"
                return 0
            else
                log_error "Cannot proceed with corrupted minikube installation"
                return 1
            fi
        fi
    fi

    return 0
}

# Start minikube with retry logic
start_minikube() {
    log_info "Starting minikube cluster..."

    # Ensure Docker is running first
    if ! docker ps >/dev/null 2>&1; then
        log_error "Docker daemon is not running. Please start Docker first."
        return 1
    fi

    # Check for corrupted installations
    check_minikube_health || return 1

    # Check if minikube is already running
    if minikube status 2>&1 | grep -q "host: Running"; then
        log_success "minikube is already running"

        # Verify Kubernetes is actually working
        if kubectl cluster-info 2>&1 | grep -q "Kubernetes control plane is running"; then
            log_success "Kubernetes cluster is healthy"
        else
            log_warning "Minikube running but Kubernetes is unhealthy. Restarting..."
            minikube stop
            sleep 3
        fi
    fi

    # Start minikube with appropriate settings
    if ! minikube status 2>&1 | grep -q "host: Running"; then
        log_info "Starting minikube (this may take a few minutes)..."

        # Try to start minikube
        if ! minikube start --driver=docker --memory=4096 --cpus=2 --container-runtime=docker; then
            log_error "minikube start failed"
            log_warning "Attempting recovery: deleting and recreating cluster..."
            minikube delete --all --purge 2>/dev/null || true
            rm -rf ~/.minikube 2>/dev/null || true
            sleep 3

            # Retry with clean state
            if ! minikube start --driver=docker --memory=4096 --cpus=2 --container-runtime=docker; then
                log_error "minikube start failed after retry"
                return 1
            fi
        fi

        # Wait a bit for Kubernetes to stabilize
        log_info "Waiting for Kubernetes to stabilize..."
        sleep 10

        # Verify cluster is actually working
        local max_retries=12
        local retry=0
        while [ $retry -lt $max_retries ]; do
            if kubectl cluster-info 2>&1 | grep -q "Kubernetes control plane is running"; then
                log_success "Kubernetes cluster is ready"
                break
            fi
            if [ $retry -eq $((max_retries - 1)) ]; then
                log_error "Kubernetes failed to become ready after minikube start"
                log_info "This may indicate Docker Desktop compatibility issues"
                return 1
            fi
            echo -n "."
            sleep 5
            retry=$((retry + 1))
        done
    fi

    # Enable registry addon
    log_info "Enabling minikube registry addon..."
    minikube addons enable registry 2>/dev/null || log_warning "Registry addon may already be enabled"

    # Enable ingress addon (optional, for exposing services)
    log_info "Enabling minikube ingress addon..."
    minikube addons enable ingress 2>/dev/null || log_warning "Ingress addon may already be enabled"

    log_success "minikube cluster started successfully"

    # Display cluster info
    log_info "Cluster information:"
    kubectl cluster-info
    kubectl get nodes
}

# Jenkins deployment moved to separate script: deploy-jenkins.sh
# This keeps 1-infra-setup.sh focused on infrastructure tools only

# Validation
validate_installation() {
    log_info "Validating installation..."
    
    local all_ok=true
    
    # Check Docker
    if docker ps >/dev/null 2>&1; then
        log_success "✓ Docker is running"
    else
        log_error "✗ Docker is not running"
        all_ok=false
    fi
    
    # Check kubectl
    if command_exists kubectl; then
        log_success "✓ kubectl is installed"
    else
        log_error "✗ kubectl is not installed"
        all_ok=false
    fi
    
    # Check minikube
    if minikube status | grep -q "host: Running"; then
        log_success "✓ minikube is running"
    else
        log_error "✗ minikube is not running"
        all_ok=false
    fi
    
    # Check Jenkins
    if docker ps --filter "name=jenkins" --format "{{.Names}}" | grep -q "^jenkins$"; then
        # Container exists, now verify it's actually healthy
        log_info "Checking Jenkins health..."
        sleep 2  # Give Jenkins a moment
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "403" ]]; then
            log_success "✓ Jenkins is running and responding (HTTP $HTTP_CODE)"
        else
            log_error "✗ Jenkins container exists but not responding (HTTP $HTTP_CODE)"
            log_info "Check logs: docker logs jenkins"
            all_ok=false
        fi
    else
        log_error "✗ Jenkins container is not running"
        log_info "Run: docker ps -a | grep jenkins"
        all_ok=false
    fi

    # Check GitLab (optional component)
    if docker ps --filter "name=gitlab" --format "{{.Names}}" | grep -q "^gitlab$"; then
        log_info "Checking GitLab health..."
        sleep 2
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            http://localhost:8090/-/health 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" == "200" ]]; then
            log_success "✓ GitLab is running and healthy (HTTP $HTTP_CODE)"

            # Verify Jenkins can reach GitLab (if both exist)
            if docker ps --filter "name=jenkins" --format "{{.Names}}" | grep -q "^jenkins$"; then
                if docker exec jenkins curl -s http://gitlab:8090/-/health >/dev/null 2>&1; then
                    log_success "✓ Jenkins → GitLab connectivity verified"
                else
                    log_warning "⚠ Jenkins cannot reach GitLab (network issue)"
                    log_info "  Run: docker network inspect gitlab-jenkins-network"
                fi
            fi
        else
            log_warning "✓ GitLab container exists but still initializing (HTTP $HTTP_CODE)"
            log_info "  GitLab may take up to 5 minutes to fully start"
            log_info "  Check with: curl http://localhost:8090/-/health"
        fi
    else
        log_info "○ GitLab not deployed (will use external GitLab)"
    fi

    # Check PHP
    if command_exists php; then
        log_success "✓ PHP is installed"
    else
        log_error "✗ PHP is not installed"
        all_ok=false
    fi
    
    # Check Git
    if command_exists git; then
        log_success "✓ Git is installed"
    else
        log_error "✗ Git is not installed"
        all_ok=false
    fi
    
    if [[ "$all_ok" == true ]]; then
        log_success "All tools installed and running!"
        return 0
    else
        log_error "Some tools failed to install. Please check the errors above."
        return 1
    fi
}

# Save environment info
save_env_info() {
    log_info "Saving environment information..."

    GITLAB_STATUS="not-deployed"
    if docker ps | grep -q gitlab; then
        GITLAB_STATUS="http://localhost:8090"
    fi

    cat > .env.interview << EOF
# DevOps Interview Environment Info
# Generated: $(date)

MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "not-started")
JENKINS_URL=http://localhost:8080
GITLAB_URL=${GITLAB_STATUS}

# Docker Configuration:
# - Jenkins and GitLab run in HOST Docker
# - App images built in minikube Docker (via: eval \$(minikube docker-env))
# - Custom network: gitlab-jenkins-network (Jenkins → GitLab communication)

# GitLab Access:
# - Browser: http://localhost:8090
# - Jenkins: http://gitlab:8090 (container name DNS)
# - Credentials: root / interview2024

# Minikube registry:
# REGISTRY=localhost:5000

# To switch back to host Docker (if needed):
# eval \$(minikube docker-env --unset)
EOF

    log_success "Environment info saved to .env.interview"
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  DevOps Interview Toolkit - Setup"
    echo "=========================================="
    echo ""
    
    detect_os
    echo ""

    # Install all tools (Docker is handled first as other tools depend on it)
    install_docker
    install_kubectl
    install_minikube
    install_php
    install_git
    
    echo ""

    # Start infrastructure
    start_minikube

    echo ""

    # Deploy GitLab FIRST (takes 3-5 min - do it early!)
    log_info "Deploying GitLab CE (initialization takes 3-5 minutes)..."
    if ! bash "$(dirname "${BASH_SOURCE[0]}")/gitlab-init-scripts/deploy-gitlab.sh"; then
        log_error "GitLab deployment failed!"
        log_info "You can skip GitLab and use external GitLab server instead."
        read -p "Continue without GitLab? [Y/n]: " SKIP_GITLAB
        if [[ ! "$SKIP_GITLAB" =~ ^[Yy]?$ ]]; then
            exit 1
        fi
        GITLAB_DEPLOYED=false
    else
        GITLAB_DEPLOYED=true
    fi

    echo ""

    # Deploy Jenkins using separate script
    # Jenkins runs in HOST Docker (not minikube's Docker)
    log_info "Running Jenkins deployment script..."
    if ! bash "$(dirname "${BASH_SOURCE[0]}")/jenkins-init-scripts/deploy-jenkins.sh"; then
        log_error "Jenkins deployment failed! Setup cannot continue."
        log_info "Please check the errors above and retry."
        exit 1
    fi

    # Create network bridge for GitLab <-> Jenkins (if both exist)
    if [[ "$GITLAB_DEPLOYED" == "true" ]]; then
        echo ""
        log_info "Connecting Jenkins and GitLab containers..."
        docker network create gitlab-jenkins-network 2>/dev/null || true
        docker network connect gitlab-jenkins-network gitlab 2>/dev/null || true
        docker network connect gitlab-jenkins-network jenkins 2>/dev/null || true

        # Verify connectivity
        sleep 2
        if docker exec jenkins curl -s http://gitlab:8090/-/health >/dev/null 2>&1; then
            log_success "Jenkins can reach GitLab at http://gitlab:8090"
        else
            log_warning "Jenkins → GitLab connectivity check failed (may need time)"
            log_info "Connectivity will be tested again during validation"
        fi
    fi

    echo ""

    # Validate
    validate_installation

    # Now that Jenkins is validated and running in host Docker,
    # configure shell to use minikube's Docker for building app images
    log_info "Configuring Docker environment to use minikube's Docker daemon..."
    eval $(minikube docker-env)
    log_success "Docker environment configured for minikube"
    log_info "All future docker commands will use minikube's Docker daemon"
    log_info "Jenkins remains accessible in host Docker at localhost:8080"

    # Save env info
    save_env_info
    
    echo ""
    log_success "=========================================="
    log_success "  Setup Complete!"
    log_success "=========================================="
    echo ""

    echo "Next steps:"
    if [[ "$GITLAB_DEPLOYED" == "true" ]]; then
        echo "1. Access GitLab at http://localhost:8090 (root / interview2024)"
        echo "2. Create a new project in GitLab (see WORKFLOWS.md)"
        echo "3. Access Jenkins at http://localhost:8080 (admin / admin)"
        echo "4. Clone or initialize your Git repository"
        echo "5. Run: ./2-generate-project.sh (generates Jenkinsfile, Dockerfile, K8s manifests)"
        echo "6. Push to GitLab - Jenkins will auto-build when changes are detected"
    else
        echo "1. Access Jenkins at http://localhost:8080 (admin / admin)"
        echo "2. Clone your Git repository (from external GitLab)"
        echo "3. Run: ./2-generate-project.sh (generates Jenkinsfile, Dockerfile, K8s manifests)"
        echo "4. Script will prompt to auto-create Jenkins pipeline job"
        echo "5. Push generated files to your repository"
        echo "6. Jenkins will auto-build when changes are detected"
    fi
    echo ""
    echo "Useful commands:"
    echo "  minikube status                  - Check cluster status"
    echo "  kubectl get pods                 - List pods"
    echo "  docker ps                        - List containers (minikube Docker)"
    echo "  docker build -t myapp:latest .   - Build images in minikube"
    echo ""
    echo "Important:"
    echo "  • Jenkins runs in HOST Docker (accessible at localhost:8080)"
    echo "  • Your shell is now configured to use minikube's Docker for building app images"
    echo "  • Images built with 'docker build' will be available to Kubernetes"
    echo ""
}

# Run main
main
