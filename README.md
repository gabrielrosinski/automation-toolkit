# DevOps Interview Toolkit

**Complete automation solution for 3-hour DevOps live coding interviews**

---

## What This Does

Automates the setup and deployment process for DevOps interviews covering:
- ✅ Jenkins CI/CD pipeline
- ✅ GitLab integration (Git only, not CI/CD)
- ✅ Dockerfile creation
- ✅ Kubernetes (minikube) deployment
- ✅ PHP debugging

**Gets you from zero to deployed in ~2 hours on a fresh laptop**

---

## Quick Start

### For Testing/Practice
```bash
./0-preflight-check.sh    # Check system requirements
./1-infra-setup.sh        # Install everything (~15 min)
./3-verify-setup.sh       # Verify it works
```

See **[WORKFLOWS.md](WORKFLOWS.md)** for complete testing flow.

### For Interview Day
```bash
./1-infra-setup.sh                    # While listening to requirements (15-20 min)
git clone <their-gitlab-url>          # Clone their buggy code
cd <project>
../2-generate-project.sh              # ONE SCRIPT: Generate files + Deploy + Jenkins setup (3-5 min)
# → Prompts for GitLab credentials
# → Generates Dockerfile, Jenkinsfile, K8s manifests
# → Optionally deploys to K8s
# → Optionally creates Jenkins pipeline job
# → DONE! Fix bugs and push - Jenkins auto-deploys
```

**Total automation time: ~20-25 minutes** (down from 55+ minutes!)

See **[WORKFLOWS.md](WORKFLOWS.md)** for complete interview flow.

---

## File Structure

```
lab-toolkit/
├── 0-preflight-check.sh      # Pre-installation checks
├── 1-infra-setup.sh          # Install Docker, kubectl, minikube, Jenkins, PHP
├── 2-generate-project.sh     # Generate files + Deploy + Jenkins job (AUTOMATED!)
├── 3-verify-setup.sh         # Verify installation
├── cleanup.sh                # Clean environment for fresh testing (NEW!)
├── WORKFLOWS.md              # ⭐ MAIN GUIDE: Testing & Interview flows
│
├── helpers/
│   ├── php-debug.sh          # Interactive PHP debugger
│   ├── jenkins-setup.sh      # Jenkins configuration guide (mostly automated now!)
│   ├── create-jenkins-job.sh # Auto-create Jenkins pipeline job (NEW!)
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
- Jenkins (CI/CD server in Docker - **fully automated**, no setup wizard!)
  - Auto-installed plugins: Pipeline, Git, Docker, Credentials
  - Pre-configured admin account (admin/admin)
  - Ready to use in ~3-4 minutes
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

### Fully Automated Jenkins Setup
- **Zero manual configuration** - No setup wizard, no plugin clicking
- **Auto-installed plugins** - Pipeline, Git, Docker, Credentials, Stage View, Timestamper
- **Pre-configured security** - Admin user created (admin/admin)
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
| **Jenkins** | Full CI/CD pipeline with Docker + K8s deployment |
| **GitLab On-Premise** | Git clone, commit, push (not CI/CD) |
| **Dockerfile** | Multi-stage, health checks, best practices |
| **Kubernetes** | Deployment, service, probes, resource management |
| **PHP Debugging** | Syntax checking, local testing, common bugs |

---

## Time Breakdown

**Testing Flow (Practice):**
- Setup: 20 min (one-time)
- Each practice session: 30-45 min
- Recommended: 2-3 practice sessions

**Interview Flow:**
- Setup: 15 min (automated - Docker, kubectl, minikube, Jenkins with plugins)
- Generate & Configure: 5 min (ONE SCRIPT - files + deploy + Jenkins job)
- Debug PHP: 20 min (LLM-assisted or manual)
- Commit & Push: 2 min (Jenkins auto-triggers)
- Verify & Demo: 25 min
- Q&A: 45 min
- **Total: ~1hr 52min** (1hr 8min buffer with full automation!)
- **Time saved vs manual: 35-40 minutes**

---

## Testing & Debugging

### Clean Environment for Testing
```bash
./cleanup.sh  # Removes Jenkins, minikube, generated files
              # Preserves installed software (Docker, kubectl, etc.)
              # Perfect for testing script changes
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
