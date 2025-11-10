#!/bin/bash

# Script para generar automáticamente un token de SonarQube
# y actualizar la configuración de Jenkins

set -e

# Configuración
SONARQUBE_HOST="${SONARQUBE_HOST:-http://localhost:9001}"
SONARQUBE_USER="${SONARQUBE_USER:-admin}"
SONARQUBE_PASSWORD="${SONARQUBE_PASSWORD:-@MiguelAngel05}"
TOKEN_NAME="${TOKEN_NAME:-jenkins-global-analysis-token}"
MAX_RETRIES=30
RETRY_INTERVAL=10

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

# Función para esperar a que SonarQube esté listo
wait_for_sonarqube() {
    local retries=0
    
    echo "⏳ Esperando a que SonarQube esté disponible en ${SONARQUBE_HOST}..."
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -s -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
            "${SONARQUBE_HOST}/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; then
            echo -e "${GREEN}✅ SonarQube está disponible${NC}"
            return 0
        fi
        
        retries=$((retries + 1))
        echo "   Intento ${retries}/${MAX_RETRIES}..."
        sleep $RETRY_INTERVAL
    done
    
    echo -e "${RED}❌ SonarQube no respondió después de ${MAX_RETRIES} intentos${NC}"
    return 1
}

# Función para revocar token existente
revoke_existing_token() {
    local token_name=$1
    
    echo ""
    echo "🔍 Verificando si existe un token con el nombre '${token_name}'..."
    
    # Listar tokens existentes
    local existing_tokens=$(curl -s -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
        "${SONARQUBE_HOST}/api/user_tokens/search?login=${SONARQUBE_USER}")
    
    # Verificar si existe el token
    if echo "$existing_tokens" | grep -q "\"name\":\"${token_name}\""; then
        echo -e "${YELLOW}⚠️  Token existente encontrado. Revocándolo...${NC}"
        
        # Revocar el token
        local response=$(curl -s -X POST -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
            "${SONARQUBE_HOST}/api/user_tokens/revoke" \
            -d "name=${token_name}" \
            -d "login=${SONARQUBE_USER}")
        
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

# Función para generar nuevo token
generate_token() {
    local token_name=$1
    
    echo ""
    echo "🔑 Generando nuevo token '${token_name}'..."
    
    local response=$(curl -s -X POST -u "${SONARQUBE_USER}:${SONARQUBE_PASSWORD}" \
        "${SONARQUBE_HOST}/api/user_tokens/generate" \
        -d "name=${token_name}" \
        -d "login=${SONARQUBE_USER}")
    
    # Extraer el token de la respuesta
    local token=$(echo "$response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$token" ]; then
        echo -e "${RED}❌ Error generando token${NC}"
        echo "Respuesta de SonarQube:"
        echo "$response"
        return 1
    fi
    
    echo -e "${GREEN}✅ Token generado exitosamente${NC}"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo -e "${BLUE}🔐 NUEVO TOKEN:${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo -e "${GREEN}${token}${NC}"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    
    # Guardar token en archivo
    local token_file="/tmp/sonarqube-token.txt"
    echo "$token" > "$token_file"
    echo ""
    echo -e "${GREEN}✅ Token guardado en: ${token_file}${NC}"
    
    # Retornar el token
    echo "$token"
}

# Función para actualizar archivos de Jenkins
update_jenkins_config() {
    local new_token=$1
    local script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    local jenkins_dir="${script_dir}/../jenkins"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🔧 ACTUALIZANDO CONFIGURACIÓN DE JENKINS"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    # Actualizar jenkins.yaml
    if [ -f "${jenkins_dir}/jenkins.yaml" ]; then
        echo "📝 Actualizando jenkins.yaml..."
        
        # Hacer backup
        cp "${jenkins_dir}/jenkins.yaml" "${jenkins_dir}/jenkins.yaml.backup"
        
        # Reemplazar token usando script Python para evitar problemas de escape
        python3 - "$new_token" "${jenkins_dir}/jenkins.yaml" <<'PY'
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
        
        echo -e "${GREEN}✅ jenkins.yaml actualizado${NC}"
    else
        echo -e "${YELLOW}⚠️  jenkins.yaml no encontrado en ${jenkins_dir}${NC}"
    fi
    
    # Actualizar master_setup.groovy
    if [ -f "${jenkins_dir}/init.groovy.d/master_setup.groovy" ]; then
        echo "📝 Actualizando master_setup.groovy..."
        
        # Hacer backup
        cp "${jenkins_dir}/init.groovy.d/master_setup.groovy" "${jenkins_dir}/init.groovy.d/master_setup.groovy.backup"
        
        # Reemplazar token en el script Groovy usando Python para evitar problemas de escape
        python3 - "$new_token" "${jenkins_dir}/init.groovy.d/master_setup.groovy" <<'PY'
import re
import sys
from pathlib import Path

token, path = sys.argv[1], Path(sys.argv[2])
text = path.read_text(encoding="utf-8")

def replace_secret(match):
    return f'Secret.fromString("{token}")'

new_text, count = re.subn(r'Secret\.fromString\("sq[au]_[^"]*"\)', replace_secret, text, count=1)
if count == 0:
    raise SystemExit("No se encontró Secret.fromString(...) en master_setup.groovy")

path.write_text(new_text, encoding="utf-8")
PY
        
        echo -e "${GREEN}✅ master_setup.groovy actualizado${NC}"
    else
        echo -e "${YELLOW}⚠️  master_setup.groovy no encontrado${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Archivos de configuración actualizados${NC}"
    echo ""
    echo "📋 Backups creados:"
    echo "   • jenkins.yaml.backup"
    echo "   • master_setup.groovy.backup"
}

# Función para aplicar cambios en Jenkins
apply_to_jenkins() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🚀 APLICANDO CAMBIOS A JENKINS"
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
    
    echo "🔧 Usando: ${CONTAINER_CMD}"
    echo ""
    
    # Verificar si el contenedor Jenkins existe
    if ! ${CONTAINER_CMD} ps -a --format "{{.Names}}" | grep -q "^jenkins$"; then
        echo -e "${YELLOW}⚠️  Contenedor Jenkins no encontrado${NC}"
        echo "ℹ️  Los archivos están actualizados localmente"
        echo "ℹ️  Aplica los cambios cuando inicies Jenkins"
        return 0
    fi
    
    local script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    local jenkins_dir="${script_dir}/../jenkins"
    
    # Copiar archivos al contenedor
    echo "📦 Copiando archivos al contenedor..."
    
    if ${CONTAINER_CMD} cp "${jenkins_dir}/jenkins.yaml" jenkins:/var/jenkins_home/jenkins.yaml; then
        echo -e "${GREEN}✅ jenkins.yaml copiado${NC}"
    else
        echo -e "${RED}❌ Error copiando jenkins.yaml${NC}"
    fi
    
    if ${CONTAINER_CMD} cp "${jenkins_dir}/init.groovy.d/master_setup.groovy" \
        jenkins:/var/jenkins_home/init.groovy.d/master_setup.groovy; then
        echo -e "${GREEN}✅ master_setup.groovy copiado${NC}"
    else
        echo -e "${RED}❌ Error copiando master_setup.groovy${NC}"
    fi
    
    # Eliminar credentials.xml para forzar regeneración
    echo ""
    echo "🗑️  Eliminando credentials.xml cacheado..."
    ${CONTAINER_CMD} exec jenkins rm -f /var/jenkins_home/credentials.xml || true
    echo -e "${GREEN}✅ credentials.xml eliminado${NC}"
    
    # Reiniciar Jenkins
    echo ""
    echo "🔄 Reiniciando Jenkins..."
    ${CONTAINER_CMD} restart jenkins
    
    echo -e "${GREEN}✅ Jenkins reiniciado${NC}"
    echo ""
    echo "⏳ Esperando 20 segundos para que Jenkins se inicie..."
    sleep 20
    
    # Verificar que Jenkins está funcionando
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8083/ | grep -q "200"; then
        echo -e "${GREEN}✅ Jenkins está funcionando correctamente${NC}"
    else
        echo -e "${YELLOW}⚠️  Jenkins aún se está iniciando...${NC}"
        echo "ℹ️  Espera unos segundos más antes de ejecutar pipelines"
    fi
}

