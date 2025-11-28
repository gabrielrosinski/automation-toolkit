# Jenkins Cheatsheet for Interview

## Pipeline Syntax Quick Reference

### Declarative Pipeline Structure
```groovy
pipeline {
    agent any                    // Where to run (any, none, label, docker)

    environment {                // Define env vars
        MY_VAR = 'value'
        CREDS = credentials('cred-id')  // From Jenkins credentials
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()             // Add timestamps to logs
        skipDefaultCheckout()    // Don't auto-checkout
    }

    stages {
        stage('Build') {
            steps {
                sh 'echo "building..."'
            }
        }
    }

    post {
        always { }    // Always runs
        success { }   // Only on success
        failure { }   // Only on failure
        cleanup { }   // After all other post conditions
    }
}
```

### Common Steps

```groovy
// Shell commands
sh 'single command'
sh '''
    multi
    line
    command
'''
sh """
    command with ${VARIABLE}
"""

// Checkout from Git
checkout scm  // Uses job's configured SCM
git url: 'http://gitlab/repo.git', branch: 'main'
git url: 'http://gitlab/repo.git', credentialsId: 'my-creds'

// File operations
writeFile file: 'config.txt', text: 'content'
readFile 'config.txt'
fileExists 'path/to/file'

// Docker
docker.build('image:tag')
docker.image('image:tag').push()
docker.withRegistry('https://registry', 'cred-id') { }

// Kubernetes
kubernetesDeploy configs: 'k8s/*.yaml', kubeconfigId: 'kubeconfig'
```

### Conditional Execution

```groovy
stage('Deploy') {
    when {
        branch 'main'                    // Only on main branch
        // OR
        expression { return env.BUILD == 'true' }
        // OR
        environment name: 'DEPLOY', value: 'true'
        // OR
        anyOf {
            branch 'main'
            branch 'develop'
        }
    }
    steps {
        // ...
    }
}
```

### Credentials

```groovy
// Username + Password
withCredentials([usernamePassword(
    credentialsId: 'my-creds',
    usernameVariable: 'USER',
    passwordVariable: 'PASS'
)]) {
    sh 'curl -u $USER:$PASS http://api'
}

// Secret Text
withCredentials([string(
    credentialsId: 'api-token',
    variable: 'TOKEN'
)]) {
    sh 'curl -H "Authorization: $TOKEN" http://api'
}

// SSH Key
withCredentials([sshUserPrivateKey(
    credentialsId: 'ssh-key',
    keyFileVariable: 'KEY_FILE'
)]) {
    sh 'ssh -i $KEY_FILE user@host'
}
```

### Parallel Execution

```groovy
stage('Test') {
    parallel {
        stage('Unit Tests') {
            steps {
                sh 'npm test'
            }
        }
        stage('Integration Tests') {
            steps {
                sh 'npm run test:integration'
            }
        }
    }
}
```

### Input/Approval

```groovy
stage('Deploy to Prod') {
    input {
        message "Deploy to production?"
        ok "Deploy"
        parameters {
            string(name: 'VERSION', defaultValue: 'latest')
        }
    }
    steps {
        sh "deploy --version=${VERSION}"
    }
}
```

---

## Common Interview Tasks

### Task 1: Add a Stage
"Add a test stage that runs before build"

```groovy
stage('Test') {
    steps {
        sh 'npm test'
    }
}
```

### Task 2: Conditional Deployment
"Only deploy on main branch"

```groovy
stage('Deploy') {
    when {
        branch 'main'
    }
    steps {
        sh 'kubectl apply -f k8s/'
    }
}
```

### Task 3: Add Credentials
"Use Docker Hub credentials for push"

```groovy
stage('Push') {
    steps {
        withCredentials([usernamePassword(
            credentialsId: 'dockerhub',
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS'
        )]) {
            sh '''
                echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                docker push myimage:latest
            '''
        }
    }
}
```

### Task 4: Fix Failing Pipeline
Common issues and fixes:

| Error | Cause | Fix |
|-------|-------|-----|
| `WorkflowScript: 1: Missing required...` | Wrong syntax | Check brackets, quotes |
| `No such DSL method 'sh'` | Outside steps block | Move into `steps { }` |
| `Permission denied` | Missing execute permission | `chmod +x script.sh` |
| `docker: not found` | Docker not in PATH | Install Docker in agent |
| `kubectl: command not found` | kubectl not installed | Install or use full path |

---

## Jenkins UI Navigation

### Creating a Pipeline Job
1. New Item → Pipeline → Enter name → OK
2. Scroll to Pipeline section
3. Definition: "Pipeline script from SCM"
4. SCM: Git
5. Repository URL: `http://gitlab.local/group/repo.git`
6. Credentials: Add if needed
7. Branch: `*/main`
8. Script Path: `Jenkinsfile`
9. Save

### Adding Credentials (UI)
1. Manage Jenkins → Manage Credentials
2. Click "(global)" under Jenkins
3. Add Credentials
4. Kind: Username with password / Secret text / SSH key
5. Fill in fields, set ID
6. Save

### Adding Credentials (Groovy - Script Console)
```groovy
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.plugins.credentials.domains.*

def store = Jenkins.instance.getExtensionList(
    'com.cloudbees.plugins.credentials.SystemCredentialsProvider'
)[0].getStore()

def credentials = new UsernamePasswordCredentialsImpl(
    CredentialsScope.GLOBAL,
    "my-credential-id",
    "Description",
    "username",
    "password"
)

store.addCredentials(Domain.global(), credentials)
```

---

## Troubleshooting Commands

```bash
# Check Jenkins container logs
docker logs jenkins -f

# Execute commands inside Jenkins
docker exec -it jenkins bash

# Test Docker access from Jenkins
docker exec jenkins docker ps

# Test kubectl access from Jenkins
docker exec jenkins kubectl get nodes

# Restart Jenkins
docker restart jenkins

# Check Jenkins home contents
docker exec jenkins ls -la /var/jenkins_home

# View job workspace
docker exec jenkins ls -la /var/jenkins_home/workspace/
```

---

## API Calls (Useful for Automation)

```bash
# Get CSRF crumb
CRUMB=$(curl -s -u admin:admin \
    "http://localhost:8080/crumbIssuer/api/json" | jq -r '.crumb')

# Trigger build
curl -X POST -u admin:admin \
    -H "Jenkins-Crumb: $CRUMB" \
    "http://localhost:8080/job/my-job/build"

# Get build status
curl -s -u admin:admin \
    "http://localhost:8080/job/my-job/lastBuild/api/json" | jq '.result'

# List all jobs
curl -s -u admin:admin \
    "http://localhost:8080/api/json?tree=jobs[name]"
```

---

## Common Mistakes in Interviews

1. **Forgetting `steps` block** - All commands must be inside `steps { }`
2. **Using `=` instead of `==`** in when conditions
3. **Not quoting variables** in shell commands: `sh "echo ${VAR}"` not `sh 'echo ${VAR}'`
4. **Missing credentials setup** before using them
5. **Forgetting `returnStatus: true`** when checking command exit codes
6. **Not handling failures** - Always add `post { failure { } }` block
