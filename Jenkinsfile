// Jenkinsfile — CI with Kaniko (Kubernetes agent, no Docker daemon)
pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["/busybox/sleep", "9999999"]
    tty: true
    volumeMounts:
      - name: workspace-volume
        mountPath: /home/jenkins/agent
"""
    }
  }

  options { disableConcurrentBuilds(); parallelsAlwaysFailFast() }

  parameters {
    string(name: 'DOCKERHUB_REPO',  defaultValue: 'yonatan009/flask-aws-monitor', description: 'Docker Hub repo')
    string(name: 'DOCKERFILE_PATH', defaultValue: 'Dockerfile',                    description: 'Dockerfile path')
    string(name: 'BUILD_CONTEXT',   defaultValue: '.',                             description: 'Build context')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'echo "Branch: $(git rev-parse --abbrev-ref HEAD)  Commit: $(git rev-parse --short HEAD)"'
      }
    }

    stage('Init Vars') {
      steps {
        script {
          env.SHORT_SHA   = sh(script: 'git rev-parse --short HEAD || echo local', returnStdout: true).trim()
          env.SAFE_BRANCH = sh(script: 'echo "${BRANCH_NAME:-main}" | tr "/: " "-"', returnStdout: true).trim()
          env.IMAGE_TAG   = "${env.SAFE_BRANCH}-${env.SHORT_SHA}"
          env.FULL_IMAGE  = "${params.DOCKERHUB_REPO}:${env.IMAGE_TAG}"
          echo "IMAGE -> ${env.FULL_IMAGE}"
        }
      }
    }

    stage('Quality (Parallel)') {
      parallel {
        stage('Linting') {
          steps {
            sh """
              if command -v flake8 >/dev/null 2>&1; then flake8 .; else echo "flake8 not installed"; fi
              if command -v shellcheck >/dev/null 2>&1; then \
                find . -type f -name "*.sh" -print0 | xargs -0 -I{} sh -c 'shellcheck -x "{}" || true'; \
              else echo "shellcheck not installed"; fi
              if command -v hadolint >/dev/null 2>&1; then hadolint "${params.DOCKERFILE_PATH}" || true; else echo "hadolint not installed"; fi
            """
          }
        }
        stage('Security (Code)') {
          steps {
            sh """
              if command -v bandit >/dev/null 2>&1; then bandit -r . || true; else echo "bandit not installed"; fi
            """
          }
        }
      }
    }

    stage('Build & Push (Kaniko)') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          container('kaniko') {
            sh """
              set -eu
              # Write Docker Hub auth where Kaniko expects it
              mkdir -p /kaniko/.docker
              AUTH_STR=\$(printf "%s" "$DOCKER_USER:$DOCKER_PASS" | base64 | tr -d '\\n')
              cat > /kaniko/.docker/config.json <<EOF
              { "auths": { "https://index.docker.io/v1/": { "auth": "\${AUTH_STR}" } } }
EOF

              # Build + push (context and Dockerfile are in the Jenkins workspace)
              /kaniko/executor \
                --context="${WORKSPACE}/${params.BUILD_CONTEXT}" \
                --dockerfile="${WORKSPACE}/${params.DOCKERFILE_PATH}" \
                --destination="${env.FULL_IMAGE}" \
                --snapshotMode=redo \
                --use-new-run
            """
          }
        }
      }
    }

    stage('Security (Image)') {
      steps {
        sh """
          if command -v trivy >/dev/null 2>&1; then
            trivy image --no-progress --exit-code 0 "${FULL_IMAGE}"
          else
            echo "trivy not installed"
          fi
        """
      }
    }
  }

  post {
    success { echo "Pushed: ${FULL_IMAGE}" }
    failure { echo "Pipeline failed" }
  }
}

