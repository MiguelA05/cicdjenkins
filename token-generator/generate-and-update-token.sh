#!/bin/bash

# Script completamente automatizado para generar token de SonarQube
# y actualizar Jenkins - NO requiere interacción del usuario
# Diseñado para ejecutarse en contenedor o como parte del stack

set -e

# Configuración desde variables de entorno o valores por defecto
SONARQUBE_HOST="${SONARQUBE_HOST:-http://sonarqube:9000}"
SONARQUBE_USER="${SONARQUBE_USER:-admin}"
SONARQUBE_PASSWORD="${SONARQUBE_PASSWORD:-@MiguelAngel05}"
JENKINS_HOST="${JENKINS_HOST:-http://jenkins:8080}"
TOKEN_NAME="${TOKEN_NAME:-jenkins-global-analysis-token}"
MAX_RETRIES="${MAX_RETRIES:-30}"
RETRY_INTERVAL="${RETRY_INTERVAL:-10}"
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/sonarqube-token.txt}"

echo "════════════════════════════════════════════════════════════════"
echo "🔐 Generador Automático de Token de SonarQube"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Configuración:"
echo "  • SonarQube: ${SONARQUBE_HOST}"
echo "  • Jenkins: ${JENKINS_HOST}"
echo "  • Usuario: ${SONARQUBE_USER}"
echo "  • Token: ${TOKEN_NAME}"
echo ""

# Esperar a SonarQube
echo "⏳ Esperando a SonarQube..."
retries=0
while [ $retries -lt $MAX_RETRIES ]; do
    if curl -s -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
        "${SONARQUBE_HOST}/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; then
        echo "✅ SonarQube disponible"
        break
    fi
    retries=$((retries + 1))
    echo "   Intento ${retries}/${MAX_RETRIES}..."
    sleep $RETRY_INTERVAL
done

if [ $retries -eq $MAX_RETRIES ]; then
    echo "❌ SonarQube no disponible después de ${MAX_RETRIES} intentos"
    exit 1
fi

# Revocar token existente
echo ""
echo "🔍 Revocando token existente (si existe)..."
curl -s -X POST -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
    "${SONARQUBE_HOST}/api/user_tokens/revoke" \
    -d "name=${TOKEN_NAME}" \
    -d "login=${SONARQUBE_USER}" > /dev/null 2>&1 || echo "   No hay token previo"

# Generar nuevo token
echo "🔑 Generando nuevo token..."
RESPONSE=$(curl -s -X POST -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
    "${SONARQUBE_HOST}/api/user_tokens/generate" \
    -d "name=${TOKEN_NAME}" \
    -d "login=${SONARQUBE_USER}")

# Extraer token
NEW_TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$NEW_TOKEN" ]; then
    echo "❌ Error generando token"
    echo "Respuesta: $RESPONSE"
    exit 1
fi

echo "✅ Token generado: ${NEW_TOKEN}"
echo ""

# Guardar en archivo
echo "$NEW_TOKEN" > "$OUTPUT_FILE"
echo "📁 Token guardado en: ${OUTPUT_FILE}"

# Exportar como variable de entorno para scripts posteriores
export SONARQUBE_TOKEN="$NEW_TOKEN"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✨ Token generado exitosamente"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Para usar este token:"
echo "  1. Manual: cat ${OUTPUT_FILE}"
echo "  2. Script: SONARQUBE_TOKEN=\$(cat ${OUTPUT_FILE})"
echo "  3. Variable de entorno ya exportada: \$SONARQUBE_TOKEN"
echo ""