# ===========================================================================
# FLUJO PRINCIPAL
# ===========================================================================

echo "📋 Configuración:"
echo "   SonarQube Host: ${SONARQUBE_HOST}"
echo "   Usuario: ${SONARQUBE_USER}"
echo "   Nombre del token: ${TOKEN_NAME}"
echo ""

# Paso 1: Esperar a que SonarQube esté listo
if ! wait_for_sonarqube; then
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

# Paso 2: Revocar token existente (si existe)
if ! revoke_existing_token "$TOKEN_NAME"; then
    echo -e "${YELLOW}⚠️  Advertencia: No se pudo revocar el token existente${NC}"
    echo "ℹ️  Continuando de todos modos..."
fi

# Paso 3: Generar nuevo token
NEW_TOKEN=$(generate_token "$TOKEN_NAME")

if [ -z "$NEW_TOKEN" ]; then
    echo ""
    echo -e "${RED}❌ Error: No se pudo generar el token${NC}"
    exit 1
fi

# Paso 4: Actualizar archivos de Jenkins
update_jenkins_config "$NEW_TOKEN"

# Paso 5: Aplicar cambios a Jenkins (si está corriendo)
echo ""
read -p "¿Deseas aplicar los cambios a Jenkins ahora? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    apply_to_jenkins
else
    echo ""
    echo "ℹ️  Cambios guardados localmente"
    echo ""
    echo "Para aplicar los cambios manualmente:"
    echo ""
    echo "  1. Copiar archivos al contenedor:"
    echo "     podman cp jenkins/jenkins.yaml jenkins:/var/jenkins_home/jenkins.yaml"
    echo "     podman cp jenkins/init.groovy.d/master_setup.groovy jenkins:/var/jenkins_home/init.groovy.d/"
    echo ""
    echo "  2. Eliminar credentials.xml:"
    echo "     podman exec jenkins rm -f /var/jenkins_home/credentials.xml"
    echo ""
    echo "  3. Reiniciar Jenkins:"
    echo "     podman restart jenkins"
    echo ""
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                    ✨ PROCESO COMPLETADO                          ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 Resumen:"
echo "   • Token generado: ✅"
echo "   • jenkins.yaml actualizado: ✅"
echo "   • master_setup.groovy actualizado: ✅"
echo "   • Token guardado en: /tmp/sonarqube-token.txt"
echo ""
echo "🎯 El nuevo token está listo para usar en tus pipelines"
echo ""

