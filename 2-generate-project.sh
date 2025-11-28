#!/bin/bash

###############################################################################
# DevOps Interview Toolkit - Project Generator
# Interactive template generator for Dockerfile, Jenkinsfile, K8s manifests
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

# Cross-platform sed in-place editing
# Usage: sed_inplace "pattern" file
sed_inplace() {
    local pattern="$1"
    local file="$2"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS (BSD sed) requires empty string after -i
        sed -i "" "$pattern" "$file"
    else
        # Linux (GNU sed)
        sed -i "$pattern" "$file"
    fi
}

# Input validation functions
validate_k8s_name() {
    local name="$1"
    # K8s naming: lowercase alphanumeric + hyphens, start/end with alphanumeric
    if ! [[ "$name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
        log_error "Invalid name: '$name'"
        log_error "K8s names must be lowercase alphanumeric + hyphens, start/end with alphanumeric"
        return 1
    fi
    return 0
}

validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Invalid port: '$port'. Must be between 1 and 65535"
        return 1
    fi
    return 0
}

validate_url() {
    local url="$1"
    if ! [[ "$url" =~ ^https?:// ]]; then
        log_error "Invalid URL: '$url'. Must start with http:// or https://"
        return 1
    fi
    return 0
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

echo ""
echo "=========================================="
echo "  Project Generator & Configurator"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Generate deployment files (Dockerfile, Jenkinsfile, K8s manifests)"
echo "  2. Optionally deploy to Kubernetes"
echo "  3. Optionally create Jenkins pipeline job"
echo ""
echo "Please provide the following information:"
echo ""

# Prompt for GitLab repository URL
while true; do
    read -p "GitLab repository URL (e.g., https://gitlab.company.local/team/php-app): " GITLAB_URL
    if [[ -z "$GITLAB_URL" ]]; then
        log_error "GitLab URL is required!"
        continue
    fi
    if validate_url "$GITLAB_URL"; then
        break
    fi
done

# Extract repo name from URL
REPO_NAME=$(basename "$GITLAB_URL" .git)
log_info "Repository name: $REPO_NAME"

# Prompt for GitLab credentials
echo ""
log_info "GitLab credentials (for Jenkins CI/CD automation)"
read -p "GitLab username: " GITLAB_USERNAME
if [[ -z "$GITLAB_USERNAME" ]]; then
    log_error "GitLab username is required!"
    exit 1
fi

read -sp "GitLab password or personal access token: " GITLAB_TOKEN
echo ""
if [[ -z "$GITLAB_TOKEN" ]]; then
    log_error "GitLab password/token is required!"
    exit 1
fi

# Auto-detect PHP version from composer.json if available
DEFAULT_PHP="8.1"
if [ -f composer.json ]; then
    log_info "Checking composer.json for PHP version..."
    DETECTED_PHP=$(cat composer.json | grep -o '"php"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -o '[0-9]\.[0-9]' | head -1)
    if [ -n "$DETECTED_PHP" ]; then
        log_success "Detected PHP version from composer.json: $DETECTED_PHP"
        DEFAULT_PHP="$DETECTED_PHP"
    fi
elif [ -f .php-version ]; then
    DETECTED_PHP=$(cat .php-version | grep -o '[0-9]\.[0-9]' | head -1)
    if [ -n "$DETECTED_PHP" ]; then
        log_success "Detected PHP version from .php-version: $DETECTED_PHP"
        DEFAULT_PHP="$DETECTED_PHP"
    fi
fi

# Prompt for PHP version
echo ""
echo "Available PHP versions: 7.4, 8.0, 8.1, 8.2, 8.3"
read -p "PHP version [$DEFAULT_PHP]: " PHP_VERSION
PHP_VERSION=${PHP_VERSION:-$DEFAULT_PHP}

# Prompt for application port
while true; do
    read -p "Application port [80]: " APP_PORT
    APP_PORT=${APP_PORT:-80}
    if validate_port "$APP_PORT"; then
        break
    fi
done

# Prompt for application name (for K8s)
while true; do
    read -p "Application name (for K8s deployment) [$REPO_NAME]: " APP_NAME
    APP_NAME=${APP_NAME:-$REPO_NAME}
    # Convert to lowercase for K8s compliance
    APP_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
    if validate_k8s_name "$APP_NAME"; then
        break
    fi
done

# Prompt for namespace
while true; do
    read -p "Kubernetes namespace [default]: " K8S_NAMESPACE
    K8S_NAMESPACE=${K8S_NAMESPACE:-default}
    if [[ "$K8S_NAMESPACE" == "default" ]] || validate_k8s_name "$K8S_NAMESPACE"; then
        break
    fi
done

# Prompt for Git branch
read -p "Git branch name [main]: " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}

# Docker image name (no registry prefix - we build directly in minikube's Docker)
# When using 'minikube docker-env', images are available to K8s without pushing to a registry
IMAGE_NAME="${APP_NAME}"

echo ""
log_info "Configuration summary:"
echo "  GitLab URL: $GITLAB_URL"
echo "  Git Branch: $GIT_BRANCH"
echo "  PHP Version: $PHP_VERSION"
echo "  App Port: $APP_PORT"
echo "  App Name: $APP_NAME"
echo "  K8s Namespace: $K8S_NAMESPACE"
echo "  Docker Image: $IMAGE_NAME (built in minikube Docker)"
echo ""

read -p "Proceed with generation? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-Y}
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log_warning "Generation cancelled"
    exit 0
fi

echo ""
log_info "Generating deployment files from templates..."

# Create .env.interview file with credentials
log_info "Saving configuration to .env.interview..."
cat > .env.interview <<EOF
# DevOps Interview Configuration
# Generated: $(date)
# WARNING: This file contains sensitive credentials - DO NOT commit to Git!

GITLAB_URL=${GITLAB_URL}
GITLAB_USERNAME=${GITLAB_USERNAME}
GITLAB_TOKEN=${GITLAB_TOKEN}
APP_NAME=${APP_NAME}
APP_PORT=${APP_PORT}
K8S_NAMESPACE=${K8S_NAMESPACE}
GIT_BRANCH=${GIT_BRANCH}
PHP_VERSION=${PHP_VERSION}
DOCKER_REGISTRY=${DOCKER_REGISTRY}
EOF

# Add to .gitignore if not already there
if [ ! -f .gitignore ]; then
    echo ".env.interview" > .gitignore
    log_info "Created .gitignore"
elif ! grep -q ".env.interview" .gitignore 2>/dev/null; then
    echo ".env.interview" >> .gitignore
    log_info "Added .env.interview to .gitignore"
fi

log_success "Configuration saved to .env.interview (git ignored)"

# Verify templates directory exists
if [ ! -d "$TEMPLATES_DIR" ]; then
    log_error "Templates directory not found: $TEMPLATES_DIR"
    exit 1
fi

# Create directories
mkdir -p k8s

# Helper function to process template files
process_template() {
    local template_file="$1"
    local output_file="$2"
    local description="$3"

    if [ ! -f "$template_file" ]; then
        log_error "Template not found: $template_file"
        exit 1
    fi

    log_info "Generating $description from template..."
    cp "$template_file" "$output_file"

    # Replace all placeholders with actual values
    sed_inplace "s|{{APP_NAME}}|${APP_NAME}|g" "$output_file"
    sed_inplace "s|{{IMAGE_NAME}}|${IMAGE_NAME}|g" "$output_file"
    sed_inplace "s|{{APP_PORT}}|${APP_PORT}|g" "$output_file"
    sed_inplace "s|{{K8S_NAMESPACE}}|${K8S_NAMESPACE}|g" "$output_file"
    sed_inplace "s|{{PHP_VERSION}}|${PHP_VERSION}|g" "$output_file"
    sed_inplace "s|{{GIT_REPO}}|${GITLAB_URL}|g" "$output_file"
    sed_inplace "s|{{GIT_BRANCH}}|${GIT_BRANCH}|g" "$output_file"
    sed_inplace "s|{{HEALTH_CHECK_PATH}}|/|g" "$output_file"

    log_success "✓ $description created"
}

# Generate Dockerfile
process_template "$TEMPLATES_DIR/docker/Dockerfile" "Dockerfile" "Dockerfile"

# Generate Jenkinsfile
process_template "$TEMPLATES_DIR/Jenkinsfile" "Jenkinsfile" "Jenkinsfile"

# Generate Kubernetes manifests
process_template "$TEMPLATES_DIR/kubernetes/deployment.yaml" "k8s/deployment.yaml" "Kubernetes deployment"
process_template "$TEMPLATES_DIR/kubernetes/service.yaml" "k8s/service.yaml" "Kubernetes service"

# Generate namespace (if not default)
if [[ "$K8S_NAMESPACE" != "default" ]]; then
    process_template "$TEMPLATES_DIR/kubernetes/namespace.yaml" "k8s/namespace.yaml" "Kubernetes namespace"
fi

# Generate .dockerignore
process_template "$TEMPLATES_DIR/docker/.dockerignore" ".dockerignore" ".dockerignore"

# Generate deployment helper script
log_info "Generating quick deploy script..."
cat > quick-deploy.sh << 'EOF'
#!/bin/bash
# Quick deployment script

set -e

echo "Building Docker image..."
eval $(minikube docker-env)
docker build -t APP_NAME_PLACEHOLDER:latest .

echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/

echo "Waiting for deployment..."
kubectl wait --for=condition=available --timeout=120s deployment/APP_NAME_PLACEHOLDER -n K8S_NAMESPACE_PLACEHOLDER

echo "Deployment complete!"
echo "Access app: minikube service APP_NAME_PLACEHOLDER -n K8S_NAMESPACE_PLACEHOLDER --url"
EOF

sed_inplace "s|APP_NAME_PLACEHOLDER|${APP_NAME}|g" quick-deploy.sh
sed_inplace "s|K8S_NAMESPACE_PLACEHOLDER|${K8S_NAMESPACE}|g" quick-deploy.sh
chmod +x quick-deploy.sh

log_success "✓ quick-deploy.sh created"

echo ""
log_success "=========================================="
log_success "  Generation Complete!"
log_success "=========================================="
echo ""
echo "Generated files:"
echo "  ✓ Dockerfile"
echo "  ✓ Jenkinsfile"
echo "  ✓ k8s/deployment.yaml"
echo "  ✓ k8s/service.yaml"
if [[ "$K8S_NAMESPACE" != "default" ]]; then
    echo "  ✓ k8s/namespace.yaml"
fi
echo "  ✓ .dockerignore"
echo "  ✓ quick-deploy.sh"
echo "  ✓ .env.interview (credentials - git ignored)"
echo ""

# Optional: Create Jenkins job FIRST (before switching Docker context)
echo "=========================================="
read -p "Create Jenkins pipeline job now? [Y/n]: " CREATE_JENKINS
CREATE_JENKINS=${CREATE_JENKINS:-Y}

if [[ "$CREATE_JENKINS" =~ ^[Yy]$ ]]; then
    log_info "Creating Jenkins pipeline job..."

    if [ -f "${SCRIPT_DIR}/helpers/create-jenkins-job.sh" ]; then
        "${SCRIPT_DIR}/helpers/create-jenkins-job.sh" "$APP_NAME" "$GITLAB_URL" "$GIT_BRANCH" "$K8S_NAMESPACE"
    else
        log_error "Helper script not found: ${SCRIPT_DIR}/helpers/create-jenkins-job.sh"
        log_info "You can create the job manually using: http://localhost:8080"
    fi
else
    echo ""
    log_info "Skipped Jenkins job creation"
    log_info "Create it later with:"
    echo "  ${SCRIPT_DIR}/helpers/create-jenkins-job.sh \"$APP_NAME\" \"$GITLAB_URL\" \"$GIT_BRANCH\" \"$K8S_NAMESPACE\""
fi

# Optional: Deploy to Kubernetes (after Jenkins job creation)
echo ""
echo "=========================================="
read -p "Deploy to Kubernetes now? [Y/n]: " DEPLOY_NOW
DEPLOY_NOW=${DEPLOY_NOW:-Y}

if [[ "$DEPLOY_NOW" =~ ^[Yy]$ ]]; then
    log_info "Deploying to Kubernetes..."

    # Use minikube's Docker daemon
    eval $(minikube docker-env)

    # Build Docker image
    log_info "Building Docker image: ${APP_NAME}:latest..."
    if docker build -t ${APP_NAME}:latest .; then
        log_success "Docker image built successfully"
    else
        log_error "Docker build failed!"
        exit 1
    fi

    # Create namespace if needed
    if [[ "$K8S_NAMESPACE" != "default" ]]; then
        log_info "Creating namespace: ${K8S_NAMESPACE}..."
        kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
    fi

    # Apply K8s manifests
    log_info "Applying Kubernetes manifests..."
    if kubectl apply -f k8s/ -n ${K8S_NAMESPACE}; then
        log_success "Manifests applied successfully"
    else
        log_error "kubectl apply failed!"
        exit 1
    fi

    # Wait for deployment to be ready
    log_info "Waiting for deployment to be ready (max 120s)..."
    if kubectl wait --for=condition=available --timeout=120s deployment/${APP_NAME} -n ${K8S_NAMESPACE} >/dev/null 2>&1; then
        log_success "Deployment is ready!"

        # Get service URL
        SERVICE_URL=$(minikube service ${APP_NAME} -n ${K8S_NAMESPACE} --url 2>/dev/null)
        echo ""
        echo "=========================================="
        log_success "Application deployed successfully!"
        echo "=========================================="
        echo "URL: ${SERVICE_URL}"
        echo ""
        echo "Test it: curl ${SERVICE_URL}"
        echo "=========================================="
        echo ""
    else
        log_warning "Deployment is taking longer than expected"
        log_info "Check status with: kubectl get pods -n ${K8S_NAMESPACE}"
    fi
fi

echo ""
echo "=========================================="
log_success "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Fix PHP bugs in your code"
echo "2. Commit and push to GitLab:"
echo "   git add ."
echo "   git commit -m 'Fix PHP bugs and add CI/CD'"
echo "   git push origin ${GIT_BRANCH}"
echo "3. Jenkins will auto-trigger and deploy"
if [[ ! "$CREATE_JENKINS" =~ ^[Yy]$ ]]; then
    echo "4. Or create Jenkins job manually: ${SCRIPT_DIR}/helpers/create-jenkins-job.sh"
fi
echo ""
