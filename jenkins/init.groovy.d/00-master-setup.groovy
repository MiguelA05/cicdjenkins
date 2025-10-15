import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl
import hudson.util.Secret
import hudson.plugins.sonar.SonarGlobalConfiguration
import hudson.plugins.sonar.SonarInstallation

def instance = Jenkins.getInstance()

println "=== INICIALIZACIÓN COMPLETA DE JENKINS ==="

// Nota: Las credenciales y la configuración de SonarQube se manejan en jenkins.yaml (JCasC)
println "ℹ️ Credenciales y SonarQube configurados vía JCasC (jenkins.yaml)"

// 1. CREAR/ACTUALIZAR PIPELINE
println "1. Configurando pipeline principal..."
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
        SONAR_HOST_URL = "http://sonarqube:9000"
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

        stage('SonarQube Analysis') {
            steps {
                script {
                    dir('service') {
                        echo "🔍 Iniciando análisis de calidad con SonarQube..."
                        withSonarQubeEnv('SonarQube') {
                            sh """
                                ${MVN} sonar:sonar \
                                    -Dsonar.projectKey=jwtmanual-taller1-micro \
                                    -Dsonar.projectName='JWT Manual Taller 1 Microservice' \
                                    -Dsonar.projectVersion=1.0 \
                                    -Dsonar.sources=src/main/java \
                                    -Dsonar.tests=src/test/java \
                                    -Dsonar.java.binaries=target/classes \
                                    -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                                    -Dsonar.junit.reportPaths=target/surefire-reports \
                                    -Dsonar.java.source=21 \
                                    -Dsonar.java.target=21 \
                                    -Dsonar.sourceEncoding=UTF-8
                            """
                        }
                        echo "✅ Análisis de SonarQube completado"
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                script {
                    echo "🚦 Esperando resultado del Quality Gate..."
                    timeout(time: 5, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            echo "⚠️ Quality Gate falló: ${qg.status}"
                            echo "ℹ️ Continuando pipeline a pesar del fallo..."
                            // No fallar el build, solo advertir
                        } else {
                            echo "✅ Quality Gate aprobado!"
                        }
                    }
                }
            }
        }

        stage('Allure (service)') {
            steps {
                dir('service') {
                    sh "if [ -d 'target/allure-results' ]; then ${MVN} -q -e allure:report; else echo '⚠️ No hay reportes Allure disponibles para el servicio - continuando sin reportes'; fi"
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
                            
                            // Generar reporte Allure (OBLIGATORIO)
                            sh "${MVN} allure:report"
                            
                            // Verificar que el reporte se generó correctamente
                            sh "test -f target/site/allure-maven-plugin/index.html || (echo '❌ ERROR: Reporte Allure no se generó correctamente' && exit 1)"
                            echo "✅ Reporte Allure generado exitosamente"
                        }
                    }
                }
                junit 'automation-tests/target/surefire-reports/*.xml'
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'automation-tests/target/site/allure-maven-plugin',
                    reportFiles: 'index.html',
                    reportName: 'Reporte Allure (E2E)'
                ])
            }
        }
    }

    post {
        always {
            echo "📊 Pipeline completado"
            echo "🔗 Reportes disponibles:"
            echo "   - Cobertura de código: Reporte de Cobertura (service)"
            echo "   - Calidad de código: SonarQube (http://localhost:9001)"
            echo "   - Tests E2E: Reporte Allure (E2E)"
        }
        success {
            echo "✅ Pipeline ejecutado exitosamente"
        }
        failure {
            echo "❌ Pipeline falló"
        }
    }
}
'''

def flowDefinition = new CpsFlowDefinition(pipelineScript, true)
def newJob = instance.createProject(WorkflowJob.class, jobName)
newJob.setDefinition(flowDefinition)
newJob.setDescription("Pipeline completo para jwtmanual-taller1-micro: build, test, SonarQube quality analysis, E2E con automation-tests")
newJob.save()

println "✅ Pipeline ${jobName} creado exitosamente"
println "📋 Configuración del pipeline:"
println "   - SERVICE_REPO_URL: https://github.com/Tourment0412/jwtmanual-taller1-micro.git"
println "   - AUTOMATION_TESTS_REPO_URL: https://github.com/MiguelA05/automation-tests.git"
println "   - AUT_TESTS_BASE_URL: http://jwtmanual-taller1-micro:8080"
println "   - SonarQube: HABILITADO (http://sonarqube:9000)"
println "   - Quality Gate: HABILITADO (no bloquea el build)"

println "=== INICIALIZACIÓN COMPLETADA ==="
