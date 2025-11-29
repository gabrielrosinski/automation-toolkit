# DevOps Interview Toolkit

**Complete automation solution for 3-hour DevOps live coding interviews**

---

## What This Does

Automates the setup and deployment process for DevOps interviews covering:
- ✅ Self-hosted GitLab CE server (optional - can use external GitLab)
- ✅ Jenkins CI/CD pipeline
- ✅ GitLab-Jenkins integration (Git only, not CI/CD)
- ✅ Dockerfile creation
- ✅ Kubernetes (minikube) deployment
- ✅ PHP debugging

**Gets you from zero to deployed in ~2 hours on a fresh laptop**

---

## Quick Start

### For Testing/Practice
```bash
./0-preflight-check.sh    # Check system requirements
./1-infra-setup.sh        # Install everything (~20-25 min, includes GitLab)
./3-verify-setup.sh       # Verify it works
```

See **[WORKFLOWS.md](WORKFLOWS.md)** for complete testing flow.

### For Interview Day
```bash
./1-infra-setup.sh                    # While listening to requirements (20-25 min)
# → Installs Docker, kubectl, minikube, GitLab CE, Jenkins
# → GitLab: http://localhost:8090 (root / Kx9mPqR2wZ)
# → Jenkins: http://localhost:8080 (admin / admin)

# get existing ssh key
# cat ~/.ssh/id_ed25519.pub

# clear out stale gitlab ssh host key
# ssh-keygen -f '/home/blaqs/.ssh/known_hosts' -R '[localhost]:8022'

# Option A: Use local GitLab (30 seconds setup)
# Open http://localhost:8090, login as root/Kx9mPqR2wZ, create project

# Option B: Clone from external GitLab
git clone <their-gitlab-url>          # Clone their buggy code
cd <project>

../2-generate-project.sh              # ONE SCRIPT: Generate files + Deploy + Jenkins setup (3-5 min)
# → Auto-detects local GitLab at localhost:8090
# → Prompts for GitLab credentials (defaults: root/Kx9mPqR2wZ)
# → Generates Dockerfile, Jenkinsfile, K8s manifests
# → Optionally deploys to K8s
# → Optionally creates Jenkins pipeline job
# → DONE! Fix bugs and push - Jenkins auto-deploys
```

**Total automation time: ~25-30 minutes** (down from 55+ minutes!)

See **[WORKFLOWS.md](WORKFLOWS.md)** for complete interview flow.

---

## Access URLs & Credentials

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| **GitLab CE** | http://localhost:8090 | `root` | `Kx9mPqR2wZ` |
| **Jenkins** | http://localhost:8080 | `admin` | `admin` |
| **PHP App (K8s)** | `minikube service <app-name> --url` | - | - |

**GitLab SSH:** `ssh://git@localhost:8022/root/<project>.git`

**GitLab HTTP Clone:** `http://localhost:8090/root/<project>.git`

**Note:** For K8s deployed apps, get the URL with:
```bash
minikube service <app-name> -n <namespace> --url
# Or use NodePort: http://<minikube-ip>:<nodeport>
kubectl get svc -n <namespace>
```

---

## File Structure

```
lab-toolkit/
├── 0-preflight-check.sh      # Pre-installation checks
├── 1-infra-setup.sh          # Install Docker, kubectl, minikube, GitLab, Jenkins, PHP
├── 2-generate-project.sh     # Generate files + Deploy + Jenkins job (AUTOMATED!)
├── 3-verify-setup.sh         # Verify installation
├── cleanup.sh                # Clean environment (default or --full mode)
├── WORKFLOWS.md              # ⭐ MAIN GUIDE: Testing & Interview flows with GitLab
│
├── gitlab-init-scripts/
│   └── deploy-gitlab.sh      # Automated GitLab CE deployment
│
├── jenkins-init-scripts/
│   ├── deploy-jenkins.sh     # Automated Jenkins deployment
│   ├── 01-install-plugins.groovy
│   ├── 02-create-admin-user.groovy
│   └── 03-configure-executors.groovy
│
├── helpers/
│   ├── php-debug.sh          # Interactive PHP debugger
│   ├── jenkins-setup.sh      # Jenkins configuration guide (mostly automated now!)
│   ├── create-jenkins-job.sh # Auto-create Jenkins pipeline job
│   ├── gitlab-helpers.sh     # GitLab operations and troubleshooting (NEW!)
│   └── k8s-helpers.sh        # kubectl command reference
│
├── docs/
│   ├── CHEATSHEET.md         # All Docker/kubectl/PHP/Git commands
│   ├── INTERVIEW-FLOW.md     # Detailed 3-hour timeline
│   └── TROUBLESHOOTING.md    # Common issues & solutions
│
├── buged-php/                # Sample buggy app (34 intentional bugs!)
│   ├── *.php                 # Buggy PHP files
│   ├── BUGS-LIST.md          # All bugs documented
│   └── copy-for-practice.sh  # Copy files for safe practice
│
└── CLAUDE.md                 # Guide for Claude Code instances
```

