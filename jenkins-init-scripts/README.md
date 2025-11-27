# Jenkins Setup Scripts

This directory contains scripts for Jenkins deployment and configuration.

## Files

### 1. deploy-jenkins.sh
**Purpose:** Deploy and configure Jenkins container

**What it does:**
- Deploys Jenkins in HOST Docker (not minikube)
- Mounts Groovy init scripts for automation
- Installs Docker CLI and kubectl inside Jenkins
- Configures Docker socket permissions
- Copies kubeconfig for K8s access

**When to run:** Automatically called by `./1-infra-setup.sh`

**Output:**
- Jenkins at http://localhost:8080
- Credentials: admin / admin
- Plugins installed, security configured, 2 executors

---

### 2. Groovy Init Scripts (Auto-executed)

#### 01-install-plugins.groovy
- Installs essential plugins: Pipeline, Git, Docker, etc.
- Skips setup wizard
- Takes 2-3 minutes

#### 02-create-admin-user.groovy
- Creates admin/admin user
- Configures security settings

#### 03-configure-executors.groovy
- Sets executor count to 2

**Note:** These run automatically when Jenkins starts. Do not modify the numbering (01, 02, 03) as it determines execution order.

---

## Pipeline Job Creation

Pipeline jobs are NOT created during Jenkins setup. Instead:

**Option 1: Automated (Recommended)**
Run `./2-generate-project.sh` which will:
1. Generate Jenkinsfile, Dockerfile, K8s manifests
2. Prompt: "Create Jenkins pipeline job now? [Y/n]"
3. If yes, automatically creates:
   - GitLab/GitHub credentials in Jenkins
   - Pipeline job with correct URL, branch, namespace
   - SCM polling configured

**Option 2: Manual**
1. Go to http://localhost:8080/newJob
2. Create Pipeline job
3. Configure SCM settings manually

---

## File Separation Logic

| File | Purpose | When | Automatic? |
|------|---------|------|------------|
| `deploy-jenkins.sh` | Setup Jenkins | During 1-infra-setup.sh | ✅ Yes |
| `01-03-*.groovy` | Configure Jenkins | On Jenkins startup | ✅ Yes |
| `helpers/create-jenkins-job.sh` | Create pipeline job | After 2-generate-project.sh | ⚙️ Optional |

---

## Troubleshooting

**Jenkins not starting:**
```bash
docker logs jenkins
```

**Plugin installation failed:**
Check logs for Groovy script errors. Plugins may be installing in background - wait 5 minutes.

**Pipeline job creation failed:**
Ensure Jenkins is fully initialized (all plugins loaded). Wait a few minutes after startup.

---

## Customization

**Add more plugins:**
Edit `01-install-plugins.groovy`, add plugin IDs to the `plugins` array.

**Change admin password:**
Edit `02-create-admin-user.groovy`, modify `createAccount()` parameters.

**Adjust executors:**
Edit `03-configure-executors.groovy`, change `setNumExecutors()` value.

---

## Architecture

```
1-infra-setup.sh
    ↓
jenkins-init-scripts/deploy-jenkins.sh
    ↓
Jenkins container starts
    ↓
Auto-runs: 01-install-plugins.groovy
Auto-runs: 02-create-admin-user.groovy
Auto-runs: 03-configure-executors.groovy
    ↓
Jenkins ready: http://localhost:8080
    ↓
User runs: 2-generate-project.sh
    ↓
(Optional) Auto-creates pipeline job via helpers/create-jenkins-job.sh
```
