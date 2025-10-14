// SonarQube configuration disabled temporarily
// import jenkins.model.*
// import hudson.plugins.sonar.SonarGlobalConfiguration

// def inst = Jenkins.getInstance()
// def sonar = inst.getDescriptorByType(hudson.plugins.sonar.SonarGlobalConfiguration.class)
// sonar.setServerUrl('http://sonarqube:9000')
// sonar.setCredentialsId('sonar-token')
// sonar.save()
println "SonarQube configuration skipped (SonarQube disabled)"
