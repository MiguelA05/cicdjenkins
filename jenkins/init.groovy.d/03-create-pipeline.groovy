import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition
import hudson.model.ParametersDefinitionProperty
import hudson.model.StringParameterDefinition

def instance = Jenkins.getInstance()

// Crear el job de pipeline
def jobName = "jwtmanual-pipeline"
def existingJob = instance.getItem(jobName)

if (existingJob != null) {
    println("Job ${jobName} ya existe, eliminando...")
    existingJob.delete()
}

def job = new WorkflowJob(instance, jobName)
job.setDescription("Pipeline completo para jwtmanual-taller1-micro: build, test, quality, E2E")

// Configurar el pipeline con script inline (más simple y compatible)
def pipelineScript = '''
pipeline {
    agent any

    parameters {
        string(name: 'SERVICE_REPO_URL', defaultValue: 'https://github.com/MiguelA05/jwtmanual-taller1-micro.git', description: 'Repo del microservicio con infraestructura completa')
        string(name: 'SERVICE_BRANCH', defaultValue: 'main', description: 'Rama del microservicio')
        string(name: 'AUTOMATION_TESTS_REPO_URL', defaultValue: 'https://github.com/MiguelA05/automation-tests.git', description: 'Repo de tests de automatización')
        string(name: 'AUTOMATION_TESTS_BRANCH', defaultValue: 'main', description: 'Rama de tests de automatización')
        string(name: 'AUT_TESTS_BASE_URL', defaultValue: 'http://jwtmanual-taller1-micro:8080', description: 'Base URL del servicio bajo prueba')
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
                script {
                    // Ejecutar tests E2E usando script del repositorio principal
                    sh "echo 'Ejecutando tests E2E usando script del repositorio principal...'"
                    
                    // Ejecutar script que maneja la ejecución de tests
                    sh "service/run-e2e-tests.sh"
                    
                    // Copiar reportes desde directorio temporal
                    sh "cp -r /tmp/jenkins-e2e-reports/allure-reports ./e2e-reports || echo 'Reportes Allure no disponibles'"
                    sh "cp -r /tmp/jenkins-e2e-reports/surefire-reports ./e2e-surefire-reports || echo 'Reportes Surefire no disponibles'"
                }
                publishTestResults testResultsPattern: 'e2e-surefire-reports/*.xml'
                publishHTML([
                    allowMissing: true,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'e2e-reports',
                    reportFiles: 'index.html',
                    reportName: 'Reporte Allure (E2E)'
                ])
            }
        }
    }
}
'''

def flowDefinition = new CpsFlowDefinition(pipelineScript, true)
job.setDefinition(flowDefinition)

// Guardar el job
job.save()
instance.reload()

println("Job ${jobName} creado exitosamente")
println("Pipeline configurado para:")
println("- Clonar: ${jobName}")
println("- Ejecutar pruebas unitarias")
println("- Ejecutar pruebas E2E")
println("- Generar reportes integrados")