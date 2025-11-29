# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**DevOps Interview Toolkit** - A complete automation solution for passing a 3-hour live DevOps coding interview.

**Interview Scenario:**
- Fresh laptop (unknown OS: WSL/Linux/macOS)
- Nothing pre-installed
- Provided: GitLab On-Premise URL, credentials, buggy PHP app
- Must complete: Tool installation → PHP debugging → Dockerfile creation → K8s deployment → Jenkins CI/CD setup

**Critical Context:**
- Self-hosted GitLab CE server now included (optional - can use external GitLab)
- GitLab is used ONLY for Git (not CI/CD) - Jenkins handles all CI/CD
- Both GitLab and Jenkins run in Docker (not K8s) for faster startup during interview
- minikube chosen over kind/k3s for wider documentation/familiarity
- Time constraint: 2-3 hours maximum
- Designed for simplicity over production features

**Recent Improvements:**
- ✅ Self-hosted GitLab CE server with automated deployment
- ✅ GitLab-Jenkins network bridge for seamless container communication
- ✅ Auto-detect local GitLab vs external GitLab URLs
- ✅ URL translation for Jenkins (localhost:8090 → gitlab:8090)
- ✅ Two-mode cleanup: default (stale resources) vs --full (complete wipe)
- ✅ Template-based file generation (replaces inline heredocs)
- ✅ Jenkins automation fully separated into `jenkins-init-scripts/`
- ✅ Single responsibility: Jenkins setup vs pipeline job creation split
- ✅ Docker environment properly isolated (Jenkins in host, apps in minikube)
- ✅ Maintainable `{{PLACEHOLDER}}` syntax instead of `_PLACEHOLDER` tokens
- ✅ True multi-stage Docker builds (builder + runtime, ~20% smaller images)
- ✅ Non-root containers (USER www-data, port 8080, runAsNonRoot: true)
- ✅ Auto-detect PHP app directory (builds from folder containing index.php)
- ✅ Optimized K8s health probes (explicit timeouts, faster startup detection)
- ✅ Security hardening (drop ALL capabilities, minimal Apache modules)

## Core Architecture

### Two-Script Automation System

**1. Infrastructure Setup (`1-infra-setup.sh`)**
- **Purpose:** Unattended installation of all required tools (~20-25 minutes including GitLab)
- **OS Detection:** Auto-detects WSL/Linux/macOS via `/proc/version` and `$OSTYPE`
- **Installs:** Docker, kubectl, minikube, GitLab CE (Docker container), Jenkins (Docker container), PHP CLI, Git
- **Deployment Order:** Docker → minikube → GitLab → Jenkins → network bridge
- **Critical Functions:**
  - `detect_os()` - Sets `$OS` and `$ARCH` variables for platform-specific installs
  - `deploy_gitlab()` - Runs `gitlab-init-scripts/deploy-gitlab.sh` to deploy GitLab CE in Docker
  - `deploy_jenkins()` - Runs `jenkins-init-scripts/deploy-jenkins.sh` to deploy Jenkins in Docker
  - `create_gitlab_jenkins_network()` - Creates custom bridge network and connects both containers
  - `start_minikube()` - Starts with `--driver=docker`, enables registry + ingress addons
  - `validate_installation()` - Checks all tools are running before exit
- **Output:** `.env.interview` file with minikube IP, GitLab URL, Jenkins URL, Docker host info

**2. Project Generator (`2-generate-project.sh`)**
- **Purpose:** Interactive template processor for deployment files (~2 minutes)
- **User Prompts:** GitLab URL, PHP version (7.4/8.0/8.1/8.2/8.3), app port, app name, K8s namespace
- **Generates:** Dockerfile, Jenkinsfile, K8s manifests, quick-deploy.sh, .dockerignore
- **Key Implementation:**
  - Uses template files from `templates/` directory with `{{PLACEHOLDER}}` tokens
  - `process_template()` function copies template and replaces all placeholders
  - Cross-platform `sed_inplace()` function (handles macOS BSD sed vs Linux GNU sed)
  - Template structure: `templates/docker/`, `templates/kubernetes/`, `templates/Jenkinsfile`
  - All templates include best practices (health checks, resource limits, proper labels)

### GitLab Automation (`gitlab-init-scripts/`)

