# DevOps Interview Toolkit - Workflows

Two workflows: **Testing/Practice** and **Interview Day**

---

## 🧪 TESTING FLOW (Practice at Home)

### Initial Setup (One-time)

```bash
# 1. Pre-flight check
./0-preflight-check.sh

# 2. Install infrastructure
./1-infra-setup.sh
# Wait ~15 minutes for Docker, minikube, Jenkins, PHP

# 3. Verify installation
./3-verify-setup.sh
# Should see all green checkmarks
```

### Practice Session (Repeatable)

```bash
# 1. Copy buggy PHP app
cd buged-php
./copy-for-practice.sh test-session-1
cd test-session-1

# 2. Debug PHP (time yourself!)
../helpers/php-debug.sh
# Option 1: Run syntax check
# Fix bugs in your editor
# Re-run until all pass

# 3. Copy Dockerfile (already included when using copy-for-practice.sh)
# Dockerfile is automatically copied to practice directory
# Review and edit if needed (usually no changes required)

# 4. Test Docker build locally (before K8s deployment)
eval $(minikube docker-env)
docker build -t test-app:latest .
docker run -d -p 8080:80 --name test-app test-app:latest
curl http://localhost:8080  # Should see app output
docker stop test-app && docker rm test-app

# 5. Generate deployment files and optionally auto-deploy
../2-generate-project.sh
# GitLab URL: http://test.local/test/app
# GitLab username: testuser
# GitLab password: [enter token]
# Branch: main
# PHP version: 8.1 (auto-detected from composer.json)
# Port: 80
# App name: test-app
# Namespace: default
# Deploy now? y (optional - auto-builds and deploys)
# Create Jenkins job? y (optional - auto-creates pipeline)

# If you chose manual deployment:
# (Already tested in step 4, just deploy to K8s)
# kubectl apply -f k8s/

# 6. Verify deployment
kubectl get pods
kubectl wait --for=condition=ready pod -l app=test-app --timeout=120s
minikube service test-app --url

# 7. Test application
curl $(minikube service test-app --url)

# 8. Test Jenkins pipeline (if created)
# Open http://localhost:8080 (login: admin/admin)
# Click on test-app-pipeline → Build Now

# 9. Cleanup
kubectl delete -f k8s/
cd ../..
rm -rf buged-php/test-session-1
```

### Full End-to-End Test

```bash
# Run the complete automated workflow with timing
time {
    cd buged-php
    ./copy-for-practice.sh e2e-test
    cd e2e-test
    # Fix all bugs (don't time this part manually)
    ../2-generate-project.sh
    # Say YES to auto-deployment and Jenkins job creation
    # Everything is automated: build → deploy → Jenkins setup
}

# Target: Complete in under 5 minutes (excluding bug fixing)
# Cleanup after
kubectl delete -f k8s/
```

### Clean Environment for Re-testing

```bash
# Use cleanup script to reset environment
../cleanup.sh
# Say YES to remove Jenkins, minikube, and generated files
# Preserves Docker, kubectl, minikube binaries, PHP, Git

# Then re-run setup
../1-infra-setup.sh
```

### Verification Checklist

After each practice session, verify:
- [ ] All PHP syntax errors found and fixed
- [ ] Docker image builds successfully
- [ ] Pods reach Running status
- [ ] Application accessible via minikube service URL
- [ ] No errors in pod logs: `kubectl logs -l app=test-app`

---

## 🎯 INTERVIEW FLOW (Interview Day)

### Phase 0: Setup (0-15 min)

```bash
# On their laptop, in toolkit directory

# 1. Make executable
chmod +x *.sh helpers/*.sh

# 2. Optional: Pre-flight check
./0-preflight-check.sh

# 3. Start installation (runs while you listen to requirements)
./1-infra-setup.sh
# Take notes while this runs:
# - GitLab URL: ________________
# - GitLab credentials: ________________
# - PHP version mentioned: ________________
# - Expected behavior: ________________
```

### Phase 1: Clone & Debug (15-35 min)

