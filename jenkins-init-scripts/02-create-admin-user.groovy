import jenkins.model.Jenkins
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy

def jenkins = Jenkins.getInstance()

println "=========================================="
println "Configuring Jenkins security..."
println "=========================================="

// Create admin user
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount('admin', 'admin')
jenkins.setSecurityRealm(hudsonRealm)

// Set authorization strategy (logged in users can do anything)
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
jenkins.setAuthorizationStrategy(strategy)

jenkins.save()

println "Admin user created:"
println "  Username: admin"
println "  Password: admin"
println "=========================================="