**gitlab-init-scripts/deploy-gitlab.sh** - GitLab CE container deployment with **MINIMAL CONFIGURATION** for interview demos
- Deploys GitLab CE using official Docker image (`gitlab/gitlab-ce:latest`)
- **Minimal mode**: Disables all unnecessary enterprise/monitoring features to reduce resource usage
- Auto-configuration via `GITLAB_OMNIBUS_CONFIG` environment variable
- Health check monitoring with 5-minute timeout (60 retries × 5 seconds)
- Three persistent volumes: `gitlab_config`, `gitlab_logs`, `gitlab_data`
- Port mappings: `8090:80` (HTTP), `8022:22` (SSH)
- Pre-configured credentials: `root` / `root`
- Health endpoint: `http://localhost:8090/-/health`

**Disabled Services (not needed for interview demos):**
- ✗ Prometheus, Alertmanager, Grafana (monitoring/metrics)
- ✗ All exporters (node, redis, postgres, gitlab)
- ✗ Container Registry
- ✗ GitLab Pages
- ✗ GitLab KAS (Kubernetes Agent Server)
- ✗ Mattermost (chat integration)
- ✗ Email (SMTP, incoming email)
- ✗ Auto DevOps and expensive CI/CD features

**Optimized Settings:**
- Puma workers: 2 (default 4+ based on CPU cores)
- Puma threads: 1-4 (default 4-8)
- Sidekiq concurrency: 10 (default 25+)
- PostgreSQL max connections: 100 (default 200+)
- PostgreSQL shared buffers: 256MB (default 512MB+)
- Shared memory: 256MB (`--shm-size=256m`)

**Why Minimal Configuration?**
- GitLab CE is a full enterprise platform with 15+ services
- Default installation uses 10-12GB RAM, slow startup (3-10 minutes)
- Interview demos only need: Web UI, Git operations (HTTP/SSH), Jenkins integration
- Disabling monitoring/registry/pages reduces RAM to ~4-6GB and improves UI responsiveness
- Puma slowness (10-40 second responses) caused by expensive features like commit signature verification

**GitLab Docker Configuration:**
```bash
docker run -d \
  --name gitlab \
  --hostname gitlab.local \
  -p 0.0.0.0:8090:80 \
  -p 0.0.0.0:8022:22 \
  -e GITLAB_OMNIBUS_CONFIG="external_url 'http://localhost:8090'; gitlab_rails['gitlab_shell_ssh_port'] = 8022;" \
  -e GITLAB_ROOT_PASSWORD="interview2024" \
  -v gitlab_config:/etc/gitlab \
  -v gitlab_logs:/var/log/gitlab \
  -v gitlab_data:/var/opt/gitlab \
  gitlab/gitlab-ce:latest
```

**Note:** GitLab initialization takes 3-10 minutes on first boot depending on system resources.

### Jenkins Automation (`jenkins-init-scripts/`)

**jenkins-init-scripts/deploy-jenkins.sh** - Jenkins container deployment with full automation
**jenkins-init-scripts/01-install-plugins.groovy** - Auto-installs essential plugins on startup
**jenkins-init-scripts/02-create-admin-user.groovy** - Creates admin/admin user automatically
**jenkins-init-scripts/03-configure-executors.groovy** - Sets executor count to 2

### GitLab-Jenkins Network Bridge

**Custom Docker Bridge Network:** `gitlab-jenkins-network`
- Created after both GitLab and Jenkins containers are running
- Enables container-to-container communication via DNS (hostname resolution)
- Jenkins can reach GitLab using `http://gitlab:8090` instead of `http://localhost:8090`
- Critical for Jenkins pipeline to clone from GitLab repository

**Why Custom Network?**
- Default Docker bridge doesn't support automatic DNS resolution
- Custom bridge networks provide built-in DNS for container names
- Allows URL translation: user uses `localhost:8090`, Jenkins uses `gitlab:8090`

### Helper Scripts (Support Tools - `helpers/`)

**helpers/php-debug.sh** - PHP debugging assistant
**helpers/create-jenkins-job.sh** - Creates Jenkins pipeline job via Script Console API (includes GitLab URL translation)
**helpers/k8s-helpers.sh** - kubectl command reference + diagnostics
**helpers/gitlab-helpers.sh** - GitLab operations and troubleshooting commands