```bash
# 4. Clone their repository
git clone <THEIR-GITLAB-URL>
cd <PROJECT-NAME>

# 5. Check what you have
ls -la
cat README.md  # If exists
find . -name "*.php" | wc -l

# 6. Run PHP debugger
../helpers/php-debug.sh
# Choose: 1) Run syntax check
# Note all errors

# 7. Fix bugs in editor
# Fix syntax errors first (fatal)
# Then logic errors
# Then warnings

# 8. Verify fixes
../helpers/php-debug.sh
# Choose: 1) Run syntax check
# Should show: ✓ All PHP files passed

# 9. Test locally with PHP dev server (optional, if time permits)
php -S localhost:8000 &
curl http://localhost:8000
pkill -f "php -S"

# 10. Copy Dockerfile to cloned repo
cp ../lab-toolkit/Dockerfile ./
# OR if you practiced with buged-php:
cp ../lab-toolkit/buged-php/Dockerfile ./

# What to edit in Dockerfile (USUALLY NOTHING!):
# ✓ Already configured for standard PHP apps
# ✓ PHP version: 8.1 (change if app needs different version)
# ✓ PHP extensions: pdo_mysql, mbstring, exif, pcntl, bcmath, gd
# ✓ Port: 80 (Apache default)
# ✓ Health check: included
#
# Only edit if:
# - App requires different PHP version (line 2: FROM php:X.X-apache)
# - App needs additional PHP extensions (line 17: add to docker-php-ext-install)
# - App uses different port (line 34: EXPOSE port)

# 11. Build and test Docker image locally (IMPORTANT - verify before K8s deploy)
eval $(minikube docker-env)  # Point to minikube's Docker
docker build -t myapp:latest .
# Wait for build to complete...

# 12. Test the Docker container locally
docker run -d -p 8080:80 --name test-app myapp:latest
sleep 5
curl http://localhost:8080
# Should see your app's output!

# 13. Stop test container
docker stop test-app && docker rm test-app
```

### Phase 2: Containerize & Deploy (35-45 min) - **AUTOMATED!**

```bash
# 14. Generate deployment files + AUTO-DEPLOY + AUTO-CREATE JENKINS JOB
../2-generate-project.sh
# Enter their details:
# - GitLab URL: <from notes>
# - GitLab username: <from notes>
# - GitLab password/token: <from notes>
# - Branch name: main (or ask them)
# - PHP version: <check composer.json or ask>
# - Port: 80 (default for Apache)
# - App name: <repo-name>
# - Namespace: default
# - Deploy to K8s now? [Y/n]: y (AUTOMATED BUILD + DEPLOY!)
# - Create Jenkins job now? [Y/n]: y (AUTOMATED JENKINS SETUP!)

# Review generated files (while deployment happens)
cat Jenkinsfile  # Dockerfile already exists from step 10
ls k8s/

# 15. Verify automated deployment
kubectl get pods
kubectl get all
minikube service <app-name> --url
curl $(minikube service <app-name> --url)

# 16. Verify Jenkins job was created
# Open http://localhost:8080 (login: admin/admin - PRE-CONFIGURED!)
# Job "<app-name>-pipeline" should exist and be ready
```

### Phase 3: Git & Test CI/CD (45-60 min) - **ALREADY CONFIGURED!**

```bash
# 17. Commit to GitLab
git add Dockerfile Jenkinsfile k8s/ .dockerignore .gitignore
git commit -m "Add CI/CD pipeline and Kubernetes deployment"
git push origin main

# 18. Jenkins is ALREADY SET UP! (automated in Phase 2)
# Open browser: http://localhost:8080
# Login: admin / admin (PRE-CONFIGURED!)
# Pipeline job "<app-name>-pipeline" already exists

# 19. Test the CI/CD pipeline
# Make a small test change
echo "// Test CI/CD" >> index.php
git add index.php
git commit -m "Test CI/CD pipeline"
git push origin main

# 20. Trigger Jenkins build
# Option A: Wait for auto-polling (5 minutes)
# Option B: Click "Build Now" in Jenkins UI
# Watch console output in Jenkins

# 21. Verify full CI/CD workflow
kubectl get pods -w  # Watch for new pod rollout
kubectl describe deployment <app-name>
minikube service <app-name> --url
curl $(minikube service <app-name> --url)  # Should see your change!
```

### Phase 4: Demo & Explain (60-90 min)

