#!/bin/bash

# Script completamente automatizado para generar token de SonarQube
# y actualizar Jenkins - NO requiere interacción del usuario
# Diseñado para ejecutarse en contenedor o como parte del stack

set -e

# Estado global para saber si la actualización de archivos fue exitosa
CONFIG_UPDATED=0
# Último token generado
GENERATED_TOKEN=""

# Configuración desde variables de entorno o valores por defecto
SONARQUBE_HOST="${SONARQUBE_HOST:-http://sonarqube:9000}"
SONARQUBE_USER="${SONARQUBE_USER:-admin}"
SONARQUBE_PASSWORD="${SONARQUBE_PASSWORD:-@MiguelAngel05}"
SONARQUBE_DEFAULT_PASSWORD="${SONARQUBE_DEFAULT_PASSWORD:-admin}"
JENKINS_HOST="${JENKINS_HOST:-http://jenkins:8080}"
TOKEN_NAME="${TOKEN_NAME:-jenkins-global-analysis-token}"
MAX_RETRIES="${MAX_RETRIES:-30}"
RETRY_INTERVAL="${RETRY_INTERVAL:-10}"
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/sonarqube-token.txt}"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║     🔐 GENERADOR AUTOMÁTICO DE TOKEN DE SONARQUBE                 ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Configuración:"
echo "   SonarQube Host: ${SONARQUBE_HOST}"
echo "   Usuario: ${SONARQUBE_USER}"
echo "   Nombre del token: ${TOKEN_NAME}"
echo ""

# Función para verificar si SonarQube está disponible (sin autenticación)
check_sonarqube_available() {
    local status=$(curl -s "${SONARQUBE_HOST}/api/system/status" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    [ "$status" = "UP" ]
}

# Función para verificar credenciales
check_credentials() {
    local user=$1
    local password=$2
    local response=$(curl -s -w "\n%{http_code}" -u "${user}:${password}" \
        "${SONARQUBE_HOST}/api/system/status" 2>/dev/null)
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ] && echo "$body" | grep -q '"status":"UP"'; then
        return 0
    else
        return 1
    fi
}

