# 📋 Configuración de Pipelines CI/CD en Jenkins

## 🎯 Resumen

Este documento describe la configuración de pipelines CI/CD para todos los microservicios del proyecto. Cada microservicio tiene su propia pipeline independiente en Jenkins.

---

## 📦 Pipelines Configuradas

### 1. **jwtmanual-pipeline** (Domain Service)
- **Tecnología:** Java 21 + Maven + Spring Boot
- **Repositorio:** `https://github.com/Tourment0412/jwtmanual-taller1-micro.git`
- **Stages:**
  - Checkout repos (servicio + automation-tests)
  - Build + Unit tests
  - SonarQube Analysis
  - Quality Gate
  - Allure Report
  - E2E Tests (con automation-tests)

### 2. **api-gateway-pipeline** (API Gateway)
- **Tecnología:** Java 17 + Maven + Spring Boot
- **Repositorio:** `https://github.com/Tourment0412/api-gateway-micro.git`
- **Stages:**
  - Checkout
  - Build + Unit tests
  - SonarQube Analysis
  - Quality Gate
  - Allure Report

### 3. **gestion-perfil-pipeline** (Gestión de Perfil)
- **Tecnología:** Java 17 + Maven + Spring Boot
- **Repositorio:** `https://github.com/Tourment0412/gestion-perfil-micro.git`
- **Stages:**
  - Checkout
  - Build + Unit tests
  - SonarQube Analysis
  - Quality Gate
  - Allure Report

### 4. **notifications-service-pipeline** (Notifications Service)
- **Tecnología:** Python 3.11 + FastAPI
- **Repositorio:** `https://github.com/Tourment0412/notifications-service-micro.git`
- **Stages:**
  - Checkout
  - Setup Python Environment
  - Lint (flake8, pylint)
  - Unit Tests (pytest con cobertura)
  - SonarQube Analysis
  - Quality Gate

### 5. **orquestador-solicitudes-pipeline** (Orquestador)
- **Tecnología:** Node.js 20 + TypeScript + Jest
- **Repositorio:** `https://github.com/Tourment0412/orquestador-solicitudes-micro.git`
- **Stages:**
  - Checkout
  - Setup Node.js
  - Lint
  - Build (TypeScript compilation)
  - Unit Tests (Jest con cobertura)
  - SonarQube Analysis
  - Quality Gate

### 6. **health-check-app-pipeline** (Health Check)
- **Tecnología:** Go 1.22
- **Repositorio:** `https://github.com/Tourment0412/health-check-app-micro.git`
- **Stages:**
  - Checkout
  - Setup Go
  - Lint (golint)
  - Build
  - Unit Tests (con cobertura)
  - SonarQube Analysis
  - Quality Gate

---

## 🔧 Configuración Automática

Las pipelines se crean automáticamente al iniciar Jenkins mediante el script:
- **Ubicación:** `cicdjenkins/jenkins/init.groovy.d/00-master-setup.groovy`

Este script:
1. Elimina pipelines existentes (si existen)
2. Crea nuevas pipelines para cada microservicio
3. Configura parámetros, herramientas y stages específicos

---

## 🚀 Cómo Funciona

### Inicialización Automática

Al iniciar Jenkins, el script `00-master-setup.groovy` se ejecuta automáticamente y crea todas las pipelines.

### Acceso a las Pipelines

1. Accede a Jenkins: `http://localhost:8083`
2. En el panel principal verás todas las pipelines listadas:
   - `jwtmanual-pipeline`
   - `api-gateway-pipeline`
   - `gestion-perfil-pipeline`
   - `notifications-service-pipeline`
   - `orquestador-solicitudes-pipeline`
   - `health-check-app-pipeline`

### Ejecutar una Pipeline

1. Haz clic en el nombre de la pipeline
2. Haz clic en "Build with Parameters"
3. Ajusta los parámetros si es necesario:
   - `SERVICE_REPO_URL`: URL del repositorio
   - `SERVICE_BRANCH`: Rama a construir (default: `main`)
4. Haz clic en "Build"

---

## 📊 Reportes Generados

Cada pipeline genera los siguientes reportes:

### Java/Maven (jwtmanual, api-gateway, gestion-perfil)
- **Cobertura de código:** Reporte HTML de JaCoCo
- **Calidad de código:** Análisis en SonarQube
- **Tests:** Reporte Allure (si está disponible)

### Python (notifications-service)
- **Cobertura de código:** Reporte HTML de pytest-cov
- **Calidad de código:** Análisis en SonarQube
- **Lint:** Resultados de flake8 y pylint

### Node.js/TypeScript (orquestador-solicitudes)
- **Cobertura de código:** Reporte HTML de Jest
- **Calidad de código:** Análisis en SonarQube
- **Build:** Compilación TypeScript

### Go (health-check-app)
- **Cobertura de código:** Reporte HTML de go test
- **Calidad de código:** Análisis en SonarQube
- **Build:** Compilación Go

---

## 🔄 Reiniciar Jenkins para Aplicar Cambios

Si modificas el script de inicialización, necesitas reiniciar Jenkins:

```bash
cd /home/miguel/Documentos/GitHub
docker-compose -f docker-compose.unified.yml restart jenkins
```

O si usas podman:

```bash
podman-compose -f docker-compose.unified.yml restart jenkins
```

---

## 📝 Notas Importantes

1. **Repositorios GitHub:** Asegúrate de que los repositorios existan y sean accesibles
2. **SonarQube:** Debe estar corriendo y accesible en `http://sonarqube:9000`
3. **Herramientas:** Jenkins debe tener configuradas:
   - Maven 3.9
   - JDK 21
   - Node.js 20 (para orquestador)
   - Python 3.11 (para notifications)
   - Go 1.22 (para health-check)

4. **Credenciales:** SonarQube token configurado en `jenkins.yaml`

---

## 🐛 Troubleshooting

### Las pipelines no aparecen en Jenkins

1. Verifica los logs de Jenkins:
   ```bash
   docker logs jenkins | grep -i "pipeline\|error"
   ```

2. Verifica que el script se ejecutó:
   ```bash
   docker logs jenkins | grep -i "INICIALIZACIÓN COMPLETA"
   ```

3. Reinicia Jenkins:
   ```bash
   docker-compose -f docker-compose.unified.yml restart jenkins
   ```

### Error al ejecutar una pipeline

1. Verifica que el repositorio existe y es accesible
2. Verifica que SonarQube está corriendo
3. Revisa los logs de la ejecución en Jenkins

---

## ✅ Verificación

Para verificar que todas las pipelines están creadas:

1. Accede a Jenkins: `http://localhost:8083`
2. Deberías ver 6 pipelines en el panel principal
3. Cada pipeline debe tener su descripción correspondiente

---

## 📚 Referencias

- **Jenkins Configuration as Code (JCasC):** `cicdjenkins/jenkins/jenkins.yaml`
- **Script de inicialización:** `cicdjenkins/jenkins/init.groovy.d/00-master-setup.groovy`
- **Documentación Jenkins:** https://www.jenkins.io/doc/