```bash
# 22. Final verification
kubectl get all
kubectl logs -l app=<app-name>
curl $(minikube service <app-name> --url)

# 23. Show the complete automated workflow
# Demonstrate: GitLab push → Jenkins auto-build → K8s auto-deploy
```

**Be ready to explain:**
1. What bugs you found and how you fixed them
2. Why you chose specific Dockerfile instructions
3. How the Jenkinsfile pipeline works (stages)
4. How GitLab → Jenkins → K8s flow works
5. What you'd improve with more time

### Emergency Procedures

**If installation fails:**
```bash
./0-preflight-check.sh  # Check requirements
# Fix issues, then retry
./1-infra-setup.sh
```

**If Docker build fails:**
```bash
docker build --no-cache -t app:latest .
# Check Dockerfile syntax
cat Dockerfile
```

**If pod won't start:**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
# Common issues:
# - ImagePullBackOff: eval $(minikube docker-env) and rebuild
# - CrashLoopBackOff: Check logs for PHP errors
```

**If Jenkins can't deploy:**
```bash
# Verify kubectl access
docker exec jenkins kubectl get nodes
# If fails, recopy kubeconfig:
docker cp ~/.kube/config jenkins:/var/jenkins_home/.kube/config
docker exec jenkins chown -R jenkins:jenkins /var/jenkins_home/.kube
docker restart jenkins
```

**If Jenkins job creation fails:**
```bash
# Manually create with helper script
../helpers/create-jenkins-job.sh <app-name> <gitlab-url> <branch> <namespace>
```

**Full reset (fast with cleanup script):**
```bash
./cleanup.sh
# Say YES to all prompts (removes Jenkins, minikube, generated files)
# Preserves Docker, kubectl, minikube binaries

# Then re-setup
./1-infra-setup.sh
```

### Success Criteria

By end of interview:
- [ ] PHP bugs fixed (app runs without errors)
- [ ] Dockerfile builds successfully
- [ ] App running in Kubernetes
- [ ] Can access app: `minikube service <app-name> --url`
- [ ] Jenkins pipeline exists (bonus: successful build)
- [ ] Code committed to GitLab
- [ ] Can explain architecture and decisions

---

## 📊 Time Management

### Testing Flow
- Setup (one-time): 20 min
- Practice session: 30-45 min each
- Do 2-3 practice sessions minimum

### Interview Flow (WITH FULL AUTOMATION)
- Phase 0 (Setup): 15 min
- Phase 1 (Debug): 20 min
- Phase 2 (Deploy): 10 min **← AUTOMATED! (was 20 min)**
- Phase 3 (Jenkins): 15 min **← AUTOMATED! (was 35 min)**
- Phase 4 (Demo): 30 min
- **Total: ~90 min (1.5 hours)**
- **Buffer: 90 min for issues and Q&A!**
- **Time saved: 30 minutes with automation**

### Priority if Behind Schedule
1. PHP fixes (MUST) - 20 min
2. Docker + K8s (MUST) - 10 min **← Use auto-deployment!**
3. GitLab commit (MUST) - 5 min
4. Jenkins pipeline (NICE) - 5 min **← Use auto-creation!**
5. Full CI/CD test (SKIP if needed) - save time

**With automation, Jenkins setup is only 5 minutes!**
Say YES to auto-deployment and Jenkins job creation.

---

## 🔍 Quick Commands Reference

**Check status:**
```bash
docker ps                          # Docker containers
minikube status                    # Kubernetes cluster
kubectl get all                    # All K8s resources
curl http://localhost:8080         # Jenkins UI
```

**Debug commands:**
```bash
php -l *.php                       # PHP syntax check
docker logs <container>            # Container logs
kubectl logs <pod>                 # Pod logs
kubectl describe pod <pod>         # Pod details
```

**Cleanup commands:**
```bash
kubectl delete -f k8s/             # Remove K8s resources
docker system prune -f             # Clean Docker
minikube delete                    # Remove cluster
```

---

**For detailed troubleshooting:** `docs/TROUBLESHOOTING.md`
**For all commands:** `docs/CHEATSHEET.md`
**For detailed timeline:** `docs/INTERVIEW-FLOW.md`
