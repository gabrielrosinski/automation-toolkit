import jenkins.model.Jenkins

def jenkins = Jenkins.getInstance()

// Set number of executors (parallel jobs)
jenkins.setNumExecutors(2)

jenkins.save()

println "Jenkins configured with 2 executors"