---

## What Gets Installed

**Infrastructure (`1-infra-setup.sh`):**
- Docker (container runtime)
- kubectl (Kubernetes CLI)
- minikube (local K8s cluster)
- **GitLab CE** (self-hosted Git server in Docker - **minimal mode for interviews**!)
  - Container name: `gitlab`
  - Web UI: http://localhost:8090
  - SSH: port 8022
  - Pre-configured root account (root / Kx9mPqR2wZ)
  - Minimal configuration: Monitoring/registry/pages/KAS disabled
  - Reduced workers: Puma=2, Sidekiq=10 (faster, lower RAM usage)
  - 3 persistent volumes (config, logs, data)
  - Ready to use in ~3-5 minutes (optimized startup)
- **Jenkins** (CI/CD server in Docker - **fully automated**, no setup wizard!)
  - Container name: `jenkins`
  - Web UI: http://localhost:8080
  - Auto-installed plugins: Pipeline, Git, Docker, Credentials, Stage View, Timestamper
  - Pre-configured admin account (admin/admin)
  - Ready to use in ~3-4 minutes
  - Connected to GitLab via custom bridge network
- PHP CLI (for debugging)
- Git

**Generated Files (`2-generate-project.sh`):**
- Dockerfile (PHP + Apache, multi-stage, health checks)
- Jenkinsfile (6-stage pipeline: checkout → test → build → push → deploy → verify)
- k8s/deployment.yaml (with probes, resource limits, labels)
- k8s/service.yaml (NodePort type)
- k8s/namespace.yaml (if not default)
- quick-deploy.sh (fast local deployment)

---

## Key Features

### Self-Hosted GitLab CE - Minimal Mode for Interviews
- **Fully automated deployment** - No manual configuration needed
- **Pre-configured credentials** - root / Kx9mPqR2wZ
- **Minimal configuration** - Monitoring/registry/pages/KAS disabled for faster performance
- **Optimized for interviews** - Reduced workers (Puma=2, Sidekiq=10), lower RAM usage (~4-6GB vs 10-12GB)
- **Custom Docker network** - Seamless GitLab ↔ Jenkins communication
- **Auto-detected by scripts** - Automatically uses local GitLab if available
- **URL translation** - Scripts handle localhost vs container hostname differences

### Fully Automated Jenkins Setup
- **Zero manual configuration** - No setup wizard, no plugin clicking
- **Auto-installed plugins** - Pipeline, Git, Docker, Credentials, Stage View, Timestamper
- **Pre-configured security** - Admin user created (admin/admin)
- **GitLab integration** - Auto-configured to pull from GitLab repos
- **Production-ready** - Create pipeline jobs immediately after install

### Smart Auto-Detection
- **PHP Version**: Reads from `composer.json` or `.php-version`
- **Git Branch**: Prompts for main/master/custom

### Security
- Docker socket access via group membership (not world-writable)
- No unnecessary sudo/root access

### Reliability
- Automatic rollback on installation failure
- Comprehensive verification script
- Pre-flight system checks

### For Practice
- Buggy PHP app with 34 intentional bugs
- Safe copy script preserves original bugs
- Complete bug list with solutions

---

## Prerequisites

