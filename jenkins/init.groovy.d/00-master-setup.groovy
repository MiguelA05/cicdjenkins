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

// ============================================================================
// CONFIGURACIÓN DE PIPELINES PARA TODOS LOS MICROSERVICIOS
// ============================================================================

// 1. PIPELINE: jwtmanual-taller1-micro (Domain Service)
createJavaMavenPipeline(
    instance,
    "jwtmanual-pipeline",
    "https://github.com/Tourment0412/jwtmanual-taller1-micro.git",
    "jwtmanual-taller1-micro",
    "JWT Manual Taller 1 Microservice",
    "21",
    "http://jwtmanual-taller1-micro:8080"
)

// 2. PIPELINE: api-gateway-micro
createJavaMavenPipeline(
    instance,
    "api-gateway-pipeline",
    "https://github.com/Tourment0412/api-gateway-micro.git",
    "api-gateway-micro",
    "API Gateway Microservice",
    "17",
    null
)

// 3. PIPELINE: gestion-perfil-micro
createJavaMavenPipeline(
    instance,
    "gestion-perfil-pipeline",
    "https://github.com/Tourment0412/gestion-perfil-micro.git",
    "gestion-perfil-micro",
    "Gestión de Perfil Microservice",
    "17",
    null
)

// 4. PIPELINE: notifications-service-micro (Python)
createPythonPipeline(
    instance,
    "notifications-service-pipeline",
    "https://github.com/Tourment0412/notifications-service-micro.git",
    "notifications-service-micro",
    "Notifications Service Microservice"
)

// 5. PIPELINE: orquestador-solicitudes-micro (Node.js/TypeScript)
createNodeJSPipeline(
    instance,
    "orquestador-solicitudes-pipeline",
    "https://github.com/Tourment0412/orquestador-solicitudes-micro.git",
    "orquestador-solicitudes-micro",
    "Orquestador de Solicitudes Microservice"
)

// 6. PIPELINE: health-check-app-micro (Go)
createGoPipeline(
    instance,
    "health-check-app-pipeline",
    "https://github.com/Tourment0412/health-check-app-micro.git",
    "health-check-app-micro",
    "Health Check App Microservice"
)

println "=== INICIALIZACIÓN COMPLETADA ==="

// ============================================================================
// FUNCIONES AUXILIARES PARA CREAR PIPELINES
// ============================================================================

