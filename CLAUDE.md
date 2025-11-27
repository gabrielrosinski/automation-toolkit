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
- GitLab is used ONLY for Git (not CI/CD) - Jenkins handles all CI/CD
- Jenkins runs in Docker (not K8s) for faster startup during interview
- minikube chosen over kind/k3s for wider documentation/familiarity
- Time constraint: 2-3 hours maximum
- Designed for simplicity over production features

**Recent Improvements:**
- ✅ Template-based file generation (replaces inline heredocs)
- ✅ Jenkins automation fully separated into `jenkins-init-scripts/`
- ✅ Single responsibility: Jenkins setup vs pipeline job creation split
- ✅ Docker environment properly isolated (Jenkins in host, apps in minikube)
- ✅ Maintainable `{{PLACEHOLDER}}` syntax instead of `_PLACEHOLDER` tokens

## Core Architecture

### Two-Script Automation System

**1. Infrastructure Setup (`1-infra-setup.sh`)**
- **Purpose:** Unattended installation of all required tools (~10-15 minutes)
- **OS Detection:** Auto-detects WSL/Linux/macOS via `/proc/version` and `$OSTYPE`
- **Installs:** Docker, kubectl, minikube, Jenkins (Docker container), PHP CLI, Git
- **Critical Functions:**
  - `detect_os()` - Sets `$OS` and `$ARCH` variables for platform-specific installs
  - `deploy_jenkins()` - Runs Jenkins in Docker (NOT K8s), mounts Docker socket, installs Docker CLI + kubectl inside Jenkins container
  - `start_minikube()` - Starts with `--driver=docker`, enables registry + ingress addons
  - `validate_installation()` - Checks all tools are running before exit
- **Output:** `.env.interview` file with minikube IP, Jenkins URL, Docker host info

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

### Jenkins Automation (`jenkins-init-scripts/`)

**jenkins-init-scripts/deploy-jenkins.sh** - Jenkins container deployment with full automation
**jenkins-init-scripts/01-install-plugins.groovy** - Auto-installs essential plugins on startup
**jenkins-init-scripts/02-create-admin-user.groovy** - Creates admin/admin user automatically
**jenkins-init-scripts/03-configure-executors.groovy** - Sets executor count to 2

### Helper Scripts (Support Tools - `helpers/`)

**helpers/php-debug.sh** - PHP debugging assistant
**helpers/create-jenkins-job.sh** - Creates Jenkins pipeline job via Script Console API
**helpers/k8s-helpers.sh** - kubectl command reference + diagnostics

## Template Files Architecture

All deployment files are generated from templates in `templates/` directory using placeholder substitution.

### Dockerfile Template (`templates/docker/Dockerfile`)
- Multi-stage build pattern with `FROM php:{{PHP_VERSION}}-apache`
- Installs common PHP extensions: pdo_mysql, mbstring, exif, pcntl, bcmath, gd
- Enables Apache mod_rewrite
- Includes HEALTHCHECK directive on port `{{APP_PORT}}`
- Sets proper permissions (www-data:www-data)
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
1. **Deploy Jenkins in host Docker** - `deploy-jenkins.sh` runs before `eval $(minikube docker-env)`
2. **Validate Jenkins** - Ensures Jenkins container is running in host Docker context
3. **Switch to minikube Docker** - After Jenkins validation, runs `eval $(minikube docker-env)`
4. **App builds use minikube** - All subsequent `docker build` commands create images in minikube's registry
5. **Jenkins accesses both** - Jenkins container stays in host Docker but can build to minikube via mounted socket

This architecture ensures:
- Jenkins container persists across minikube restarts
- Faster Jenkins startup (no K8s overhead)
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
# Stop and remove all components
minikube delete
docker stop jenkins && docker rm jenkins
docker volume rm jenkins_home

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

## Interview Workflow Timeline

**Phase 1 (0:00-0:20):** Run `1-infra-setup.sh` while listening to requirements
**Phase 2 (0:20-0:40):** Clone GitLab repo, debug PHP with `php-debug.sh`
**Phase 3 (0:40-0:55):** Run `2-generate-project.sh`, customize Dockerfile
**Phase 4 (0:55-1:15):** Test Docker build, deploy to K8s with `quick-deploy.sh`
**Phase 5 (1:15-1:50):** Push to GitLab, configure Jenkins, run pipeline
**Phase 6 (1:50-2:15):** Integration test, verify full CI/CD flow
**Phase 7 (2:15-3:00):** Q&A, demonstrate architecture

See `INTERVIEW-FLOW.md` for detailed minute-by-minute breakdown.

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

## Documentation Files

- **README.md** - Overview, quick start, what gets installed
- **QUICK-START.md** - Fast setup for interview day
- **INSTALLATION-GUIDE.md** - Detailed installation steps
- **docs/INTERVIEW-FLOW.md** - Detailed 3-hour timeline with phases
- **docs/CHEATSHEET.md** - All Docker/kubectl/PHP/Git commands
- **docs/TROUBLESHOOTING.md** - Common issues and solutions

## Design Philosophy

1. **Speed over perfection** - Get working deployment fast, refine if time allows
2. **Simplicity over features** - No Helm, no service mesh, no complex networking
3. **Interview-optimized** - Designed for 3-hour constraint, fresh laptop, unknown OS
4. **Foolproof automation** - Scripts handle edge cases, validate everything
5. **Best practices embedded** - Templates include health checks, resource limits, proper labels, security contexts
6. **Educational value** - User learns by seeing generated files, not black-box magic
7. **Maintainability** - Template-based generation makes files easy to customize and version control
8. **Single responsibility** - Each script does one job well (infra setup, project generation, job creation)
