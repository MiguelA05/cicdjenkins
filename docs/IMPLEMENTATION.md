# Implementación de la Plataforma CI/CD con Jenkins

## 1. Jenkins Configuration as Code (JCasC)

### 1.1. Objetivo
Centralizar la configuración de Jenkins en archivos versionados para:
- Reconstrucciones determinísticas del controlador
- Revisión de cambios vía PR
- Promoción entre entornos sin cambios manuales

### 1.2. Archivos clave
- `jenkins/jenkins.yaml`: Configuración declarativa (ubicación, credenciales, herramientas, SonarQube, etc.)
- `jenkins/init.groovy.d/master_setup.groovy`: Tareas complementarias no cubiertas por JCasC (creación/rotación de credenciales, definición de pipelines con CpsFlowDefinition, ajustes condicionales)

### 1.3. Orden de carga
1) Jenkins levanta y aplica JCasC (`jenkins.yaml`).
2) Al finalizar, ejecuta scripts Groovy en `init.groovy.d/` (idempotentes, preparar para re-ejecución).

## 2. Gestión de Credenciales y Tokens

### 2.1. Token de SonarQube
- Token global utilizado para análisis desde pipelines.
- Escrito en dos ubicaciones para compatibilidad:
  - `jenkins/jenkins.yaml` → credencial `sonar-token`
  - `jenkins/init.groovy.d/master_setup.groovy` → `Secret.fromString("<token>")`

### 2.2. Script de rotación `scripts/generate-sonar-token.sh`
- Flujo:
  1. Verifica SonarQube (`/api/system/status`)
  2. Revoca token previo (si existe)
  3. Genera token y lo persiste en `/tmp/sonarqube-token.txt`
  4. Actualiza `jenkins.yaml` y `master_setup.groovy` usando reemplazos seguros (Python `re.sub`)
  5. Copia archivos al contenedor `jenkins` y reinicia
- Validación automática:
  - `curl -u <token>:` a `/api/authentication/validate` debe responder `{"valid":true}`
- Consideraciones:
  - Evitar que el token quede impreso en logs permanentes
  - Si la estructura de Groovy cambia, actualizar la expresión regular de reemplazo

## 3. Pipelines Declarados por Groovy

### 3.1. Objetivo
Crear y actualizar pipelines de manera programática cuando el controlador se inicializa, para:
- Normalizar stages entre proyectos heterogéneos (Java, Node.js, Python, Go)
- Inyectar steps comunes (Sonar, Quality Gate, reports)

### 3.2. Puntos de extensión
- Variables de entorno construidas dinámicamente (`dollar` para interpolaciones en Jenkinsfile Groovy)
- Pipelines por tecnología (ejemplos):
  - Java/Maven: `mvn -B -DskipTests=false clean verify sonar:sonar`
  - Node/Jest: `npm ci && npm test -- --coverage`
  - Python/pytest: `pip install -r requirements.txt && pytest`
  - Go: `go test ./...` + cobertura si aplica

### 3.3. SonarQube en pipelines
- Uso de credencial `sonar-token`
- En Maven: propiedades Sonar (`sonar.projectKey`, `sonar.host.url`, `sonar.login`)
- En Node/Python/Go: sonar-scanner si aplica, o análisis a través de contenedor Maven cuando sea posible

## 4. Procedimientos Operativos

### 4.1. Aplicar cambios de configuración (sin reconstruir imagen)
1. Copiar `jenkins.yaml` y `master_setup.groovy` al contenedor
2. Borrar `credentials.xml` para forzar relectura
3. Reiniciar el contenedor Jenkins

### 4.2. Recuperación ante corrupción de config
- Mantener backups automáticos: el script crea `.backup` al modificar `jenkins.yaml` y Groovy
- Si Jenkins no levanta tras un cambio:
  - Restaurar `jenkins.yaml.backup` y `master_setup.groovy.backup`
  - Reiniciar

### 4.3. Validación post-reinicio
- Acceder a `http://<host>:8083/` y verificar estado 200
- Confirmar que existen las credenciales esperadas en `Manage Jenkins > Credentials`
- Ejecutar un pipeline para validar Sonar y Quality Gate

## 5. SonarQube: Consideraciones de Proyecto

### 5.1. Java / Maven
- `pom.xml`: incluir `sonar-maven-plugin` o usar `sonar:sonar`
- Asegurar `src/test/java` presente (aunque sea vacío) para evitar que Sonar falle

### 5.2. Node.js / TypeScript
- `jest` con cobertura
- `transformIgnorePatterns` según dependencias ESM (ej. `uuid`)

### 5.3. Python
- `pytest` y `pytest-cov` si se requiere cobertura
- Evitar rutas relativas frágiles en tests (usar paquetes y `__init__.py`)

### 5.4. Go
- `go test ./...` y `go tool cover` si aplica
- Exportar GOPATH/PATH correctamente en el entorno del agente

## 6. Seguridad y Mantenimiento

- Evitar incluir secretos en repos; usar credenciales en Jenkins
- Auditar plugins instalados en `plugins.txt`; mantener versiones seguras
- Controlar acceso a `/var/jenkins_home/` y al socket del motor de contenedores
- Mantener SonarQube disponible y accesible para evitar bloqueos en pipelines

## 7. Troubleshooting

- Token inválido en Sonar: regenerar con `generate-sonar-token.sh` y validar `/api/authentication/validate`
- Jobs que no aparecen: verificar ejecución de `master_setup.groovy` y logs de arranque
- Quality Gate pendiente: configurar `waitForQualityGate()` si se usa sonar-scanner, o revisar estado en Sonar UI
- Variables con `${}` no interpolan: usar patrón `${dollar}{VAR}` dentro de strings Groovy para evitar expansión temprana

## 8. Roadmap Técnico

- Externalizar plantillas de pipelines por tecnología
- Añadir soporte para firmas de artefactos
- Integrar notificaciones a Slack/Teams
- Añadir step de publicación de reportes (Allure/HTML Publisher) por tecnología
