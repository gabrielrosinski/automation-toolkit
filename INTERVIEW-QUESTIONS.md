# Interview Day - Questions to Ask

## 🔴 CRITICAL (Ask Immediately - Blocking)

These are **must-have** before you can start:

### 1. Git Repository Access
- [ ] **GitLab/GitHub URL**: Full clone URL (e.g., `https://gitlab.company.com/interview/buggy-app.git`)
- [ ] **Username**: Your login username
- [ ] **Password/Token**: Access token or password
- [ ] **Branch name**: Which branch to work on? (usually `main` or `master`)
- [ ] **Permissions**: Do I have push access? Or just read-only?

### 2. Environment & Setup
- [ ] **Internet access**: WiFi credentials? Any proxy/VPN needed?
- [ ] **Laptop OS**: What OS is on this laptop? (Windows/Linux/macOS)
- [ ] **Installation permissions**: Can I install Docker, kubectl, minikube, Jenkins?
- [ ] **Sudo/Admin access**: Do I have sudo/administrator privileges?

### 3. Time & Scope
- [ ] **Total time**: How long do I have? (e.g., 3 hours)
- [ ] **Priority order**: What's most important? (Bugs > Docker > K8s > Jenkins?)
- [ ] **Required deliverables**: What MUST be done vs nice-to-have?
- [ ] **Can I use automation**: Can I use my pre-built toolkit/scripts?

---

## 🟡 IMPORTANT (Ask Early - Affects Implementation)

These affect how you build/configure things:

### 4. Application Details
- [ ] **PHP version**: What PHP version does the app require? (check `composer.json` or ask)
- [ ] **Expected behavior**: What should the app do when working correctly?
- [ ] **Test data/URLs**: Are there specific endpoints I should test?
- [ ] **Database needed**: Does the app need a database? MySQL/PostgreSQL?
- [ ] **Database credentials**: If yes, what are the connection details?
  - Host: `_________________`
  - Database name: `_________________`
  - Username: `_________________`
  - Password: `_________________`
- [ ] **Environment variables**: Any `.env` file or config needed?
- [ ] **Special dependencies**: Any non-standard PHP extensions required?

### 5. Containerization
- [ ] **Base image preference**: Any preference for PHP base image?
- [ ] **Port**: What port should the app run on? (default: 80)
- [ ] **Registry**: Should I push to a registry? Or use local minikube?
- [ ] **Image naming**: Any naming convention? (e.g., `company/app-name:tag`)

### 6. Kubernetes Deployment
- [ ] **Namespace**: Which K8s namespace to use? (default: `default`)
- [ ] **Cluster access**: Existing cluster? Or should I create one (minikube)?
- [ ] **Resource limits**: Any CPU/memory limits required?
  - Default: 100m CPU, 128Mi memory (requests)
  - Default: 200m CPU, 256Mi memory (limits)
- [ ] **Replicas**: How many pod replicas? (default: 1)
- [ ] **Service type**: NodePort, LoadBalancer, or ClusterIP?
- [ ] **Ingress**: Do you want an Ingress configured?
- [ ] **Labels/annotations**: Any required labels or annotations?

### 7. CI/CD Pipeline
- [ ] **Jenkins required**: Must I use Jenkins? Or can I use GitHub Actions/GitLab CI?
- [ ] **Jenkins access**: Existing Jenkins? Or should I deploy one?
- [ ] **Pipeline stages**: Any specific stages you want to see?
  - Syntax check ✓
  - Unit tests?
  - Security scanning?
  - Code quality checks?
- [ ] **Auto-deploy**: Should pipeline auto-deploy? Or require manual approval?
- [ ] **Webhook/polling**: Git webhook or polling for auto-trigger?

---

## 🟢 NICE TO HAVE (Ask if Time Permits)

These are optional but show thoroughness:

### 8. Monitoring & Observability
- [ ] **Logging**: Should I set up logging? (stdout is default)
- [ ] **Monitoring**: Any monitoring tools? (Prometheus, Grafana?)
- [ ] **Health checks**: Liveness/readiness probe paths?
- [ ] **Alerts**: Any alerting requirements?

### 9. Security & Best Practices
- [ ] **Security scanning**: Should I scan Docker images for vulnerabilities?
- [ ] **Secret management**: How to handle secrets? (K8s secrets, vault?)
- [ ] **RBAC**: Any specific K8s RBAC requirements?
- [ ] **Network policies**: Any network isolation needed?

### 10. Documentation & Presentation
- [ ] **Documentation**: Should I create a README with setup instructions?
- [ ] **Architecture diagram**: Do you want me to draw the architecture?
- [ ] **Demo format**: What should I demonstrate at the end?
- [ ] **Presentation time**: How much time for final demo/explanation?

---

## 📋 Pre-Interview Checklist

Before you arrive:

- [ ] Toolkit USB drive or cloud access ready
- [ ] Printed cheat sheet (CHEATSHEET.md)
- [ ] Know your toolkit structure by heart
- [ ] Practice the full flow 2-3 times
- [ ] Time yourself (target: 90 minutes total)

