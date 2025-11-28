import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl
import com.cloudbees.plugins.credentials.SystemCredentialsProvider

// GitLab credentials (from deploy-gitlab.sh)
def gitlabUsername = "root"
def gitlabPassword = "Kx9mPqR2wZ"
def credentialsId = "gitlab-creds"

// Get Jenkins instance and credentials store
def jenkins = Jenkins.getInstance()
def store = SystemCredentialsProvider.getInstance().getStore()

// Check if credential already exists
def existingCreds = store.getCredentials(Domain.global()).find {
    it.id == credentialsId
}

if (existingCreds) {
    println "GitLab credentials '${credentialsId}' already exist - skipping creation"
} else {
    // Create username/password credential
    def credentials = new UsernamePasswordCredentialsImpl(
        CredentialsScope.GLOBAL,
        credentialsId,
        "GitLab Credentials (root/Kx9mPqR2wZ)",
        gitlabUsername,
        gitlabPassword
    )

    // Add to Jenkins
    store.addCredentials(Domain.global(), credentials)
    jenkins.save()

    println "Successfully created GitLab credentials '${credentialsId}'"
}
