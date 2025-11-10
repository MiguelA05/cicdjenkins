# Guía de Inicio Rápido - CI/CD Jenkins Infrastructure

Esta guía te permitirá poner en marcha la infraestructura de CI/CD con Jenkins en tu entorno local y realizar pruebas básicas.

## Requisitos Previos

- Docker o Podman
- Git
- Acceso a repositorios de los microservicios
- SonarQube (puede ejecutarse en contenedor)

## Instalación Rápida

### 1. Construir Imagen de Jenkins

```bash
cd cicdjenkins/jenkins
podman build -t custom-jenkins .  # o docker build
```

### 2. Ejecutar Jenkins

```bash
podman run -d --name jenkins \
  -p 8083:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  custom-jenkins
```

O usando Docker:
```bash
docker run -d --name jenkins \
  -p 8083:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  custom-jenkins
```

### 3. Acceder a Jenkins

Abrir navegador en `http://localhost:8083`

La contraseña inicial se encuentra en los logs:
```bash
podman logs jenkins | grep -A 5 "Please use the following password"
```

### 4. Configurar Token de SonarQube

```bash
cd cicdjenkins/scripts
./generate-sonar-token.sh
```

Este script:
- Genera un token en SonarQube
- Actualiza la configuración de Jenkins
- Reinicia Jenkins automáticamente

## Verificación Inicial

### Verificar que Jenkins Está Corriendo

```bash
curl http://localhost:8083/login
```

Debería retornar HTML de la página de login.

### Verificar Configuración de SonarQube

1. Acceder a Jenkins UI: `http://localhost:8083`
2. Ir a `Manage Jenkins > Configure System`
3. Buscar sección "SonarQube"
4. Verificar que la credencial `sonar-token` esté configurada

### Verificar Pipelines Creados

1. En Jenkins UI, ir a la lista de jobs
2. Deberías ver pipelines para cada microservicio:
   - `jwtmanual-pipeline`
   - `gestion-perfil-pipeline`
   - `api-gateway-pipeline`
   - `notifications-pipeline`
   - `orquestador-pipeline`
   - `health-check-pipeline`

## Pruebas Básicas

### 1. Ejecutar un Pipeline Manualmente

1. En Jenkins UI, seleccionar un pipeline (ej: `api-gateway-pipeline`)
2. Click en "Build Now"
3. Ver el progreso en "Build History"
4. Revisar logs del build

### 2. Verificar Resultados del Build

Después de que el build complete:
- Revisar console output
- Verificar que los tests pasaron
- Verificar que SonarQube analysis se ejecutó
- Verificar que Quality Gate pasó

### 3. Verificar Integración con SonarQube

1. Acceder a SonarQube UI (normalmente `http://localhost:9001`)
2. Buscar el proyecto analizado
3. Verificar que el análisis más reciente corresponde al build de Jenkins

## Configurar Webhooks (Opcional)

### Para GitHub

1. En el repositorio de GitHub, ir a Settings > Webhooks
2. Agregar webhook:
   - URL: `http://<jenkins-host>:8083/github-webhook/`
   - Content type: `application/json`
   - Events: `Push events`

### Para GitLab

1. En el repositorio de GitLab, ir a Settings > Webhooks
2. Agregar webhook:
   - URL: `http://<jenkins-host>:8083/gitlab-webhook/`
   - Trigger: `Push events`

## Ejecutar Scripts de Utilidad

### Generar Token de SonarQube

```bash
cd cicdjenkins/scripts
./generate-sonar-token.sh
```

### Configurar Stack Completo

```bash
cd cicdjenkins/scripts
./setup-complete-stack.sh
```

## Verificar Logs de Jenkins

### Ver Logs del Contenedor

```bash
podman logs jenkins --tail 100
```

### Ver Logs de un Build Específico

1. En Jenkins UI, ir al build
2. Click en "Console Output"
3. Revisar logs completos del build

## Troubleshooting

### Error: Jenkins no inicia

Verificar logs del contenedor:
```bash
podman logs jenkins
```

Problemas comunes:
- Puerto 8083 ya en uso: cambiar puerto en el comando `run`
- Permisos en volumen: verificar permisos de `/var/jenkins_home`

### Error: Token de SonarQube inválido

Regenerar token:
```bash
cd cicdjenkins/scripts
./generate-sonar-token.sh
```

Verificar que SonarQube esté accesible:
```bash
curl http://localhost:9001/api/system/status
```

### Error: Pipeline no encuentra repositorio

Verificar que:
1. Las credenciales de Git estén configuradas en Jenkins
2. La URL del repositorio sea correcta
3. El repositorio sea accesible desde el contenedor Jenkins

### Error: Tests fallan en Pipeline

Verificar que:
1. Las dependencias estén instaladas correctamente
2. Las variables de entorno estén configuradas
3. Los servicios dependientes estén disponibles

### Error: SonarQube analysis falla

Verificar que:
1. El token de SonarQube sea válido
2. SonarQube esté accesible desde el agente Jenkins
3. Las propiedades de Sonar estén configuradas en el proyecto

## Próximos Pasos

- Revisar `docs/IMPLEMENTATION.md` para detalles de arquitectura
- Configurar notificaciones (email, Slack) para builds
- Personalizar pipelines según necesidades específicas
- Configurar agentes adicionales para builds paralelos
- Revisar métricas y reportes de calidad en SonarQube

