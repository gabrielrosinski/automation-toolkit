# Interview Day Workflow

## ⏱️ Complete Timeline (3 Hours Total)

This guide breaks down the interview into manageable time blocks with clear milestones.

---

## 🎯 Pre-Interview (Before You Arrive)

### Checklist
- [ ] Toolkit copied to USB drive or accessible via GitHub gist
- [ ] Scripts tested on similar environment
- [ ] Cheatsheet printed or saved offline
- [ ] Practiced full workflow at least twice
- [ ] Mental review of common PHP bugs
- [ ] Review of Jenkins pipeline syntax

### What to Bring
- USB drive with toolkit
- Notebook for notes
- Water bottle (stay hydrated!)
- Confidence! You've prepared well.

---

## 📝 Phase 1: Setup & Understanding (0:00 - 0:20)

**Time: 20 minutes**

### Minutes 0-5: Initial Setup
```bash
# While interviewer explains the task:
1. Copy toolkit to their laptop
2. Start infrastructure setup (runs unattended)
   ./1-infra-setup.sh
3. Listen carefully and take notes on:
   - GitLab URL
   - GitLab credentials
   - Any specific requirements
   - Expected outcomes
```

**What's Happening:**
- Docker installing
- minikube starting
- Jenkins deploying
- PHP installing

**You're Doing:**
- Understanding the task
- Asking clarifying questions
- Making notes

### Minutes 5-10: Read Requirements
While setup runs in background:
- [ ] Read any documentation they provide
- [ ] Note the PHP bugs they mention
- [ ] Understand expected functionality
- [ ] Ask about:
  - PHP version preference
  - Any specific dependencies
  - How they'll test the result

### Minutes 10-20: Clone & Initial Assessment
```bash
# Setup should be done by now
git clone https://their-gitlab.local/project/php-app
cd php-app

# Quick assessment
ls -la                          # See project structure
cat README.md                   # Read docs if available
find . -name "*.php" | wc -l    # Count PHP files
```

**Questions to Answer:**
- What type of application is this? (Web app, API, CLI?)
- How many files need attention?
- Is there a database component?
- Are there existing tests?

---

## 🐛 Phase 2: Debug PHP Code (0:20 - 0:40)

**Time: 20 minutes**

### Minutes 20-25: Syntax Check
```bash
# Run syntax checker
../helpers/php-debug.sh
# Choose option 1: Run syntax check

# Review all errors
find . -name "*.php" -exec php -l {} \; 2>&1 | grep -i error
```

**Common Issues to Look For:**
- Missing semicolons
- Unclosed brackets/parentheses
- Typos in variable names ($usre vs $user)
- Missing $ before variables

### Minutes 25-35: Fix Bugs & Test
```bash
# Start local PHP server in background
php -S localhost:8000 &

# Open in browser or curl
curl http://localhost:8000

# Or if you need to see in browser:
# Ask interviewer if you can open browser
```

**Fix Priority:**
1. **Fatal errors** (blocks execution)
2. **Parse errors** (syntax issues)
3. **Warnings** (logic issues)
4. **Notices** (undefined variables)

**Common PHP Bugs:**
```php
// ❌ Missing semicolon
echo "Hello"
// ✅ Fixed
echo "Hello";

// ❌ Undefined variable
echo $username;
// ✅ Fixed
$username = "admin";
echo $username;

// ❌ Wrong comparison
if ($count = 5)  // Assignment, always true
// ✅ Fixed
if ($count == 5)  // Comparison

// ❌ Missing quotes
$name = admin;
// ✅ Fixed
$name = "admin";
```

### Minutes 35-40: Verify Fixes
```bash
# Run syntax check again
find . -name "*.php" -exec php -l {} \; 2>&1 | grep "No syntax errors"

# Test application functionality
curl http://localhost:8000
# Or test manually in browser

# Kill PHP server when done
pkill -f "php -S"
```

---

## 🐳 Phase 3: Generate Files & Auto-Deploy (0:40 - 0:50) - **AUTOMATED!**

**Time: 10 minutes (down from 35 minutes!)**

### Minutes 40-50: Full Automation - Generate, Build, Deploy, Jenkins Setup
```bash
# Run project generator with FULL AUTOMATION
../2-generate-project.sh

# Enter when prompted:
GitLab URL: https://their-gitlab.local/project/php-app
GitLab username: <from notes>
GitLab password/token: <from notes>
PHP version: 8.1  # Or whatever they're using
App port: 80
App name: php-app
Namespace: default
Deploy to Kubernetes now? [Y/n]: y  # ← AUTO-BUILD & DEPLOY!
Create Jenkins pipeline job now? [Y/n]: y  # ← AUTO-CREATE JENKINS JOB!

# Script will automatically:
# 1. Generate all files (Dockerfile, Jenkinsfile, K8s manifests)
# 2. Build Docker image
# 3. Deploy to Kubernetes
# 4. Wait for deployment to be ready
# 5. Create Jenkins pipeline job
# 6. Show service URL
```

