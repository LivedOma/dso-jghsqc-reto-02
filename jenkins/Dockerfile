# =========================================================
#  Jenkins controller con Docker CLI incorporado
#
#  Estrategia: Docker-outside-of-Docker (DooD).
#  Jenkins corre en un contenedor pero usa el demonio Docker
#  del host a traves del socket montado. No instala un Docker
#  dentro de otro Docker: solo necesita el cliente.
# =========================================================

FROM jenkins/jenkins:lts-jdk17

USER root

# Cliente de Docker + Compose. El agente ejecuta 'docker build'
# y 'docker push' desde el pipeline, por eso necesita el binario.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Plugins requeridos por el reto, preinstalados para no depender
# del wizard: Pipeline, Git, Docker Pipeline y utilidades.
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins
