FROM alpine:3.19

# Instalar dependencias necesarias
RUN apk update && apk add --no-cache \
    bash \
    curl \
    jq \
    grep \
    python3

# Instalar podman (opcional, para aplicar cambios a Jenkins)
# Nota: Podman requiere más dependencias, así que lo hacemos opcional
# Si no está disponible, el script continuará sin aplicar cambios al contenedor

# Crear directorio de trabajo
WORKDIR /app

# Copiar script
COPY generate-and-update-token.sh /app/

# Hacer ejecutable
RUN chmod +x /app/generate-and-update-token.sh

# Comando por defecto
CMD ["/app/generate-and-update-token.sh"]

