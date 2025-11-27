# Jenkins Init Scripts

These Groovy scripts are automatically executed when Jenkins starts for the first time. They provide full automation of Jenkins setup, eliminating the need for manual configuration through the setup wizard.

## How It Works

These scripts are mounted into the Jenkins container at:
```
/usr/share/jenkins/ref/init.groovy.d/
```

Jenkins automatically executes all `.groovy` files in this directory during initialization.

## Scripts

### 01-install-plugins.groovy
**Purpose:** Install essential Jenkins plugins automatically

**What it does:**
- Skips the setup wizard
- Installs these plugins:
  - `workflow-aggregator` - Pipeline support
  - `git` - Git integration
  - `credentials-binding` - Secure credential management
  - `docker-workflow` - Docker pipeline steps
  - `pipeline-stage-view` - Better pipeline visualization
  - `timestamper` - Timestamps in console logs

**Why these plugins:**
- Required for running the generated Jenkinsfile
- Enable Docker builds and Kubernetes deployments
- Provide better UX for pipeline management

### 02-create-admin-user.groovy
**Purpose:** Create admin user automatically

**What it does:**
- Creates user: `admin` / `admin`
- Configures security realm
- Sets authorization strategy
- Disables anonymous access

**Security Note:**
- Default credentials are `admin/admin`
- Change these in production environments
- For interview/demo purposes, these simple credentials are acceptable

### 03-configure-executors.groovy
**Purpose:** Set executor count

**What it does:**
- Configures Jenkins to run 2 jobs in parallel
- Sufficient for interview demo purposes
- Can be adjusted based on system resources

### 04-create-pipeline-job.groovy
**Purpose:** Automatically create PHP application pipeline job

**What it does:**
- Creates pipeline job named `php-app-pipeline`
- Configures Git SCM with placeholder URL
- Sets up SCM polling every 2 minutes (`H/2 * * * *`)
- References `Jenkinsfile` in repository root
- Expects credentials ID: `gitlab-creds`

**What happens when triggered:**
1. Pulls latest code from GitLab
2. Checks PHP syntax
3. Builds Docker image (in minikube's Docker)
4. Deploys to Kubernetes (rolling update)
5. Verifies deployment

**User must configure:**
- Update Git repository URL in job configuration
- Create `gitlab-creds` credential in Jenkins
- Ensure repository has a `Jenkinsfile` in root

## Usage

These scripts are automatically used by `deploy-jenkins.sh`:

```bash
# Script mounts this directory into Jenkins container
-v "$INIT_SCRIPTS_DIR":/usr/share/jenkins/ref/init.groovy.d:ro
```

The `:ro` flag makes it read-only for security.

## Customization

To modify the automation:

1. **Add more plugins:**
   Edit `01-install-plugins.groovy`, add plugin IDs to the `plugins` array

2. **Change admin credentials:**
   Edit `02-create-admin-user.groovy`, change `createAccount()` parameters

3. **Adjust executors:**
   Edit `03-configure-executors.groovy`, change `setNumExecutors()` value

4. **Add new automation:**
   Create new `.groovy` files (will be executed in alphabetical order)

## Debugging

If Jenkins fails to start after modifications:

1. Check container logs:
   ```bash
   docker logs jenkins
   ```

2. Look for Groovy errors in the logs

3. Verify script syntax:
   ```bash
   groovy -c jenkins-init-scripts/01-install-plugins.groovy
   ```

4. Check Jenkins init logs:
   ```bash
   docker exec jenkins cat /var/jenkins_home/logs/jenkins.log
   ```

## References

- [Jenkins Init Scripts Documentation](https://www.jenkins.io/doc/book/managing/groovy-hook-scripts/)
- [Jenkins Plugin Manager API](https://javadoc.jenkins.io/plugin/plugin/)
- [Jenkins Security API](https://javadoc.jenkins.io/jenkins/model/Jenkins.html)
