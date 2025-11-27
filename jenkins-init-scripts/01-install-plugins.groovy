import jenkins.model.Jenkins
import jenkins.install.InstallState

def jenkins = Jenkins.getInstance()

// Skip setup wizard
jenkins.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)

println "=========================================="
println "Installing essential plugins..."
println "=========================================="

// List of plugins to install
def plugins = [
    'workflow-aggregator',      // Pipeline support
    'git',                      // Git checkout
    'credentials-binding',      // Secure credentials
    'docker-workflow',          // Docker integration
    'pipeline-stage-view',      // Better UI
    'timestamper'               // Logs with timestamps
]

def pluginManager = jenkins.getPluginManager()
def updateCenter = jenkins.getUpdateCenter()

// Trigger update center refresh
updateCenter.updateAllSites()

// Wait for update center to have data
def maxRetries = 30
def retries = 0
while (updateCenter.getSites().isEmpty() || updateCenter.getSite('default').availables.isEmpty()) {
    if (retries++ > maxRetries) {
        println "WARNING: Update center took too long to load, proceeding anyway..."
        break
    }
    println "Waiting for update center data... (${retries}/${maxRetries})"
    Thread.sleep(2000)
}

// Install each plugin
def pluginsToInstall = []
plugins.each { pluginName ->
    if (!pluginManager.getPlugin(pluginName)) {
        println "Queuing plugin for installation: ${pluginName}"
        def plugin = updateCenter.getPlugin(pluginName)
        if (plugin) {
            pluginsToInstall << plugin.deploy()
        } else {
            println "WARNING: Plugin ${pluginName} not found in update center"
        }
    } else {
        println "Plugin already installed: ${pluginName}"
    }
}

// Wait for installations to complete
if (!pluginsToInstall.isEmpty()) {
    println "Installing ${pluginsToInstall.size()} plugins..."
    pluginsToInstall.each { future ->
        future.get()
    }
    println "Plugin installation complete!"
    println "Jenkins will restart to activate plugins..."
}

jenkins.save()
