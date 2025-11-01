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
  volumes:
    - name: workspace-volume
      emptyDir: {}
"""
    }
  }

  options {
    disableConcurrentBuilds()
    parallelsAlwaysFailFast()
  }

  parameters {
    string(name: 'DOCKERHUB_REPO', defaultValue: 'yonatan009/flask-aws-monitor', description: 'Docker Hub repo')
    booleanParam(name: 'ENABLE_ENV_REPO_BUMP', defaultValue: false, description: 'Update env repo values.yaml with new tag')
    string(name: 'ENV_REPO_URL', defaultValue: 'https://github.com/Yonatan009/env-configs.git', description: 'Env repo URL (if bump enabled)')
    string(name: 'ENV_REPO_BRANCH', defaultValue: 'main', description: 'Env repo branch (if bump enabled)')
    string(name: 'ENV_VALUES_PATH', defaultValue: 'mapp/flask-aws-monitor/values.yaml', description: 'values.yaml path inside env repo')
  }

  environment {
    // Jenkins credentials
    DOCKER_CREDS = credentials('dockerhub-creds')     // username/password for Docker Hub
    GITHUB_PAT   = credentials('github-fg-token')     // Personal Access Token (if bump enabled)
  }

  stages {

    stage('Checkout app') {
      steps {
        checkout scm
      }
    }

    stage('Init vars') {
      steps {
        script {
          env.SHORT_SHA   = sh(script: 'git rev-parse --short HEAD || echo local', returnStdout: true).trim()
          env.SAFE_BRANCH = sh(script: 'echo "${BRANCH_NAME:-main}" | tr "/: " "-"', returnStdout: true).trim()
          env.IMAGE_TAG   = "${env.SAFE_BRANCH}-${env.BUILD_NUMBER}-${env.SHORT_SHA}"
          env.FULL_IMAGE  = "${params.DOCKERHUB_REPO}:${env.IMAGE_TAG}"
          echo "Will build & push -> ${env.FULL_IMAGE}"
        }
      }
    }

    stage('Parallel checks') {
      parallel {
        stage('Linting') {
          steps {
            sh '''
              if command -v flake8 >/dev/null 2>&1; then flake8 . || true; else echo "flake8 not installed"; fi
              if command -v shellcheck >/dev/null 2>&1; then \
                find . -type f -name "*.sh" -print0 | xargs -0 -I{} sh -c 'shellcheck -x "{}" || true'; \
              else echo "shellcheck not installed"; fi
              if command -v hadolint >/dev/null 2>&1; then hadolint Dockerfile || true; else echo "hadolint not installed"; fi
            '''
          }
        }
        stage('Security scan') {
          steps {
            sh '''
              if command -v bandit >/dev/null 2>&1; then bandit -r . || true; else echo "bandit not installed"; fi
              if command -v trivy >/dev/null 2>&1; then echo "Trivy will scan built image later"; else echo "trivy not installed"; fi
            '''
          }
        }
      }
    }

    stage('Build & Push image (Kaniko)') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          container('kaniko') {
            sh """
              set -eu
              mkdir -p /kaniko/.docker
              AUTH_STR=\$(printf "%s" "$DOCKER_USER:$DOCKER_PASS" | base64 | tr -d '\\n')
              cat > /kaniko/.docker/config.json <<EOF
              { "auths": { "https://index.docker.io/v1/": { "auth": "\${AUTH_STR}" } } }
EOF

              /kaniko/executor \
                --context="${WORKSPACE}/." \
                --dockerfile="${WORKSPACE}/Dockerfile" \
                --destination="${FULL_IMAGE}" \
                --cache=true \
                --cache-repo="${params.DOCKERHUB_REPO}" \
                --snapshot-mode=redo \
                --use-new-run
            """
          }
        }
      }
    }

    stage('Image scan (optional)') {
      steps {
        sh '''
          if command -v trivy >/dev/null 2>&1; then
            trivy image --no-progress --exit-code 0 "${FULL_IMAGE}" || true
          else
            echo "trivy not installed"
          fi
        '''
      }
    }

    stage('Bump tag in env-repo & push') {
      when { expression { return params.ENABLE_ENV_REPO_BUMP } }
      steps {
        dir('env-repo') {
          sh """
            set -eu
            git init
            git config user.name "Jenkins CI"
            git config user.email "jenkins@example.com"
            git remote add origin https://${GITHUB_PAT_USR}:${GITHUB_PAT_PSW}@${params.ENV_REPO_URL#https://}
            git fetch origin ${params.ENV_REPO_BRANCH}
            git checkout -B ${params.ENV_REPO_BRANCH} FETCH_HEAD

            test -f "${params.ENV_VALUES_PATH}" || { echo "values.yaml not found: ${params.ENV_VALUES_PATH}"; ls -la; exit 2; }

            sed -i -E 's#^([[:space:]]*tag:[[:space:]]*).*$#\\1"'"${IMAGE_TAG}"'"#' "${params.ENV_VALUES_PATH}"

            git add "${params.ENV_VALUES_PATH}"
            git commit -m "Bump image tag to ${IMAGE_TAG}" || true
            git push origin ${params.ENV_REPO_BRANCH}
          """
        }
      }
    }

  } // stages

  post {
    success {
      echo "Done. Pushed ${FULL_IMAGE}"
    }
    failure {
      echo "Pipeline failed"
    }
  }
}

