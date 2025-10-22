🚀 Flask AWS Monitor — CI/CD on EKS with Jenkins & Argo CD

A lightweight Flask service packaged with Docker, deployed to Amazon EKS via Helm and Argo CD, and built automatically through Jenkins using Kaniko (no Docker-in-Docker).

The pipeline builds, tests, pushes to Docker Hub, and Argo CD continuously syncs the application to your Kubernetes cluster.

⚙️ Requires AWS Account with EKS + LoadBalancer support.
See Prerequisites
 and Argo CD Setup
.

🧩 Features

✅ Simple Flask REST API (listening on port 5001)

🐳 Helm chart for Kubernetes deployment

🔧 Jenkins CI/CD with Kaniko image builds

🚀 Argo CD for automated GitOps deployment

🔐 AWS credentials via ConfigMap for demo mode

📂 Repository Structure
myapp/
├── Jenkinsfile                   # CI pipeline (build & push)
├── flask-aws-monitor/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py                    # Flask app (port 5001)
│   └── flask-aws-monitor/
│       ├── Chart.yaml
│       ├── values.yaml           # Image, service, probes, etc.
│       └── templates/
│           └── deployment.yaml   # References ConfigMap 'aws-config'

⚙️ Prerequisites
Requirement	Description
🟦 AWS	Active AWS Account with an EKS Cluster
🧠 IAM	Node role permissions to create LoadBalancers
🧰 kubectl	Configured to access your cluster
🧭 Helm 3.x	Installed locally
🐋 Docker Hub	Repository (e.g. yonatan009/flask-aws-monitor)
🔄 Jenkins + Argo CD	Installed via Helm (see below)
🧪 Local Build (Optional)

If you wish to test locally before CI/CD:

cd flask-aws-monitor
docker build -t yonatan009/flask-aws-monitor:dev -f Dockerfile .


Jenkins + Kaniko handle this automatically in CI.

⚡ Helm Configuration

File: flask-aws-monitor/flask-aws-monitor/values.yaml

image:
  repository: yonatan009/flask-aws-monitor
  tag: "0.1.0"

service:
  type: LoadBalancer
  port: 5001
  targetPort: 5001

Create Required ConfigMap
kubectl -n default create configmap aws-config \
  --from-literal=AWS_ACCESS_KEY_ID=YOUR_KEY_ID \
  --from-literal=AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY \
  --from-literal=AWS_DEFAULT_REGION=us-east-1


⚠️ For production, use IRSA or Secrets instead of ConfigMap.

🧰 Jenkins — Installation via Helm
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
helm install jenkins jenkinsci/jenkins


Check status:

kubectl get pods -n default -l "app.kubernetes.io/instance=jenkins"
helm status jenkins

🔑 Get Admin Password
kubectl exec -n default -it svc/jenkins -c jenkins \
  -- /bin/cat /run/secrets/additional/chart-admin-password && echo


Default user: admin

🌐 Access Jenkins

LoadBalancer (AWS):

kubectl -n default get svc jenkins


Open the EXTERNAL-IP in your browser.

Port-forward (local):

kubectl -n default port-forward svc/jenkins 8080:8080


→ http://localhost:8080

💡 Jenkins Setup

Add Credentials → System → dockerhub-creds (your Docker Hub login).

Create a Pipeline from Git:

Repo: https://github.com/Yonatan009/myapp.git

Script Path: Jenkinsfile

🧭 Argo CD — Install & Deploy
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


Wait for all pods to be ready:

kubectl get pods -n argocd -w


Expose ArgoCD:

kubectl patch svc argocd-server -n argocd \
  -p '{"spec":{"type":"LoadBalancer"}}'
kubectl get svc argocd-server -n argocd


Get login credentials:

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

Create Application
Setting	Value
Repo URL	https://github.com/Yonatan009/myapp.git
Revision	main (or dev)
Path	flask-aws-monitor
Cluster	https://kubernetes.default.svc
Namespace	default

After creation → Sync → App deployed 🎉

🌍 Access Your Application
kubectl -n default get svc myapp-flask-aws-monitor -o wide


Then open in browser:

http://<ELB-DNS>:5001/


For cleaner URL (optional):

service:
  port: 80
  targetPort: 5001

🧩 Branching & Environments

Use main for production

Use dev for testing with Argo tracking targetRevision: dev

Jenkins tags images automatically (dev-<sha>)

🛠 Troubleshooting
Issue	Solution
❌ CreateContainerConfigError	Ensure aws-config ConfigMap exists
❌ ImagePullBackOff	Verify tag in values.yaml exists in Docker Hub
🕓 “Progressing” forever	Confirm containerPort, service, and probes match (5001)
🌐 ELB not reachable	Add inbound rule (TCP 5001) in AWS Security Group
