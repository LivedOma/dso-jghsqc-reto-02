# =========================================================
#  Dockerfile - demo-micro
#  La imagen ES el binario: lo que se construye aqui es el
#  entregable que despues se despliega en cualquier ambiente.
#
#  Base multi-arquitectura (amd64 + arm64): la variante
#  alpine de eclipse-temurin solo publica amd64, por lo que
#  falla al construir en agentes ARM (Apple Silicon).
# =========================================================

FROM eclipse-temurin:17-jre

# Metadatos trazables (los inyecta el pipeline via build-args)
ARG APP_VERSION=local
ARG GIT_SHA=unknown
LABEL org.opencontainers.image.title="demo-micro" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}"

ARG JAR_FILE=target/*.jar

# Buena practica de seguridad del curso: el contenedor NO corre como root
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

WORKDIR /opt/app
COPY ${JAR_FILE} /opt/app/app.jar
RUN chown -R appuser:appgroup /opt/app

USER appuser

ENV APP_VERSION=${APP_VERSION} \
    JAVA_OPTS=""

EXPOSE 8080

# Java 17 trae jcmd/jwebserver pero no curl ni wget en la imagen slim:
# se usa una conexion TCP nativa de bash para la probe.
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD bash -c 'exec 3<>/dev/tcp/localhost/8080' || exit 1

ENTRYPOINT ["sh","-c","java $JAVA_OPTS -jar /opt/app/app.jar"]
