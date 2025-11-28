# Solutions - Broken Jenkinsfiles

---

## 01-syntax-error.jenkinsfile (3 bugs)

### Bug 1 - Line 18: Missing opening brace after `steps`
```groovy
// WRONG
steps
    sh 'echo "Testing..."'

// CORRECT
steps {
    sh 'echo "Testing..."'
```

### Bug 2 - Line 20: Extra closing brace
```groovy
// WRONG (two closing braces)
            }
        }

// CORRECT (one closing brace for steps, one for stage)
```
Actually, the bug is the missing `{` after `steps` which causes brace mismatch.

### Bug 3 - Line 27: Missing closing quote
```groovy
// WRONG
sh "kubectl set image deployment/myapp myapp=myapp:${IMAGE_TAG}

// CORRECT
sh "kubectl set image deployment/myapp myapp=myapp:${IMAGE_TAG}"
```

---

## 02-missing-steps.jenkinsfile (2 bugs)

### Bug 1 - Line 9: `git` command outside `steps` block
```groovy
// WRONG
stage('Checkout') {
    git url: 'http://gitlab.local/repo.git', branch: 'main'
}

// CORRECT
stage('Checkout') {
    steps {
        git url: 'http://gitlab.local/repo.git', branch: 'main'
    }
}
```

### Bug 2 - Line 21: `sh` command outside `steps` block
```groovy
// WRONG
stage('Deploy') {
    steps {
        echo "Deploying to production"
    }
    sh 'kubectl apply -f k8s/'  // Outside steps!
}

// CORRECT
stage('Deploy') {
    steps {
        echo "Deploying to production"
        sh 'kubectl apply -f k8s/'
    }
}
```

**Key Lesson:** ALL commands must be inside `steps { }` block.

---

## 03-wrong-conditional.jenkinsfile (2 bugs)

### Bug 1 - Line 17: Wrong syntax in `when` condition
```groovy
// WRONG (using = instead of :)
when {
    environment name: 'DEPLOY_ENV', value = 'staging'
}

// CORRECT
when {
    environment name: 'DEPLOY_ENV', value: 'staging'
}
```

### Bug 2 - Line 33: Assignment instead of comparison
```groovy
// WRONG (= is assignment, not comparison)
if (currentBuild.result = 'SUCCESS') {

// CORRECT
if (currentBuild.result == 'SUCCESS') {
```

**Key Lesson:** This is the same trap as PHP's `=` vs `==`. Always use `==` for comparison.

---

## 04-credentials-issue.jenkinsfile (2 bugs)

### Bug 1 - Lines 7-8: Hardcoded credentials in environment
```groovy
// WRONG - Credentials visible in pipeline code!
environment {
    DOCKER_USER = 'admin'
    DOCKER_PASS = 'secretpassword123'
}

// CORRECT - Use Jenkins credentials store
environment {
    DOCKER_CREDS = credentials('docker-hub-creds')
}
// Then use DOCKER_CREDS_USR and DOCKER_CREDS_PSW
```

### Bug 2 - Line 28: Echoing secret token
```groovy
// WRONG - Exposes token in logs!
withCredentials([string(credentialsId: 'kube-token', variable: 'TOKEN')]) {
    sh 'kubectl --token=$TOKEN apply -f k8s/'
    echo "Deployed with token: $TOKEN"  // SECURITY ISSUE!
}

// CORRECT - Never echo secrets
withCredentials([string(credentialsId: 'kube-token', variable: 'TOKEN')]) {
    sh 'kubectl --token=$TOKEN apply -f k8s/'
    echo "Deployed successfully"
}
```

**Key Lesson:** Never hardcode credentials. Never log secrets.

---

## 05-docker-issue.jenkinsfile (3 bugs)

### Bug 1 - Line 8: Single quotes prevent variable expansion
```groovy
// WRONG - Single quotes don't expand variables in environment block
environment {
    IMAGE_TAG = '${BUILD_NUMBER}'  // Literally "${BUILD_NUMBER}"
}

// CORRECT - Use double quotes for Groovy variable expansion
environment {
    IMAGE_TAG = "${BUILD_NUMBER}"
}
```

### Bug 2 - Lines 14-17: Single quotes in shell don't expand env vars
```groovy
// WRONG - Single quotes prevent expansion
sh '''
    echo "Building image: ${IMAGE_NAME}:${IMAGE_TAG}"
'''

// CORRECT - Use double quotes for variable expansion
sh """
    echo "Building image: ${IMAGE_NAME}:${IMAGE_TAG}"
"""
```

### Bug 3 - Line 21: Pushing :latest but built with :${IMAGE_TAG}
```groovy
// WRONG - Image was built with tag ${IMAGE_TAG}, not :latest
sh 'docker push ${IMAGE_NAME}:latest'

// CORRECT - Push the tag that was built, or tag it first
sh """
    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
    docker push ${IMAGE_NAME}:${IMAGE_TAG}
    docker push ${IMAGE_NAME}:latest
"""
```

### Bug 4 (Bonus) - Line 33: `returnStatus: false` doesn't make sense
```groovy
// WRONG - returnStatus should be true to capture exit code
def status = sh(
    script: 'kubectl rollout status deployment/myapp',
    returnStatus: false  // This returns stdout, not status
)
if (status != 0) {  // This comparison won't work

// CORRECT
def status = sh(
    script: 'kubectl rollout status deployment/myapp',
    returnStatus: true  // Returns exit code as integer
)
if (status != 0) {
    error("Deployment failed")
}
```

**Key Lessons:**
- `'single quotes'` = literal string (no expansion)
- `"double quotes"` = variable expansion in Groovy
- `'''triple single'''` = multi-line literal (no expansion in shell)
- `"""triple double"""` = multi-line with expansion

---

## Quick Reference: Quote Rules

| Context | Single `'...'` | Double `"..."` |
|---------|---------------|----------------|
| Groovy string | Literal | Expands `${VAR}` |
| Shell in `sh '...'` | Literal (shell expansion works) | Groovy expands first |
| Shell in `sh "..."` | N/A | Groovy expands, then shell |
| `'''...'''` | Multi-line literal | N/A |
| `"""..."""` | N/A | Multi-line, Groovy expands |

**Rule of thumb:** Use `"""..."""` when you need Jenkins variables in shell commands.
