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

# Verify Jenkins is running
log_info "Checking Jenkins status..."
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

wait_for_jenkins || exit 1

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
    docker exec jenkins java -jar /var/jenkins_home/war/WEB-INF/jenkins-cli.jar \
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

    cat > /tmp/pipeline-config.xml <<EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Auto-generated CI/CD pipeline for ${APP_NAME}</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <hudson.triggers.SCMTrigger>
          <spec>H/5 * * * *</spec>
          <ignorePostCommitHooks>false</ignorePostCommitHooks>
        </hudson.triggers.SCMTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition">
    <scm class="hudson.plugins.git.GitSCM">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>${GITLAB_URL}</url>
          <credentialsId>gitlab-creds</credentialsId>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/${GIT_BRANCH}</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

    # Copy XML to Jenkins container
    docker cp /tmp/pipeline-config.xml jenkins:/tmp/pipeline-config.xml

    # Create job via Jenkins CLI
    docker exec jenkins java -jar /var/jenkins_home/war/WEB-INF/jenkins-cli.jar \
        -s http://localhost:8080/ \
        -auth admin:admin \
        create-job "${APP_NAME}-pipeline" \
        < /tmp/pipeline-config.xml 2>/dev/null

    local exit_code=$?
    rm /tmp/pipeline-config.xml

    if [ $exit_code -eq 0 ]; then
        log_success "Pipeline job created successfully!"
    else
        log_error "Failed to create pipeline job. It may already exist."
        log_info "Delete existing job: http://localhost:8080/job/${APP_NAME}-pipeline/delete"
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
    echo "The job polls GitLab every 5 minutes for changes."
    echo ""
    echo "=========================================="
    echo "Next Steps:"
    echo "=========================================="
    echo "1. Fix PHP bugs in your code"
    echo "2. Commit and push to GitLab:"
    echo "   git add ."
    echo "   git commit -m 'Fix PHP bugs'"
    echo "   git push origin ${GIT_BRANCH}"
    echo "3. Jenkins will auto-trigger within 5 minutes"
    echo "4. Or manually trigger: http://localhost:8080/job/${APP_NAME}-pipeline/build"
    echo ""
fi
