# DevOps Interview Cheat Sheet

## 🚀 Quick Command Reference

### Setup Commands
```bash
# Pre-flight check (optional)
./0-preflight-check.sh

# Run infrastructure setup (Docker, kubectl, minikube, Jenkins, PHP)
./1-infra-setup.sh

# Generate project files + OPTIONAL AUTO-DEPLOYMENT + JENKINS JOB
./2-generate-project.sh
# Say YES to: Deploy now? [Y/n]
# Say YES to: Create Jenkins job? [Y/n]

# Verify setup
./3-verify-setup.sh

# Clean environment for testing/debugging
./cleanup.sh

# Make scripts executable
chmod +x *.sh helpers/*.sh
```

---

## 🐳 Docker Commands

### Build & Run
```bash
# Build image
docker build -t myapp:latest .

# Run container
docker run -p 8080:80 myapp:latest

# Run in background
docker run -d -p 8080:80 myapp:latest

# Build with tag
docker build -t myregistry/myapp:v1.0 .
```

### Image Management
```bash
# List images
docker images

# Remove image
docker rmi image-name

# Tag image
docker tag myapp:latest localhost:5000/myapp:latest

# Push to registry
docker push localhost:5000/myapp:latest
```

### Container Management
```bash
# List running containers
docker ps

# List all containers
docker ps -a

# Stop container
docker stop container-id

# Remove container
docker rm container-id

# View logs
docker logs container-id
docker logs -f container-id  # Follow logs

# Execute command in container
docker exec -it container-id /bin/bash

# Copy files
docker cp file.txt container-id:/path/
```

### Debugging
```bash
# Check container logs
docker logs container-id

# Inspect container
docker inspect container-id

# Check resource usage
docker stats

# Clean up
docker system prune -f        # Remove unused data
docker image prune -a         # Remove unused images
```

### Use Minikube Docker
```bash
# Switch to minikube's Docker daemon
eval $(minikube docker-env)

# Switch back to host Docker
eval $(minikube docker-env -u)
```

---

## ☸️ Kubernetes (kubectl) Commands

### Cluster Info
```bash
kubectl cluster-info
kubectl get nodes
kubectl version
```

### Pods
```bash
# List pods
kubectl get pods
kubectl get pods -A              # All namespaces
kubectl get pods -o wide         # More details

# Describe pod
kubectl describe pod pod-name

# Logs
kubectl logs pod-name
kubectl logs pod-name -f         # Follow logs
kubectl logs pod-name --previous # Previous instance

# Execute in pod
kubectl exec -it pod-name -- /bin/bash

# Delete pod
kubectl delete pod pod-name
```

### Deployments
```bash
# List deployments
kubectl get deployments

# Create deployment
kubectl create deployment myapp --image=myapp:latest

# Scale deployment
kubectl scale deployment myapp --replicas=3

# Update image
kubectl set image deployment/myapp myapp=myapp:v2

# Rollout status
kubectl rollout status deployment/myapp

# Rollout history
kubectl rollout history deployment/myapp

# Rollback
kubectl rollout undo deployment/myapp

# Restart deployment
kubectl rollout restart deployment/myapp

# Delete deployment
kubectl delete deployment myapp
```

### Services
```bash
# List services
kubectl get svc

# Expose deployment
kubectl expose deployment myapp --port=80 --type=NodePort

# Describe service
kubectl describe svc myapp

# Delete service
kubectl delete svc myapp

# Get service URL (minikube)
minikube service myapp --url
```

### Apply Resources
```bash
# Apply file
kubectl apply -f deployment.yaml

# Apply directory
kubectl apply -f k8s/

# Delete from file
kubectl delete -f deployment.yaml

# Create from file
kubectl create -f deployment.yaml
```

### Namespaces
```bash
# List namespaces
kubectl get namespaces

# Create namespace
kubectl create namespace dev

# Set default namespace
kubectl config set-context --current --namespace=dev

# Delete namespace
kubectl delete namespace dev
```

### Debugging
```bash
# Get events
kubectl get events
kubectl get events --sort-by='.lastTimestamp'

# Describe (detailed info + events)
kubectl describe pod pod-name
kubectl describe deployment deployment-name

# Port forward
kubectl port-forward pod/pod-name 8080:80
kubectl port-forward svc/service-name 8080:80

# Resource usage
kubectl top nodes
kubectl top pods

# Get all resources
kubectl get all
kubectl get all -A  # All namespaces
```

---

## 🔧 Minikube Commands

