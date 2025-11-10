# 🔌 Ejemplos de API de SonarQube

Comandos cURL para interactuar directamente con la API de SonarQube.

## 🔐 Autenticación

```bash
# Usuario y contraseña por defecto
SONARQUBE_USER="admin"
SONARQUBE_PASSWORD="@MiguelAngel05"

# URL base
SONARQUBE_URL="http://localhost:9001"
```

## 📋 Comandos Básicos

### 1. Verificar Estado del Sistema

```bash
# Verificar si SonarQube está disponible
curl -s -u admin:@MiguelAngel05 \
  http://localhost:9001/api/system/status | jq

# Respuesta esperada:
{
  "id": "12345678",
  "version": "25.11.0.114957",
  "status": "UP"
}
```

### 2. Validar Credenciales

```bash
# Verificar que las credenciales son correctas
curl -s -u admin:@MiguelAngel05 \
  http://localhost:9001/api/authentication/validate | jq

# Respuesta esperada:
{
  "valid": true
}
```

## 🔑 Gestión de Tokens

### 1. Listar Tokens Existentes

```bash
# Listar todos los tokens del usuario admin
curl -s -u admin:@MiguelAngel05 \
  "http://localhost:9001/api/user_tokens/search?login=admin" | jq

# Respuesta esperada:
{
  "login": "admin",
  "userTokens": [
    {
      "name": "jenkins-global-analysis-token",
      "createdAt": "2025-11-10T10:30:00+0000",
      "lastConnectionDate": "2025-11-10T11:00:00+0000"
    }
  ]
}
```

### 2. Generar Nuevo Token

```bash
# Generar un token nuevo
curl -s -X POST -u admin:@MiguelAngel05 \
  http://localhost:9001/api/user_tokens/generate \
  -d "name=jenkins-global-analysis-token" \
  -d "login=admin" | jq

# Respuesta esperada:
{
  "login": "admin",
  "name": "jenkins-global-analysis-token",
  "token": "squ_c9c4f98a83783fb601f4db5066f447ceafd0aa8b",
  "createdAt": "2025-11-10T11:30:00+0000"
}

# Extraer solo el token
curl -s -X POST -u admin:@MiguelAngel05 \
  http://localhost:9001/api/user_tokens/generate \
  -d "name=jenkins-global-analysis-token" \
  -d "login=admin" | jq -r '.token'

# Salida:
squ_c9c4f98a83783fb601f4db5066f447ceafd0aa8b
```

### 3. Revocar Token

```bash
# Revocar un token existente
curl -s -X POST -u admin:@MiguelAngel05 \
  http://localhost:9001/api/user_tokens/revoke \
  -d "name=jenkins-global-analysis-token" \
  -d "login=admin"

# Sin respuesta si es exitoso (HTTP 204)
```

## 🔗 Gestión de Webhooks

### 1. Listar Webhooks

```bash
# Listar todos los webhooks configurados
curl -s -u admin:@MiguelAngel05 \
  http://localhost:9001/api/webhooks/list | jq

# Respuesta esperada:
{
  "webhooks": [
    {
      "key": "AY123456",
      "name": "jenkins-webhook",
      "url": "http://jenkins:8080/sonarqube-webhook/",
      "hasSecret": false
    }
  ]
}
```

### 2. Crear Webhook

```bash
# Crear un webhook para notificar a Jenkins
curl -s -X POST -u admin:@MiguelAngel05 \
  http://localhost:9001/api/webhooks/create \
  -d "name=jenkins-webhook" \
  -d "url=http://jenkins:8080/sonarqube-webhook/" | jq

# Respuesta esperada:
{
  "webhook": {
    "key": "AY123456",
    "name": "jenkins-webhook",
    "url": "http://jenkins:8080/sonarqube-webhook/",
    "hasSecret": false
  }
}
```

### 3. Eliminar Webhook

```bash
# Primero obtener el key del webhook
WEBHOOK_KEY=$(curl -s -u admin:@MiguelAngel05 \
  http://localhost:9001/api/webhooks/list | jq -r '.webhooks[0].key')

# Eliminar el webhook
curl -s -X POST -u admin:@MiguelAngel05 \
  http://localhost:9001/api/webhooks/delete \
  -d "webhook=${WEBHOOK_KEY}"

# Sin respuesta si es exitoso (HTTP 204)
```

## 📊 Proyectos y Quality Gates

### 1. Listar Proyectos

```bash
# Listar todos los proyectos
curl -s -u admin:@MiguelAngel05 \
  "http://localhost:9001/api/projects/search" | jq

# Respuesta esperada:
{
  "paging": {
    "pageIndex": 1,
    "pageSize": 100,
    "total": 6
  },
  "components": [
    {
      "key": "jwtmanual-taller1-micro",
      "name": "JWT Manual Taller 1 Microservice",
      "qualifier": "TRK",
      "visibility": "public"
    },
    {
      "key": "api-gateway-micro",
      "name": "API Gateway Microservice",
      "qualifier": "TRK",
      "visibility": "public"
    }
  ]
}
```

