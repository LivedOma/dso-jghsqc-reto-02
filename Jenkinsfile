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
          def build   = env.BUILD_NUMBER
          def fullName = "${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}"

          // La imagen es el binario entregable: se construye una vez y se
          // etiqueta varias veces para dar trazabilidad al mismo artefacto.
          def image = docker.build(
            "${fullName}:${build}",
            "--build-arg APP_VERSION=${build} --build-arg GIT_SHA=${env.GIT_SHA} ."
          )

          docker.withRegistry("https://${REGISTRY}", 'dockerhub-creds') {
            image.push()                        // numero de build
            image.push("sha-${env.GIT_SHA}")    // trazabilidad al commit

            // 'latest' solo desde la rama principal: evita que una rama de
            // trabajo sobreescriba la version que todos descargan por defecto.
            if (env.BRANCH_NAME == null || env.BRANCH_NAME == 'main') {
              image.push('latest')
            }
          }

          env.PUBLISHED_TAGS = "${build}, sha-${env.GIT_SHA}"
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
      sh "docker image prune -f || true"
      cleanWs()
    }
  }
}
