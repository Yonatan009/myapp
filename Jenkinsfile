// Jenkinsfile — myapp: clone -> parallel lint & security -> docker build -> push
// Requirements:
// - Jenkins credentials (Username/Password) with ID: "dockerhub-creds" for Docker Hub.
// - Job is "Pipeline from SCM" pointing to git@github.com:Yonatan009/myapp.git (branch main).
// - Docker is available on the agent.

pipeline {
  agent any
  options {
    timestamps()
    disableConcurrentBuilds()
    ansiColor('xterm')
    parallelsAlwaysFailFast()   // stop other parallel branches if one fails
  }

  parameters {
    string(name: 'DOCKERHUB_REPO',  defaultValue: 'yonatan009/myapp',  description: 'Docker Hub repo')
    string(name: 'DOCKERFILE_PATH', defaultValue: 'Dockerfile',        description: 'Path to Dockerfile')
    string(name: 'BUILD_CONTEXT',   defaultValue: '.',                 description: 'Docker build context directory')
    booleanParam(name: 'RUN_MOCKS', defaultValue: true,                description: 'Use mock commands for lint & security')
  }

  stages {
    stage('Checkout') {
      steps {
        // Uses job SCM config. If needed, replace with:
        // git branch: 'main', url: 'git@github.com:Yonatan009/myapp.git'
        checkout scm
        sh 'echo "Checked out $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"'
      }
    }

    stage('Init Vars') {
      steps {
        script {
          env.SHORT_SHA   = sh(script: 'git rev-parse --short HEAD || echo local', returnStdout: true).trim()
          env.SAFE_BRANCH = sh(script: 'echo "${BRANCH_NAME:-local}" | tr "/: " "-"', returnStdout: true).trim()
          env.IMAGE_TAG   = "${env.SAFE_BRANCH}-${env.SHORT_SHA}"
          env.FULL_IMAGE  = "${params.DOCKERHUB_REPO}:${env.IMAGE_TAG}"
          echo "FULL_IMAGE=${env.FULL_IMAGE}"
        }
      }
    }

    stage('Parallel Checks') {
      options { timeout(time: 10, unit: 'MINUTES') }
      parallel {
        stage('Linting') {
          steps {
            script {
              if (params.RUN_MOCKS) {
                sh """
                  echo "[MOCK] flake8 ."
                  echo "[MOCK] shellcheck **/*.sh"
                  echo "[MOCK] hadolint ${params.DOCKERFILE_PATH}"
                  sleep 1
                """
              } else {
                sh """
                  if command -v flake8 >/dev/null 2>&1; then flake8 .; else echo "flake8 not installed"; fi
                  if command -v shellcheck >/dev/null 2>&1; then \
                    find . -type f -name "*.sh" -print0 | xargs -0 -I{} sh -c 'shellcheck -x "{}" || true'; \
                  else echo "shellcheck not installed"; fi
                  if command -v hadolint >/dev/null 2>&1; then hadolint "${params.DOCKERFILE_PATH}" || true; else echo "hadolint not installed"; fi
                """
              }
            }
          }
        }

        stage('Security Scan') {
          steps {
            script {
              if (params.RUN_MOCKS) {
                sh """
                  echo "[MOCK] bandit -r ."
                  echo "[MOCK] trivy image ${env.FULL_IMAGE}"
                  sleep 1
                """
              } else {
                sh """
                  if command -v bandit >/dev/null 2>&1; then bandit -r . || true; else echo "bandit not installed"; fi
                  # Trivy will run after build on the built image
                """
              }
            }
          }
        }
      }
    }

    stage('Docker Build') {
      steps {
        sh """
          echo "Building ${env.FULL_IMAGE} with context: ${params.BUILD_CONTEXT}"
          docker build -t "${env.FULL_IMAGE}" -f "${params.DOCKERFILE_PATH}" "${params.BUILD_CONTEXT}"
        """
      }
    }

    stage('Trivy on Image (optional)') {
      when { expression { return !params.RUN_MOCKS } }
      steps {
        sh '''
          if command -v trivy >/dev/null 2>&1; then
            trivy image --no-progress --exit-code 0 "${FULL_IMAGE}"
          else
            echo "trivy not installed"
          fi
        '''
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
        }
        sh 'docker push "${FULL_IMAGE}"'
      }
    }

    stage('Tag latest (main only)') {
      when { branch 'main' }
      steps {
        sh '''
          docker tag "${FULL_IMAGE}" "${DOCKERHUB_REPO}:latest"
          docker push "${DOCKERHUB_REPO}:latest"
        '''
      }
    }
  }

  post {
    always {
      sh 'docker images | head -n 20 || true'
    }
    success {
      echo "Pipeline completed. Pushed: ${FULL_IMAGE}"
    }
    failure {
      echo 'Pipeline failed! Check logs for details.'
    }
  }
}

