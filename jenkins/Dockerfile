FROM jenkins/jenkins:2.516.3-lts
USER root

# Instalar Docker, Podman, Go, Node.js, Python y herramientas adicionales
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    podman \
    wget \
    unzip \
    python3 \
    python3-pip \
    python3-venv && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Instalar Go 1.21
RUN curl -OL https://go.dev/dl/go1.21.13.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.21.13.linux-amd64.tar.gz && \
    rm go1.21.13.linux-amd64.tar.gz
ENV PATH="${PATH}:/usr/local/go/bin"
ENV GOPATH="/var/jenkins_home/go"
ENV PATH="${PATH}:${GOPATH}/bin"

# Instalar Node.js 20.x y npm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest

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