import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition
import hudson.model.ParametersDefinitionProperty
import hudson.model.StringParameterDefinition

def instance = Jenkins.getInstance()

// Actualizar el job de pipeline existente
def jobName = "jwtmanual-pipeline"
def existingJob = instance.getItem(jobName)

if (existingJob == null) {
    println("Job ${jobName} no existe, creando...")
    existingJob = new WorkflowJob(instance, jobName)
} else {
    println("Actualizando job ${jobName}...")
}

existingJob.setDescription("Pipeline completo para jwtmanual-taller1-micro: build, test, quality, E2E con automation-tests")

// Configurar el pipeline actualizado con automation-tests
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
existingJob.setDefinition(flowDefinition)

// Guardar el job
existingJob.save()
instance.reload()

println("Job ${jobName} actualizado exitosamente")
println("Pipeline actualizado para:")
println("- Clonar: service + automation-tests")
println("- Ejecutar pruebas unitarias del servicio")
println("- Ejecutar pruebas E2E desde automation-tests")
println("- Generar reportes integrados")
println("- URL base actualizada a puerto 8081")
