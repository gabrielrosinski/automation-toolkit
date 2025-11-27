# Troubleshooting Guide

Common issues and solutions for the DevOps interview toolkit.

---

## ⚡ NEW: Auto-Fixed Issues (v2.0+)

These issues are **now automatically detected and fixed** by the 1-infra-setup.sh script:

### ✅ Docker Daemon Not Running
**Status**: Auto-fixed in setup script

The script now:
- Detects if Docker daemon is running even if Docker is installed
- Automatically starts Docker service on WSL/Linux
- Prompts user to start Docker Desktop on macOS
- Waits for Docker to become ready before proceeding

**Manual fix (if needed)**:
```bash
# WSL/Linux
sudo service docker start

# Verify
docker ps
```

---

### ✅ Minikube Kubelet Bootstrap Failure
**Status**: Auto-detected with recovery prompt

**Symptoms:**
- `failed to run Kubelet: unable to load bootstrap kubeconfig`
- `kubelet.service: Failed with result 'exit-code'`
- Kubelet restarting 100+ times

**Auto-Recovery:**
The script now:
1. Detects corrupted minikube installations automatically
2. Checks if Kubernetes API server is responding
3. Prompts to delete and recreate if broken
4. Retries minikube start with `--force` flag if first attempt fails
5. Verifies Kubernetes is actually healthy before continuing

**Manual recovery (if script fails)**:
```bash
# Use cleanup script
./cleanup.sh

# Or manual cleanup
minikube delete --all --purge
rm -rf ~/.minikube ~/.kube/config

# Restart fresh
minikube start --driver=docker --memory=4096 --cpus=2 --force
```

**Root Cause**: This happens when:
- Docker Desktop running in rootful mode with WSL2
- Network interruption during cluster initialization
- Previous corrupted installation not fully cleaned up

---

### ✅ Jenkins Deployment Validation Failure
**Status**: Auto-fixed with better error handling

**Symptoms:**
- Setup script reports "✓ Jenkins is running"
- But `http://localhost:8080` doesn't work
- `docker ps` shows no Jenkins container
- User gets "Setup Complete!" but Jenkins never deployed

**Root Cause (Fixed in v2.1)**:
1. `docker run` command could fail silently
2. Validation only checked if container exists, not if it's healthy
3. Errors in `docker exec` commands were suppressed to `/dev/null`

**Fixes Applied:**
1. **Explicit error checking** on `docker run` command
2. **Container health verification** 3 seconds after start
3. **Detailed error messages** with troubleshooting hints
4. **Jenkins HTTP health check** in validation (checks if service responds)
5. **Better logging** for each deployment step

**Now if Jenkins fails to deploy:**
- Script will immediately show error with container logs
- Validation will detect non-responsive Jenkins
- Clear guidance on how to debug (check port conflicts, view logs)

---

## 🔧 Infrastructure Setup Issues

### Docker Installation Fails

**Symptom:** Setup script fails during Docker installation

**On Linux/WSL:**
```bash
# Check if Docker service is running
sudo service docker status

# Start Docker
sudo service docker start

# Check if user is in docker group
groups | grep docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Test Docker
docker ps
```

**On macOS:**
- Install Docker Desktop manually: https://www.docker.com/products/docker-desktop
- Start Docker Desktop application
- Wait for Docker to fully start (whale icon in menu bar)
- Re-run setup script

**On WSL:**
```bash
# Ensure Docker Desktop has WSL2 integration enabled
# In Docker Desktop: Settings → Resources → WSL Integration
# Enable integration with your WSL distro

# Then start Docker service in WSL
sudo service docker start
```

---

### Minikube Won't Start

**Symptom:** `minikube start` hangs or fails

**Solution 1: Driver Issues**
```bash
# Check Docker driver is available
docker ps

# Start with explicit driver
minikube start --driver=docker --force

# If Docker driver doesn't work, try alternatives
minikube start --driver=virtualbox
```

