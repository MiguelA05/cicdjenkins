FROM alpine:3.18

# Instalar herramientas necesarias
RUN apk add --no-cache \
    bash \
    curl \
    jq

# Copiar script de configuración
COPY configure-webhook.sh /usr/local/bin/configure-webhook.sh
RUN chmod +x /usr/local/bin/configure-webhook.sh

# Comando por defecto
CMD ["/usr/local/bin/configure-webhook.sh"]

