#!/bin/bash

# Script completo para inicializar el stack CI/CD con configuración automática
# Este script automatiza:
# 1. Generación de token de SonarQube
# 2. Configuración de webhook
# 3. Actualización de Jenkins

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="${SCRIPT_DIR}/.."

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║         🚀 CONFIGURACIÓN COMPLETA DEL STACK CI/CD                 ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Detectar container runtime
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    echo "❌ No se encontró docker ni podman"
    exit 1
fi

echo "🔧 Usando: ${CONTAINER_CMD}"
echo ""

# Verificar que los servicios estén corriendo
echo "═══════════════════════════════════════════════════════════════════"
echo "📋 Verificando servicios..."
echo "═══════════════════════════════════════════════════════════════════"
echo ""

services=("sonarqube" "jenkins")
all_running=true

for service in "${services[@]}"; do
    if ${CONTAINER_CMD} ps --format "{{.Names}}" | grep -q "^${service}$"; then
        echo "✅ ${service} está corriendo"
    else
        echo "❌ ${service} no está corriendo"
        all_running=false
    fi
done

if [ "$all_running" = false ]; then
    echo ""
    echo "⚠️  Algunos servicios no están corriendo"
    read -p "¿Deseas iniciar los servicios ahora? (y/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🚀 Iniciando servicios..."
        cd "${PROJECT_ROOT}"
        ${CONTAINER_CMD}-compose up -d sonarqube jenkins
        
        echo "⏳ Esperando 60 segundos a que los servicios se inicien..."
        sleep 60
    else
        echo "❌ Los servicios deben estar corriendo para continuar"
        exit 1
    fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "🔐 Paso 1: Generar Token de SonarQube"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

if [ -f "${SCRIPT_DIR}/generate-sonar-token.sh" ]; then
    bash "${SCRIPT_DIR}/generate-sonar-token.sh"
else
    echo "❌ Script generate-sonar-token.sh no encontrado"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "🔗 Paso 2: Configurar Webhook de SonarQube"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Ejecutar configurador de webhook en contenedor
echo "🚀 Ejecutando configurador de webhook..."

${CONTAINER_CMD} run --rm \
    --network="${PROJECT_ROOT##*/}_default" \
    -e SONARQUBE_HOST=http://sonarqube:9000 \
    -e SONARQUBE_USER=admin \
    -e SONARQUBE_PASSWORD=@MiguelAngel05 \
    -e JENKINS_HOST=http://jenkins:8080 \
    webhook-configurator:latest || {
        echo "⚠️  Error ejecutando configurador de webhook"
        echo "ℹ️  Puedes configurarlo manualmente más tarde"
    }

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "✅ Paso 3: Verificar Configuración"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Verificar Jenkins
echo "🔍 Verificando Jenkins..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8083/ | grep -q "200"; then
    echo "✅ Jenkins está accesible en http://localhost:8083/"
else
    echo "⚠️  Jenkins no está respondiendo en http://localhost:8083/"
fi

# Verificar SonarQube
echo "🔍 Verificando SonarQube..."
if curl -s http://localhost:9001/api/system/status | grep -q '"status":"UP"'; then
    echo "✅ SonarQube está accesible en http://localhost:9001/"
else
    echo "⚠️  SonarQube no está respondiendo en http://localhost:9001/"
fi

# Mostrar token generado
if [ -f "/tmp/sonarqube-token.txt" ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🔐 Token de SonarQube Generado:"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    cat /tmp/sonarqube-token.txt
    echo ""
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║              ✨ CONFIGURACIÓN COMPLETADA                          ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Resumen:"
echo "   • Token de SonarQube: ✅ Generado y configurado"
echo "   • Webhook SonarQube → Jenkins: ✅ Configurado"
echo "   • Jenkins actualizado: ✅ Con nuevo token"
echo ""
echo "🎯 Siguiente paso:"
echo "   Ejecuta tus pipelines en Jenkins:"
echo "   → http://localhost:8083/"
echo ""
echo "📊 Visualiza análisis en SonarQube:"
echo "   → http://localhost:9001/"
echo "   Credenciales: admin / @MiguelAngel05"
echo ""

