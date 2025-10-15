import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl
import hudson.util.Secret

def instance = Jenkins.getInstance()

println "=== INICIALIZACIÓN COMPLETA DE JENKINS ==="

// 1. CREAR CREDENCIALES
println "1. Configurando credenciales..."
def store = instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()
def c = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    "sonar-token",
    "SonarQube token (hardcoded for testing)",
    Secret.fromString("admin123456789")
)
store.addCredentials(Domain.global(), c)
println "✅ Credenciales creadas"

// 2. CONFIGURAR SONARQUBE (OPCIONAL)
println "2. Configurando SonarQube..."
println "ℹ️ SonarQube configuration skipped (SonarQube disabled)"

// 3. CREAR/ACTUALIZAR PIPELINE
println "3. Configurando pipeline principal..."
def jobName = "jwtmanual-pipeline"

// Eliminar job existente si existe
def existingJob = instance.getItem(jobName)
if (existingJob != null) {
    println "🗑️ Eliminando job existente ${jobName}..."
    existingJob.delete()
}

// Crear el pipeline con configuración unificada
println "🚀 Creando pipeline ${jobName}..."

def pipelineScript = '''
pipeline {
    agent any

    parameters {
        string(name: 'SERVICE_REPO_URL', defaultValue: 'https://github.com/Tourment0412/jwtmanual-taller1-micro.git', description: 'Repo del microservicio con infraestructura completa')
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
                        allowMissing: true,
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
                    sh "if [ -d 'target/allure-results' ]; then ${MVN} -q -e allure:report; else echo 'No hay reportes Allure disponibles para el servicio'; fi"
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
                    // Ejecutar tests E2E directamente desde Jenkins
                    sh "echo 'Ejecutando tests E2E directamente desde Jenkins...'"
                    
                    // Configurar variables de entorno para los tests
                    withEnv([
                        "AUT_TESTS_BASE_URL=${params.AUT_TESTS_BASE_URL}"
                    ]) {
                        dir('automation-tests') {
                            // Ejecutar tests E2E directamente
                            sh "${MVN} clean test -Dtest=CucumberTest -Dmaven.test.failure.ignore=true"
                            
                            // Generar reporte Allure
                            sh "${MVN} allure:report -Dmaven.test.failure.ignore=true || echo 'Error generando reporte Allure'"
                        }
                    }
                }
                junit 'automation-tests/target/surefire-reports/*.xml'
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

println "✅ Pipeline ${jobName} creado exitosamente"
println "📋 Configuración del pipeline:"
println "   - SERVICE_REPO_URL: https://github.com/Tourment0412/jwtmanual-taller1-micro.git"
println "   - AUTOMATION_TESTS_REPO_URL: https://github.com/MiguelA05/automation-tests.git"
println "   - AUT_TESTS_BASE_URL: http://jwtmanual-taller1-micro:8080"
println "   - Sin jacocoAdapter (usando solo publishHTML)"
println "   - Tests E2E ejecutados desde host"

println "=== INICIALIZACIÓN COMPLETADA ==="
