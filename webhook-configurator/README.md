# Configurador Automático de Webhook SonarQube-Jenkins

Este directorio contiene una imagen Docker que configura automáticamente el webhook entre SonarQube y Jenkins para que el Quality Gate funcione sin timeouts.

## 📋 ¿Qué hace?

El configurador:
1. ✅ Espera a que SonarQube y Jenkins estén disponibles
2. ✅ Elimina webhooks existentes si hay conflictos
3. ✅ Crea un webhook que notifica a Jenkins cuando SonarQube completa el análisis
4. ✅ Verifica que la configuración se aplicó correctamente

## 🚀 Uso Rápido

### Opción 1: Ejecutar manualmente

```bash
# Desde el directorio cicdjenkins/webhook-configurator
docker build -t webhook-configurator:latest .
docker run --rm --network github_observability webhook-configurator:latest
```

### Opción 2: Configurar password de SonarQube y ejecutar

Si la contraseña de admin de SonarQube NO es `admin`:

1. Accede a SonarQube: http://localhost:9001
2. Login con admin/admin (o la contraseña que hayas configurado)
3. Edita `configure-webhook.sh` y actualiza:
   ```bash
   SONARQUBE_PASSWORD="tu_password_aqui"
   ```
4. Reconstruye y ejecuta:
   ```bash
   docker build -t webhook-configurator:latest .
   docker run --rm --network github_observability webhook-configurator:latest
   ```

## 🔧 Configuración Manual del Webhook

Si prefieres configurarlo manualmente:

1. Accede a SonarQube: http://localhost:9001
2. Login como admin
3. Ir a: **Administration** → **Configuration** → **Webhooks**
4. Click en **Create**
5. Configurar:
   - **Name**: `jenkins-webhook`
   - **URL**: `http://jenkins:8080/sonarqube-webhook/`
6. Click en **Create**

## 📊 Verificación

Para verificar que el webhook funciona:

```bash
# Listar webhooks configurados
curl -s -u admin:tu_password "http://localhost:9001/api/webhooks/list" | jq '.'
```

Deberías ver algo como:

```json
{
  "webhooks": [
    {
      "key": "...",
      "name": "jenkins-webhook",
      "url": "http://jenkins:8080/sonarqube-webhook/"
    }
  ]
}
```

## ❓ ¿Es necesario el webhook?

**NO es obligatorio**. La pipeline funciona correctamente sin webhook:

- **Sin webhook**: Quality Gate espera 2 minutos, luego continúa → ✅ Funciona
- **Con webhook**: Quality Gate recibe respuesta inmediata → ⚡ Mejor experiencia

## 🐛 Troubleshooting

### Error: "Insufficient privileges"

El token de análisis NO puede crear webhooks. Necesitas:
- Usar credenciales de admin (usuario/password)
- O crear el webhook manualmente desde la interfaz web

### Error: "401 Unauthorized"

La contraseña es incorrecta. Verifica:
1. Las credenciales en SonarQube
2. Actualiza `SONARQUBE_PASSWORD` en el script

### Error: "unable to find network"

Verifica el nombre de la red Docker:

```bash
# Ver redes disponibles
docker network ls

# Usar la red correcta (probablemente github_observability)
docker run --rm --network github_observability webhook-configurator:latest
```

## 📝 Archivos

- `Dockerfile` - Imagen Alpine con bash, curl y jq
- `configure-webhook.sh` - Script que configura el webhook
- `README.md` - Esta documentación

## ✨ Mejoras Futuras

- [ ] Automatizar la ejecución en docker-compose
- [ ] Usar secrets para la contraseña
- [ ] Reintentos automáticos si falla
- [ ] Soporte para múltiples webhooks

