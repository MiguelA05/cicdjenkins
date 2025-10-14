FROM jenkins/jenkins:2.516.3-lts
USER root

# Instalar Docker y Podman para TestContainers y ejecución de contenedores
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    podman && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Crear directorios para configuración automática en ubicación que no sea sobrescrita
RUN mkdir -p /usr/share/jenkins/ref/casc_configs
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

# Copiar archivos de configuración
COPY jenkins.yaml /usr/share/jenkins/ref/casc_configs/jenkins.yaml
COPY init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/

# Establecer permisos correctos
RUN chown -R jenkins:jenkins /usr/share/jenkins/ref/casc_configs
RUN chown -R jenkins:jenkins /usr/share/jenkins/ref/init.groovy.d
RUN chmod 644 /usr/share/jenkins/ref/casc_configs/jenkins.yaml
RUN chmod 644 /usr/share/jenkins/ref/init.groovy.d/*

USER jenkins