## Template Files Architecture

All deployment files are generated from templates in `templates/` directory using placeholder substitution.

### Dockerfile Template (`templates/docker/Dockerfile`)
- **True multi-stage build:** Builder stage compiles PHP extensions, runtime stage is lean (~20% smaller)
- **Builder stage:** Installs -dev packages, compiles extensions (pdo_mysql, mbstring, exif, pcntl, bcmath, gd)
- **Runtime stage:** Only runtime libraries (libpng16-16, libonig5, libxml2), no build tools
- **Security hardening:**
  - Runs as non-root user (USER www-data)
  - Non-privileged port 8080 (configurable via {{APP_PORT}})
  - Disabled unnecessary Apache modules (access_compat, auth_basic, autoindex, deflate, etc.)
- **Optimizations:**
  - Aggressive cleanup: `apt-get autoremove`, removes docs/man pages, cleans /tmp
  - `--no-install-recommends` to minimize package installation
  - `COPY --chown` for efficient ownership transfer
- **Health check:** `curl -sSf` (silent but shows errors on failure)
- Placeholders: `{{PHP_VERSION}}`, `{{APP_PORT}}`

### Jenkinsfile Template (`templates/Jenkinsfile`)
- **6 Stages:** Checkout → PHP Syntax Check → Build → Push → Deploy → Verify
- **Environment Variables:** APP_NAME, IMAGE_NAME, IMAGE_TAG, GIT_REPO, K8S_NAMESPACE
- **PHP Syntax Check Stage:** Finds all `*.php` files (excluding vendor/), runs `php -l` on each
- **Build Stage:** Builds Docker image with `${BUILD_NUMBER}` tag + latest tag
- **Deploy Stage:** Uses `kubectl set image` (updates existing) OR `kubectl apply -f k8s/` (creates new)
- **Post Actions:** Success shows service URL, failure shows debug info, always cleans up with `docker system prune`
- Placeholders: `{{APP_NAME}}`, `{{IMAGE_NAME}}`, `{{GIT_REPO}}`, `{{GIT_BRANCH}}`, `{{K8S_NAMESPACE}}`

### Kubernetes Manifest Templates (`templates/kubernetes/`)
- **deployment.yaml:** Includes liveness/readiness/startup probes, resource requests/limits, security context, proper labels
  - Placeholders: `{{APP_NAME}}`, `{{IMAGE_NAME}}`, `{{K8S_NAMESPACE}}`, `{{APP_PORT}}`, `{{HEALTH_CHECK_PATH}}`
- **service.yaml:** Type NodePort (accessible via minikube service URL)
  - Placeholders: `{{APP_NAME}}`, `{{K8S_NAMESPACE}}`, `{{APP_PORT}}`
- **namespace.yaml:** Only generated if namespace != "default"
  - Placeholders: `{{K8S_NAMESPACE}}`
