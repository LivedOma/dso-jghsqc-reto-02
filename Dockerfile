# =========================================================
#  Dockerfile - demo-micro
#  La imagen ES el binario: lo que se construye aqui es el
#  entregable que despues se despliega en cualquier ambiente.
# =========================================================

FROM eclipse-temurin:17-jre

# Metadatos trazables (los inyecta GitHub Actions via build-args)
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

HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget -q --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["sh","-c","java $JAVA_OPTS -jar /opt/app/app.jar"]