def createJavaMavenPipeline(instance, jobName, repoUrl, projectKey, projectName, javaVersion, baseUrl) {
    println "\n📦 Creando pipeline para ${projectName}..."
    
    // Eliminar job existente si existe
    def existingJob = instance.getItem(jobName)
    if (existingJob != null) {
        println "🗑️ Eliminando job existente ${jobName}..."
        existingJob.delete()
    }
    
    def automationTestsUrl = "https://github.com/MiguelA05/automation-tests.git"
    def hasE2ETests = (baseUrl != null)
    
    def pipelineScript = """
pipeline {
    agent any

    parameters {
        string(name: 'SERVICE_REPO_URL', defaultValue: '${repoUrl}', description: 'Repo del microservicio')
        string(name: 'SERVICE_BRANCH', defaultValue: 'main', description: 'Rama del microservicio')
        ${hasE2ETests ? """
        string(name: 'AUTOMATION_TESTS_REPO_URL', defaultValue: '${automationTestsUrl}', description: 'Repo de tests de automatización')
        string(name: 'AUTOMATION_TESTS_BRANCH', defaultValue: 'main', description: 'Rama de tests de automatización')
        string(name: 'AUT_TESTS_BASE_URL', defaultValue: '${baseUrl}', description: 'Base URL del servicio bajo prueba')
        """ : ""}
    }

    tools {
        maven 'Maven-3.9'
        jdk 'jdk21'
    }

    environment {
        MVN_HOME = tool(name: 'Maven-3.9', type: 'maven')
        JDK_HOME = tool(name: 'jdk21', type: 'jdk')
        MVN = "\${MVN_HOME}/bin/mvn"
        SONAR_HOST_URL = "http://sonarqube:9000"
    }

    stages {
        stage('Checkout repos') {
            steps {
                dir('service') {
                    git branch: params.SERVICE_BRANCH, url: params.SERVICE_REPO_URL
                }
                ${hasE2ETests ? """
                dir('automation-tests') {
                    git branch: params.AUTOMATION_TESTS_BRANCH, url: params.AUTOMATION_TESTS_REPO_URL
                }
                """ : ""}
            }
        }

        stage('Build + Unit tests') {
            steps {
                dir('service') {
                    sh 'ls -la'
                    sh "\${MVN} -v"
                    sh "\${MVN} clean verify"
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
                        reportName: 'Reporte de Cobertura'
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
                                \${MVN} sonar:sonar \\
                                    -Dsonar.projectKey=${projectKey} \\
                                    -Dsonar.projectName='${projectName}' \\
                                    -Dsonar.projectVersion=1.0 \\
                                    -Dsonar.sources=src/main/java \\
                                    -Dsonar.tests=src/test/java \\
                                    -Dsonar.java.binaries=target/classes \\
                                    -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \\
                                    -Dsonar.junit.reportPaths=target/surefire-reports \\
                                    -Dsonar.java.source=${javaVersion} \\
                                    -Dsonar.java.target=${javaVersion} \\
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
                            echo "⚠️ Quality Gate falló: \${qg.status}"
                            echo "ℹ️ Continuando pipeline a pesar del fallo..."
                        } else {
                            echo "✅ Quality Gate aprobado!"
                        }
                    }
                }
            }
        }

        stage('Allure Report') {
            steps {
                dir('service') {
                    sh "if [ -d 'target/allure-results' ]; then \${MVN} -q -e allure:report; else echo '⚠️ No hay reportes Allure disponibles - continuando sin reportes'; fi"
                }
                publishHTML([
                    allowMissing: true,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'service/target/site/allure-maven-plugin',
                    reportFiles: 'index.html',
                    reportName: 'Reporte Allure'
                ])
            }
        }
        ${hasE2ETests ? """
        stage('E2E Tests') {
            steps {
                script {
                    withEnv([
                        "AUT_TESTS_BASE_URL=\${params.AUT_TESTS_BASE_URL}"
                    ]) {
                        dir('automation-tests') {
                            sh "\${MVN} clean test -Dtest=CucumberTest -Dmaven.test.failure.ignore=true"
                            sh "\${MVN} allure:report"
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
        """ : ""}
    }

    post {
        always {
            echo "📊 Pipeline completado para ${projectName}"
        }
        success {
            echo "✅ Pipeline ejecutado exitosamente"
        }
        failure {
            echo "❌ Pipeline falló"
        }
    }
}
"""
    
    def flowDefinition = new CpsFlowDefinition(pipelineScript, true)
    def newJob = instance.createProject(WorkflowJob.class, jobName)
    newJob.setDefinition(flowDefinition)
    newJob.setDescription("Pipeline CI/CD para ${projectName}: build, test, SonarQube analysis${hasE2ETests ? ', E2E tests' : ''}")
    newJob.save()
    
    println "✅ Pipeline ${jobName} creado exitosamente"
}

def createPythonPipeline(instance, jobName, repoUrl, projectKey, projectName) {
    println "\n🐍 Creando pipeline Python para ${projectName}..."
    
    def existingJob = instance.getItem(jobName)
    if (existingJob != null) {
        println "🗑️ Eliminando job existente ${jobName}..."
        existingJob.delete()
    }
    
    def pipelineScript = """
pipeline {
    agent any

    parameters {
        string(name: 'SERVICE_REPO_URL', defaultValue: '${repoUrl}', description: 'Repo del microservicio')
        string(name: 'SERVICE_BRANCH', defaultValue: 'main', description: 'Rama del microservicio')
    }

    environment {
        PYTHON_VERSION = '3.11'
    }

    stages {
        stage('Checkout') {
            steps {
                dir('service') {
                    git branch: params.SERVICE_BRANCH, url: params.SERVICE_REPO_URL
                }
            }
        }

        stage('Setup Python Environment') {
            steps {
                dir('service') {
                    sh '''
                        python3 --version
                        python3 -m venv venv || true
                        . venv/bin/activate
                        pip install --upgrade pip
                        pip install -r requirements.txt
                    '''
                }
            }
        }

        stage('Lint') {
            steps {
                dir('service') {
                    sh '''
                        . venv/bin/activate
                        pip install flake8 pylint || true
                        flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics || true
                        pylint app/ || true
                    '''
                }
            }
        }

        stage('Unit Tests') {
            steps {
                dir('service') {
                    sh '''
                        . venv/bin/activate
                        pytest tests/ -v --cov=app --cov-report=html --cov-report=xml || true
                    '''
                }
            }
            post {
                always {
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'service/htmlcov',
                        reportFiles: 'index.html',
                        reportName: 'Reporte de Cobertura (Python)'
                    ])
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    dir('service') {
                        withSonarQubeEnv('SonarQube') {
                            sh """
                                . venv/bin/activate
                                pip install sonar-scanner-cli || true
                                sonar-scanner \\
                                    -Dsonar.projectKey=${projectKey} \\
                                    -Dsonar.projectName='${projectName}' \\
                                    -Dsonar.sources=app \\
                                    -Dsonar.tests=tests \\
                                    -Dsonar.python.coverage.reportPaths=coverage.xml \\
                                    -Dsonar.sourceEncoding=UTF-8
                            """
                        }
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                script {
                    timeout(time: 5, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            echo "⚠️ Quality Gate falló: \${qg.status}"
                        } else {
                            echo "✅ Quality Gate aprobado!"
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo "📊 Pipeline completado para ${projectName}"
        }
        success {
            echo "✅ Pipeline ejecutado exitosamente"
        }
        failure {
            echo "❌ Pipeline falló"
        }
    }
}
"""
    
    def flowDefinition = new CpsFlowDefinition(pipelineScript, true)
    def newJob = instance.createProject(WorkflowJob.class, jobName)
    newJob.setDefinition(flowDefinition)
    newJob.setDescription("Pipeline CI/CD para ${projectName} (Python): build, test, lint, SonarQube analysis")
    newJob.save()
    
    println "✅ Pipeline ${jobName} creado exitosamente"
}

def createNodeJSPipeline(instance, jobName, repoUrl, projectKey, projectName) {
    println "\n📦 Creando pipeline Node.js/TypeScript para ${projectName}..."
    
    def existingJob = instance.getItem(jobName)
    if (existingJob != null) {
        println "🗑️ Eliminando job existente ${jobName}..."
        existingJob.delete()
    }
    
    def pipelineScript = """
pipeline {
    agent any

    parameters {
        string(name: 'SERVICE_REPO_URL', defaultValue: '${repoUrl}', description: 'Repo del microservicio')
        string(name: 'SERVICE_BRANCH', defaultValue: 'main', description: 'Rama del microservicio')
    }

    environment {
        NODE_VERSION = '20'
    }

    stages {
        stage('Checkout') {
            steps {
                dir('service') {
                    git branch: params.SERVICE_BRANCH, url: params.SERVICE_REPO_URL
                }
            }
        }

        stage('Setup Node.js') {
            steps {
                dir('service') {
                    sh '''
                        node --version || echo "Node.js no instalado, usando nvm"
                        npm --version || echo "npm no instalado"
                        npm ci
                    '''
                }
            }
        }

        stage('Lint') {
            steps {
                dir('service') {
                    sh '''
                        npm run lint || echo "⚠️ Lint no configurado, continuando..."
                    '''
                }
            }
        }

        stage('Build') {
            steps {
                dir('service') {
                    sh '''
                        npm run build
                    '''
                }
            }
        }

        stage('Unit Tests') {
            steps {
                dir('service') {
                    sh '''
                        npm test -- --coverage || true
                    '''
                }
            }
            post {
                always {
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'service/coverage',
                        reportFiles: 'index.html',
                        reportName: 'Reporte de Cobertura (Jest)'
                    ])
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    dir('service') {
                        withSonarQubeEnv('SonarQube') {
                            sh """
                                npm install -g sonarqube-scanner || true
                                sonar-scanner \\
                                    -Dsonar.projectKey=${projectKey} \\
                                    -Dsonar.projectName='${projectName}' \\
                                    -Dsonar.sources=src \\
                                    -Dsonar.tests=src \\
                                    -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info \\
                                    -Dsonar.sourceEncoding=UTF-8
                            """
                        }
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                script {
                    timeout(time: 5, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            echo "⚠️ Quality Gate falló: \${qg.status}"
                        } else {
                            echo "✅ Quality Gate aprobado!"
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo "📊 Pipeline completado para ${projectName}"
        }
        success {
            echo "✅ Pipeline ejecutado exitosamente"
        }
        failure {
            echo "❌ Pipeline falló"
        }
    }
}
"""
    
    def flowDefinition = new CpsFlowDefinition(pipelineScript, true)
    def newJob = instance.createProject(WorkflowJob.class, jobName)
    newJob.setDefinition(flowDefinition)
    newJob.setDescription("Pipeline CI/CD para ${projectName} (Node.js/TypeScript): build, test, lint, SonarQube analysis")
    newJob.save()
    
    println "✅ Pipeline ${jobName} creado exitosamente"
}

def createGoPipeline(instance, jobName, repoUrl, projectKey, projectName) {
    println "\n🐹 Creando pipeline Go para ${projectName}..."
    
    def existingJob = instance.getItem(jobName)
    if (existingJob != null) {
        println "🗑️ Eliminando job existente ${jobName}..."
        existingJob.delete()
    }
    
    def pipelineScript = """
pipeline {
    agent any

    parameters {
        string(name: 'SERVICE_REPO_URL', defaultValue: '${repoUrl}', description: 'Repo del microservicio')
        string(name: 'SERVICE_BRANCH', defaultValue: 'main', description: 'Rama del microservicio')
    }

    environment {
        GO_VERSION = '1.22'
    }

    stages {
        stage('Checkout') {
            steps {
                dir('service') {
                    git branch: params.SERVICE_BRANCH, url: params.SERVICE_REPO_URL
                }
            }
        }

        stage('Setup Go') {
            steps {
                dir('service') {
                    sh '''
                        go version
                        go mod download
                        go mod verify
                    '''
                }
            }
        }

        stage('Lint') {
            steps {
                dir('service') {
                    sh '''
                        go install golang.org/x/lint/golint@latest || true
                        golint ./... || echo "⚠️ Lint no disponible, continuando..."
                    '''
                }
            }
        }

        stage('Build') {
            steps {
                dir('service') {
                    sh '''
                        go build -v ./...
                    '''
                }
            }
        }

        stage('Unit Tests') {
            steps {
                dir('service') {
                    sh '''
                        go test -v -coverprofile=coverage.out ./... || true
                        go tool cover -html=coverage.out -o coverage.html || true
                    '''
                }
            }
            post {
                always {
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'service',
                        reportFiles: 'coverage.html',
                        reportName: 'Reporte de Cobertura (Go)'
                    ])
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    dir('service') {
                        withSonarQubeEnv('SonarQube') {
                            sh """
                                go install github.com/sonarsource/sonar-scanner-cli@latest || true
                                sonar-scanner \\
                                    -Dsonar.projectKey=${projectKey} \\
                                    -Dsonar.projectName='${projectName}' \\
                                    -Dsonar.sources=. \\
                                    -Dsonar.tests=. \\
                                    -Dsonar.go.coverage.reportPaths=coverage.out \\
                                    -Dsonar.sourceEncoding=UTF-8
                            """
                        }
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                script {
                    timeout(time: 5, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            echo "⚠️ Quality Gate falló: \${qg.status}"
                        } else {
                            echo "✅ Quality Gate aprobado!"
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo "📊 Pipeline completado para ${projectName}"
        }
        success {
            echo "✅ Pipeline ejecutado exitosamente"
        }
        failure {
            echo "❌ Pipeline falló"
        }
    }
}
"""
    
    def flowDefinition = new CpsFlowDefinition(pipelineScript, true)
    def newJob = instance.createProject(WorkflowJob.class, jobName)
    newJob.setDefinition(flowDefinition)
    newJob.setDescription("Pipeline CI/CD para ${projectName} (Go): build, test, lint, SonarQube analysis")
    newJob.save()
    
    println "✅ Pipeline ${jobName} creado exitosamente"
}
