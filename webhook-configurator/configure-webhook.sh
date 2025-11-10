#!/bin/bash

# Script para configurar webhook en SonarQube para notificar a Jenkins
# Este script espera a que ambos servicios estén listos antes de configurar

SONARQUBE_HOST="http://sonarqube:9000"
SONARQUBE_USER="admin"
SONARQUBE_PASSWORD="@MiguelAngel05"
JENKINS_HOST="http://jenkins:8080"
WEBHOOK_NAME="jenkins-webhook"
WEBHOOK_URL="${JENKINS_HOST}/sonarqube-webhook/"
MAX_RETRIES=30
RETRY_INTERVAL=10

echo "═══════════════════════════════════════════════"
echo "🔧 CONFIGURADOR AUTOMÁTICO DE WEBHOOK"
echo "═══════════════════════════════════════════════"
echo ""

# Función para esperar a que un servicio esté listo
wait_for_service() {
    local service_name=$1
    local service_url=$2
    local check_command=$3
    local retries=0
    
    echo "⏳ Esperando a que ${service_name} esté disponible..."
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if eval "$check_command" > /dev/null 2>&1; then
            echo "✅ ${service_name} está disponible"
            return 0
        fi
        
        retries=$((retries + 1))
        echo "   Intento ${retries}/${MAX_RETRIES}..."
        sleep $RETRY_INTERVAL
    done
    
    echo "❌ ${service_name} no respondió después de ${MAX_RETRIES} intentos"
    return 1
}

# Esperar a SonarQube
if ! wait_for_service "SonarQube" "$SONARQUBE_HOST" \
    "curl -s -u '${SONARQUBE_USER}:${SONARQUBE_PASSWORD}' '${SONARQUBE_HOST}/api/system/status' | grep -q '\"status\":\"UP\"'"; then
    echo "❌ No se pudo conectar a SonarQube"
    exit 1
fi

# Esperar a Jenkins
if ! wait_for_service "Jenkins" "$JENKINS_HOST" \
    "curl -s '${JENKINS_HOST}/login' | grep -q 'Jenkins'"; then
    echo "❌ No se pudo conectar a Jenkins"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "🔗 CONFIGURANDO WEBHOOK"
echo "═══════════════════════════════════════════════"
echo ""

# Verificar si el webhook ya existe
echo "🔍 Verificando si el webhook ya existe..."
EXISTING_WEBHOOK=$(curl -s -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
    "${SONARQUBE_HOST}/api/webhooks/list" | grep -o "\"name\":\"${WEBHOOK_NAME}\"")

if [ -n "$EXISTING_WEBHOOK" ]; then
    echo "⚠️  El webhook '${WEBHOOK_NAME}' ya existe. Eliminándolo..."
    
    # Obtener el key del webhook existente
    WEBHOOK_KEY=$(curl -s -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
        "${SONARQUBE_HOST}/api/webhooks/list" | \
        jq -r '.webhooks[0].key' 2>/dev/null)
    
    if [ -n "$WEBHOOK_KEY" ] && [ "$WEBHOOK_KEY" != "null" ]; then
        RESPONSE=$(curl -s -X POST -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
            "${SONARQUBE_HOST}/api/webhooks/delete?webhook=${WEBHOOK_KEY}")
        
        if echo "$RESPONSE" | grep -q "errors"; then
            echo "⚠️  Error eliminando webhook existente, continuando..."
        else
            echo "✅ Webhook existente eliminado"
        fi
    fi
fi

# Crear el webhook
echo "🔗 Creando webhook..."
RESPONSE=$(curl -s -X POST -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
    "${SONARQUBE_HOST}/api/webhooks/create" \
    -d "name=${WEBHOOK_NAME}" \
    -d "url=${WEBHOOK_URL}")

if echo "$RESPONSE" | grep -q "\"webhook\"" || echo "$RESPONSE" | grep -q "\"key\""; then
    echo "✅ Webhook creado exitosamente"
    echo ""
    echo "📋 Detalles del webhook:"
    echo "   Nombre: ${WEBHOOK_NAME}"
    echo "   URL: ${WEBHOOK_URL}"
    echo "   SonarQube: ${SONARQUBE_HOST}"
    echo "   Jenkins: ${JENKINS_HOST}"
    echo ""
    echo "🎯 Jenkins ahora recibirá notificaciones de SonarQube"
else
    echo "❌ Error creando webhook"
    echo "Respuesta: $RESPONSE"
    
    # Intentar obtener más detalles del error
    if echo "$RESPONSE" | grep -q "errors"; then
        echo "Detalles del error:"
        echo "$RESPONSE" | jq '.errors' 2>/dev/null || echo "$RESPONSE"
    fi
    
    exit 1
fi

# Verificar que el webhook se creó correctamente
echo ""
echo "🔍 Verificando webhook..."
VERIFICATION=$(curl -s -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
    "${SONARQUBE_HOST}/api/webhooks/list")

if echo "$VERIFICATION" | grep -q "\"name\":\"${WEBHOOK_NAME}\""; then
    echo "✅ Webhook verificado correctamente"
    
    # Mostrar todos los webhooks configurados
    echo ""
    echo "📋 Webhooks configurados en SonarQube:"
    echo "$VERIFICATION" | jq -r '.webhooks[] | "   • \(.name): \(.url)"' 2>/dev/null || \
        echo "$VERIFICATION" | grep -o "\"name\":\"[^\"]*\"" | sed 's/"name":"/   • /g' | sed 's/"//g'
else
    echo "⚠️  No se pudo verificar el webhook"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "✨ CONFIGURACIÓN COMPLETADA"
echo "═══════════════════════════════════════════════"
echo ""
echo "ℹ️  El Quality Gate ahora funcionará correctamente"
echo "ℹ️  Las pipelines recibirán notificaciones de SonarQube"
echo ""

