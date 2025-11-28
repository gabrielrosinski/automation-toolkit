# DevOps Interview Toolkit - Complete Workflow

This document provides a step-by-step workflow for using the toolkit during a DevOps interview or demonstration.

## Prerequisites

- A fresh laptop (WSL/Linux/macOS)
- Internet connection
- Terminal access

---

## Step 1: Infrastructure Setup

Run the automated infrastructure setup script. This installs all required tools and starts the environment.

```bash
cd ~/lab-toolkit
./1-infra-setup.sh
```

**What this does:**
- Installs Docker, kubectl, minikube, PHP, Git
- Starts minikube Kubernetes cluster
- **Deploys GitLab CE (3-5 minutes initialization)**
- Deploys Jenkins (fully automated, no setup wizard)
- Creates network bridge for GitLab ↔ Jenkins communication
- Configures all components

**Time:** 20-25 minutes (includes GitLab initialization)

**Output:**
- GitLab: http://localhost:8090 (root / interview2024)
- Jenkins: http://localhost:8080 (admin / admin)

---

## Step 2: Configure GitLab (Manual - One Time Setup)

**Note:** This step is ONLY needed if using local GitLab (http://localhost:8090)
**Skip if:** Using external GitLab server provided by interviewer

### Part A: Login to GitLab (10 seconds)

**Credentials (Auto-configured by deployment script):**
- **URL:** http://localhost:8090
- **Username:** `root`
- **Password:** `Kx9mPqR2wZ`

```bash
# Open GitLab in browser
# Linux/WSL:
xdg-open http://localhost:8090

# macOS:
open http://localhost:8090

# Windows (from WSL):
explorer.exe http://localhost:8090

# Or just visit in browser: http://localhost:8090
```

**Login:**
1. Enter username: `root`
2. Enter password: `Kx9mPqR2wZ`
3. Click "Sign in"

---

### Part B: Create Project (30 seconds)

**In GitLab web UI:**

1. Click **"New Project"** button (blue button, top right)
2. Select **"Create blank project"**
3. Fill in:
   - **Project name:** `buggy-php-app` (or match your app name)
   - **Visibility Level:** Private (default)
   - **IMPORTANT:** UNCHECK "Initialize repository with a README"
4. Click **"Create project"**

**Note the Git URLs shown on the project page:**
- SSH: `ssh://git@localhost:8022/root/buggy-php-app.git`
- HTTP: `http://localhost:8090/root/buggy-php-app.git`

---

### Part C: Setup SSH Key for Git (1-2 minutes)

**RECOMMENDED:** SSH is the fastest and most reliable method - no passwords needed!

#### Step 1: Check if SSH key already exists

```bash
# Check for existing SSH keys
ls -la ~/.ssh/id_*

# If you see files like:
#   id_ed25519     (private key)
#   id_ed25519.pub (public key)
# Then you already have an SSH key - skip to Step 3
```

#### Step 2: Generate new SSH key (if needed)

```bash
# Generate Ed25519 SSH key (modern, secure, fast)
ssh-keygen -t ed25519 -C "interview@laptop"

# You'll see:
#   Generating public/private ed25519 key pair.
#   Enter file in which to save the key (/home/user/.ssh/id_ed25519):
# → Press ENTER (accept default location)

#   Enter passphrase (empty for no passphrase):
# → Press ENTER (no passphrase for interview speed)

#   Enter same passphrase again:
# → Press ENTER

# Output shows:
#   Your identification has been saved in /home/user/.ssh/id_ed25519
#   Your public key has been saved in /home/user/.ssh/id_ed25519.pub
```

#### Step 3: Copy your public key

```bash
# Display and copy your public key
cat ~/.ssh/id_ed25519.pub

# Output looks like:
#   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGx... interview@laptop
#
# Copy the ENTIRE line (starts with "ssh-ed25519", ends with your comment)
```

**Pro tip:** Use clipboard commands for easy copying:

```bash
# Linux/WSL (install xclip if needed):
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard

# macOS:
cat ~/.ssh/id_ed25519.pub | pbcopy

# Or manually select and copy from terminal
```

#### Step 4: Add SSH key to GitLab

**In GitLab web UI:**

1. Click your **avatar** (top right corner)
2. Select **"Preferences"**
3. In left sidebar, click **"SSH Keys"**
4. Paste your public key in the **"Key"** text box
5. **Title:** Auto-filled (e.g., "interview@laptop") - you can change it
6. **Usage type:** Leave as "Authentication & Signing" (default)
7. **Expiration date:** Leave blank or set to future date
8. Click **"Add key"**

**Confirmation:**
- You should see your new key listed with a green checkmark
- Shows: Key fingerprint, title, creation date

#### Step 5: Test SSH connection

```bash
# Test SSH connection to GitLab
ssh -T git@localhost -p 8022

# First time: You'll see a fingerprint warning:
#   The authenticity of host '[localhost]:8022' can't be established.
#   ED25519 key fingerprint is SHA256:...
#   Are you sure you want to continue connecting (yes/no/[fingerprint])?
# → Type: yes

# Expected output (success):
#   Welcome to GitLab, @root!

# If you see this, SSH is working! ✅
```

**Troubleshooting:**

```bash
# If connection fails, check:

# 1. GitLab is running
docker ps | grep gitlab

# 2. Port 8022 is accessible
nc -zv localhost 8022

# 3. SSH key permissions are correct
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

**Why SSH is better than HTTP/HTTPS for interviews:**
- ✅ **No password prompts** - uses key automatically
- ✅ **No Personal Access Token** - simpler setup
- ✅ **Industry standard** - shows professional knowledge
- ✅ **Faster** - no typing passwords repeatedly
- ✅ **Works on fresh machines** - same process everywhere

**Time:** 1-2 minutes total

---

## Step 3: Get the PHP Application

Choose the option that matches your interview scenario.

---

### Option A: Clone from External Repository (Interviewer Provides GitLab URL)

```bash
cd ~
git clone <their-gitlab-url> buggy-php-app
cd buggy-php-app

# Verify you're in the right directory
pwd
# Should show: /home/username/buggy-php-app

# Check what's in the repo
ls -la
```

**Use this if:** Interviewer provides a GitLab repository URL with buggy code already in it.

---

### Option B: Clone Empty Project from Local GitLab

```bash
# Use SSH (recommended - no password prompts)
cd ~
git clone ssh://git@localhost:8022/root/buggy-php-app.git
cd buggy-php-app

# Verify
pwd
# Should show: /home/username/buggy-php-app

ls -la
# Should show: empty directory with .git folder
```

**Alternative (HTTP):**
```bash
cd ~
git clone http://localhost:8090/root/buggy-php-app.git
cd buggy-php-app
```

**Use this if:** You created an empty GitLab project and will add files next.

---

### Option C: Push Existing App Folder to GitLab

**Scenario:** You already have a folder with PHP files (e.g., downloaded, copied, or provided as files) and need to push it to GitLab.

#### Step 1: Navigate to your existing app folder

```bash
# Example: Your PHP files are in ~/my-php-app/
cd ~/my-php-app

# Or wherever your files are located
cd /path/to/your/php/files

# Verify you're in the right place
pwd
ls -la
# Should see your PHP files (index.php, etc.)
```

#### Step 2: Initialize Git repository (if not already a git repo)

```bash
# Check if it's already a git repo
ls -la .git

# If you see "No such file or directory", initialize git:
git init

# Output:
#   Initialized empty Git repository in /home/user/my-php-app/.git/
```

#### Step 3: Configure Git user (if not configured)

```bash
# Set your name and email for commits
git config user.name "Your Name"
git config user.email "you@example.com"

# Or use interview-friendly defaults:
git config user.name "Interview Candidate"
git config user.email "interview@localhost"
```

#### Step 4: Add GitLab as remote

```bash
# Add remote using SSH (recommended)
git remote add origin ssh://git@localhost:8022/root/buggy-php-app.git

# Verify remote was added
git remote -v
# Should show:
#   origin  ssh://git@localhost:8022/root/buggy-php-app.git (fetch)
#   origin  ssh://git@localhost:8022/root/buggy-php-app.git (push)
```

**Alternative (HTTP):**
```bash
# Add remote using HTTP
git remote add origin http://localhost:8090/root/buggy-php-app.git

# Verify
git remote -v
```

**If you get "remote origin already exists" error:**
```bash
# Update existing remote
git remote set-url origin ssh://git@localhost:8022/root/buggy-php-app.git

# Verify
git remote -v
```

#### Step 5: Add and commit your files

```bash
# Check what files will be committed
git status

# Add all files
git add .

# Verify what's staged
git status

# Commit with a message
git commit -m "Initial commit: Add PHP application files"

# Output shows:
#   [main (root-commit) abc1234] Initial commit: Add PHP application files
#   X files changed, Y insertions(+)
```

#### Step 6: Push to GitLab

```bash
# Push to GitLab (SSH - no password prompt!)
git push -u origin main

# Or if your branch is called 'master':
git push -u origin master

# First time output:
#   Enumerating objects: X, done.
#   Counting objects: 100% (X/X), done.
#   ...
#   To ssh://git@localhost:8022/root/buggy-php-app.git
#    * [new branch]      main -> main
#   Branch 'main' set up to track remote branch 'main' from 'origin'.
```

**If push fails with "src refspec main does not match any" error:**
```bash
# Your local branch might be named 'master'
git branch

# Push using your actual branch name
git push -u origin master
```

**If push fails with "rejected" error:**
```bash
# GitLab has files you don't have locally (e.g., README from project creation)
# Pull first, then push
git pull origin main --allow-unrelated-histories

# Resolve any merge conflicts if they appear, then:
git push -u origin main
```

#### Step 7: Verify in GitLab

1. Open http://localhost:8090/root/buggy-php-app in browser
2. You should see your files listed
3. Click on files to verify content uploaded correctly

**Use this if:** Interviewer provides files in a folder/zip, or you already have PHP code locally.

---

### Quick Reference: Git Remote URLs

**Local GitLab (from this toolkit):**
- SSH: `ssh://git@localhost:8022/root/PROJECT-NAME.git`
- HTTP: `http://localhost:8090/root/PROJECT-NAME.git`

**External GitLab:**
- SSH: `git@gitlab.company.com:team/PROJECT-NAME.git`
- HTTP: `https://gitlab.company.com/team/PROJECT-NAME.git`

**Time:** 2-5 minutes (depending on option)

---

## Step 4: Debug PHP Application

Fix any PHP syntax errors or bugs in the application.

```bash
# Use the PHP debugging helper
~/lab-toolkit/helpers/php-debug.sh

# Or manually:
php -l *.php  # Check syntax
php index.php  # Run locally
```

**Time:** 10-20 minutes (varies by bugs)

---

## Step 5: Generate Deployment Files

Run the project generator to create Dockerfile, Jenkinsfile, and Kubernetes manifests.

```bash
# STAY in the app repo directory!
pwd
# Must show: ~/buggy-php-app (NOT ~/lab-toolkit!)

# Run the generator using FULL PATH to toolkit
~/lab-toolkit/2-generate-project.sh

# The script will auto-detect local GitLab if running

# Answer the prompts:
#
# If using LOCAL GitLab:
#   ─────────────────────────────────────
#   Local GitLab detected at http://localhost:8090
#   Use local GitLab? [Y/n]: Y
#   GitLab project path (e.g., root/php-app): root/buggy-php-app
#   GitLab username [root]: root
#   GitLab password [interview2024]: interview2024
#   ─────────────────────────────────────
#
# If using EXTERNAL GitLab:
#   ─────────────────────────────────────
#   Use local GitLab? [Y/n]: n
#   External GitLab URL: https://gitlab.company.local/team/buggy-php-app.git
#   GitLab username: your-username
#   GitLab password: your-token
#   ─────────────────────────────────────
#
# Other prompts (same for both):
#   PHP version [8.1]: 8.1
#   Application port [8080]: 8080
#   Application name [buggy-php-app]: buggy-php-app
#   Kubernetes namespace [default]: default
#   Git branch name [main]: main
#
#   Proceed with generation? [Y/n]: Y
#   Create Jenkins pipeline job now? [Y/n]: Y
#   Deploy to Kubernetes now? [Y/n]: Y
```

**Files Generated:**
- `Dockerfile` (multi-stage, optimized, non-root)
- `Jenkinsfile` (6-stage pipeline with GitLab integration)
- `k8s/deployment.yaml` (with health probes, resource limits)
- `k8s/service.yaml` (NodePort type)
- `.dockerignore`
- `quick-deploy.sh` (fast local deployment)
- `.env.interview` (credentials - git ignored)

**Time:** 2-5 minutes

---

## Step 6: Push to GitLab

Push your code and generated files to GitLab using SSH (no passwords needed!).

### If Repo Was Cloned from GitLab

```bash
# Check current remote
git remote -v

# If using HTTP, switch to SSH:
git remote set-url origin ssh://git@localhost:8022/root/buggy-php-app.git

# Add, commit, and push (NO PASSWORD PROMPT!)
git add .
git commit -m "Add CI/CD pipeline and fix PHP bugs"
git push -u origin main
```

### If New Repo (Initialized Locally)

```bash
# Initialize Git
git init
git config user.name "Your Name"
git config user.email "you@example.com"

# Add GitLab remote (SSH)
# For local GitLab:
git remote add origin ssh://git@localhost:8022/root/buggy-php-app.git
# For external GitLab:
git remote add origin git@gitlab.company.local:team/buggy-php-app.git

# Add, commit, and push (NO PASSWORD PROMPT!)
git add .
git commit -m "Add CI/CD pipeline and fix PHP bugs"
git push -u origin main
```

**Note:** SSH uses your key from Step 2 - no passwords or tokens needed!

### Alternative: HTTP with Personal Access Token (If SSH Not Available)

**Only use this if SSH doesn't work on the interview machine.**

```bash
# 1. Create Personal Access Token in GitLab:
#    http://localhost:8090/-/user_settings/personal_access_tokens
#    Scopes: api, read_repository, write_repository

# 2. Use HTTP remote
git remote set-url origin http://localhost:8090/root/buggy-php-app.git

# 3. Push (will prompt for credentials)
git push -u origin main
# Username: root
# Password: <paste-your-personal-access-token>
#           (NOT your root password!)
```

**Note:** SSH is recommended because it's faster and more reliable.

**Time:** 1-2 minutes

---

## Step 7: Jenkins Pipeline Execution

Jenkins automatically polls GitLab every 2 minutes for changes. You can also manually trigger the build.

```bash
# 1. Open Jenkins
open http://localhost:8080
# Login: admin / admin

# 2. Find your pipeline job
# Job name: buggy-php-app-pipeline (or your app name)

# 3. Option A: Wait for auto-trigger (max 2 minutes)
# Option B: Click "Build Now" to trigger immediately

# 4. Watch the pipeline execute:
# - Checkout code from GitLab
# - PHP syntax check
# - Docker build
# - Push to registry
# - Deploy to Kubernetes
# - Verify deployment
```

**Pipeline Stages:**
1. **Checkout**: Clone from GitLab using stored credentials
2. **PHP Syntax Check**: Validates all *.php files
3. **Build**: Creates Docker image in minikube's Docker
4. **Push**: No-op (image already in minikube)
5. **Deploy**: Applies K8s manifests or updates deployment
6. **Verify**: Checks deployment rollout status

**Time:** 5-10 minutes for first build

---

## Step 8: Verify Deployment

Check that your application is running in Kubernetes.

```bash
# Get service URL
minikube service buggy-php-app --url
# Example output: http://192.168.49.2:30123

# Test the application
curl $(minikube service buggy-php-app --url)
# Should show your PHP app output

# Check pods
kubectl get pods
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Check service
kubectl get svc
```

**Expected Output:**
- Pod status: Running
- Service accessible via NodePort URL
- Application responds to HTTP requests

**Time:** 2 minutes

---

## Step 9: Demonstrate Full CI/CD Flow

Make a change to demonstrate the full automation.

```bash
# 1. Make a small change to your code
echo "// Updated version" >> index.php

# 2. Commit and push
git add index.php
git commit -m "Update application"
git push origin main

# 3. Watch Jenkins auto-trigger
# Open: http://localhost:8080/job/buggy-php-app-pipeline/

# 4. Verify new deployment
kubectl get pods -w  # Watch pod recreation
curl $(minikube service buggy-php-app --url)  # Test new version
```

**Time:** 3-5 minutes

---

## Time Management Table

| Phase | Time | What | Where |
|-------|------|------|-------|
| Infrastructure Setup | 0:00-0:25 | Run 1-infra-setup.sh (includes GitLab initialization) | ~/lab-toolkit/ |
| GitLab Setup | 0:25-0:27 | Create project + add SSH key (1 min) | browser |
| Clone/Init Repo | 0:27-0:30 | Clone their repo OR init git | cd ~ then clone |
| Debug PHP | 0:30-0:50 | Fix PHP bugs | ~/buggy-php-app/ |
| Generate Files | 0:50-0:55 | Run 2-generate-project.sh, deploy | ~/buggy-php-app/ |
| Push to GitLab | 0:55-0:56 | git commit + push (SSH, no password!) | ~/buggy-php-app/ |
| Jenkins Build | 0:56-1:06 | Build pipeline (auto-triggered or manual) | browser |
| Verify | 1:06-1:08 | Test application, check K8s | terminal |
| Demo CI/CD | 1:08-1:13 | Make change, push, watch automation | full cycle |
| **Buffer** | 1:13-3:00 | Q&A, troubleshooting, deep dives | - |

**Total active work: ~1hr 15min**
**Buffer time: 1hr 45min** (58% buffer - very comfortable for 3-hour interview)

**Notes:**
- GitLab initialization (3-5 min) happens during infrastructure setup in parallel
- GitLab setup: 30 sec project creation + 30 sec SSH key setup
- SSH git push has NO password prompts (uses key automatically)
- Jenkins auto-triggers on push (polls every 2 minutes)

---

## Quick Reference Commands

### GitLab Commands
```bash
# Access GitLab UI
open http://localhost:8090
# Login: root / Kx9mPqR2wZ

# Git clone (HTTP)
git clone http://localhost:8090/root/project-name.git

# Git clone (SSH)
git clone ssh://git@localhost:8022/root/project-name.git

# Check GitLab health
curl http://localhost:8090/-/health
# Expected: {"status":"ok"}

# GitLab container logs
docker logs gitlab

# Restart GitLab
docker restart gitlab
```

### Jenkins Commands
```bash
# Access Jenkins UI
open http://localhost:8080
# Login: admin / admin

# Check Jenkins logs
docker logs jenkins

# Restart Jenkins
docker restart jenkins

# Check Jenkins can reach GitLab
docker exec jenkins curl http://gitlab:80/-/health
```

### Kubernetes Commands
```bash
# Get all resources
kubectl get all

# Get service URL
minikube service <app-name> --url

# Watch pods
kubectl get pods -w

# Check logs
kubectl logs <pod-name>

# Describe pod
kubectl describe pod <pod-name>

# Delete pod (forces recreation)
kubectl delete pod <pod-name>

# Apply manifests
kubectl apply -f k8s/
```

### Docker Commands
```bash
# List containers (host Docker)
docker ps

# Switch to minikube Docker
eval $(minikube docker-env)

# List images in minikube
docker images

# Switch back to host Docker
eval $(minikube docker-env -u)

# Build image in minikube
eval $(minikube docker-env)
docker build -t app:latest .
```

---

## Troubleshooting

### GitLab Not Responding

```bash
# Check if GitLab is still initializing
docker logs gitlab | tail -20
# Wait for: "gitlab Reconfigured!"

# Check health endpoint
curl http://localhost:8090/-/health
# Wait for: {"status":"ok"}

# If stuck > 10 minutes, restart
docker restart gitlab
```

### Jenkins Cannot Reach GitLab

```bash
# Check network
docker network inspect gitlab-jenkins-network
# Should show both gitlab and jenkins

# Test connectivity
docker exec jenkins curl -v http://gitlab:8090/-/health

# Reconnect if needed
docker network connect gitlab-jenkins-network gitlab
docker network connect gitlab-jenkins-network jenkins
```

### Pipeline Fails to Clone from GitLab

```bash
# Check credentials in Jenkins
# Go to: http://localhost:8080/credentials/

# Verify GitLab URL in Jenkins job config
# Should use: http://gitlab:80 (NOT localhost:8090)

# Check Jenkinsfile GIT_REPO variable
cat Jenkinsfile | grep GIT_REPO
# For local GitLab, should show: http://gitlab:80/root/project.git
```

### ImagePullBackOff in Kubernetes

```bash
# Ensure using minikube's Docker daemon
eval $(minikube docker-env)
docker images | grep your-app
# Should see your image

# If missing, rebuild
docker build -t your-app:latest .

# Delete pod to force recreation
kubectl delete pod <pod-name>
```

---

## Cleanup

To remove all deployed components and start fresh:

```bash
cd ~/lab-toolkit
./cleanup.sh
```

This removes:
- Jenkins and GitLab containers
- All Docker volumes
- minikube cluster
- Generated files

This preserves:
- Installed software (Docker, kubectl, minikube, PHP, Git)
- Base Docker images

---

## Next Steps

After successful demo:
- Review generated Dockerfile for optimizations
- Customize Jenkinsfile stages
- Add tests to PHP syntax check stage
- Configure ingress for production-like URLs
- Set up persistent volumes for database
- Explore Jenkins plugins for notifications
- Configure GitLab webhooks (faster than polling)

---

## Resources

- **QUICK-START.md**: Fast setup for interview day
- **INSTALLATION-GUIDE.md**: Detailed installation steps
- **docs/INTERVIEW-FLOW.md**: Detailed 3-hour timeline
- **docs/CHEATSHEET.md**: All Docker/kubectl/PHP/Git commands
- **docs/TROUBLESHOOTING.md**: Common issues and solutions
- **CLAUDE.md**: Technical architecture documentation
- **helpers/gitlab-helpers.sh**: GitLab command reference