**Solution 2: Cleanup Previous Installation**
```bash
# Delete existing cluster
minikube delete

# Remove cached files
rm -rf ~/.minikube

# Start fresh
minikube start --driver=docker
```

**Solution 3: Resource Issues**
```bash
# Start with lower resources
minikube start --memory=2048 --cpus=1

# Check available resources
free -h    # Memory
nproc      # CPUs
```

---

### Jenkins Container Fails to Start

**Symptom:** Jenkins container exits immediately

**Check logs:**
```bash
docker logs jenkins
```

**Common Causes:**

**Port 8080 Already in Use:**
```bash
# Check what's using port 8080
sudo lsof -i :8080
sudo netstat -tulpn | grep 8080

# Kill process or use different port
docker run -p 8081:8080 jenkins/jenkins:lts
```

**Permission Issues:**
```bash
# Fix Docker socket permissions
sudo chmod 666 /var/run/docker.sock

# Or run with proper permissions
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $(getent group docker | cut -d: -f3) \
  jenkins/jenkins:lts
```

---

## 🐳 Docker Build Issues

### ImagePullBackOff in Kubernetes

**Symptom:** Pods stuck in `ImagePullBackOff` or `ErrImagePull`

**Cause:** Kubernetes can't find the Docker image

**Solution:**
```bash
# Make sure you're using minikube's Docker daemon
eval $(minikube docker-env)

# Verify you're using minikube Docker
docker ps  # Should show minikube containers

# Rebuild image
docker build -t php-app:latest .

# Verify image exists in minikube
docker images | grep php-app

# Update deployment
kubectl delete -f k8s/deployment.yaml
kubectl apply -f k8s/deployment.yaml
```

**Alternative: Use imagePullPolicy: Never**
```yaml
# In k8s/deployment.yaml
spec:
  containers:
  - name: php-app
    image: php-app:latest
    imagePullPolicy: Never  # Add this line
```

---

### Docker Build Fails

**Symptom:** `docker build` command fails

**Common Issues:**

**1. Syntax Error in Dockerfile:**
```bash
# Check Dockerfile syntax
cat Dockerfile

# Common issues:
# - Typos in commands (e.g., RNU instead of RUN)
# - Missing backslashes in multi-line commands
# - Incorrect line endings (Windows CRLF vs Unix LF)
```

**2. Network Issues:**
```bash
# Can't download packages
# Check internet connection
ping -c 3 google.com

# Use different mirror if apt-get fails
# Add to Dockerfile:
RUN sed -i 's/archive.ubuntu.com/mirror.math.princeton.edu\/pub/g' /etc/apt/sources.list
```

**3. Layer Caching Issues:**
```bash
# Build without cache
docker build --no-cache -t php-app:latest .
```

---

### Can't Push to Registry

**Symptom:** `docker push` fails

**For Minikube Registry:**
```bash
# Enable registry addon
minikube addons enable registry

# Check registry is running
kubectl get pods -n kube-system | grep registry

# Port forward to access registry
kubectl port-forward -n kube-system service/registry 5000:80 &

# Tag and push
docker tag php-app:latest localhost:5000/php-app:latest
docker push localhost:5000/php-app:latest
```

---

## ☸️ Kubernetes Issues

### Pods Stuck in Pending

**Symptom:** Pods remain in `Pending` state

**Check why:**
```bash
kubectl describe pod <pod-name>

# Look for:
# - "Insufficient memory" or "Insufficient cpu"
# - "No nodes available"
# - PersistentVolumeClaim issues
```

**Solutions:**

**Insufficient Resources:**
```bash
# Check node capacity
kubectl describe nodes

# Reduce resource requests in deployment
# Edit k8s/deployment.yaml:
resources:
  requests:
    memory: "64Mi"    # Reduced from 128Mi
    cpu: "50m"        # Reduced from 100m
```

**Node Issues:**
```bash
# Check nodes are ready
kubectl get nodes

# Restart minikube if node not ready
minikube stop
minikube start
```

---

