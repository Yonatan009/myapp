Flask AWS Monitor — CI/CD on EKS with Jenkins & Argo CD

A minimal Flask service packaged with Docker, deployed to Amazon EKS via Helm and Argo CD, and built by Jenkins (using Kaniko, no Docker-in-Docker).
The pipeline lints, (optionally) scans, builds, and pushes an image to Docker Hub, then Argo CD continuously deploys it.

Requires an AWS account (EKS, LoadBalancer support, and basic IAM). See the “Prerequisites” and “Argo CD” sections below.

Features

Flask app (HTTP service).

Helm chart for Kubernetes deployment.

Jenkins pipeline (declarative), builds with Kaniko, pushes to Docker Hub.

Argo CD GitOps deployment (auto-sync optional).

Runtime AWS credentials via ConfigMap (aws-config) as environment variables (simple demo mode).

Repository Layout
myapp/
├─ Jenkinsfile                    # CI: builds with Kaniko and pushes to Docker Hub
├─ flask-aws-monitor/             # Application + Helm chart
│  ├─ Dockerfile
│  ├─ requirements.txt
│  ├─ app.py                      # Flask app (listens on 5001)
│  ├─ flask-aws-monitor/          # Helm chart root
│  │  ├─ Chart.yaml
│  │  ├─ values.yaml              # Image tag, service ports, probes, etc.
│  │  └─ templates/
│  │     └─ deployment.yaml       # Uses ConfigMap `aws-config` for AWS_* env vars
└─ (optional) other utility files

Prerequisites

AWS Account with:

An EKS cluster (with IAM role/node permissions to create LoadBalancers).

Outbound internet from nodes for image pulls.

kubectl configured against your cluster.

Helm 3.x installed.

Argo CD (instructions below).

Jenkins (installed via Helm; instructions below).

Docker Hub account and repository (e.g. yonatan009/flask-aws-monitor).

Local Build (optional)
# If you have Docker locally (not required for CI):
cd flask-aws-monitor
docker build -t yonatan009/flask-aws-monitor:dev -f Dockerfile .

Helm Chart — Runtime Configuration

The chart expects the image and ports in flask-aws-monitor/flask-aws-monitor/values.yaml.
Current defaults:

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

Required ConfigMap (simple demo auth)

The Deployment requires a ConfigMap named aws-config in the target namespace (defaults to default) with:

AWS_ACCESS_KEY_ID

AWS_SECRET_ACCESS_KEY

AWS_DEFAULT_REGION

Create it:

kubectl -n default create configmap aws-config \
  --from-literal=AWS_ACCESS_KEY_ID=YOUR_KEY_ID \
  --from-literal=AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY \
  --from-literal=AWS_DEFAULT_REGION=us-east-1


⚠️ For real production, prefer IRSA or Kubernetes Secrets over ConfigMap for credentials.
The ConfigMap flow is kept here for simplicity and to match the project requirements.

Jenkins — Installation with Helm

Prereqs: running cluster, Helm 3, kubectl context set.

Add repo & install

helm repo add jenkinsci https://charts.jenkins.io
helm repo update
helm install jenkins jenkinsci/jenkins


Verify

kubectl get pods -n default -l "app.kubernetes.io/instance=jenkins"
helm status jenkins


Wait until the pod is Running.

Get admin password

kubectl exec -n default -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo


Keep this password safe (admin is the default username).

Access Jenkins

LoadBalancer (recommended on AWS):

kubectl -n default get svc jenkins


Use the EXTERNAL-IP to open Jenkins in your browser.

Port-forward (alternative for local/cloud-shell):

kubectl -n default port-forward svc/jenkins 8080:8080
# http://localhost:8080

Jenkins Credentials & Pipeline

In Manage Jenkins → Credentials → System, create:

Username/Password credential with ID dockerhub-creds (your Docker Hub login).

Multibranch/SCM Pipeline:

SCM: https://github.com/Yonatan009/myapp.git

Script path: Jenkinsfile

The pipeline:

Lints (if tools are present).

Builds via Kaniko (Kubernetes agent), no Docker daemon needed.

Pushes image: yonatan009/flask-aws-monitor:<branch>-<short-sha>.
Optionally also pushes :0.1.0 depending on your Jenkinsfile condition.

Argo CD — Install & First Deployment

Create namespace

kubectl create namespace argocd


Install Argo CD

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


Wait for pods

kubectl get pods -n argocd -w


Expose Argo CD server (LoadBalancer)

kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"LoadBalancer"}}'
kubectl get svc argocd-server -n argocd


Get initial password (user is admin)

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

Create the Application (UI or YAML)

Source (Git)

Repo URL: https://github.com/Yonatan009/myapp.git

Revision: main (or dev if you work on a dev branch)

Path: flask-aws-monitor

Destination

Cluster: https://kubernetes.default.svc

Namespace: default (or another)

After creation, Sync the app. Argo renders the Helm chart and applies it.

Remember: the app expects ConfigMap aws-config (see above) before the Pod can start.

Access the Application

Your service is a LoadBalancer on port 5001 by default:

kubectl -n default get svc myapp-flask-aws-monitor -o wide
# Open:
#   http://<ELB-DNS>:5001/


Optional: expose on port 80 instead of 5001:

# values.yaml
service:
  type: LoadBalancer
  port: 80
  targetPort: 5001


Commit → push → Argo Sync, then browse: http://<ELB-DNS>/

Branching & Environments

You can keep a dev branch and a separate Argo Application that tracks targetRevision: dev (e.g., myapp-dev in namespace dev). Jenkins will tag images like dev-<sha>; set the chart’s image.tag accordingly for that app.

Troubleshooting

CreateContainerConfigError (aws-config not found):
Create the ConfigMap with required keys (see “Helm Chart — Runtime Configuration”).

ImagePullBackOff:
Ensure the tag in values.yaml exists in Docker Hub (e.g., 0.1.0 or your CI tag).

Progressing forever:
Check probes/ports alignment (Flask listens on 5001 by default here).
kubectl -n default describe pod <pod> → review Events.

ELB not reachable:
Open the Security Group to your client IP (TCP on service por
