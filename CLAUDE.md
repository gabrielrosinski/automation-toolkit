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
- **Purpose:** Interactive template generator for deployment files (~2 minutes)
- **User Prompts:** GitLab URL, PHP version (7.4/8.0/8.1/8.2), app port, app name, K8s namespace
- **Generates:** Dockerfile, Jenkinsfile, K8s manifests, quick-deploy.sh, .dockerignore
- **Key Implementation:**
  - Uses heredocs for embedding complete file templates
  - Cross-platform `sed_inplace()` function (handles macOS BSD sed vs Linux GNU sed)
  - Jenkinsfile uses placeholder tokens (`APP_NAME_PLACEHOLDER`, etc.) replaced via sed
  - All generated files include best practices (health checks, resource limits, proper labels)

### Helper Scripts (Support Tools - `helpers/`)

**helpers/php-debug.sh** - PHP debugging assistant
**helpers/jenkins-setup.sh** - Step-by-step Jenkins configuration guide
**helpers/k8s-helpers.sh** - kubectl command reference + diagnostics

## Generated Files Architecture

### Dockerfile Template
- Multi-stage build pattern with `FROM php:${PHP_VERSION}-apache`
- Installs common PHP extensions: pdo_mysql, mbstring, exif, pcntl, bcmath, gd
- Enables Apache mod_rewrite
- Includes HEALTHCHECK directive
- Sets proper permissions (www-data:www-data)

### Jenkinsfile Pipeline
- **6 Stages:** Checkout → PHP Syntax Check → Build → Push → Deploy → Verify
- **Environment Variables:** DOCKER_REGISTRY, IMAGE_NAME, IMAGE_TAG, GIT_REPO, K8S_NAMESPACE
- **PHP Syntax Check Stage:** Finds all `*.php` files (excluding vendor/), runs `php -l` on each
- **Build Stage:** Builds Docker image with `${BUILD_NUMBER}` tag + latest tag
- **Deploy Stage:** Uses `kubectl set image` (updates existing) OR `kubectl apply -f k8s/` (creates new)
- **Post Actions:** Success shows service URL, failure shows debug info, always cleans up with `docker system prune`

### Kubernetes Manifests
- **deployment.yaml:** Includes liveness/readiness probes, resource requests/limits, proper labels
- **service.yaml:** Type NodePort (accessible via minikube service URL)
- **namespace.yaml:** Only generated if namespace != "default"
- **ImagePullPolicy:** Set to `IfNotPresent` (works with minikube's Docker daemon)

### quick-deploy.sh
- Fast local deployment helper
- Switches to minikube Docker, builds image, applies manifests, waits for rollout

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
- **Auto-Installed Plugins:**
  - `workflow-aggregator` - Pipeline support
  - `git` - GitLab checkout
  - `credentials-binding` - Secure credentials
  - `docker-workflow` - Docker integration
  - `pipeline-stage-view` - Better UI
  - `timestamper` - Logs with timestamps
- **Groovy Init Scripts:** 3 scripts auto-configure Jenkins on first boot
  - `01-install-plugins.groovy` - Installs all plugins, skips setup wizard
  - `02-create-admin-user.groovy` - Creates admin/admin user, configures security
  - `03-configure-executors.groovy` - Sets executor count to 2
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
The `2-generate-project.sh` script uses a placeholder replacement pattern:
1. Embed full file templates in heredocs with `PLACEHOLDER` tokens
2. Write heredoc to file
3. Use `sed_inplace()` to replace all placeholders with user-provided values
4. Example: `APP_NAME_PLACEHOLDER` → `${APP_NAME}` via `sed_inplace "s|APP_NAME_PLACEHOLDER|${APP_NAME}|g" Jenkinsfile`

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
Edit `2-generate-project.sh`:
1. Update line 62: `echo "Available PHP versions: 7.4, 8.0, 8.1, 8.2, 8.3"`
2. Dockerfile FROM line automatically uses `${PHP_VERSION}` variable
3. Test with `docker build --build-arg PHP_VERSION=8.3`

### Supporting Additional Tools
To add Node.js, Python, etc.:
1. Add `install_nodejs()` function to `1-infra-setup.sh` following existing patterns
2. Call from `main()` function
3. Add to `validate_installation()` checks
4. Update Dockerfile template in `2-generate-project.sh` if needed

### Customizing Jenkinsfile Stages
Edit the Jenkinsfile heredoc in `2-generate-project.sh` (lines 153-283):
- Add stages between existing ones
- Use `sh '''...'''` for multi-line shell commands
- Use `sh """..."""` for commands needing variable expansion
- Always add to `post` block if cleanup needed

### Changing K8s Resource Defaults
Edit `k8s/deployment.yaml` template in `2-generate-project.sh` (lines 294-338):
- Resource requests: `memory: "128Mi"`, `cpu: "100m"`
- Resource limits: `memory: "256Mi"`, `cpu: "200m"`
- Replicas: Line 303 `replicas: 1`
- Probe timings: `initialDelaySeconds`, `periodSeconds`

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
5. **Best practices embedded** - Templates include health checks, resource limits, proper labels
6. **Educational value** - User learns by seeing generated files, not black-box magic
