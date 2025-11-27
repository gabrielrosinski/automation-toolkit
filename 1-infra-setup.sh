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

# Ensure Docker daemon is running
ensure_docker_running() {
    log_info "Checking Docker daemon status..."

    # Try to ping Docker daemon
    if docker ps >/dev/null 2>&1; then
        log_success "Docker daemon is running"
        # Fix credential helper if needed
        fix_docker_credentials
        return 0
    fi

    log_warning "Docker daemon is not running. Attempting to start..."

    case $OS in
        wsl)
            sudo service docker start
            sleep 3
            ;;
        linux)
            sudo systemctl start docker
            sleep 3
            ;;
        macos)
            log_warning "Please start Docker Desktop manually"
            log_info "Waiting for Docker Desktop to start..."
            for i in {1..30}; do
                if docker ps >/dev/null 2>&1; then
                    log_success "Docker Desktop is now running"
                    return 0
                fi
                echo -n "."
                sleep 2
            done
            log_error "Docker Desktop did not start within 60 seconds"
            return 1
            ;;
    esac

    # Verify Docker started
    if docker ps >/dev/null 2>&1; then
        log_success "Docker daemon started successfully"
        # Fix credential helper if needed
        fix_docker_credentials
        return 0
    else
        log_error "Failed to start Docker daemon"
        return 1
    fi
}

# Install Docker
install_docker() {
    log_info "Checking Docker installation..."

    if command_exists docker; then
        log_success "Docker already installed: $(docker --version)"
        # Even if installed, ensure daemon is running
        ensure_docker_running
        return 0
    fi

    log_info "Installing Docker..."
    
    case $OS in
        linux|wsl)
            # Install Docker on Linux/WSL
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            rm get-docker.sh
            
            # Start Docker service
            if [[ $OS == "wsl" ]]; then
                sudo service docker start
            else
                sudo systemctl start docker
                sudo systemctl enable docker
            fi
            ;;
        macos)
            log_warning "Please install Docker Desktop manually from: https://www.docker.com/products/docker-desktop"
            log_warning "Press Enter after Docker Desktop is installed and running..."
            read
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
            minikube delete
            sleep 3

            # Retry with force flag
            if ! minikube start --driver=docker --memory=4096 --cpus=2 --container-runtime=docker --force; then
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
    
    cat > .env.interview << EOF
# DevOps Interview Environment Info
# Generated: $(date)

MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "not-started")
JENKINS_URL=http://localhost:8080

# Docker is configured to use minikube's Docker daemon
# This was done automatically during setup with: eval \$(minikube docker-env)
# Jenkins runs in HOST Docker and remains accessible at localhost:8080

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
    
    # Install all tools
    install_docker
    install_kubectl
    install_minikube
    install_php
    install_git
    
    echo ""
    
    # Start infrastructure
    start_minikube

    # Deploy Jenkins using separate script
    # Jenkins runs in HOST Docker (not minikube's Docker)
    log_info "Running Jenkins deployment script..."
    if ! bash "$(dirname "${BASH_SOURCE[0]}")/deploy-jenkins.sh"; then
        log_error "Jenkins deployment failed! Setup cannot continue."
        log_info "Please check the errors above and retry."
        exit 1
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
    echo "1. Access Jenkins (see credentials output above)"
    echo "2. Complete Jenkins setup wizard (5 minutes)"
    echo "3. Clone the GitLab repository"
    echo "4. Run: ./2-generate-project.sh"
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
