FROM alpine:3.19

# Instalar dependencias necesarias
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    grep

# Crear directorio de trabajo
WORKDIR /app

# Copiar script
COPY generate-and-update-token.sh /app/

# Hacer ejecutable
RUN chmod +x /app/generate-and-update-token.sh

# Comando por defecto
CMD ["/app/generate-and-update-token.sh"]

