pipeline {
  agent any

  environment {
    IMAGE_NAME          = "demo-micro"
    DOCKERHUB_NAMESPACE = "cclememte"          // <-- usuario de Docker Hub
    REGISTRY            = "docker.io"

    JAVA_HOME  = tool name: 'JDK17', type: 'hudson.model.JDK'
    MAVEN_HOME = tool name: 'M3',    type: 'hudson.tasks.Maven$MavenInstallation'
    PATH       = "${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${env.PATH}"
  }

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timeout(time: 20, unit: 'MINUTES')
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
        script {
          // SHA corto del commit: permite rastrear que codigo produjo cada imagen
          env.GIT_SHA = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          echo "Commit: ${env.GIT_SHA} | Rama: ${env.BRANCH_NAME ?: 'N/A'}"
        }
      }
    }

    stage('Verificar herramientas') {
      steps {
        sh '''
          echo "== Java =="   && java -version
          echo "== Maven =="  && mvn -v
          echo "== Docker ==" && docker --version
        '''
      }
    }

    stage('Pruebas unitarias') {
      steps {
        sh 'mvn -B test'
      }
      post {
        always {
          junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
        }
      }
    }

    stage('Build JAR') {
      steps {
        sh 'mvn -B -DskipTests clean package'
      }
      post {
        success {
          archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
        }
      }
    }

    stage('Build & Push Image') {
      steps {
        script {
          def build    = env.BUILD_NUMBER
          def fullName = "${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}"

          // La imagen es el binario entregable: se construye una vez y se
          // etiqueta varias veces para dar trazabilidad al mismo artefacto.
          sh """
            docker build -t ${fullName}:${build} \\
              --build-arg APP_VERSION=${build} \\
              --build-arg GIT_SHA=${env.GIT_SHA} .
          """

          // Se usa withCredentials + 'docker login' sin URL en lugar de
          // docker.withRegistry(): el plugin se autentica contra
          // https://docker.io, que emite un token sin permiso de escritura,
          // mientras que el login por defecto apunta a index.docker.io.
          // Ademas --password-stdin evita exponer el token en la linea de comandos.
          withCredentials([usernamePassword(
              credentialsId: 'dockerhub-creds',
              usernameVariable: 'DH_USER',
              passwordVariable: 'DH_PASS')]) {

            sh """
              set -e
              echo "\$DH_PASS" | docker login -u "\$DH_USER" --password-stdin

              docker tag ${fullName}:${build} ${fullName}:sha-${env.GIT_SHA}
              docker push ${fullName}:${build}
              docker push ${fullName}:sha-${env.GIT_SHA}
            """

            // 'latest' solo desde la rama principal: evita que una rama de
            // trabajo sobreescriba la version que todos descargan por defecto.
            script {
              if (env.BRANCH_NAME == null || env.BRANCH_NAME == 'main') {
                sh """
                  docker tag ${fullName}:${build} ${fullName}:latest
                  docker push ${fullName}:latest
                """
                env.PUBLISHED_TAGS = "${build}, sha-${env.GIT_SHA}, latest"
              } else {
                env.PUBLISHED_TAGS = "${build}, sha-${env.GIT_SHA}"
              }
            }

            sh 'docker logout'
          }
        }
      }
    }
  }

  post {
    success {
      echo "Imagen publicada: ${env.REGISTRY}/${DOCKERHUB_NAMESPACE}/${IMAGE_NAME} -> [${env.PUBLISHED_TAGS}]"
    }
    failure {
      echo "Build fallido. Revisar los logs de la etapa que termino en rojo."
    }
    always {
      // Las imagenes intermedias llenan el disco del agente si no se limpian.
      sh "docker image rm -f ${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}:${env.BUILD_NUMBER} || true"
      sh "docker image rm -f ${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}:sha-${env.GIT_SHA} || true"
      sh "docker image prune -f || true"
      cleanWs()
    }
  }
}