### CrashLoopBackOff

**Symptom:** Pod keeps restarting

**Debug:**
```bash
# Check pod logs
kubectl logs <pod-name>

# Check previous logs (before crash)
kubectl logs <pod-name> --previous

# Describe pod (see restart reason)
kubectl describe pod <pod-name>
```

**Common Causes:**

**1. Application Error:**
```bash
# PHP syntax error, fatal error, etc.
# Fix the code and rebuild

# Check with local PHP first
php -l index.php
```

**2. Wrong Port:**
```bash
# Check if app listens on correct port
# In Dockerfile: EXPOSE 80
# In deployment: containerPort: 80
# Must match!
```

**3. Health Check Failing:**
```yaml
# Temporarily disable health checks to debug
# Comment out in k8s/deployment.yaml:
# livenessProbe:
#   httpGet:
#     path: /
#     port: 80
```

---

### Service Not Accessible

**Symptom:** Can't access application via service URL

**Debug Steps:**

**1. Check Service Exists:**
```bash
kubectl get svc

# Should show your service with a NodePort or ClusterIP
```

**2. Check Endpoints:**
```bash
kubectl get endpoints <service-name>

# Should show pod IPs
# If empty, selector might be wrong
```

**3. Check Selector Matches:**
```bash
# Service selector must match pod labels
kubectl get svc <service-name> -o yaml | grep selector -A 2
kubectl get pods --show-labels

# Labels must match!
```

**4. Get Service URL:**
```bash
# For minikube
minikube service <service-name> --url

# Test with curl
curl $(minikube service <service-name> --url)
```

**5. Port Forwarding (Debugging):**
```bash
# Forward service port to localhost
kubectl port-forward svc/<service-name> 8080:80

# Test
curl http://localhost:8080
```

---

## 🔄 Jenkins Issues

### Can't Access Jenkins UI

**Symptom:** http://localhost:8080 doesn't work

**Check Jenkins is Running:**
```bash
docker ps | grep jenkins

# If not running:
docker start jenkins

# If doesn't exist:
./1-infra-setup.sh  # Run setup again
```

**Check Port:**
```bash
# Verify Jenkins is on port 8080
docker ps | grep jenkins

# Should show: 0.0.0.0:8080->8080/tcp

# Test connection
curl http://localhost:8080
```

---

### Jenkins Can't Connect to GitLab

**Symptom:** Pipeline fails at checkout stage

**Check Credentials:**
```bash
# In Jenkins:
# Manage Jenkins → Manage Credentials
# Verify gitlab-creds exists and is correct

# Test Git access manually:
git clone <gitlab-url>  # From terminal
```

**Network Issues:**
```bash
# Test from Jenkins container
docker exec jenkins curl <gitlab-url>

# If fails, check network connectivity
```

---

### Jenkins Can't Run Docker Commands

**Symptom:** Pipeline fails with "docker: command not found" or "permission denied"

**Solution 1: Docker Socket Permission:**
```bash
# Give Jenkins container access to Docker socket
docker exec -u root jenkins chmod 666 /var/run/docker.sock
```

**Solution 2: Docker Group:**
```bash
# Add jenkins user to docker group in container
docker exec -u root jenkins usermod -aG docker jenkins
docker restart jenkins
```

**Verify:**
```bash
# Test Docker from Jenkins container
docker exec jenkins docker ps
```

---

### Jenkins Can't Run kubectl

**Symptom:** Pipeline fails with "kubectl: command not found"

**Solution: Install kubectl in Jenkins:**
```bash
docker exec -u root jenkins bash -c "
  curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && \
  chmod +x kubectl && \
  mv kubectl /usr/local/bin/
"
```

**Copy Kubeconfig:**
```bash
docker exec jenkins mkdir -p /var/jenkins_home/.kube
docker cp ~/.kube/config jenkins:/var/jenkins_home/.kube/config
docker exec jenkins chown -R jenkins:jenkins /var/jenkins_home/.kube
```