# Función para cambiar contraseña inicial
change_initial_password() {
    echo -e "${YELLOW}🔐 Detectado primer inicio de sesión. Cambiando contraseña...${NC}"
    
    local change_response=$(curl -s -w "\n%{http_code}" -u "${SONARQUBE_USER}:${SONARQUBE_DEFAULT_PASSWORD}" \
        -X POST "${SONARQUBE_HOST}/api/users/change_password" \
        -d "login=${SONARQUBE_USER}" \
        -d "previousPassword=${SONARQUBE_DEFAULT_PASSWORD}" \
        -d "password=${SONARQUBE_PASSWORD}" 2>/dev/null)
    
    local http_code=$(echo "$change_response" | tail -n1)
    
    if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Contraseña cambiada exitosamente${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  No se pudo cambiar la contraseña (puede que ya esté cambiada)${NC}"
        echo "   Código HTTP: ${http_code}"
        return 1
    fi
}

# Función para revocar token existente (mejorada)
revoke_existing_token() {
    local token_name=$1
    
    echo ""
    echo -e "${BLUE}🔍 Verificando si existe un token con el nombre '${token_name}'...${NC}"
    
    # Listar tokens existentes
    local existing_tokens=$(curl -s -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
        "${SONARQUBE_HOST}/api/user_tokens/search?login=${SONARQUBE_USER}" 2>/dev/null || echo "")
    
    # Verificar si existe el token
    if echo "$existing_tokens" | grep -q "\"name\":\"${token_name}\""; then
        echo -e "${YELLOW}⚠️  Token existente encontrado. Revocándolo...${NC}"
        
        # Revocar el token
        local response=$(curl -s -X POST -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
            "${SONARQUBE_HOST}/api/user_tokens/revoke" \
            -d "name=${token_name}" \
            -d "login=${SONARQUBE_USER}" 2>/dev/null)
        
        if echo "$response" | grep -q "errors"; then
            echo -e "${RED}❌ Error revocando token existente${NC}"
            echo "$response"
            return 1
        else
            echo -e "${GREEN}✅ Token existente revocado${NC}"
        fi
    else
        echo "ℹ️  No existe un token con ese nombre"
    fi
    
    return 0
}

# ===========================================================================
# FLUJO PRINCIPAL
# ===========================================================================

# Paso 1: Esperar a que SonarQube esté listo
echo -e "${BLUE}⏳ Esperando a que SonarQube esté disponible en ${SONARQUBE_HOST}...${NC}"
retries=0
while [ $retries -lt $MAX_RETRIES ]; do
    if check_sonarqube_available; then
        echo -e "${GREEN}✅ SonarQube está disponible${NC}"
        break
    fi
    retries=$((retries + 1))
    echo "   Intento ${retries}/${MAX_RETRIES}..."
    sleep $RETRY_INTERVAL
done

if [ $retries -eq $MAX_RETRIES ]; then
    echo ""
    echo -e "${RED}❌ Error: No se pudo conectar a SonarQube${NC}"
    echo ""
    echo "Verifica que:"
    echo "  1. SonarQube esté ejecutándose"
    echo "  2. El host sea correcto: ${SONARQUBE_HOST}"
    echo "  3. Las credenciales sean correctas"
    echo ""
    exit 1
fi

# Paso 2: Verificar credenciales y manejar cambio de contraseña inicial
echo ""
echo -e "${BLUE}🔍 Verificando credenciales...${NC}"
if check_credentials "${SONARQUBE_USER}" "${SONARQUBE_PASSWORD}"; then
    echo -e "${GREEN}✅ Credenciales válidas${NC}"
elif check_credentials "${SONARQUBE_USER}" "${SONARQUBE_DEFAULT_PASSWORD}"; then
    echo -e "${YELLOW}⚠️  Usando contraseña por defecto. Cambiando a contraseña configurada...${NC}"
    if ! change_initial_password; then
        echo -e "${YELLOW}⚠️  Continuando con contraseña por defecto...${NC}"
        SONARQUBE_PASSWORD="${SONARQUBE_DEFAULT_PASSWORD}"
    fi
else
    echo -e "${RED}❌ No se pudo autenticar con ninguna contraseña${NC}"
    echo "   Verifica las credenciales configuradas"
    exit 1
fi

# Paso 3: Revocar token existente (si existe)
if ! revoke_existing_token "$TOKEN_NAME"; then
    echo -e "${YELLOW}⚠️  Advertencia: No se pudo revocar el token existente${NC}"
    echo "ℹ️  Continuando de todos modos..."
fi

# Paso 4: Generar nuevo token
echo ""
echo -e "${BLUE}🔑 Generando nuevo token '${TOKEN_NAME}'...${NC}"

token_response=$(curl -s -w "\n%{http_code}" -X POST -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
    "${SONARQUBE_HOST}/api/user_tokens/generate" \
    -d "name=${TOKEN_NAME}" \
    -d "login=${SONARQUBE_USER}" 2>/dev/null)

token_http_code=$(echo "$token_response" | tail -n1)
token_body=$(echo "$token_response" | head -n-1)

# Extraer token
NEW_TOKEN=$(echo "$token_body" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$NEW_TOKEN" ]; then
    echo -e "${RED}❌ Error generando token${NC}"
    echo "Código HTTP: ${token_http_code}"
    echo "Respuesta: ${token_body}"
    
    # Si el error es por autenticación, intentar cambiar contraseña
    if [ "$token_http_code" = "401" ] || echo "$token_body" | grep -qi "authentication"; then
        echo ""
        echo -e "${YELLOW}⚠️  Error de autenticación. Intentando cambiar contraseña...${NC}"
        if change_initial_password; then
            echo -e "${BLUE}🔄 Reintentando generación de token...${NC}"
            token_response=$(curl -s -w "\n%{http_code}" -X POST -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
                "${SONARQUBE_HOST}/api/user_tokens/generate" \
                -d "name=${TOKEN_NAME}" \
                -d "login=${SONARQUBE_USER}" 2>/dev/null)
            token_http_code=$(echo "$token_response" | tail -n1)
            token_body=$(echo "$token_response" | head -n-1)
            NEW_TOKEN=$(echo "$token_body" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
            
            if [ -z "$NEW_TOKEN" ]; then
                echo -e "${RED}❌ Error persistente generando token después de cambiar contraseña${NC}"
                exit 1
            fi
        else
            exit 1
        fi
    else
        exit 1
    fi
fi

echo -e "${GREEN}✅ Token generado exitosamente${NC}"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo -e "${BLUE}🔐 NUEVO TOKEN:${NC}"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}${NEW_TOKEN}${NC}"
echo ""
echo "═══════════════════════════════════════════════════════════════════"

# Guardar token en archivo
echo "$NEW_TOKEN" > "$OUTPUT_FILE"
echo ""
echo -e "${GREEN}✅ Token guardado en: ${OUTPUT_FILE}${NC}"

# Guardar token en variable global para uso posterior
GENERATED_TOKEN="$NEW_TOKEN"

# Exportar como variable de entorno para scripts posteriores
export SONARQUBE_TOKEN="$NEW_TOKEN"

# Función para actualizar archivos de Jenkins
update_jenkins_config() {
    local new_token=$1
    local script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    local jenkins_dir="${script_dir}/../jenkins"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo -e "${BLUE}🔧 ACTUALIZANDO CONFIGURACIÓN DE JENKINS${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    # Actualizar jenkins.yaml
    if [ -f "${jenkins_dir}/jenkins.yaml" ]; then
        echo -e "${BLUE}📝 Actualizando jenkins.yaml...${NC}"
        
        # Hacer backup
        cp "${jenkins_dir}/jenkins.yaml" "${jenkins_dir}/jenkins.yaml.backup"
        
        # Reemplazar token usando script Python para evitar problemas de escape
        if python3 - "$new_token" "${jenkins_dir}/jenkins.yaml" <<'PY'
import re
import sys
from pathlib import Path

token, path = sys.argv[1], Path(sys.argv[2])
text = path.read_text(encoding="utf-8")

def replace_secret(match):
    prefix, suffix = match.group(1), match.group(2)
    return f"{prefix}{token}{suffix}"

new_text, count = re.subn(r'(secret:\s*")[^"]*(")', replace_secret, text, count=1)
if count == 0:
    raise SystemExit("No se encontró el campo 'secret:' en jenkins.yaml")

path.write_text(new_text, encoding="utf-8")
PY
        then
            echo -e "${GREEN}✅ jenkins.yaml actualizado${NC}"
        else
            echo -e "${RED}❌ Error actualizando jenkins.yaml${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  jenkins.yaml no encontrado en ${jenkins_dir}${NC}"
    fi
    
    # Actualizar master_setup.groovy
    if [ -f "${jenkins_dir}/init.groovy.d/master_setup.groovy" ]; then
        echo -e "${BLUE}📝 Actualizando master_setup.groovy...${NC}"
        
        # Hacer backup
        cp "${jenkins_dir}/init.groovy.d/master_setup.groovy" "${jenkins_dir}/init.groovy.d/master_setup.groovy.backup"
        
        # Reemplazar token en el script Groovy usando Python para evitar problemas de escape
        if python3 - "$new_token" "${jenkins_dir}/init.groovy.d/master_setup.groovy" <<'PY'
import re
import sys
from pathlib import Path

token, path = sys.argv[1], Path(sys.argv[2])
text = path.read_text(encoding="utf-8")

def replace_secret(match):
    return f'Secret.fromString("{token}")'

new_text, count = re.subn(r'Secret\.fromString\(".*?"\)', replace_secret, text, count=1)
if count == 0:
    raise SystemExit("No se encontró Secret.fromString(...) en master_setup.groovy")

path.write_text(new_text, encoding="utf-8")
PY
        then
            echo -e "${GREEN}✅ master_setup.groovy actualizado${NC}"
        else
            echo -e "${RED}❌ Error actualizando master_setup.groovy${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  master_setup.groovy no encontrado${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Archivos de configuración actualizados${NC}"
    echo ""
    echo "📋 Backups creados:"
    echo "   • jenkins.yaml.backup"
    echo "   • master_setup.groovy.backup"
    
    CONFIG_UPDATED=1
    return 0
}

# Función para aplicar cambios en Jenkins
apply_to_jenkins() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo -e "${BLUE}🚀 APLICANDO CAMBIOS A JENKINS${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    # Detectar si estamos usando docker o podman
    if command -v podman &> /dev/null; then
        CONTAINER_CMD="podman"
    elif command -v docker &> /dev/null; then
        CONTAINER_CMD="docker"
    else
        echo -e "${RED}❌ No se encontró docker ni podman${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔧 Usando: ${CONTAINER_CMD}${NC}"
    echo ""
    
    # Verificar si el contenedor Jenkins existe
    local jenkins_container=$(${CONTAINER_CMD} ps -a --format "{{.Names}}" | grep -E "^jenkins$|^.*jenkins.*$" | head -n1)
    
    if [ -z "$jenkins_container" ]; then
        echo -e "${YELLOW}⚠️  Contenedor Jenkins no encontrado${NC}"
        echo "ℹ️  Los archivos están actualizados localmente"
        echo "ℹ️  Aplica los cambios cuando inicies Jenkins"
        return 0
    fi
    
    local script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    local jenkins_dir="${script_dir}/../jenkins"
    
    # Copiar archivos al contenedor
    echo -e "${BLUE}📦 Copiando archivos al contenedor...${NC}"
    
    if ${CONTAINER_CMD} cp "${jenkins_dir}/jenkins.yaml" "${jenkins_container}:/var/jenkins_home/jenkins.yaml" 2>/dev/null; then
        echo -e "${GREEN}✅ jenkins.yaml copiado${NC}"
    else
        echo -e "${YELLOW}⚠️  No se pudo copiar jenkins.yaml (puede que el contenedor no esté corriendo)${NC}"
    fi
    
    if ${CONTAINER_CMD} cp "${jenkins_dir}/init.groovy.d/master_setup.groovy" \
        "${jenkins_container}:/var/jenkins_home/init.groovy.d/master_setup.groovy" 2>/dev/null; then
        echo -e "${GREEN}✅ master_setup.groovy copiado${NC}"
    else
        echo -e "${YELLOW}⚠️  No se pudo copiar master_setup.groovy (puede que el contenedor no esté corriendo)${NC}"
    fi
    
    # Eliminar credentials.xml para forzar regeneración
    echo ""
    echo -e "${BLUE}🗑️  Eliminando credentials.xml cacheado...${NC}"
    ${CONTAINER_CMD} exec "${jenkins_container}" rm -f /var/jenkins_home/credentials.xml 2>/dev/null || true
    echo -e "${GREEN}✅ credentials.xml eliminado${NC}"
    
    # Reiniciar Jenkins
    echo ""
    echo -e "${BLUE}🔄 Reiniciando Jenkins...${NC}"
    ${CONTAINER_CMD} restart "${jenkins_container}" 2>/dev/null || echo -e "${YELLOW}⚠️  No se pudo reiniciar Jenkins${NC}"
    
    echo -e "${GREEN}✅ Jenkins reiniciado${NC}"
    echo ""
    echo -e "${BLUE}⏳ Esperando 20 segundos para que Jenkins se inicie...${NC}"
    sleep 20
    
    # Verificar que Jenkins está funcionando
    local jenkins_url="${JENKINS_HOST}"
    if echo "$jenkins_url" | grep -q "jenkins:"; then
        # Si es URL interna del contenedor, intentar localhost
        jenkins_url=$(echo "$jenkins_url" | sed 's/jenkins:/localhost:/')
    fi
    
    if curl -s -o /dev/null -w "%{http_code}" "${jenkins_url}" 2>/dev/null | grep -q "200"; then
        echo -e "${GREEN}✅ Jenkins está funcionando correctamente${NC}"
    else
        echo -e "${YELLOW}⚠️  Jenkins aún se está iniciando...${NC}"
        echo "ℹ️  Espera unos segundos más antes de ejecutar pipelines"
    fi
}

# Paso 5: Actualizar archivos de Jenkins
if [ -n "$NEW_TOKEN" ]; then
    if update_jenkins_config "$NEW_TOKEN"; then
        echo -e "${GREEN}✅ Configuración de Jenkins actualizada${NC}"
    else
        echo -e "${YELLOW}⚠️  No se pudieron actualizar todos los archivos de Jenkins${NC}"
    fi
else
    echo -e "${RED}❌ No se puede actualizar Jenkins sin token${NC}"
fi

# Paso 6: Aplicar cambios a Jenkins (si está corriendo y la actualización fue exitosa)
if [ "$CONFIG_UPDATED" -eq 1 ]; then
    apply_to_jenkins || echo -e "${YELLOW}⚠️  No se pudo aplicar cambios a Jenkins (puede que no esté corriendo)${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠️  Se omitió la aplicación automática porque la actualización de archivos no fue exitosa${NC}"
    echo "ℹ️  Revisa el output anterior, corrige el problema y vuelve a ejecutar el script."
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                    ✨ PROCESO COMPLETADO                          ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 Resumen:"
echo "   • Token generado: ✅"
if [ "$CONFIG_UPDATED" -eq 1 ]; then
    echo "   • jenkins.yaml actualizado: ✅"
    echo "   • master_setup.groovy actualizado: ✅"
else
    echo "   • jenkins.yaml actualizado: ⚠️"
    echo "   • master_setup.groovy actualizado: ⚠️"
fi
echo "   • Token guardado en: ${OUTPUT_FILE}"
echo ""
echo "🎯 El nuevo token está listo para usar en tus pipelines"
echo ""

