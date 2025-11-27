import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.GitSCM
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.UserRemoteConfig
import hudson.triggers.SCMTrigger

def jenkins = Jenkins.getInstance()

println "=========================================="
println "Creating PHP App Pipeline Job..."
println "=========================================="

// Check if job already exists
def jobName = "php-app-pipeline"
def existingJob = jenkins.getItem(jobName)

if (existingJob != null) {
    println "Job '${jobName}' already exists, skipping creation"
    return
}

// Create Pipeline job
def job = jenkins.createProject(WorkflowJob.class, jobName)

// Set description
job.setDescription("Automated PHP application CI/CD pipeline - Polls GitLab every 2 minutes, builds Docker image, deploys to Kubernetes")

// Configure Git repository
// Default placeholder - users MUST update this with their actual GitLab URL
def gitUrl = System.getenv('JENKINS_GIT_URL') ?: 'https://gitlab.example.com/username/php-app.git'
def gitBranch = System.getenv('JENKINS_GIT_BRANCH') ?: '*/main'
def credentialsId = 'gitlab-creds' // Users will create this credential

// Create Git SCM configuration
def userRemoteConfig = new UserRemoteConfig(gitUrl, null, null, credentialsId)
def scm = new GitSCM([userRemoteConfig])
scm.branches = [new BranchSpec(gitBranch)]

// Configure pipeline to use Jenkinsfile from SCM
def flowDefinition = new CpsScmFlowDefinition(scm, "Jenkinsfile")
flowDefinition.setLightweight(true) // Lightweight checkout for faster performance
job.setDefinition(flowDefinition)

// Configure SCM polling - every 2 minutes
// H/2 means "every 2 minutes" with hash-based distribution to avoid spikes
def trigger = new SCMTrigger("H/2 * * * *")
trigger.start(job, true) // Start the trigger
job.addTrigger(trigger)

// Save the job
job.save()

println "Pipeline job created successfully!"
println ""
println "Job Configuration:"
println "  Name: ${jobName}"
println "  Git URL: ${gitUrl}"
println "  Branch: ${gitBranch}"
println "  Credentials ID: ${credentialsId}"
println "  Poll SCM: Every 2 minutes (H/2 * * * *)"
println "  Script Path: Jenkinsfile"
println ""
println "NEXT STEPS:"
println "  1. Create GitLab credentials in Jenkins:"
println "     - Go to: Manage Jenkins → Manage Credentials"
println "     - Add: Username with password"
println "     - ID: gitlab-creds"
println ""
println "  2. Update pipeline job configuration:"
println "     - Go to: http://localhost:8080/job/${jobName}/configure"
println "     - Update 'Repository URL' with your GitLab URL"
println "     - Select 'gitlab-creds' credentials"
println "     - Save"
println ""
println "  3. Trigger first build:"
println "     - Click 'Build Now'"
println ""
println "After that, Jenkins will automatically:"
println "  • Poll GitLab every 2 minutes for changes"
println "  • Build Docker image when code changes"
println "  • Deploy to Kubernetes (update or create)"
println "  • Verify deployment succeeded"
println ""
println "=========================================="

jenkins.save()
