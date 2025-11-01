// Jenkinsfile - Minimal GitOps: build & push image, then bump Helm tag in env-repo

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

  options { disableConcurrentBuilds() }

  parameters {
    string(name: 'DOCKERHUB_REPO',  defaultValue: 'yonatan009/flask-aws-monitor', description: 'Docker Hub repo')
    string(name: 'DOCKERFILE_PATH', defaultValue: 'Dockerfile',                    description: 'Dockerfile path')
    string(name: 'BUILD_CONTEXT',   defaultValue: '.',                             description: 'Build context')
  }

  environment {
    ENV_REPO_URL = 'https://github.com/Yonatan009/myapp.git'
    CHART_VALUES_PATH = 'flask-aws-monitor/values.yaml'
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
          env.IMAGE_TAG  = "0.1.${env.BUILD_NUMBER}"
          env.FULL_IMAGE = "${params.DOCKERHUB_REPO}:${env.IMAGE_TAG}"
          echo "IMAGE -> ${env.FULL_IMAGE}"
        }
      }
    }

    stage('Build & Push image (Kaniko)') {
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
              /kaniko/executor \
                --context="${WORKSPACE}/${BUILD_CONTEXT}" \
                --dockerfile="${WORKSPACE}/${DOCKERFILE_PATH}" \
                --destination="${FULL_IMAGE}" \
                --cache=true \
                --cache-repo="${DOCKERHUB_REPO}" \
                --snapshot-mode=redo \
                --use-new-run
            '''
          }
        }
      }
    }

    stage('Bump tag in env-repo & push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'github-creds', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
          sh '''
            set -eu
            rm -rf env-repo
            git clone "https://${GH_USER}:${GH_TOKEN}@${ENV_REPO_URL#https://}" env-repo
            cd env-repo

            # Update .image.tag to the new tag
            sed -i -E 's#^([[:space:]]*tag:[[:space:]]*).*$#\\1"'"${IMAGE_TAG}"'"#' "${CHART_VALUES_PATH}"

            # (Optional) ensure repository is correct; uncomment if you want to pin it
            # sed -i -E 's#^([[:space:]]*repository:[[:space:]]*).*$#\\1"'"${DOCKERHUB_REPO}"'"#' "${CHART_VALUES_PATH}"

            git config user.name "Jenkins CI"
            git config user.email "jenkins@example.com"
            git add "${CHART_VALUES_PATH}"
            git commit -m "chore: bump image tag to ${IMAGE_TAG}" || true
            git push origin HEAD
          '''
        }
      }
    }
  }

  post {
    success {
      echo "Done: ${FULL_IMAGE} pushed and env-repo updated."
    }
    failure {
      echo "Pipeline failed"
    }
  }
}