### 2. Obtener Quality Gate de un Proyecto

```bash
# Obtener el estado del Quality Gate
curl -s -u admin:@MiguelAngel05 \
  "http://localhost:9001/api/qualitygates/project_status?projectKey=jwtmanual-taller1-micro" | jq

# Respuesta esperada:
{
  "projectStatus": {
    "status": "OK",
    "conditions": [],
    "periods": []
  }
}
```

### 3. Obtener Medidas de un Proyecto

```bash
# Obtener medidas específicas
curl -s -u admin:@MiguelAngel05 \
  "http://localhost:9001/api/measures/component?component=jwtmanual-taller1-micro&metricKeys=coverage,bugs,vulnerabilities,code_smells" | jq

# Respuesta esperada:
{
  "component": {
    "key": "jwtmanual-taller1-micro",
    "name": "JWT Manual Taller 1 Microservice",
    "qualifier": "TRK",
    "measures": [
      {
        "metric": "coverage",
        "value": "85.2"
      },
      {
        "metric": "bugs",
        "value": "0"
      },
      {
        "metric": "vulnerabilities",
        "value": "0"
      },
      {
        "metric": "code_smells",
        "value": "5"
      }
    ]
  }
}
```

## 👤 Gestión de Usuarios

### 1. Listar Usuarios

```bash
# Listar todos los usuarios
curl -s -u admin:@MiguelAngel05 \
  http://localhost:9001/api/users/search | jq

# Respuesta esperada:
{
  "paging": {
    "pageIndex": 1,
    "pageSize": 50,
    "total": 1
  },
  "users": [
    {
      "login": "admin",
      "name": "Administrator",
      "active": true,
      "local": true
    }
  ]
}
```

### 2. Cambiar Contraseña

```bash
# Cambiar contraseña del usuario admin
curl -s -X POST -u admin:@MiguelAngel05 \
  http://localhost:9001/api/users/change_password \
  -d "login=admin" \
  -d "password=NuevaContraseña123" \
  -d "previousPassword=@MiguelAngel05"

# Sin respuesta si es exitoso (HTTP 204)
```

## 🧪 Scripts de Automatización

### Script 1: Generar Token Completo

```bash
#!/bin/bash

SONAR_URL="http://localhost:9001"
SONAR_USER="admin"
SONAR_PASS="@MiguelAngel05"
TOKEN_NAME="jenkins-global-analysis-token"

echo "🔍 Revocando token anterior..."
curl -s -X POST -u ${SONAR_USER}:${SONAR_PASS} \
  ${SONAR_URL}/api/user_tokens/revoke \
  -d "name=${TOKEN_NAME}" \
  -d "login=${SONAR_USER}" > /dev/null 2>&1

echo "🔑 Generando nuevo token..."
RESPONSE=$(curl -s -X POST -u ${SONAR_USER}:${SONAR_PASS} \
  ${SONAR_URL}/api/user_tokens/generate \
  -d "name=${TOKEN_NAME}" \
  -d "login=${SONAR_USER}")

TOKEN=$(echo "$RESPONSE" | jq -r '.token')

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
    echo "❌ Error generando token"
    echo "$RESPONSE"
    exit 1
fi

echo "✅ Token generado: ${TOKEN}"
echo "$TOKEN" > /tmp/sonarqube-token.txt
echo "📁 Guardado en: /tmp/sonarqube-token.txt"
```

### Script 2: Verificar Estado de Proyectos

