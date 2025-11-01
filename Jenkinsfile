// Jenkinsfile — Kaniko CI with numeric+datetime tag, optional GitOps bump for Argo CD
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
    string(name: 'DOCKERHUB_REPO', defaultValue: 'yonatan009/flask-aws-monitor', description: 'Docker Hub repo, e.g. user/app')
    string(name: 'BASE_VERSION',   defaultValue: '0.1', description: 'Semantic base, e.g. 0.1 or 1.0')
    booleanParam(name: 'PUSH_LATEST', defaultValue: false, description: 'Also push :latest tag')
    booleanParam(name: 'ENABLE_ENV_REPO_BUMP', defaultValue: false, description: 'If true, update values.yaml tag in env/app repo')
    string(name: 'ENV_REPO_URL',     defaultValue: 'https://github.com/Yonatan009/myapp.git', description: 'Repo that contains values.yaml')
    string(name: 'ENV_REPO_BRANCH',  defaultValue: 'main', description: 'Branch to bump')
    string(name: 'ENV_VALUES_PATH',  defaultValue: 'flask-aws-monitor/values.yaml', description: 'Path to values.yaml inside the repo')
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
        sh 'echo "Branch: $(git rev-parse --abbrev-ref HEAD)  Commit: $(git rev-parse --short HEAD)"'
      }
    }

    stage('Init vars') {
      steps {
        script {
          // Build numeric+datetime tag: <BASE_VERSION>.<BUILD_NUMBER>-<YYYYMMDDTHHMMSS>
          env.DATE_UTC   = sh(script: 'date -u +%Y%m%dT%H%M%S', returnStdout: true).trim()
          env.VERSION    = "${params.BASE_VERSION}.${env.BUILD_NUMBER}"
          env.IMAGE_TAG  = "${env.VERSION}-${env.DATE_UTC}"
          env.FULL_IMAGE = "${params.DOCKERHUB_REPO}:${env.IMAGE_TAG}"
          echo "IMAGE_TAG: ${env.IMAGE_TAG}"
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
        stage('Security (code)') {
          steps {
            sh 'command -v bandit >/dev/null 2>&1 && bandit -r . || echo "bandit not installed"'
          }
        }
      }
    }

    stage('Build & push image (Kaniko)') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          container('kaniko') {
            sh '''
              set -eu
              mkdir -p /kaniko/.docker
              AUTH_STR=$(printf "%s" "$DOCKER_USER:$DOCKER_PASS" | base64 | tr -d '\\n')
              cat > /kaniko/.docker/config.json <<EOF
              { "auths": { "https://index.docker.io/v1/": { "auth": "${AUTH_STR}" } } }
EOF

              # Safe defaults/guards for set -u
              : "${PUSH_LATEST:=false}"
              : "${DOCKERHUB_REPO:?DOCKERHUB_REPO is required}"
              : "${FULL_IMAGE:?FULL_IMAGE is required}"

              DESTS="--destination=${FULL_IMAGE}"
              if [ "${PUSH_LATEST}" = "true" ]; then
                DESTS="$DESTS --destination=${DOCKERHUB_REPO}:latest"
              fi

              /kaniko/executor \
                --context="${WORKSPACE}/." \
                --dockerfile="${WORKSPACE}/Dockerfile" \
                $DESTS \
                --cache=true \
                --cache-repo="${DOCKERHUB_REPO}" \
                --snapshot-mode=redo \
                --use-new-run
            '''
          }
        }
      }
    }

    stage('Security (image)') {
      steps {
        sh 'command -v trivy >/dev/null 2>&1 && trivy image --no-progress --exit-code 0 "${FULL_IMAGE}" || echo "trivy not installed"'
      }
    }

    stage('Bump tag in env-repo & push') {
      when { expression { return params.ENABLE_ENV_REPO_BUMP } }
      steps {
        withCredentials([usernamePassword(credentialsId: 'github-creds', usernameVariable: 'PAT_USER', passwordVariable: 'PAT_PSW')]) {
          script {
            def repoUrl = params.ENV_REPO_URL
            if (!repoUrl.startsWith('https://')) { repoUrl = "https://${repoUrl}" }
            def sanitized = repoUrl.replaceFirst('https://','')

            sh '''
              set -eu
              rm -rf env-repo
              git clone --branch "${ENV_REPO_BRANCH}" "${repoUrl}" env-repo
              cd env-repo

              VALUES_FILE="${ENV_VALUES_PATH}"
              test -f "$VALUES_FILE" || { echo "values.yaml not found: $VALUES_FILE"; ls -la; exit 2; }

              # Replace: image.tag: "<anything>"  -> image.tag: "<IMAGE_TAG>"
              sed -i -E 's|^([[:space:]]*tag:[[:space:]]*).*$|\\1"'"${IMAGE_TAG}"'"|' "$VALUES_FILE"

              git config user.name "Jenkins CI"
              git config user.email "jenkins@example.com"
              git add "$VALUES_FILE"
              git commit -m "Bump image tag to ${IMAGE_TAG}" || true

              git remote set-url origin "https://${PAT_USER}:${PAT_PSW}@${sanitized}"
              git push origin "${ENV_REPO_BRANCH}"
            '''
          }
        }
      }
    }
  }

  post {
    success { echo "Done. Pushed: ${FULL_IMAGE}" }
    failure { echo "Pipeline failed" }
  }
}

