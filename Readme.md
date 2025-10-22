Flask AWS Monitor — CI/CD on EKS with Jenkins & Argo CD

A minimal Flask service, containerized with Docker, deployed to Amazon EKS using Helm and Argo CD, and built via Jenkins (Kaniko; no Docker-in-Docker).
The pipeline lints, optionally scans, builds & pushes to Docker Hub, and Argo CD continuously deploys it.

Requires an AWS account with EKS + LoadBalancer support. See Prerequisites, Jenkins, and Argo CD below.

Table of Contents

Features

Repository Layout

Prerequisites

Local Build (optional)

Helm Chart — Runtime Configuration

Jenkins — Installation with Helm

Argo CD — Install & First Deployment

Access the Application

Branching & Environments

Troubleshooting

Features

Simple Flask HTTP service (listens on port 5001).

Helm chart for Kubernetes deployment.

Jenkins declarative pipeline: builds with Kaniko and pushes to Docker Hub.

Argo CD GitOps deployment (auto-sync optional).

Runtime AWS credentials via ConfigMap (aws-config) for demo simplicity.

Repository Layout
myapp/
├─ Jenkinsfile                        # CI pipeline: Kaniko build & push
├─ flask-aws-monitor/                 # Application + Helm chart
│  ├─ Dockerfile
│  ├─ requirements.txt
│  ├─ app.py                          # Flask app (port 5001)
│  └─ flask-aws-monitor/              # Helm chart
│     ├─ Chart.yaml
│     ├─ values.yaml                  # Image, service ports, probes, etc.
│     └─ templates/
│        └─ deployment.yaml           # Requires ConfigMap `aws-config`
└─ (optional) supporting files

Prerequisites

AWS:

EKS cluster with permission to provision LoadBalancers.

Worker nodes with outbound internet access.

kubectl configured against your EKS cluster.

Helm 3.x installed.

Docker Hub repository (e.g., yonatan009/flask-aws-monitor).

Jenkins (installed via Helm; see below).

Argo CD (see below).

Local Build (optional)

If you have local Docker and want to test the image:

cd flask-aws-monitor
docker build -t yonatan009/flask-aws-monitor:dev -f Dockerfile .


(Not required for CI/CD; Jenkins+Kaniko does the building.)

Helm Chart — Runtime Configuration

Main settings: flask-aws-monitor/flask-aws-monitor/values.yaml

image:
  repository: yonatan009/flask-aws-monitor
  tag: "0.1.0"

service:
  type: LoadBalancer
  port: 5001
  targetPort: 5001

readinessProbe:
  tcpSocket: { port: 5001 }
livenessProbe:
  tcpSocket: { port: 5001 }

Required ConfigMap (demo credentials)

The Deployment requires a ConfigMap named aws-config in your target namespace (default: default) with these keys:

AWS_ACCESS_KEY_ID

AWS_SECRET_ACCESS_KEY

AWS_DEFAULT_REGION

Create it:

kubectl -n default create configmap aws-config \
  --from-literal=AWS_ACCESS_KEY_ID=YOUR_KEY_ID \
  --from-literal=AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY \
  --from-literal=AWS_DEFAULT_REGION=us-east-1


⚠️ Production note: prefer IRSA (IAM Role for Service Account) or Kubernetes Secrets (possibly via External Secrets) over ConfigMaps for credentials. The ConfigMap path is kept for simplicity and to match the exercise requirements.

Jenkins — Installation with Helm

Prereqs: running cluster, Helm 3, kubectl context set.

Add repo & install

helm repo add jenkinsci https://charts.jenkins.io
helm repo update
helm install jenkins jenkinsci/jenkins


Verify

kubectl get pods -n default -l "app.kubernetes.io/instance=jenkins"
helm status jenkins


Wait until the Jenkins pod is Running.

Get admin password

kubectl exec -n default -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo


(Username: admin. Keep the password safe.)

Access Jenkins

LoadBalancer (AWS recommended)

kubectl -n default get svc jenkins


Open the EXTERNAL-IP in your browser.

Port-forward (alternative)

kubectl -n default port-forward svc/jenkins 8080:8080
# http://localhost:8080

Jenkins Credentials & Pipeline

Credentials → System → add Username/Password with ID dockerhub-creds (your Docker Hub login).

Create a Pipeline job pointing at:

SCM: https://github.com/Yonatan009/myapp.git

Script path: Jenkinsfile

Pipeline behavior:

Lints (if tools available).

Builds the image with Kaniko in a K8s agent.

Pushes to Docker Hub: yonatan009/flask-aws-monitor:<branch>-<short-sha>
(Optionally also :0.1.0 depending on Jenkinsfile conditions.)

Argo CD — Install & First Deployment

Create namespace

kubectl create namespace argocd


Install Argo CD

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


Wait for pods

kubectl get pods -n argocd -w


Expose Argo CD server (LoadBalancer)

kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"LoadBalancer"}}'
kubectl get svc argocd-server -n argocd


Get initial password (user: admin)

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

Create the Application (UI or YAML)

Source

Repo: https://github.com/Yonatan009/myapp.git

Revision: main (or dev)

Path: flask-aws-monitor

Destination

Cluster: https://kubernetes.default.svc

Namespace: default (or another)

Click Sync to deploy. Argo renders the Helm chart and applies it.

Reminder: ensure aws-config ConfigMap exists in your app namespace before the Pod can start.

Access the Application

Service is LoadBalancer on port 5001 by default:

kubectl -n default get svc myapp-flask-aws-monitor -o wide
# Open:
#   http://<ELB-DNS>:5001/


Optional: expose on port 80 (clean URL):

# values.yaml
service:
  type: LoadBalancer
  port: 80
  targetPort: 5001


Commit → push → Argo Sync, then visit http://<ELB-DNS>/.

Branching & Environments

Use a dev branch with a dedicated Argo Application that tracks targetRevision: dev (e.g., myapp-dev in namespace dev).
Jenkins tags images like dev-<sha>; set image.tag in the dev app’s values to match the pushed tag.

Troubleshooting

CreateContainerConfigError (e.g., “configmap aws-config not found”):
Create the ConfigMap with required keys (see above).

ImagePullBackOff:
Ensure the tag in values.yaml exists in Docker Hub (0.1.0 or your CI tag).

“Progressing” forever:
Align containerPort/service/targetPort/probes (Flask here listens on 5001).

ELB not reachable:
Open the Security Group inbound rule to your client IP on the service port.