**Generated Files:**
- ✅ Dockerfile (with health checks, security)
- ✅ Jenkinsfile (6-stage pipeline with Pre-Flight checks)
- ✅ k8s/deployment.yaml (with security context, probes, rolling updates)
- ✅ k8s/service.yaml (NodePort)
- ✅ .dockerignore
- ✅ .env.interview (credentials, gitignored)

**What Happened Automatically:**
- ✅ Docker image built in minikube
- ✅ Kubernetes deployment created
- ✅ Service exposed via NodePort
- ✅ Deployment rolled out successfully
- ✅ Jenkins credentials added
- ✅ Jenkins pipeline job created

### Quick Review (while automation runs)
```bash
# Review generated files
cat Dockerfile  # Multi-stage build, health checks
cat Jenkinsfile  # 6 stages: Pre-Flight → Checkout → Test → Build → Deploy → Verify
cat k8s/deployment.yaml  # Security context, probes, resource limits
```

---

## ☸️ Phase 4: Verify Deployment (0:50 - 0:55) - **ALREADY DONE!**

**Time: 5 minutes (deployment already automated in Phase 3)**

### Minutes 50-55: Verify Automated Deployment
```bash
# Check deployment status (should already be Running)
kubectl get deployments
kubectl get pods
kubectl get svc

# Get service URL (displayed by script, but check again)
minikube service php-app --url

# Test the application
curl $(minikube service php-app --url)

# Verify Jenkins job exists
# Open http://localhost:8080 (login: admin/admin)
# Job "php-app-pipeline" should exist
```

**Quick Checks:**
- [ ] Pod status: Running
- [ ] Deployment: Available
- [ ] Service: Accessible
- [ ] Application: Returns expected response
- [ ] Jenkins job: Created and visible

**If Issues (rare with automation):**
```bash
# Pod not running?
kubectl describe pod $(kubectl get pods -l app=php-app -o name)

# Check logs
kubectl logs $(kubectl get pods -l app=php-app -o name)

# Re-run automated deployment
kubectl delete -f k8s/
../2-generate-project.sh  # Say Y to deployment
```

---

## 🔄 Phase 5: Test CI/CD Pipeline (0:55 - 1:10) - **ALREADY CONFIGURED!**

**Time: 15 minutes (down from 35 minutes!)**

### Minutes 55-60: Commit to GitLab
```bash
# Add generated files
git add Dockerfile Jenkinsfile k8s/ .dockerignore .gitignore

# Commit
git commit -m "Add CI/CD pipeline and K8s deployment"

# Push to GitLab
git push origin main
```

### Minutes 60-65: Jenkins is Already Set Up!
```bash
# Jenkins was PRE-CONFIGURED during installation:
# ✅ Admin user: admin/admin
# ✅ Plugins installed
# ✅ Docker access configured
# ✅ kubectl access configured

# Pipeline job was AUTO-CREATED in Phase 3:
# ✅ GitLab credentials added
# ✅ Pipeline job "php-app-pipeline" created
# ✅ SCM polling configured (every 2 minutes)

# Open Jenkins: http://localhost:8080
# Login: admin / admin
# Job "php-app-pipeline" should be visible
```

### Minutes 65-70: Test CI/CD Flow
```bash
# Make a small test change
echo "// Test CI/CD" >> index.php

# Commit and push
git add index.php
git commit -m "Test CI/CD pipeline"
git push origin main

# Option A: Wait for auto-polling (2 minutes)
# Option B: Trigger manually in Jenkins UI (faster)
```

### Minutes 70-75: Monitor Pipeline Execution
```bash
# In Jenkins UI:
# 1. Go to php-app-pipeline
# 2. Click "Build Now" (if not auto-triggered)
# 3. Click on build #1
# 4. Click "Console Output"
# 5. Watch the 6 stages execute
```

**Pipeline Stages (Automated):**
1. ✅ Pre-Flight Check (verify Docker, kubectl, create namespace)
2. ✅ Checkout (clone from GitLab)
3. ✅ PHP Syntax Check (validate all .php files)
4. ✅ Build Docker Image (with build number tag)
5. ✅ Deploy to Kubernetes (kubectl set image)
6. ✅ Verify Deployment (check rollout status)

---

## ✅ Phase 6: Verification & Demo (1:10 - 1:30)

**Time: 20 minutes**

### Minutes 70-80: Verify Pipeline Success
```bash
# Watch pipeline complete in Jenkins Console Output

# Verify deployment updated
kubectl get pods -w  # Watch for new pod rollout
kubectl describe deployment php-app

# Check new image deployed
kubectl get deployment php-app -o jsonpath='{.spec.template.spec.containers[0].image}'

# Test the updated application
curl $(minikube service php-app --url)
```

