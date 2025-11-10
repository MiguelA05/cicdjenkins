# CI/CD Jenkins Infrastructure

Repositorio con la configuración de Jenkins como código, scripts de automatización y utilidades de soporte para la plataforma de CI/CD. Incluye configuración inicial del controlador Jenkins, automatización de tokens de SonarQube, herramientas para webhooks y generadores de secretos.

## Estructura del Repositorio

```
cicdjenkins/
├── jenkins/
│   ├── Dockerfile
│   ├── jenkins.yaml
│   ├── plugins.txt
│   └── init.groovy.d/
│       └── master_setup.groovy
├── scripts/
│   ├── generate-sonar-token.sh
│   └── setup-complete-stack.sh
├── sonar/
│   └── conf.d/
│       └── sonar-project.properties
├── token-generator/
│   ├── Dockerfile
│   └── generate-and-update-token.sh
└── webhook-configurator/
    ├── Dockerfile
    └── configure-webhook.sh
```

## Jenkins como Código (JCasC)

El directorio `jenkins/` contiene todo lo necesario para inicializar una instancia de Jenkins utilizando Jenkins Configuration as Code (JCasC).

- `jenkins.yaml`: Configuración principal de Jenkins (usuarios, credenciales, herramientas, pipelines, etc.).
- `init.groovy.d/master_setup.groovy`: Script Groovy que crea credenciales, define pipelines y realiza ajustes adicionales durante el arranque.
- `plugins.txt`: Lista de plugins que se instalan automáticamente en la imagen Docker.
- `Dockerfile`: Imagen base para ejecutar Jenkins con la configuración incluida.

### Construir imagen personalizada de Jenkins

```bash
cd jenkins
podman build -t custom-jenkins .      # o docker build
```

### Aplicar cambios sin reconstruir la imagen

1. Copiar `jenkins.yaml` y los scripts Groovy al contenedor:
   ```bash
   podman cp jenkins/jenkins.yaml jenkins:/var/jenkins_home/jenkins.yaml
   podman cp jenkins/init.groovy.d/master_setup.groovy \
     jenkins:/var/jenkins_home/init.groovy.d/master_setup.groovy
   ```
2. Eliminar `credentials.xml` para forzar la regeneración:
   ```bash
   podman exec jenkins rm -f /var/jenkins_home/credentials.xml
   ```
3. Reiniciar Jenkins:
   ```bash
   podman restart jenkins
   ```

## Automatización de Token de SonarQube

El script `scripts/generate-sonar-token.sh` automatiza la creación de tokens globales en SonarQube y actualiza la configuración de Jenkins.

### Dependencias

- SonarQube accesible (por defecto `http://localhost:9001`).
- `curl`, `sed`, `python3` instalados.
- Herramienta de contenedores (`podman` o `docker`).
- Credenciales de SonarQube (usuario y contraseña de administrador).

### Ejecución

```bash
cd scripts
./generate-sonar-token.sh
```

El script realiza los siguientes pasos:

1. Verifica que SonarQube esté disponible.
2. Revoca el token existente (si aplica).
3. Genera un nuevo token y lo almacena en `/tmp/sonarqube-token.txt`.
4. Actualiza `jenkins/jenkins.yaml` y `init.groovy.d/master_setup.groovy` con el token nuevo.
5. Copia los archivos al contenedor `jenkins` y reinicia el servicio (solo si el contenedor está corriendo).

Variables que se pueden ajustar antes de ejecutar el script:

```bash
export SONARQUBE_HOST="http://localhost:9001"
export SONARQUBE_USER="admin"
export SONARQUBE_PASSWORD="admin"
export TOKEN_NAME="jenkins-global-analysis-token"
```

## Aprovisionamiento de la Plataforma

El script `scripts/setup-complete-stack.sh` prepara la pila de herramientas necesaria para la plataforma (Jenkins, SonarQube, PostgreSQL, RabbitMQ, Loki, Grafana, entre otros). Revisar y adaptar el script antes de su ejecución para garantizar rutas y parámetros correctos.

```bash
cd scripts
./setup-complete-stack.sh
```

## Token Generator

`token-generator/` contiene una utilidad para generar tokens o secretos y actualizarlos en Jenkins u otros servicios.

- `generate-and-update-token.sh`: Script principal; registra los valores generados en los archivos de configuración cuando corresponde.
- `Dockerfile`: Imagen ligera para ejecutar el generador en ambientes aislados.

Uso básico:

```bash
cd token-generator
./generate-and-update-token.sh
```

## Webhook Configurator

`webhook-configurator/` incluye herramientas para configurar webhooks de repositorios (GitHub o GitLab) apuntando a Jenkins.

- `configure-webhook.sh`: Script que crea o actualiza webhooks utilizando la API del proveedor.
- `Dockerfile`: Imagen preparada para ejecutar el configurador en entornos controlados.

Ejemplo de uso:

```bash
cd webhook-configurator
./configure-webhook.sh \
  --provider github \
  --repo https://github.com/<org>/<repo> \
  --webhook-url https://jenkins.example.com/github-webhook/
```

Revisar el script para conocer todos los parámetros soportados (token de API, opciones de SSL, eventos de webhook, etc.).

## Buenas Prácticas

- Versionar cualquier cambio en `jenkins.yaml` y `master_setup.groovy`; estos archivos definen la infraestructura de CI/CD.
- Ejecutar `generate-sonar-token.sh` cada vez que se rote el token global de SonarQube.
- Evitar credenciales en claro dentro de los scripts; usar variables de entorno o gestores de secretos.
- Antes de reiniciar Jenkins, confirmar que no existan pipelines en ejecución.

## Referencias

- Jenkins Configuration as Code: https://www.jenkins.io/projects/jcasc/
- Tokens de SonarQube: https://docs.sonarsource.com/sonarqube/latest/user-guide/user-account-tokens/
- API de GitHub Webhooks: https://docs.github.com/en/rest/webhooks
- API de GitLab Webhooks: https://docs.gitlab.com/ee/api/projects.html#add-project-hook
