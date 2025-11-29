#!/bin/bash

###############################################################################
# Jenkins Job Auto-Creation Helper
# Automates GitLab credentials and pipeline job creation in Jenkins
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check parameters
if [ $# -lt 4 ]; then
    log_error "Usage: $0 <app-name> <gitlab-url> <git-branch> <k8s-namespace>"
    exit 1
fi

APP_NAME="$1"
GITLAB_URL="$2"
GIT_BRANCH="$3"
K8S_NAMESPACE="$4"

# Load credentials from .env.interview
if [ ! -f .env.interview ]; then
    log_error ".env.interview file not found. Run 2-generate-and-configure.sh first."
    exit 1
fi

source .env.interview

# Translate GitLab URL for Jenkins (localhost:8090 → gitlab:80)
# Note: Host uses port 8090, but GitLab container listens on port 80 internally
if [[ "$GITLAB_URL" =~ localhost:8090 ]]; then
    JENKINS_GITLAB_URL=$(echo "$GITLAB_URL" | sed 's|localhost:8090|gitlab:80|g')
    log_info "Translated GitLab URL for Jenkins: $JENKINS_GITLAB_URL"
else
    # External GitLab - no translation needed
    JENKINS_GITLAB_URL="$GITLAB_URL"
fi

log_info "User GitLab URL: $GITLAB_URL"
log_info "Jenkins GitLab URL: $JENKINS_GITLAB_URL"

# Verify Jenkins is running (in HOST Docker, not minikube)
log_info "Checking Jenkins status..."

# Temporarily unset minikube docker-env to check host Docker
unset DOCKER_TLS_VERIFY DOCKER_HOST DOCKER_CERT_PATH MINIKUBE_ACTIVE_DOCKERD

if ! docker ps | grep -q jenkins; then
    log_error "Jenkins container is not running. Start it with ./1-infra-setup.sh"
    exit 1
fi

# Wait for Jenkins to be ready
wait_for_jenkins() {
    log_info "Waiting for Jenkins to be ready..."
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:8080/login >/dev/null 2>&1; then
            log_success "Jenkins is ready"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    log_error "Jenkins failed to respond within 60 seconds"
    return 1
}

# Download Jenkins CLI jar if not exists
download_jenkins_cli() {
    log_info "Downloading Jenkins CLI..."
    docker exec jenkins bash -c "
        if [ ! -f /var/jenkins_home/jenkins-cli.jar ]; then
            curl -s http://localhost:8080/jnlpJars/jenkins-cli.jar -o /var/jenkins_home/jenkins-cli.jar
        fi
    " >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        log_success "Jenkins CLI ready"
        return 0
    else
        log_error "Failed to download Jenkins CLI"
        return 1
    fi
}

wait_for_jenkins || exit 1
download_jenkins_cli || exit 1

# Step 1: Create GitLab credentials in Jenkins
create_jenkins_credentials() {
    log_info "Creating GitLab credentials in Jenkins..."

    cat > /tmp/gitlab-creds.xml <<EOF
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>gitlab-creds</id>
  <description>GitLab Credentials - Auto-Generated</description>
  <username>${GITLAB_USERNAME}</username>
  <password>${GITLAB_TOKEN}</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF

    # Copy XML to Jenkins container
    docker cp /tmp/gitlab-creds.xml jenkins:/tmp/gitlab-creds.xml

    # Create credentials via Jenkins CLI
    docker exec jenkins java -jar /var/jenkins_home/jenkins-cli.jar \
        -s http://localhost:8080/ \
        -auth admin:admin \
        create-credentials-by-xml system::system::jenkins _ \
        < /tmp/gitlab-creds.xml 2>/dev/null

    local exit_code=$?
    rm /tmp/gitlab-creds.xml

    if [ $exit_code -eq 0 ]; then
        log_success "GitLab credentials created in Jenkins"
    else
        log_warning "Credentials may already exist (this is OK)"
    fi
}

# Step 2: Create Pipeline job
create_pipeline_job() {
    log_info "Creating Jenkins pipeline job: ${APP_NAME}-pipeline..."

    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    TEMPLATE_FILE="${SCRIPT_DIR}/jenkins-init-scripts/pipeline-job-template.xml"

    if [ ! -f "$TEMPLATE_FILE" ]; then
        log_error "Template file not found: $TEMPLATE_FILE"
        return 1
    fi

    # Process template with variable substitution
    # Use translated URL for Jenkins (gitlab:80 instead of localhost:8090)
    cat "$TEMPLATE_FILE" | \
        sed "s|{{APP_NAME}}|${APP_NAME}|g" | \
        sed "s|{{GITLAB_URL}}|${JENKINS_GITLAB_URL}|g" | \
        sed "s|{{GIT_BRANCH}}|${GIT_BRANCH}|g" \
        > /tmp/pipeline-config.xml

    # Copy XML to Jenkins container
    docker cp /tmp/pipeline-config.xml jenkins:/tmp/pipeline-config.xml

    # Create job via Jenkins CLI (run command inside container to access file)
    docker exec jenkins bash -c "java -jar /var/jenkins_home/jenkins-cli.jar \
        -s http://localhost:8080/ \
        -auth admin:admin \
        create-job ${APP_NAME}-pipeline \
        < /tmp/pipeline-config.xml"

    local exit_code=$?
    rm /tmp/pipeline-config.xml

    if [ $exit_code -eq 0 ]; then
        log_success "Pipeline job created successfully!"
        echo ""
        echo "View job at: http://localhost:8080/job/${APP_NAME}-pipeline/"
        echo "Build now:   http://localhost:8080/job/${APP_NAME}-pipeline/build"
        echo ""
    else
        log_error "Failed to create pipeline job"
        log_info "Check if job exists: http://localhost:8080/job/${APP_NAME}-pipeline/"
        return 1
    fi
}

# Execute
echo ""
echo "=========================================="
echo "Jenkins Job Auto-Configuration"
echo "=========================================="
echo ""

create_jenkins_credentials
create_pipeline_job

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    log_success "✓ Jenkins Job Created!"
    echo "=========================================="
    echo ""
    echo "Job URL: http://localhost:8080/job/${APP_NAME}-pipeline/"
    echo "Login: admin / admin"
    echo ""
    echo "The job polls GitLab every 2 minutes for changes."
    echo ""
    echo "=========================================="
    echo "Next Steps:"
    echo "=========================================="
    echo "1. Fix PHP bugs in your code"
    echo "2. Commit and push to GitLab:"
    echo "   git add ."
    echo "   git commit -m 'Fix PHP bugs'"
    echo "   git push origin ${GIT_BRANCH}"
    echo "3. Jenkins will auto-trigger within 2 minutes"
    echo "4. Or manually trigger: http://localhost:8080/job/${APP_NAME}-pipeline/build"
    echo ""
fi