### Minutes 80-90: Demonstrate Complete Workflow
```bash
# Show the complete automated flow:

# 1. Application running in Kubernetes
kubectl get all
kubectl get pods -o wide
minikube service php-app --url
curl $(minikube service php-app --url)

# 2. Jenkins pipeline automation
# Open Jenkins UI: http://localhost:8080
# Show successful build with all 6 stages
# Show build history and console output

# 3. Application logs
kubectl logs $(kubectl get pods -l app=php-app -o name)

# 4. Kubernetes deployment details
kubectl describe deployment php-app
kubectl describe service php-app
```

### Minutes 90: Final Verification Checklist
- [ ] Application accessible and working
- [ ] All pods in Running state
- [ ] Jenkins pipeline successful (all stages green)
- [ ] Code committed to GitLab
- [ ] No errors in pod logs
- [ ] CI/CD automation working (push → build → deploy)

---

## 🎤 Phase 7: Q&A & Wrap Up (1:30 - 3:00)

**Time: 90 minutes (you have plenty of time!)**

### Be Ready to Explain:

**Architecture:**
- How GitLab → Jenkins → K8s flow works
- Why you chose specific Dockerfile instructions
- How the Jenkinsfile stages work
- Kubernetes deployment strategy

**Decisions:**
- Why PHP version X?
- Why these resource limits?
- Why NodePort vs LoadBalancer?
- Any trade-offs you made for time

**Automation Benefits:**
- How automation saved 30+ minutes
- Eliminated manual Jenkins configuration
- Removed error-prone manual steps
- Consistent, repeatable deployments

**Improvements:**
- What you'd add with more time:
  - Database integration
  - Secrets management (vault, sealed-secrets)
  - Ingress controller with TLS
  - Monitoring (Prometheus/Grafana)
  - Logging (ELK stack)
  - Security scanning (Trivy, Snyk)
  - Automated tests (PHPUnit)
  - GitLab webhooks for instant triggers
  - Multi-environment deployments (dev/staging/prod)

**Troubleshooting:**
- Issues you encountered
- How you debugged them
- What you learned

---

## 📊 Time Management Tips

### If Running Ahead of Schedule (You Will Be!):
With 90 minutes of buffer time, you can add:
- Implement proper secrets management
- Configure horizontal pod autoscaling
- Add ingress controller with custom domain
- Set up basic monitoring
- Implement automated rollback on failure
- Add comprehensive tests
- Create multiple environments (dev/staging)
- Add database integration
- Implement logging aggregation

### If Running Behind Schedule (Unlikely):
**Priority Order:**
1. ✅ PHP debugging (must work) - 20 min
2. ✅ Auto-deployment (use YES option) - 5 min **← FAST!**
3. ✅ GitLab commit (must work) - 5 min
4. ✅ Jenkins automation (use YES option) - 5 min **← FAST!**
5. ⚠️ Full CI/CD test (can skip) - 10 min

**With automation, you can complete core requirements in ~45 minutes!**

**Cut These First:**
- Multiple CI/CD test cycles
- Advanced security features
- Monitoring setup
- Multiple environments

---

## 🎯 Success Criteria

By the end, you should have:
- [ ] ✅ PHP application with bugs fixed
- [ ] ✅ Working Dockerfile (with health checks, security)
- [ ] ✅ Application running in Kubernetes (with probes, resource limits)
- [ ] ✅ Jenkins pipeline fully automated
- [ ] ✅ Full CI/CD flow working (GitLab → Jenkins → K8s)
- [ ] ✅ Code committed to GitLab
- [ ] ✅ Able to demonstrate complete automated flow
- [ ] ✅ Able to explain architecture and automation
- [ ] ✅ Handled with professionalism

**With automation, all criteria can be met in ~90 minutes!**

---

## 💡 Pro Tips

1. **Use automation:** Say YES to auto-deployment and Jenkins job creation
2. **Communicate:** Talk through what you're doing
3. **Ask questions:** Better to clarify than assume
4. **Stay calm:** If something breaks, debug methodically
5. **Time box:** Don't get stuck on one issue
6. **Show process:** Even if incomplete, show good methodology
7. **Document:** Add comments to explain decisions
8. **Test incrementally:** Don't wait until the end
9. **Leverage tools:** Use cleanup.sh for quick resets if needed
10. **Trust automation:** The scripts have error handling and validation

---

## ⚡ NEW: Time Savings with Full Automation

**Old Manual Process:**
- Phase 3 (Dockerfile + Build + Test): 15 min
- Phase 4 (K8s Deployment): 20 min
- Phase 5 (Jenkins Setup): 35 min
- **Total: 70 minutes**

**New Automated Process:**
- Phase 3 (Auto-Generate + Auto-Deploy + Auto-Jenkins): 10 min
- Phase 4 (Verify): 5 min
- Phase 5 (Test CI/CD): 15 min
- **Total: 30 minutes**

**Time Saved: 40 minutes!**

---

**Remember: They're evaluating your process as much as the result!**

**With full automation, you'll finish with 90+ minutes to spare for Q&A and enhancements.**

Good luck! 🚀
