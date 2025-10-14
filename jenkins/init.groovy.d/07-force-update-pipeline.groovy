import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition

def instance = Jenkins.getInstance()
def jobName = "jwtmanual-pipeline"

// Eliminar el job existente si existe
def existingJob = instance.getItem(jobName)
if (existingJob != null) {
    println("Eliminando job existente ${jobName}...")
    existingJob.delete()
}

// Crear el job con la configuración correcta
println("Creando job ${jobName} con URLs correctas...")

def pipelineScript = '''
pipeline {
    agent any

    parameters {
        string(name: 'SERVICE_REPO_URL', defaultValue: 'https://github.com/Tourment0412/jwtmanual-taller1-micro.git', description: 'Repo del microservicio a construir')
        string(name: 'SERVICE_BRANCH', defaultValue: 'main', description: 'Rama del microservicio')
        string(name: 'AUTOMATION_TESTS_REPO_URL', defaultValue: 'https://github.com/MiguelA05/automation-tests.git', description: 'Repo de tests de automatización')
        string(name: 'AUTOMATION_TESTS_BRANCH', defaultValue: 'main', description: 'Rama de tests de automatización')
        string(name: 'AUT_TESTS_BASE_URL', defaultValue: 'http://jwtmanual-taller1-micro:8081', description: 'Base URL del servicio bajo prueba')
    }

    tools {
        maven 'Maven-3.9'
        jdk 'jdk21'
    }

    environment {
        MVN_HOME = tool(name: 'Maven-3.9', type: 'maven')
        JDK_HOME = tool(name: 'jdk21', type: 'jdk')
        MVN = "${MVN_HOME}/bin/mvn"
    }

    stages {
        stage('Checkout repos') {
            steps {
                dir('service') {
                    git branch: params.SERVICE_BRANCH, url: params.SERVICE_REPO_URL
                }
                dir('automation-tests') {
                    git branch: params.AUTOMATION_TESTS_BRANCH, url: params.AUTOMATION_TESTS_REPO_URL
                }
            }
        }

        stage('Build + Unit tests (service)') {
            steps {
                dir('service') {
                    sh 'ls -la'
                    sh "${MVN} -v"
                    sh "${MVN} clean verify"
                }
            }
            post {
                always {
                    junit 'service/target/surefire-reports/*.xml'
                    publishCoverage adapters: [
                        jacocoAdapter('service/target/site/jacoco/jacoco.xml')
                    ], sourceFileResolver: sourceFiles('STORE_LAST_BUILD')
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'service/target/site/jacoco',
                        reportFiles: 'index.html',
                        reportName: 'Reporte de Cobertura (service)'
                    ])
                }
            }
        }

        stage('Allure (service)') {
            steps {
                dir('service') {
                    sh "${MVN} -q -e allure:report || true"
                }
                publishHTML([
                    allowMissing: true,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'service/target/site/allure-maven-plugin',
                    reportFiles: 'index.html',
                    reportName: 'Reporte Allure (service)'
                ])
            }
        }

        stage('E2E (automation-tests)') {
            steps {
                dir('automation-tests') {
                    sh "${MVN} -q -e clean test -Dtest=CucumberTest"
                    sh "${MVN} -q -e allure:report || true"
                }
                publishHTML([
                    allowMissing: true,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'automation-tests/target/site/allure-maven-plugin',
                    reportFiles: 'index.html',
                    reportName: 'Reporte Allure (E2E)'
                ])
            }
        }
    }
}
'''

def flowDefinition = new CpsFlowDefinition(pipelineScript, true)
def newJob = instance.createProject(WorkflowJob.class, jobName)
newJob.setDefinition(flowDefinition)
newJob.setDescription("Pipeline completo para jwtmanual-taller1-micro: build, test, quality, E2E con automation-tests")
newJob.save()

println("Job ${jobName} creado exitosamente con URLs correctas:")
println("- SERVICE_REPO_URL: https://github.com/Tourment0412/jwtmanual-taller1-micro.git")
println("- AUTOMATION_TESTS_REPO_URL: https://github.com/MiguelA05/automation-tests.git")


