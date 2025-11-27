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

# Docker registry (minikube local)
DOCKER_REGISTRY="localhost:5000"

echo ""
log_info "Configuration summary:"
echo "  GitLab URL: $GITLAB_URL"
echo "  Git Branch: $GIT_BRANCH"
echo "  PHP Version: $PHP_VERSION"
echo "  App Port: $APP_PORT"
echo "  App Name: $APP_NAME"
echo "  K8s Namespace: $K8S_NAMESPACE"
echo "  Docker Registry: $DOCKER_REGISTRY"
echo ""

read -p "Proceed with generation? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-Y}
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    log_warning "Generation cancelled"
    exit 0
fi

echo ""
log_info "Generating deployment files..."

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

# Create directories
mkdir -p k8s

# Generate Dockerfile
log_info "Generating Dockerfile..."
cat > Dockerfile << EOF
# Multi-stage build for PHP application
FROM php:${PHP_VERSION}-apache as base

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    git \\
    curl \\
    libpng-dev \\
    libonig-dev \\
    libxml2-dev \\
    zip \\
    unzip \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Set working directory
WORKDIR /var/www/html

# Copy application code
COPY . /var/www/html/

# Set permissions
RUN chown -R www-data:www-data /var/www/html \\
    && chmod -R 755 /var/www/html