---

## 🎯 Interview Start Script

**When they hand you the laptop, ask in this order:**

```
Hi! I have a few quick questions before I start:

1. CRITICAL (30 seconds):
   - GitLab URL and credentials?
   - WiFi password?
   - Can I install Docker/kubectl/minikube/Jenkins?

2. IMPORTANT (1 minute):
   - What PHP version does the app need?
   - What should the app do when working?
   - Any database or special dependencies?
   - Time limit and priority order?

3. CLARIFICATION (30 seconds):
   - Can I use my automation scripts?
   - Any specific K8s namespace or naming conventions?
   - Jenkins required or optional?

[Take notes while infrastructure installs - 15 minutes]
```

---

## 📝 Interview Notes Template

Copy this to a notepad during the interview:

```
=== INTERVIEW NOTES ===
Date: ___________  Time: ___________

GIT:
- URL: _________________________________
- User: ____________  Pass: ____________
- Branch: __________

APP:
- PHP: ______  Port: ______
- Expected behavior: _____________________
- Database: [ ] Yes [ ] No
  - If yes: Host:_____ DB:_____ User:_____ Pass:_____

KUBERNETES:
- Namespace: __________
- Replicas: __________
- Resources: CPU:______ Memory:______

JENKINS:
- Required: [ ] Yes [ ] No
- Auto-deploy: [ ] Yes [ ] No

TIME:
- Total: _______ minutes
- Priority: 1)_______ 2)_______ 3)_______

NOTES:
_________________________________________
_________________________________________
```

---

## 🚨 Red Flags - Clarify Immediately

If you hear any of these, **stop and ask for clarification**:

- "The database is on a separate server" → Need host/port/credentials
- "Use our company registry" → Need registry URL and credentials
- "Deploy to our existing cluster" → Need kubeconfig file
- "The app connects to external APIs" → Need API keys/endpoints
- "Follow our security policies" → Need specific requirements
- "Use our Jenkins" → Need Jenkins URL and credentials
- "The app needs special PHP modules" → Which ones exactly?

---

## 💡 Smart Follow-up Questions

After they explain the scenario, ask:

1. **"What does success look like?"**
   - Clarifies expectations
   - Shows you're goal-oriented

2. **"Are there any constraints I should know about?"**
   - Security policies
   - Network restrictions
   - Tool limitations

3. **"Can I ask questions during the interview?"**
   - Some allow it, some want you to figure it out
   - Better to know upfront

4. **"Should I explain as I go, or demo at the end?"**
   - Helps you plan communication strategy

---

## ⚠️ Assumptions to State Upfront

If they don't provide info, **state your assumptions clearly**:

```
"I'll assume:
- PHP 8.1 unless composer.json says otherwise
- Port 80 for the web server
- Using minikube for local Kubernetes
- Default namespace in K8s
- No database unless code shows otherwise
- Image stored in minikube's local registry

Please stop me if any of these are wrong!"
```

This shows:
- You're thinking ahead
- You communicate well
- You handle ambiguity professionally

---

## 📊 Information Priority Matrix

| Info | When Needed | Can Proceed Without? |
|------|-------------|---------------------|
| Git URL | Immediately | ❌ No |
| Git credentials | Immediately | ❌ No |
| Internet access | Immediately | ❌ No |
| PHP version | Before Docker build | ✅ Yes (assume 8.1) |
| Database details | Before K8s deploy | ✅ Yes (if not needed) |
| K8s namespace | Before K8s deploy | ✅ Yes (use default) |
| Jenkins details | Before CI/CD setup | ✅ Yes (skip if no time) |
| Resource limits | Before K8s deploy | ✅ Yes (use defaults) |

---

## 🎓 Pro Tips

1. **Take notes on paper** - Faster than digital during interview
2. **Repeat back critical info** - "So the GitLab URL is X, correct?"
3. **Ask about priorities** - "If I run short on time, what's most important?"
4. **State assumptions early** - Don't wait until you've built the wrong thing
5. **Confirm success criteria** - "Should the app show X when I access it?"
6. **Ask about automation** - "Can I use scripts, or do you want to see manual steps?"

---

## 📞 If Stuck - Questions to Unstick Yourself

**Can't clone repo:**
- "Is the URL correct? Should it be .git at the end?"
- "Is my account set up with access? Can you verify in GitLab?"

**PHP errors won't fix:**
- "Is there a requirements.txt or composer.json I should check?"
- "Are there any known dependencies I should be aware of?"

**Docker won't build:**
- "What PHP version is this app designed for?"
- "Any special extensions needed beyond the standard ones?"

**K8s pod won't start:**
- "Should this app connect to any external services?"
- "Any environment variables I should set?"

**Jenkins can't connect:**
- "Should Jenkins use the same kubeconfig I'm using?"
- "Any firewall rules I should know about?"

---

**Remember:** Asking good questions shows competence, not weakness!