- Fresh laptop with 16GB RAM (minimum 8GB)
- 10GB free disk space
- Internet connection
- WSL/Linux/macOS (auto-detected)
- Admin/sudo access

---

## Documentation

- **[WORKFLOWS.md](WORKFLOWS.md)** - ⭐ **START HERE**: Testing & Interview step-by-step
- **[INTERVIEW-QUESTIONS.md](INTERVIEW-QUESTIONS.md)** - 🎯 **CRITICAL**: What to ask the interviewer
- **[docs/CHEATSHEET.md](docs/CHEATSHEET.md)** - All commands quick reference
- **[docs/INTERVIEW-FLOW.md](docs/INTERVIEW-FLOW.md)** - Detailed 3-hour timeline
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues & solutions
- **[buged-php/BUGS-LIST.md](buged-php/BUGS-LIST.md)** - All 34 bugs documented

---

## Interview Topics Covered

| Topic | Coverage |
|-------|----------|
| **GitLab CE Self-Hosted** | Docker deployment, Git operations, project creation (not CI/CD) |
| **Jenkins** | Full CI/CD pipeline with Docker + K8s deployment |
| **GitLab-Jenkins Integration** | Network bridge, URL translation, automated credentials |
| **Dockerfile** | Multi-stage, health checks, non-root, best practices |
| **Kubernetes** | Deployment, service, probes, resource management |
| **PHP Debugging** | Syntax checking, local testing, common bugs |

---

## Time Breakdown

**Testing Flow (Practice):**
- Setup: 25 min (one-time - includes GitLab initialization)
- Each practice session: 30-45 min
- Recommended: 2-3 practice sessions

**Interview Flow:**
- Setup: 25 min (automated - Docker, kubectl, minikube, GitLab, Jenkins with plugins)
- GitLab Project: 1 min (create project in web UI - 30 seconds)
- Generate & Configure: 5 min (ONE SCRIPT - files + deploy + Jenkins job)
- Debug PHP: 20 min (LLM-assisted or manual)
- Commit & Push: 2 min (Jenkins auto-triggers)
- Verify & Demo: 15 min
- Q&A: 52 min
- **Total: ~2hr** (1hr buffer with full automation!)
- **Time saved vs manual: 35-40 minutes**

See **[WORKFLOWS.md](WORKFLOWS.md)** for detailed minute-by-minute breakdown.

---

## Testing & Debugging

### Clean Environment for Testing
```bash
# DEFAULT MODE - Remove stale resources, keep base images & network
./cleanup.sh
# Removes:
#  - GitLab & Jenkins containers + volumes (fresh start)
#  - minikube cluster
#  - Toolkit-built Docker images
#  - Generated files
# Preserves:
#  - Installed software (Docker, kubectl, minikube, PHP, Git)
#  - gitlab-jenkins-network (faster re-setup)
#  - Base images (gitlab/gitlab-ce, jenkins/jenkins, php:*) - faster re-setup

# FULL MODE - Complete wipe including base images
./cleanup.sh --full
# Removes EVERYTHING including base images
# Next setup will download all base images (~2GB)
```

### Full Testing Cycle
```bash
# 1. Clean environment
./cleanup.sh

# 2. Run infrastructure setup
./1-infra-setup.sh

# 3. Create test project
mkdir test-app && cd test-app
git init
echo "<?php echo 'Hello World';" > index.php

# 4. Test automated workflow
../2-generate-project.sh
# Enter test credentials when prompted
# Say YES to deployment and Jenkins job creation

# 5. Verify everything works
kubectl get pods
curl http://localhost:8080  # Jenkins
```

---

## Support

- Check [WORKFLOWS.md](WORKFLOWS.md) for step-by-step instructions
- Check [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for issues
- Test on your machine before interview day
- Use `./cleanup.sh` to reset environment between tests

---

## Design Philosophy

1. **Speed over perfection** - Working deployment fast
2. **Simplicity over features** - No Helm, no complex networking
3. **Interview-optimized** - 3-hour constraint, fresh laptop
4. **Foolproof automation** - Scripts handle edge cases
5. **Best practices** - Health checks, resource limits, labels included

---

**Good luck with your interview! 🚀**
