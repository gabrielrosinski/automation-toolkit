#!/bin/bash

###############################################################################
# Jenkins Setup Helper
# Step-by-step guide for configuring Jenkins pipeline
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

cat << 'EOF'

==============================================
  JENKINS SETUP GUIDE
==============================================

This guide will help you configure Jenkins to:
1. Connect to GitLab repository
2. Create a pipeline job
3. Set up automated builds

==============================================
STEP 1: ACCESS JENKINS (FULLY AUTOMATED)
==============================================

✓ Jenkins is fully configured and ready to use!

1. Open Jenkins in browser:
   URL: http://localhost:8080

2. Login with auto-configured credentials:
   Username: admin
   Password: admin

3. Pre-installed plugins (via Groovy automation):
   ✓ Pipeline (workflow-aggregator)
   ✓ Git
   ✓ Credentials Binding
   ✓ Docker Pipeline
   ✓ Pipeline Stage View
   ✓ Timestamper

4. Auto-configured tools:
   ✓ Docker CLI installed in Jenkins container
   ✓ kubectl installed in Jenkins container
   ✓ Docker socket mounted and accessible
   ✓ kubeconfig copied from host
   ✓ 2 executors configured

Note: Setup wizard was skipped via Groovy init scripts
      All automation scripts are in: jenkins-init-scripts/

==============================================
STEP 2: ADD GITLAB CREDENTIALS
==============================================

1. Go to: Manage Jenkins → Manage Credentials

2. Click "(global)" → "Add Credentials"

3. Fill in:
   - Kind: Username with password
   - Scope: Global
   - Username: [Your GitLab username]
   - Password: [Your GitLab password or token]
   - ID: gitlab-creds
   - Description: GitLab Credentials

4. Click "Create"

==============================================
STEP 3: CONFIGURE AUTO-CREATED PIPELINE JOB
==============================================

✓ Pipeline job 'php-app-pipeline' was auto-created during setup!

1. Go to: http://localhost:8080/job/php-app-pipeline/configure

2. Update the Git configuration:

   Repository Section:
   • Repository URL: [Your GitLab URL]
     (Replace: https://gitlab.example.com/username/php-app.git)
   • Credentials: Select "gitlab-creds" (created in Step 2)
   • Branch Specifier: */main (or */master)

   Note: Other settings are pre-configured:
   ✓ Poll SCM: H/2 * * * * (every 2 minutes)
   ✓ Pipeline from SCM: Jenkinsfile
   ✓ Lightweight checkout: Enabled

3. Click "Save"

==============================================
STEP 4: RUN FIRST BUILD
==============================================

1. Go to your pipeline job

2. Click "Build Now"

3. Watch the build progress:
   - Click on build #1
   - Click "Console Output"
   - Monitor logs

4. If successful, you'll see:
   ✓ Code checked out from GitLab
   ✓ Docker image built
   ✓ Image pushed to registry
   ✓ Deployed to Kubernetes

==============================================
OPTIONAL: SETUP WEBHOOK (Auto-trigger)
==============================================

To automatically trigger Jenkins when you push to GitLab:

1. In GitLab project:
   - Settings → Webhooks
   - URL: http://[jenkins-ip]:8080/project/php-app-pipeline
   - Trigger: Push events
   - Click "Add webhook"

2. In Jenkins:
   - Job Configuration → Build Triggers
   - Check "Build when a change is pushed to GitLab"
   - Save

Note: Webhook may not work with localhost. Use in production.

==============================================
TROUBLESHOOTING
==============================================

Issue: "Permission denied" for Docker
Fix: 
  docker exec -u root jenkins chmod 666 /var/run/docker.sock

Issue: "kubectl not found"
Fix:
  docker exec -u root jenkins bash -c "curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && mv kubectl /usr/local/bin/"

Issue: "Cannot connect to GitLab"
Fix:
  - Check GitLab URL is accessible
  - Check credentials are correct
  - Try with personal access token instead of password

Issue: Pipeline fails at K8s deploy
Fix:
  - Check kubeconfig is correctly mounted
  - Test: docker exec jenkins kubectl get nodes
  - Check namespace exists: kubectl get ns

==============================================
VERIFICATION
==============================================

After setup, verify everything works:

1. Jenkins Dashboard shows your pipeline job
2. Build runs successfully (green checkmark)
3. Console output shows all stages passed
4. Check K8s deployment:
   kubectl get pods
   kubectl get svc

==============================================

EOF

echo ""
read -p "Press Enter to continue..."
echo ""

# Quick setup option
read -p "Do you want to see Jenkins login credentials? [y/N]: " help_login
if [[ "$help_login" =~ ^[Yy]$ ]]; then
    if docker ps | grep -q jenkins; then
        echo ""
        log_success "Jenkins Credentials (auto-configured):"
        echo ""
        echo "    URL: http://localhost:8080"
        echo "    Username: admin"
        echo "    Password: admin"
        echo ""
        log_info "No setup wizard required - Jenkins is ready to use!"
        echo ""
    else
        log_warning "Jenkins container is not running. Run 1-infra-setup.sh first."
    fi
fi

echo ""
log_info "For detailed instructions, refer to the guide above."
echo ""
