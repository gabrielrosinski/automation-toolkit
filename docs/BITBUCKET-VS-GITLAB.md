# Bitbucket vs GitLab - Quick Reference

The job mentions **Bitbucket On-Premise**, but this toolkit is designed for GitLab.
Here are the key differences you need to know.

---

## Key Differences Summary

| Feature | GitLab | Bitbucket |
|---------|--------|-----------|
| URL format | `http://gitlab.local/group/repo.git` | `http://bitbucket.local/scm/PROJECT/repo.git` |
| SSH URL | `git@gitlab.local:group/repo.git` | `ssh://git@bitbucket.local/PROJECT/repo.git` |
| Native CI | `.gitlab-ci.yml` | `bitbucket-pipelines.yml` |
| API endpoint | `/api/v4/` | `/rest/api/1.0/` |
| Webhooks | Settings → Webhooks | Repository Settings → Webhooks |
| Deploy Keys | Settings → Repository → Deploy Keys | Repository Settings → Access Keys |

---

## Jenkins + Bitbucket Integration

### Checkout from Bitbucket in Jenkinsfile

```groovy
// HTTP with credentials
stage('Checkout') {
    steps {
        git url: 'http://bitbucket.local/scm/PROJ/repo.git',
            branch: 'main',
            credentialsId: 'bitbucket-creds'
    }
}

// Or using checkout step for more control
stage('Checkout') {
    steps {
        checkout([
            $class: 'GitSCM',
            branches: [[name: '*/main']],
            userRemoteConfigs: [[
                url: 'http://bitbucket.local/scm/PROJ/repo.git',
                credentialsId: 'bitbucket-creds'
            ]]
        ])
    }
}
```

### Setting Up Bitbucket Credentials in Jenkins

1. **Manage Jenkins** → **Manage Credentials**
2. Click **(global)** → **Add Credentials**
3. **Kind:** Username with password
4. **Username:** Your Bitbucket username
5. **Password:** Your Bitbucket password (or App Password)
6. **ID:** `bitbucket-creds` (use this in Jenkinsfile)

### Bitbucket Webhook for Jenkins

1. In Bitbucket: **Repository Settings** → **Webhooks**
2. **URL:** `http://jenkins.local:8080/bitbucket-hook/`
3. **Events:** Repository Push
4. **Status:** Active

Install Jenkins plugin: **Bitbucket Plugin** or **Bitbucket Branch Source Plugin**

---

## URL Format Differences

### GitLab URLs
```
# HTTP
http://gitlab.local/group/project.git
http://gitlab.local/group/subgroup/project.git

# SSH
git@gitlab.local:group/project.git
```

### Bitbucket Server URLs
```
# HTTP (note: /scm/ in path)
http://bitbucket.local/scm/PROJECTKEY/repo.git

# SSH
ssh://git@bitbucket.local/PROJECTKEY/repo.git
ssh://git@bitbucket.local:7999/PROJECTKEY/repo.git  # Custom port
```

**Important:** Bitbucket uses PROJECT KEYS (uppercase), not group names!

---

## Common Bitbucket Commands

```bash
# Clone from Bitbucket Server
git clone http://bitbucket.local/scm/PROJ/myrepo.git

# Add remote
git remote add origin http://bitbucket.local/scm/PROJ/myrepo.git

# Push to Bitbucket
git push -u origin main

# Check remote URL
git remote -v
```

---

## If Interview Uses Bitbucket

### Quick Adaptation Steps

1. **Change URL format** in Jenkinsfile:
   ```groovy
   // Change from GitLab:
   GIT_REPO = 'http://gitlab.local/group/repo.git'

   // To Bitbucket:
   GIT_REPO = 'http://bitbucket.local/scm/PROJ/repo.git'
   ```

2. **Update credentials** setup in Jenkins

3. **Webhook URL** might differ:
   - GitLab: `http://jenkins:8080/gitlab-webhook/`
   - Bitbucket: `http://jenkins:8080/bitbucket-hook/`

### Modified `create-jenkins-job.sh` for Bitbucket

If using Bitbucket, modify the job creation script:

```bash
# Replace GitLab URL pattern with Bitbucket
GIT_URL="http://bitbucket.local/scm/${PROJECT_KEY}/${REPO_NAME}.git"
```

---

## Bitbucket REST API Basics

```bash
# List projects
curl -u admin:admin http://bitbucket.local/rest/api/1.0/projects

# List repos in project
curl -u admin:admin http://bitbucket.local/rest/api/1.0/projects/PROJ/repos

# Get repo details
curl -u admin:admin http://bitbucket.local/rest/api/1.0/projects/PROJ/repos/myrepo

# Create webhook
curl -u admin:admin -X POST \
    -H "Content-Type: application/json" \
    -d '{"name":"Jenkins","url":"http://jenkins:8080/bitbucket-hook/","events":["repo:refs_changed"]}' \
    http://bitbucket.local/rest/api/1.0/projects/PROJ/repos/myrepo/webhooks
```

---

## Bitbucket Pipeline (Native CI) - FYI Only

The interview uses **Jenkins**, not Bitbucket Pipelines. But for reference:

```yaml
# bitbucket-pipelines.yml
image: php:8.1

pipelines:
  default:
    - step:
        name: Build and Test
        script:
          - php -l *.php
          - docker build -t myapp .
        services:
          - docker

  branches:
    main:
      - step:
          name: Deploy
          script:
            - kubectl apply -f k8s/
```

**Remember:** Interview uses Jenkins for CI/CD, Bitbucket only for Git!

---

## Quick Conversion Checklist

When switching from GitLab to Bitbucket:

- [ ] Update Git URL format (`/scm/PROJECT/repo.git`)
- [ ] Update credentials in Jenkins
- [ ] Change webhook plugin (if used)
- [ ] Update any API calls
- [ ] Verify SSH URL format if using SSH

---

## Interview Tip

If they give you a Bitbucket URL, the format tells you everything:

```
http://bitbucket.company.local/scm/DEVOPS/php-app.git
│                              │   │      │
│                              │   │      └─ Repository name
│                              │   └─ Project key (usually uppercase)
│                              └─ Bitbucket Server marker
└─ Server URL
```

Use this to construct your Jenkins job configuration!
