# Reto 2 — CI con Jenkins → imagen Docker → Docker Hub

Mismo microservicio del Reto 1, pero orquestado con **Jenkins** en lugar de GitHub Actions. El objetivo es comprobar que el pipeline es el mismo concepto y que la herramienta es intercambiable.

---

## 0. Arranque rápido

```bash
cd jenkins
docker compose up -d --build      # tarda ~3 min la primera vez
docker compose logs -f jenkins    # espera a ver la contraseña inicial
```

Jenkins queda en **http://localhost:8081** (el 8080 se deja libre para el microservicio).

Contraseña inicial:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

En el wizard: **Select plugins to install → None** (ya vienen preinstalados vía `plugins.txt`), crea tu usuario admin y continúa.

---

## 1. Verificar que el agente tiene Docker

Este es el prerrequisito que más falla del reto. El pipeline ejecuta `docker build` y `docker push`, así que el nodo donde corre necesita el cliente de Docker y permiso sobre el socket.

```bash
docker exec jenkins docker --version
docker exec jenkins docker ps
```

Si el segundo comando responde con la lista de contenedores, está listo. Si da *permission denied on /var/run/docker.sock*:

```bash
# macOS / Docker Desktop
docker exec -u root jenkins chmod 666 /var/run/docker.sock

# Linux: agregar el usuario jenkins al grupo docker del host
docker exec -u root jenkins sh -c 'groupadd -f -g $(stat -c %g /var/run/docker.sock) docker && usermod -aG docker jenkins'
docker compose restart jenkins
```

> **Nota de seguridad:** montar el socket del host da al contenedor control total sobre el demonio Docker. Es aceptable en un entorno de laboratorio; en producción se usan agentes dedicados o builders sin privilegios (Kaniko, BuildKit rootless).

---

## 2. Configurar las herramientas

**Manage Jenkins → Tools**

| Herramienta | Nombre (exacto) | Configuración |
|---|---|---|
| JDK | `JDK17` | *Install automatically* → Adoptium → `jdk-17` |
| Maven | `M3` | *Install automatically* → versión 3.9.x |

Los nombres deben coincidir **exactamente** con los del `Jenkinsfile`; si escribes `jdk17` o `Maven3`, el pipeline falla al resolver el `tool name:`.

---

## 3. Crear las credenciales

**Manage Jenkins → Credentials → System → Global credentials → Add Credentials**

| Campo | Valor |
|---|---|
| Kind | Username with password |
| Username | tu usuario de Docker Hub |
| Password | el Personal Access Token (`dckr_pat_...`) |
| ID | `dockerhub-creds` |
| Description | Docker Hub — push de imágenes |

El **ID** es el que referencia `docker.withRegistry(..., 'dockerhub-creds')`. Si no coincide, el push falla con *credentials not found*.

---

## 4. Crear el pipeline

**New Item → nombre `demo-micro-ci` → Multibranch Pipeline → OK**

| Sección | Valor |
|---|---|
| Branch Sources | Git (o GitHub) |
| Project Repository | `https://github.com/<usuario>/dso-jghsqc-reto-02.git` |
| Credentials | tu token de GitHub (si el repo es privado) |
| Build Configuration | by Jenkinsfile → `Jenkinsfile` |

**Save**. Jenkins escanea el repositorio, encuentra el `Jenkinsfile` en `main` y lanza el primer build automáticamente.

> Se eligió **Multibranch** sobre el pipeline simple porque detecta las ramas por sí solo y no exige configurar el trigger ni la ruta del `Jenkinsfile` a mano.

---

## 5. Verificación

```bash
docker pull --platform linux/arm64 <usuario>/demo-micro:latest
docker run -d --name demo-micro-jenkins -p 8080:8080 -e APP_VERSION=jenkins-1 <usuario>/demo-micro:latest

docker ps --filter name=demo-micro-jenkins
curl http://localhost:8080/ ; echo
curl http://localhost:8080/version ; echo
curl http://localhost:8080/actuator/health ; echo
docker exec demo-micro-jenkins whoami

docker rm -f demo-micro-jenkins
```

En Docker Hub deben aparecer las etiquetas: el **número de build** (`1`, `2`, ...), el **SHA del commit** (`sha-a1b2c3d`) y `latest`.

---

## 6. Diferencias respecto al Jenkinsfile del enunciado

| Cambio | Motivo |
|---|---|
| Etapa `Pruebas unitarias` con publicación `junit` | El enunciado solo tiene `-DskipTests`: publicaría la imagen aunque el código estuviera roto. Además Jenkins grafica la tendencia de pruebas build a build. |
| Etiqueta `sha-<commit>` además del número de build | `BUILD_NUMBER` identifica la ejecución, no el código. Si se borra el historial de Jenkins se pierde la trazabilidad; el SHA la conserva. |
| `latest` solo desde `main` | Evita que una rama de trabajo sobrescriba la versión que todos descargan por defecto. |
| Etapa `Verificar herramientas` | Falla temprano y con un mensaje claro si el agente no tiene Docker o si los tools están mal nombrados, en vez de romper con un error críptico en el build. |
| `buildDiscarder` y `timeout` | Sin rotación de builds el `JENKINS_HOME` crece indefinidamente; sin timeout un build colgado bloquea el ejecutor. |
| `post { always }` con `docker image prune` y `cleanWs()` | Cada build deja una imagen y un workspace; sin limpieza el disco del agente se llena en pocas decenas de ejecuciones. |
| `ansiColor('xterm')` retirado del bloque `options` | Requiere el plugin AnsiColor; si no está instalado el pipeline ni siquiera arranca. Se dejó el plugin en `plugins.txt` pero sin acoplarlo al pipeline. |
| `--build-arg APP_VERSION / GIT_SHA` | Inyecta la versión y el commit como metadatos de la imagen (labels OCI), consultables después con `docker inspect`. |

---

## 7. Errores frecuentes

| Síntoma | Causa / solución |
|---|---|
| `docker: not found` en el stage de imagen | El agente no tiene el cliente Docker. Verificar con `docker exec jenkins docker --version`. |
| `permission denied ... /var/run/docker.sock` | Faltan permisos sobre el socket. Ver sección 1. |
| `No tool named JDK17 found` | El nombre en Manage Jenkins → Tools no coincide con el del `Jenkinsfile`. |
| `Could not find credentials matching dockerhub-creds` | El ID de la credencial es distinto, o se creó dentro de un *folder* en lugar de en el ámbito global. |
| `denied: requested access to the resource is denied` | `DOCKERHUB_NAMESPACE` no coincide con el usuario del token. |
| El multibranch no encuentra ramas | El repositorio es privado y faltan credenciales de GitHub en la Branch Source. |
| La imagen sale `linux/arm64` | Jenkins construye con el Docker del host; en Apple Silicon eso produce ARM64, a diferencia del runner x86 de GitHub Actions. Es un hallazgo válido para documentar. |

---

## 8. Comandos útiles

```bash
docker compose logs -f jenkins            # logs del controller
docker exec -it jenkins bash              # shell dentro de Jenkins
docker compose down                       # detener (conserva jenkins_home)
docker compose down -v                    # detener y BORRAR la configuración
docker volume inspect jenkins_home        # ubicación de los datos persistidos
```