### Cluster Management
```bash
# Start cluster
minikube start

# Start with specific resources
minikube start --memory=4096 --cpus=2

# Stop cluster
minikube stop

# Delete cluster
minikube delete

# Status
minikube status

# Get IP
minikube ip
```

### Addons
```bash
# List addons
minikube addons list

# Enable addon
minikube addons enable ingress
minikube addons enable registry

# Disable addon
minikube addons disable ingress
```

### Services
```bash
# List services
minikube service list

# Get service URL
minikube service myapp --url

# Open service in browser
minikube service myapp
```

### Docker Daemon
```bash
# Use minikube's Docker
eval $(minikube docker-env)

# Stop using minikube's Docker
eval $(minikube docker-env -u)
```

### Dashboard
```bash
# Open Kubernetes dashboard
minikube dashboard
```

---

## 🐘 PHP Commands

### Syntax Check
```bash
# Check single file
php -l file.php

# Check all files
find . -name "*.php" -exec php -l {} \;

# Check excluding vendor
find . -name "*.php" -not -path "./vendor/*" -exec php -l {} \;
```

### Development Server
```bash
# Start built-in server
php -S localhost:8000

# Specify document root
php -S localhost:8000 -t public/
```

### Debugging
```bash
# Show PHP info
php -i

# Show loaded modules
php -m

# Check configuration
php -i | grep error

# Show PHP version
php --version
```

### In PHP Code
```php
<?php
// Display all errors
ini_set('display_errors', 1);
error_reporting(E_ALL);

// Debug variable
var_dump($variable);
print_r($array);

// Log to file
error_log("Debug message", 3, "/tmp/debug.log");
?>
```

---

## 🔨 Jenkins Commands

### Access Jenkins (PRE-CONFIGURED!)
```bash
# Jenkins is already set up during installation!
# Login credentials: admin / admin

# Jenkins URL
http://localhost:8080

# Note: No need to get initial password anymore!
# Admin user is pre-created with known credentials
```

### Jenkins Job Automation
```bash
# Auto-create Jenkins job (done by 2-generate-project.sh)
# Or manually create:
./helpers/create-jenkins-job.sh <app-name> <gitlab-url> <branch> <namespace>

# Example:
./helpers/create-jenkins-job.sh php-app https://gitlab.local/proj/app main default
```

### Jenkins CLI (Optional)
```bash
# Download CLI
wget http://localhost:8080/jnlpJars/jenkins-cli.jar

# List jobs
java -jar jenkins-cli.jar -s http://localhost:8080/ list-jobs

# Build job
java -jar jenkins-cli.jar -s http://localhost:8080/ build job-name
```

### Jenkins in Docker
```bash
# View Jenkins logs
docker logs jenkins
docker logs -f jenkins  # Follow

# Restart Jenkins
docker restart jenkins

# Stop Jenkins
docker stop jenkins

# Start Jenkins
docker start jenkins

# Backup Jenkins home
docker cp jenkins:/var/jenkins_home ./jenkins-backup
```

---

## 🔐 Git Commands

### Basic Operations
```bash
# Clone repository
git clone https://gitlab.company.local/project/app.git

# Check status
git status

# Add files
git add .
git add Dockerfile Jenkinsfile

# Commit
git commit -m "Add deployment files"

# Push
git push origin main

# Pull
git pull origin main
```

### Branches
```bash
# List branches
git branch

# Create branch
git checkout -b feature-branch

# Switch branch
git checkout main

# Merge branch
git merge feature-branch
```

### Config
```bash
# Set user
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# View config
git config --list
```

---

## 📋 Common Workflows

### AUTOMATED: Generate + Build + Deploy + Jenkins (NEW!)
```bash
# ONE SCRIPT does everything!
../2-generate-project.sh

# When prompted:
# - Enter GitLab URL, credentials, PHP version, etc.
# - Deploy to Kubernetes now? [Y/n]: y  ← Auto-deploys!
# - Create Jenkins job now? [Y/n]: y    ← Auto-creates!

# That's it! Everything is automated:
# ✅ Files generated
# ✅ Docker image built
# ✅ Deployed to K8s
# ✅ Jenkins job created
# ✅ Ready to push code!
```

### MANUAL: Build and Deploy to K8s (if needed)
```bash
# 1. Switch to minikube Docker
eval $(minikube docker-env)

# 2. Build image
docker build -t myapp:latest .

# 3. Apply K8s manifests
kubectl apply -f k8s/

# 4. Check deployment
kubectl get pods
kubectl get svc

# 5. Access service
minikube service myapp --url
```

### Debug Failed Deployment
```bash
# 1. Check pod status
kubectl get pods

# 2. Describe pod (see events)
kubectl describe pod pod-name

# 3. Check logs
kubectl logs pod-name

# 4. Check previous logs (if restarted)
kubectl logs pod-name --previous

# 5. Check events
kubectl get events --sort-by='.lastTimestamp'
```

### Update Deployment
```bash
# 1. Build new image
docker build -t myapp:v2 .

# 2. Update deployment
kubectl set image deployment/myapp myapp=myapp:v2

# 3. Watch rollout
kubectl rollout status deployment/myapp

# 4. Check pods
kubectl get pods
```

### Jenkins Pipeline Trigger (AUTOMATED!)
```bash
# 1. Commit changes
git add .
git commit -m "Fix bug"
git push origin main

# 2. Jenkins auto-polls every 5 minutes (pre-configured!)
# Or trigger manually: http://localhost:8080/job/<app-name>-pipeline/ → Build Now

# 3. Monitor in Jenkins Console Output
# Watch the 6 stages:
# - Pre-Flight Check
# - Checkout
# - PHP Syntax Check
# - Build
# - Deploy
# - Verify
```

---

## 🚨 Troubleshooting Commands

### Environment Reset (NEW!)
```bash
# Clean environment for fresh testing
./cleanup.sh
# Removes: Jenkins, minikube cluster, Docker images, generated files
# Preserves: Docker, kubectl, minikube binaries, PHP, Git

# Then re-run setup
./1-infra-setup.sh
```

### Docker Issues
```bash
# Docker not running
sudo service docker start          # Linux/WSL
# Or start Docker Desktop          # macOS

# Permission denied
sudo usermod -aG docker $USER      # Add user to docker group
newgrp docker                      # Activate without logout

# Clean up space
docker system prune -a -f
```

### Kubernetes Issues
```bash
# Pod not starting
kubectl describe pod pod-name      # Check events
kubectl logs pod-name              # Check logs

# ImagePullBackOff
eval $(minikube docker-env)        # Use minikube Docker
docker images                      # Verify image exists

# Service not accessible
kubectl get svc                    # Check service exists
minikube service myapp --url       # Get correct URL
kubectl get endpoints myapp        # Check endpoints exist
```

### Jenkins Issues
```bash
# Jenkins not starting
docker logs jenkins                # Check logs
docker restart jenkins             # Restart container

# Login issues
# Use: admin / admin (pre-configured!)

# Can't connect to Docker
docker exec jenkins docker ps      # Verify Docker access
# If fails: Check /var/run/docker.sock is mounted

# kubectl not found (shouldn't happen)
docker exec jenkins kubectl version  # Check if installed
# If missing, re-run 1-infra-setup.sh

# Job creation failed
./helpers/create-jenkins-job.sh <app-name> <gitlab-url> <branch> <namespace>
```

---

## 📝 Quick Environment Setup

### AUTOMATED WORKFLOW (NEW!)
```bash
# One-time setup
./1-infra-setup.sh        # Wait ~15 minutes

# Per project (FULLY AUTOMATED!)
cd your-project
../2-generate-project.sh
# Enter details, say YES to deployment and Jenkins
# DONE! Application deployed and Jenkins job created!

# Verify
kubectl get pods
minikube service <app-name> --url
curl $(minikube service <app-name> --url)
```

### MANUAL WORKFLOW (if needed)
```bash
# Complete setup step by step
./1-infra-setup.sh
cd your-project
../2-generate-project.sh
eval $(minikube docker-env)
docker build -t myapp:latest .
kubectl apply -f k8s/
kubectl get pods
minikube service myapp --url
```

---

## ⚡ NEW: Automation Features

**What's Automated:**
- ✅ Jenkins admin user (admin/admin)
- ✅ Jenkins plugins installation
- ✅ Docker + kubectl access in Jenkins
- ✅ Optional: Auto-build and deploy to K8s
- ✅ Optional: Auto-create Jenkins pipeline job
- ✅ Kubernetes security best practices
- ✅ Rolling updates configuration
- ✅ Health probes (startup, liveness, readiness)

**Time Savings:**
- Old process: ~70 minutes (manual Jenkins + deployment)
- New process: ~30 minutes (full automation)
- **Saved: 40 minutes per interview!**

**Helper Scripts:**
- `cleanup.sh` - Reset environment for testing
- `helpers/create-jenkins-job.sh` - Manually create Jenkins job
- `helpers/php-debug.sh` - Interactive PHP debugger
- `helpers/jenkins-setup.sh` - Jenkins configuration guide
- `helpers/k8s-helpers.sh` - kubectl command reference

---

**Print this page and keep it handy during the interview!**