- **ImagePullPolicy:** Set to `IfNotPresent` (works with minikube's Docker daemon)

### Docker Ignore Template (`templates/docker/.dockerignore`)
- Excludes .git, k8s/, .env files, documentation from Docker build context

### Generated Helper Script (quick-deploy.sh)
- Fast local deployment script (generated, not templated)
- Switches to minikube Docker, builds image, applies manifests, waits for rollout
- Custom-generated with app-specific values

## Key Technical Patterns

### Bash Script Conventions
- All scripts use `set -e` (exit on error)
- Colored logging functions: `log_info()`, `log_success()`, `log_warning()`, `log_error()`
- Color codes: BLUE=info, GREEN=success, YELLOW=warning, RED=error, NC=no color

### Cross-Platform Compatibility
- **macOS Homebrew:** Auto-installs if missing, handles arm64 vs amd64 paths
- **Docker Desktop on macOS:** Manual install required (script prompts user)
- **WSL Docker:** Auto-starts with `sudo service docker start`
- **sed Differences:** `sed_inplace()` function handles `-i ""` (macOS) vs `-i` (Linux)

### Jenkins Configuration
- **Fully Automated Setup:** No manual setup wizard - ready to use immediately
- **Credentials:** Username `admin`, Password `admin` (auto-created)
- **Deployment Script:** `jenkins-init-scripts/deploy-jenkins.sh` handles full Jenkins deployment
- **Auto-Installed Plugins:**
  - `workflow-aggregator` - Pipeline support
  - `git` - GitLab checkout
  - `credentials-binding` - Secure credentials
  - `docker-workflow` - Docker integration
  - `pipeline-stage-view` - Better UI
  - `timestamper` - Logs with timestamps
- **Groovy Init Scripts:** 3 scripts in `jenkins-init-scripts/` auto-configure Jenkins on first boot
  - `01-install-plugins.groovy` - Installs all plugins, skips setup wizard
  - `02-create-admin-user.groovy` - Creates admin/admin user, configures security
  - `03-configure-executors.groovy` - Sets executor count to 2
- **Pipeline Job Creation:** `helpers/create-jenkins-job.sh` creates jobs via Script Console API (runs after project generation)
- **Docker Access:** Runs in Docker with volume mounts: `jenkins_home` + `/var/run/docker.sock`
- Docker CLI installed inside Jenkins container (using `get.docker.com`)
- kubectl installed inside Jenkins container (latest stable release)
- kubeconfig copied from host: `~/.kube/config` → `/var/jenkins_home/.kube/config`
- Docker socket permissions managed via group ID matching for secure access

### minikube Setup
- Started with `--driver=docker --memory=4096 --cpus=2`
- Registry addon enabled (local registry at `localhost:5000`)
- Ingress addon enabled (optional, for exposing services)
- Local Docker daemon used via `eval $(minikube docker-env)`

### Docker Environment Switching
The infrastructure setup follows this critical sequence:
1. **Start minikube** - Starts Kubernetes cluster first (creates `minikube` Docker network)
2. **Deploy GitLab in host Docker** - `deploy-gitlab.sh` runs in host Docker context
3. **Deploy Jenkins in host Docker** - `deploy-jenkins.sh` runs in host Docker context
4. **Create GitLab-Jenkins network bridge** - Connects GitLab and Jenkins via `gitlab-jenkins-network`
5. **Connect Jenkins to minikube network** - Jenkins joins `minikube` network for Docker access
6. **Copy minikube TLS certs to Jenkins** - Certs copied to `/var/jenkins_home/.minikube-docker/`
7. **Create minikube Docker env file** - `/var/jenkins_home/minikube-docker-env.sh` with minikube's internal IP
8. **Switch shell to minikube Docker** - After validation, runs `eval $(minikube docker-env)` for CLI

**Jenkins Network Architecture:**
- Jenkins is connected to TWO Docker networks:
  - `gitlab-jenkins-network` - For GitLab connectivity (`http://gitlab:80`)
  - `minikube` - For Docker build access (`tcp://192.168.49.2:2376`)
- Jenkins uses TLS certs to securely connect to minikube's Docker daemon
- Jenkinsfile sources `/var/jenkins_home/minikube-docker-env.sh` to build images

This architecture ensures:
- GitLab and Jenkins containers persist across minikube restarts
- Faster startup (no K8s overhead for CI/CD infrastructure)
- Container-to-container communication via DNS (gitlab-jenkins-network)
- Jenkins can build images directly in minikube's Docker daemon
- Images built by Jenkins are immediately available to K8s pods
- No need to push images to external registry

## Common Development Commands

### Testing the Full Workflow
```bash
# 1. Run infrastructure setup
./1-infra-setup.sh

# 2. Create test project directory
mkdir test-php-app && cd test-php-app

# 3. Generate deployment files
../2-generate-project.sh
# Enter test values when prompted

# 4. Verify generated files
ls -la
cat Dockerfile
cat Jenkinsfile
ls k8s/

# 5. Test local deployment
eval $(minikube docker-env)
docker build -t test-app:latest .
kubectl apply -f k8s/
kubectl get pods
minikube service test-app --url
```

### Testing Individual Scripts
```bash
# Test OS detection
bash -c "source 1-infra-setup.sh && detect_os && echo OS=$OS ARCH=$ARCH"

# Test sed_inplace function
bash -c "source 2-generate-project.sh && echo 'test' > /tmp/test.txt && sed_inplace 's/test/replaced/' /tmp/test.txt && cat /tmp/test.txt"

# Validate Jenkins setup
docker exec jenkins docker ps  # Test Docker access
docker exec jenkins kubectl get nodes  # Test kubectl access
```

### Working with Templates
```bash
# View all template files
find templates/ -type f

# Test template processing manually
cp templates/docker/Dockerfile /tmp/test-Dockerfile
sed -i 's|{{PHP_VERSION}}|8.1|g' /tmp/test-Dockerfile
sed -i 's|{{APP_PORT}}|80|g' /tmp/test-Dockerfile
cat /tmp/test-Dockerfile

# Validate template placeholders
grep -r "{{" templates/  # Should show all placeholders

# Test template generation with dry-run
# (Run 2-generate-project.sh and review generated files without deploying)
./2-generate-project.sh
# Answer prompts, then select 'n' for deployment questions
```

### Cleanup Commands
```bash
# DEFAULT MODE - Remove stale resources, keep base images and network
./cleanup.sh

# FULL MODE - Complete wipe including base images
./cleanup.sh --full

# Manual cleanup (if needed)
# Stop and remove all components
minikube delete
docker stop gitlab jenkins && docker rm gitlab jenkins
docker volume rm gitlab_config gitlab_logs gitlab_data jenkins_home
docker network rm gitlab-jenkins-network

# Remove generated files
rm -f Dockerfile Jenkinsfile .dockerignore quick-deploy.sh .env.interview
rm -rf k8s/
```

## Critical Implementation Details

### Template Placeholder System
The `2-generate-project.sh` script uses a template-based file generation pattern:
1. Template files stored in `templates/` directory with `{{PLACEHOLDER}}` tokens
2. `process_template()` function copies template to target location
3. Multiple `sed_inplace()` calls replace all placeholders with user-provided values
4. Supported placeholders:
   - `{{APP_NAME}}` → application name (e.g., `my-app`)
   - `{{IMAGE_NAME}}` → full image path (e.g., `localhost:5000/my-app`)
   - `{{APP_PORT}}` → application port (e.g., `80`)
   - `{{K8S_NAMESPACE}}` → Kubernetes namespace (e.g., `default`)
   - `{{PHP_VERSION}}` → PHP version (e.g., `8.1`)
   - `{{GIT_REPO}}` → GitLab repository URL
   - `{{GIT_BRANCH}}` → Git branch name (e.g., `main`)
   - `{{HEALTH_CHECK_PATH}}` → health check endpoint path (e.g., `/`)
5. Template structure:
   ```
   templates/
   ├── Jenkinsfile
   ├── docker/
   │   ├── Dockerfile
   │   └── .dockerignore
   └── kubernetes/
       ├── deployment.yaml
       ├── service.yaml
       └── namespace.yaml
   ```

### Jenkins Docker Socket Access
Jenkins must access Docker to build images:
- `/var/run/docker.sock` mounted from host into Jenkins container
- Docker CLI installed inside Jenkins (not just Docker-in-Docker)
- Socket permissions set to `666` (security trade-off for interview speed)
- Verified with `docker exec jenkins docker ps`

### minikube Registry Strategy
Images must be available to K8s without external registry:
- Use minikube's Docker daemon: `eval $(minikube docker-env)`
- Build images directly in minikube's Docker (avoids push/pull)
- Alternative: Use minikube registry addon at `localhost:5000`
- ImagePullPolicy set to `IfNotPresent` in deployment manifests

### PHP Syntax Checking Pattern
Jenkinsfile stage finds all PHP files and checks syntax:
```bash
find . -name "*.php" -not -path "./vendor/*" | while read file; do
    php -l "$file" || ERROR_COUNT=$((ERROR_COUNT + 1))
done
```

### GitLab URL Translation Pattern
**Problem:** GitLab container is accessible at different URLs depending on context:
- User (browser, git clone): `http://localhost:8090`
- Jenkins container: `http://gitlab:8090` (uses container name)

**Solution:** Automatic URL translation in `2-generate-project.sh`:

```bash
translate_gitlab_url_for_jenkins() {
    local url="$1"
    if [[ "$url" =~ localhost:8090 ]]; then
        echo "$url" | sed 's|localhost:8090|gitlab:8090|g'
    else
        echo "$url"  # External GitLab - no translation needed
    fi
}
```

**Where Translation Happens:**
1. **User input:** User provides `http://localhost:8090/root/project.git`
2. **Jenkinsfile generation:** Template substitutes with `http://gitlab:8090/root/project.git`
3. **Job creation:** `helpers/create-jenkins-job.sh` also translates for job XML
4. **`.env.interview`:** Saves both URLs:
   - `GITLAB_URL` - for user reference (localhost:8090)
   - `GITLAB_URL_JENKINS` - for Jenkins use (gitlab:8090)

**Why This Works:**
- Custom bridge network (`gitlab-jenkins-network`) provides DNS resolution
- Jenkins container resolves `gitlab` hostname to GitLab container's IP
- User continues using `localhost:8090` for browser and git operations
- Jenkins pipeline automatically uses correct internal URL

## Interview Workflow Timeline

**Phase 1 (0:00-0:25):** Run `1-infra-setup.sh` while listening to requirements (includes GitLab initialization)
**Phase 2 (0:25-0:26):** Create GitLab project in web UI (30 seconds - manual, visual)
**Phase 3 (0:26-0:29):** Clone GitLab repo or initialize new repository
**Phase 4 (0:29-0:49):** Debug PHP with `php-debug.sh`
**Phase 5 (0:49-0:54):** Run `2-generate-project.sh`, customize Dockerfile
**Phase 6 (0:54-0:56):** Push to GitLab (git add, commit, push)
**Phase 7 (0:56-1:06):** Jenkins pipeline auto-triggers and completes build
**Phase 8 (1:06-1:08):** Verify deployment, test application
**Phase 9 (1:08-1:13):** Demo full CI/CD flow with code change
**Buffer (1:13-3:00):** Q&A, troubleshooting, deep dives

**Total active work:** ~1hr 15min
**Buffer time:** 1hr 45min (58% buffer - very comfortable for 3-hour interview)

See `WORKFLOWS.md` for complete step-by-step guide with commands.

## Modification Guidelines

### Adding New PHP Versions
1. Edit `2-generate-project.sh` - Update available versions list:
   ```bash
   echo "Available PHP versions: 7.4, 8.0, 8.1, 8.2, 8.3, 8.4"
   ```
2. Template automatically uses `{{PHP_VERSION}}` placeholder - no template changes needed
3. Verify PHP version exists on Docker Hub: `docker pull php:8.4-apache`

### Supporting Additional Tools
To add Node.js, Python, etc.:
1. Add `install_nodejs()` function to `1-infra-setup.sh` following existing patterns
2. Call from `main()` function
3. Add to `validate_installation()` checks
4. Edit `templates/docker/Dockerfile` to install additional runtime/dependencies

### Customizing Jenkinsfile Stages
Edit `templates/Jenkinsfile`:
- Add stages between existing ones
- Use `sh '''...'''` for multi-line shell commands
- Use `sh """..."""` for commands needing variable expansion
- Always add to `post` block if cleanup needed
- Keep `{{PLACEHOLDER}}` tokens for values that should be replaced

### Changing K8s Resource Defaults
Edit `templates/kubernetes/deployment.yaml`:
- Resource requests: `memory: "128Mi"`, `cpu: "100m"`
- Resource limits: `memory: "256Mi"`, `cpu: "200m"`
- Replicas: `replicas: 1`
- Probe timings: `initialDelaySeconds`, `periodSeconds`, `failureThreshold`
- Security context: `runAsUser`, `fsGroup`, `capabilities`

### Adding New Template Placeholders
To add a new placeholder (e.g., `{{DATABASE_HOST}}`):
1. Add the placeholder in template files (e.g., `templates/kubernetes/deployment.yaml`)
2. Collect value from user in `2-generate-project.sh` prompts section
3. Add replacement in `process_template()` function:
   ```bash
   sed_inplace "s|{{DATABASE_HOST}}|${DATABASE_HOST}|g" "$output_file"
   ```

## Jenkins Automation Architecture

### Two-Stage Jenkins Setup

**Stage 1: Jenkins Deployment (During Infrastructure Setup)**
- `jenkins-init-scripts/deploy-jenkins.sh` runs Jenkins container with init scripts
- Groovy init scripts execute on first boot (mounted at `/var/jenkins_home/init.groovy.d/`)
- Fully automated: No setup wizard, admin user auto-created, plugins pre-installed
- Jenkins runs in **host Docker** (not minikube) for faster startup and simpler architecture

**Stage 2: Pipeline Job Creation (After Project Generation)**
- `helpers/create-jenkins-job.sh` creates pipeline job via Jenkins Script Console API
- Runs after user provides GitLab URL and app configuration
- Automatically creates GitLab credentials in Jenkins
- Separate from deployment to maintain single responsibility principle

### Jenkins Init Scripts Flow
1. **01-install-plugins.groovy**: Installs 6 essential plugins, skips setup wizard
2. **02-create-admin-user.groovy**: Creates admin/admin user, configures security realm
3. **03-configure-executors.groovy**: Sets executor count to 2 for parallel builds

### Why Two Separate Scripts?
- **deploy-jenkins.sh**: Infrastructure concern - sets up Jenkins container, should run once
- **create-jenkins-job.sh**: Project concern - creates app-specific pipeline, runs per project
- Separation allows creating multiple projects without redeploying Jenkins

## Troubleshooting Common Issues

### macOS Docker Desktop Required
- Script detects macOS but can't auto-install Docker Desktop
- Prompts user to install manually from docker.com
- Waits for user confirmation before proceeding
- Verifies with `docker ps` after user confirms

### Jenkins kubectl Access
If Jenkins can't reach K8s cluster:
```bash
# Re-copy kubeconfig
docker exec jenkins mkdir -p /var/jenkins_home/.kube
docker cp ~/.kube/config jenkins:/var/jenkins_home/.kube/config
docker exec jenkins chown -R jenkins:jenkins /var/jenkins_home/.kube

# Verify
docker exec jenkins kubectl get nodes
```

### ImagePullBackOff in K8s
Image not found by minikube:
```bash
# Ensure using minikube's Docker daemon
eval $(minikube docker-env)
docker images  # Verify image exists
docker build -t app:latest .  # Rebuild in minikube Docker
kubectl delete pod <pod-name>  # Force recreation
```

### WSL Docker Service Not Running
```bash
sudo service docker start
docker ps  # Verify running
# If still fails, check Docker Desktop WSL integration in Windows
```

### Stale Docker Image :latest Tag (FIXED)
**Problem:** Pods fail health checks (403/500) even after successful Docker build. Kubernetes uses old image with `:latest` tag.

**Root Cause:** When rebuilding images in minikube's Docker, old `:latest` tags persist and point to broken images. Kubernetes pulls the old image.

**Permanent Fix Applied:**
1. **Jenkinsfile** (lines 59-60): Automatically removes old `:latest` tag before each build
   ```groovy
   docker rmi ${IMAGE_NAME}:latest 2>/dev/null || echo "No old :latest tag found"
   ```
2. **cleanup.sh** (lines 113-131): Cleans images from **both** host Docker and minikube Docker
   ```bash
   # Switches to minikube Docker context and removes all toolkit images
   eval $(minikube docker-env)
   docker rmi -f localhost:5000/automation-toolkit:*
   ```

**Manual Fix (if needed):**
```bash
# Remove stale images from minikube Docker
bash -c 'eval $(minikube docker-env) && docker images | grep automation-toolkit'
bash -c 'eval $(minikube docker-env) && docker rmi -f localhost:5000/automation-toolkit:latest'

# Rebuild and retag
bash -c 'eval $(minikube docker-env) && docker build -t localhost:5000/app:3 .'
bash -c 'eval $(minikube docker-env) && docker tag localhost:5000/app:3 localhost:5000/app:latest'

# Force pod recreation
kubectl delete pod <pod-name> -n <namespace>
```

**Prevention:** Run `./cleanup.sh` before each test cycle to ensure clean Docker environment.

### GitLab Initialization Timeout
**Problem:** GitLab container starts but health check fails after 5 minutes.

**Root Cause:** GitLab CE initialization takes 3-10 minutes on first boot depending on system resources (CPU, memory, disk I/O). The default 5-minute timeout may be insufficient on slower systems.

**Immediate Solution:**
```bash
# Wait longer - GitLab may still be initializing
# Check logs to monitor progress
docker logs -f gitlab

# Look for: "gitlab Reconfigured!" (initialization complete)
# Then manually check health
curl http://localhost:8090/-/health
# Expected: {"status":"ok"}
```

**Permanent Fix Options:**
1. **Increase timeout in `gitlab-init-scripts/deploy-gitlab.sh`:**
   ```bash
   # Change from 60 to 120 retries (10 minutes)
   local max_attempts=120  # 120 × 5 seconds = 10 minutes
   ```

2. **Use helper script to monitor:**
   ```bash
   ./helpers/gitlab-helpers.sh logs-live
   # Wait for "gitlab Reconfigured!" message
   ```

3. **Verify container resources:**
   ```bash
   docker stats gitlab
   # Ensure adequate CPU/memory allocation
   ```

**If GitLab still fails:**
```bash
# Restart GitLab container
docker restart gitlab

# Or redeploy from scratch
docker stop gitlab && docker rm gitlab
docker volume rm gitlab_config gitlab_logs gitlab_data
./gitlab-init-scripts/deploy-gitlab.sh
```

### GitLab-Jenkins Connectivity Issues
**Problem:** Jenkins pipeline fails to clone from GitLab repository.

**Common Causes:**
1. **Network not connected:** Containers aren't on `gitlab-jenkins-network`
2. **URL mismatch:** Jenkinsfile uses `localhost:8090` instead of `gitlab:8090`
3. **GitLab not ready:** GitLab container is starting but not fully initialized

**Diagnosis:**
```bash
# 1. Check network connections
docker network inspect gitlab-jenkins-network
# Should show both gitlab and jenkins containers

# 2. Test connectivity from Jenkins
docker exec jenkins curl -v http://gitlab:8090/-/health
# Should return HTTP 200

# 3. Use helper script
./helpers/gitlab-helpers.sh test
# Runs full connectivity test
```

**Fix:**
```bash
# Reconnect containers to network
docker network connect gitlab-jenkins-network gitlab
docker network connect gitlab-jenkins-network jenkins

# Verify Jenkinsfile uses correct URL
cat Jenkinsfile | grep GIT_REPO
# For local GitLab, should show: http://gitlab:8090/root/project.git
# (NOT localhost:8090)
```

### GitLab Web UI Not Accessible
**Problem:** Cannot access GitLab at `http://localhost:8090`

**Diagnosis:**
```bash
# 1. Check container status
docker ps | grep gitlab
# Should show gitlab container with ports 0.0.0.0:8090->80/tcp

# 2. Check health endpoint
curl http://localhost:8090/-/health

# 3. Check logs
docker logs gitlab | tail -50
```

**Common Fixes:**
```bash
# Port conflict - another service using 8090
sudo lsof -i :8090  # Linux/macOS
# Kill conflicting process or change GitLab port

# Container crashed - check logs
docker logs gitlab
# Look for errors, OOM (out of memory), etc.

# Restart GitLab
./helpers/gitlab-helpers.sh restart
```

## Documentation Files

- **README.md** - Overview, quick start, what gets installed
- **QUICK-START.md** - Fast setup for interview day
- **INSTALLATION-GUIDE.md** - Detailed installation steps
- **WORKFLOWS.md** - Complete step-by-step workflow with GitLab setup
- **docs/INTERVIEW-FLOW.md** - Detailed 3-hour timeline with phases
- **docs/CHEATSHEET.md** - All Docker/kubectl/PHP/Git commands
- **docs/TROUBLESHOOTING.md** - Common issues and solutions
- **helpers/gitlab-helpers.sh** - GitLab command reference and diagnostics

## Design Philosophy

1. **Speed over perfection** - Get working deployment fast, refine if time allows
2. **Simplicity over features** - No Helm, no service mesh, no complex networking
3. **Interview-optimized** - Designed for 3-hour constraint, fresh laptop, unknown OS
4. **Foolproof automation** - Scripts handle edge cases, validate everything
5. **Best practices embedded** - Templates include health checks, resource limits, proper labels, security contexts
6. **Educational value** - User learns by seeing generated files, not black-box magic
7. **Maintainability** - Template-based generation makes files easy to customize and version control
8. **Single responsibility** - Each script does one job well (infra setup, project generation, job creation)