# Expose port
EXPOSE ${APP_PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \\
    CMD curl -f http://localhost:${APP_PORT}/ || exit 1

# Start Apache
CMD ["apache2-foreground"]
EOF

log_success "✓ Dockerfile created"

# Generate Jenkinsfile
log_info "Generating Jenkinsfile..."
cat > Jenkinsfile << 'JENKINSFILE_END'
pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = 'localhost:5000'
        IMAGE_NAME = 'APP_NAME_PLACEHOLDER'
        IMAGE_TAG = "${BUILD_NUMBER}"
        GIT_REPO = 'GITLAB_URL_PLACEHOLDER'
        K8S_NAMESPACE = 'K8S_NAMESPACE_PLACEHOLDER'
    }

    stages {
        stage('Pre-Flight Check') {
            steps {
                script {
                    echo "=========================================="
                    echo "Pre-Flight Environment Validation"
                    echo "=========================================="

                    sh '''
                        # Verify Docker access
                        echo "Checking Docker access..."
                        if ! docker version >/dev/null 2>&1; then
                            echo "ERROR: Docker is not accessible"
                            exit 1
                        fi
                        echo "✓ Docker is accessible"

                        # Verify kubectl access
                        echo "Checking kubectl access..."
                        if ! kubectl cluster-info >/dev/null 2>&1; then
                            echo "ERROR: kubectl is not configured"
                            exit 1
                        fi
                        echo "✓ kubectl is configured"

                        # Create namespace if needed
                        echo "Checking namespace: ${K8S_NAMESPACE}..."
                        if ! kubectl get namespace ${K8S_NAMESPACE} >/dev/null 2>&1; then
                            echo "Creating namespace: ${K8S_NAMESPACE}"
                            kubectl create namespace ${K8S_NAMESPACE}
                        fi
                        echo "✓ Namespace ${K8S_NAMESPACE} exists"

                        # Verify registry access (optional)
                        echo "Checking registry access..."
                        curl -f http://${DOCKER_REGISTRY}/v2/ >/dev/null 2>&1 || \
                            echo "WARNING: Registry may not be accessible (non-critical)"

                        echo "=========================================="
                        echo "✓ Pre-flight checks passed"
                        echo "=========================================="
                    '''
                }
            }
        }

        stage('Checkout') {
            steps {
                echo "Cloning repository from GitLab..."
                git branch: 'GIT_BRANCH_PLACEHOLDER',
                    url: "${GIT_REPO}"
            }
        }
        
        stage('PHP Syntax Check') {
            steps {
                echo "Running PHP syntax check..."
                script {
                    sh '''
                        # Check all PHP files for syntax errors
                        echo "Checking PHP syntax..."
                        ERROR_COUNT=0
                        while IFS= read -r file; do
                            if ! php -l "$file" > /dev/null 2>&1; then
                                echo "ERROR: Syntax error in $file"
                                php -l "$file"
                                ERROR_COUNT=$((ERROR_COUNT + 1))
                            fi
                        done < <(find . -name "*.php" -not -path "./vendor/*")

                        if [ $ERROR_COUNT -gt 0 ]; then
                            echo "Found $ERROR_COUNT file(s) with syntax errors"
                            exit 1
                        else
                            echo "All PHP files passed syntax check"
                        fi
                    '''
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo "Building Docker image..."
                script {
                    sh """
                        docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest
                    """
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                echo "Pushing image to registry..."
                script {
                    sh """
                        # Push to minikube local registry
                        docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest
                    """
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                echo "Deploying to Kubernetes..."
                script {
                    sh """
                        # Update deployment image
                        kubectl set image deployment/${IMAGE_NAME} \\
                            ${IMAGE_NAME}=${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} \\
                            -n ${K8S_NAMESPACE} || \\
                        kubectl apply -f k8s/ -n ${K8S_NAMESPACE}
                    """
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo "Verifying deployment..."
                script {
                    sh """
                        kubectl rollout status deployment/${IMAGE_NAME} -n ${K8S_NAMESPACE}
                        kubectl get pods -n ${K8S_NAMESPACE} -l app=${IMAGE_NAME}
                        kubectl get svc -n ${K8S_NAMESPACE} -l app=${IMAGE_NAME}
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ Pipeline succeeded!'
            script {
                sh """
                    echo "Application deployed successfully!"
                    echo "Access via: minikube service ${IMAGE_NAME} -n ${K8S_NAMESPACE} --url"
                """
            }
        }
        failure {
            echo '❌ Pipeline failed!'
            script {
                sh '''
                    echo "Debug information:"
                    docker ps -a || true
                    kubectl get pods -n ${K8S_NAMESPACE} || true
                    kubectl describe pods -n ${K8S_NAMESPACE} || true
                '''
            }
        }
        always {
            echo 'Cleaning up...'
            sh 'docker system prune -f || true'
        }
    }
}
JENKINSFILE_END

# Replace placeholders
sed_inplace "s|APP_NAME_PLACEHOLDER|${APP_NAME}|g" Jenkinsfile
sed_inplace "s|GITLAB_URL_PLACEHOLDER|${GITLAB_URL}|g" Jenkinsfile
sed_inplace "s|K8S_NAMESPACE_PLACEHOLDER|${K8S_NAMESPACE}|g" Jenkinsfile
sed_inplace "s|GIT_BRANCH_PLACEHOLDER|${GIT_BRANCH}|g" Jenkinsfile

log_success "✓ Jenkinsfile created"

# Generate Kubernetes Deployment
log_info "Generating Kubernetes deployment..."
cat > k8s/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${K8S_NAMESPACE}
  labels:
    app: ${APP_NAME}
  annotations:
    description: "PHP application deployed via Jenkins CI/CD"
    version: "latest"
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 33  # www-data
        fsGroup: 33
      containers:
      - name: ${APP_NAME}
        image: ${DOCKER_REGISTRY}/${APP_NAME}:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: ${APP_PORT}
          name: http
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          readOnlyRootFilesystem: false  # PHP needs write access to /tmp
        startupProbe:
          httpGet:
            path: /
            port: ${APP_PORT}
          failureThreshold: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: ${APP_PORT}
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: ${APP_PORT}
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
EOF

log_success "✓ k8s/deployment.yaml created (with security best practices)"

# Generate Kubernetes Service
log_info "Generating Kubernetes service..."
cat > k8s/service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
  namespace: ${K8S_NAMESPACE}
  labels:
    app: ${APP_NAME}
spec:
  type: NodePort
  selector:
    app: ${APP_NAME}
  ports:
  - port: ${APP_PORT}
    targetPort: ${APP_PORT}
    protocol: TCP
    name: http
EOF

log_success "✓ k8s/service.yaml created"

# Generate namespace (if not default)
if [[ "$K8S_NAMESPACE" != "default" ]]; then
    log_info "Generating Kubernetes namespace..."
    cat > k8s/namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${K8S_NAMESPACE}
EOF
    log_success "✓ k8s/namespace.yaml created"
fi

# Generate .dockerignore
log_info "Generating .dockerignore..."
cat > .dockerignore << EOF
.git
.gitignore
README.md
Jenkinsfile
k8s/
*.md
.env
.env.*
EOF

log_success "✓ .dockerignore created"

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

# Optional: Deploy to Kubernetes now
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

# Optional: Create Jenkins job
echo ""
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