```bash
#!/bin/bash

SONAR_URL="http://localhost:9001"
SONAR_USER="admin"
SONAR_PASS="@MiguelAngel05"

echo "📊 Estado de Proyectos en SonarQube:"
echo "═══════════════════════════════════════════════════════════"

# Obtener lista de proyectos
PROJECTS=$(curl -s -u ${SONAR_USER}:${SONAR_PASS} \
  "${SONAR_URL}/api/projects/search" | jq -r '.components[].key')

for PROJECT in $PROJECTS; do
    echo ""
    echo "Proyecto: $PROJECT"
    
    # Obtener Quality Gate
    QG_STATUS=$(curl -s -u ${SONAR_USER}:${SONAR_PASS} \
      "${SONAR_URL}/api/qualitygates/project_status?projectKey=${PROJECT}" \
      | jq -r '.projectStatus.status')
    
    # Obtener medidas
    MEASURES=$(curl -s -u ${SONAR_USER}:${SONAR_PASS} \
      "${SONAR_URL}/api/measures/component?component=${PROJECT}&metricKeys=coverage,bugs,vulnerabilities,code_smells")
    
    COVERAGE=$(echo "$MEASURES" | jq -r '.component.measures[] | select(.metric=="coverage") | .value // "N/A"')
    BUGS=$(echo "$MEASURES" | jq -r '.component.measures[] | select(.metric=="bugs") | .value // "0"')
    VULNS=$(echo "$MEASURES" | jq -r '.component.measures[] | select(.metric=="vulnerabilities") | .value // "0"')
    SMELLS=$(echo "$MEASURES" | jq -r '.component.measures[] | select(.metric=="code_smells") | .value // "0"')
    
    echo "  Quality Gate: $QG_STATUS"
    echo "  Coverage: ${COVERAGE}%"
    echo "  Bugs: $BUGS"
    echo "  Vulnerabilities: $VULNS"
    echo "  Code Smells: $SMELLS"
done

echo ""
echo "═══════════════════════════════════════════════════════════"
```

### Script 3: Configurar Webhook

```bash
#!/bin/bash

SONAR_URL="http://localhost:9001"
SONAR_USER="admin"
SONAR_PASS="@MiguelAngel05"
WEBHOOK_NAME="jenkins-webhook"
WEBHOOK_URL="http://jenkins:8080/sonarqube-webhook/"

echo "🔍 Verificando webhook existente..."
EXISTING=$(curl -s -u ${SONAR_USER}:${SONAR_PASS} \
  ${SONAR_URL}/api/webhooks/list | jq -r ".webhooks[] | select(.name==\"${WEBHOOK_NAME}\") | .key")

if [ -n "$EXISTING" ]; then
    echo "🗑️  Eliminando webhook existente..."
    curl -s -X POST -u ${SONAR_USER}:${SONAR_PASS} \
      ${SONAR_URL}/api/webhooks/delete \
      -d "webhook=${EXISTING}"
fi

echo "🔗 Creando webhook..."
RESPONSE=$(curl -s -X POST -u ${SONAR_USER}:${SONAR_PASS} \
  ${SONAR_URL}/api/webhooks/create \
  -d "name=${WEBHOOK_NAME}" \
  -d "url=${WEBHOOK_URL}")

if echo "$RESPONSE" | jq -e '.webhook' > /dev/null 2>&1; then
    echo "✅ Webhook creado exitosamente"
    echo "   Nombre: ${WEBHOOK_NAME}"
    echo "   URL: ${WEBHOOK_URL}"
else
    echo "❌ Error creando webhook"
    echo "$RESPONSE"
    exit 1
fi
```

## 🔧 Variables de Entorno Recomendadas

```bash
# Agregar a ~/.bashrc o ~/.zshrc
export SONARQUBE_URL="http://localhost:9001"
export SONARQUBE_USER="admin"
export SONARQUBE_PASSWORD="@MiguelAngel05"

# Función helper para llamadas a la API
sonar_api() {
    local endpoint=$1
    shift
    curl -s -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
        "${SONARQUBE_URL}${endpoint}" "$@"
}

# Uso:
# sonar_api /api/system/status | jq
# sonar_api /api/projects/search | jq
```

## 📚 Referencias de API

- **Documentación completa**: http://localhost:9001/web_api
- **User Tokens API**: `/api/user_tokens`
- **Webhooks API**: `/api/webhooks`
- **Projects API**: `/api/projects`
- **Quality Gates API**: `/api/qualitygates`
- **Measures API**: `/api/measures`
- **Authentication API**: `/api/authentication`

## 🔒 Notas de Seguridad

1. **No expongas contraseñas en logs**: Usa `-s` en curl para modo silencioso
2. **No commitees tokens**: Usa `.gitignore` para archivos con tokens
3. **Usa HTTPS en producción**: Nunca HTTP con credenciales reales
4. **Rota tokens regularmente**: Genera nuevos tokens periódicamente
5. **Usa variables de entorno**: No hardcodees credenciales en scripts
6. **Limita permisos de tokens**: Crea tokens con el mínimo privilegio necesario

## 💡 Tips

- Usa `jq` para formatear JSON: `curl ... | jq`
- Usa `jq -r` para extraer valores sin comillas: `jq -r '.token'`
- Guarda respuestas en variables: `TOKEN=$(curl ... | jq -r '.token')`
- Verifica códigos HTTP: `curl -w "%{http_code}" -o /dev/null ...`
- Usa `-X POST` para métodos POST
- Usa `-d "key=value"` para datos del body
- Usa `-H "Header: Value"` para headers personalizados

---

**Última actualización**: 2025-11-10  
**Versión API de SonarQube**: 25.11.0  
**Autor**: Miguel Ángel