**Verify:**
```bash
docker exec jenkins kubectl get nodes
```

---

## 🐘 PHP Issues

### Syntax Errors

**Common PHP Syntax Errors:**

**1. Missing Semicolon:**
```php
// ❌ Error
echo "Hello"

// ✅ Fixed
echo "Hello";
```

**2. Undefined Variable:**
```php
// ❌ Error
echo $username;

// ✅ Fixed
$username = "admin";
echo $username;
```

**3. Missing $:**
```php
// ❌ Error
name = "John";

// ✅ Fixed
$name = "John";
```

**4. Wrong Quotes:**
```php
// ❌ Error (using smart quotes)
$name = "John";  // These are not regular quotes!

// ✅ Fixed
$name = "John";  // Regular ASCII quotes
```

**Check All Files:**
```bash
find . -name "*.php" -exec php -l {} \; 2>&1 | grep "error"
```

---

### PHP Extensions Missing

**Symptom:** "Call to undefined function" error

**Check Available Extensions:**
```bash
php -m

# Or in Docker container:
docker exec <container> php -m
```

**Add to Dockerfile:**
```dockerfile
# Add more PHP extensions
RUN docker-php-ext-install pdo_mysql mysqli gd xml
```

---

## 🌐 Network Issues

### Can't Clone from GitLab

**Symptom:** `git clone` fails

**Check URL:**
```bash
# Try with curl first
curl <gitlab-url>

# If HTTPS issues, try HTTP (not recommended for prod)
git clone http://gitlab.company.local/project/app.git
```

**Credentials:**
```bash
# Clone with credentials in URL
git clone https://username:password@gitlab.company.local/project/app.git

# Or use SSH if available
git clone git@gitlab.company.local:project/app.git
```

---

### Webhook Not Working

**Symptom:** Jenkins doesn't auto-trigger on Git push

**Requirements:**
- Jenkins must be accessible from GitLab server
- `http://localhost:8080` won't work (localhost is GitLab's localhost)

**Solution:**
- Use IP address instead of localhost
- Or configure on same machine/network
- Or skip webhook and trigger manually

---

## 💾 General Issues

### Out of Disk Space

```bash
# Check disk usage
df -h

# Clean up Docker
docker system prune -a -f
docker volume prune -f

# Clean up minikube
minikube delete
minikube start
```

---

### Permission Denied Errors

```bash
# For Docker socket
sudo chmod 666 /var/run/docker.sock

# For files
chmod +x script.sh

# For directories
chmod 755 directory/
```

---

### Command Not Found

```bash
# Check if tool is installed
which docker
which kubectl
which minikube
which php

# If not found, install it
./1-infra-setup.sh  # Re-run setup
```

---

## 🆘 Emergency Procedures

### Complete Reset

If everything is broken, nuclear option:

```bash
# Stop and remove everything
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
minikube delete

# Clean Docker
docker system prune -a -f

# Re-run setup
./1-infra-setup.sh
```

---

### Quick Health Check

Run this to check all components:

```bash
echo "=== Docker ==="
docker ps

echo "=== Minikube ==="
minikube status

echo "=== Kubectl ==="
kubectl get nodes

echo "=== Jenkins ==="
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
echo ""

echo "=== PHP ==="
php --version
```

---

## 📞 Getting Help

### Useful Commands for Diagnosis

```bash
# System info
uname -a
free -h
df -h

# Docker info
docker version
docker info

# Kubernetes info
kubectl version
kubectl cluster-info

# View logs
docker logs <container-name>
kubectl logs <pod-name>
journalctl -u docker  # On systemd systems
```

### Interview Context

If stuck during interview:
1. **Stay calm** - It happens!
2. **Explain** what you're trying to do
3. **Show** your debugging process
4. **Ask** interviewer if they've seen this before
5. **Have backup** - show what you already accomplished

Remember: They're evaluating your problem-solving, not expecting perfection!

---

**Keep this guide handy during your interview! 📋**
