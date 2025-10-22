# 🚀 Flask AWS Monitor — CI/CD on EKS with Jenkins & Argo CD

A lightweight **Flask** service packaged with **Docker**, deployed to **Amazon EKS** via **Helm** and **Argo CD**, and built automatically through **Jenkins** using **Kaniko** (no Docker-in-Docker).  
The pipeline builds, tests, pushes to **Docker Hub**, and **Argo CD** continuously syncs the application to your Kubernetes cluster.

> ⚙️ **Requires AWS Account** with EKS + LoadBalancer support.  
> See sections: [Prerequisites](#-prerequisites) and [Argo CD Setup](#-argo-cd--install--deploy).

---

## 🧩 Features

- ✅ Simple **Flask REST API** (port `5001`)  
- 🐳 **Helm Chart** for Kubernetes deployment  
- 🔧 **Jenkins CI/CD** using **Kaniko**  
- 🚀 **Argo CD GitOps** automated deployment  
- 🔐 AWS credentials via **ConfigMap** for demo simplicity  

---

## 📁 Repository Structure

```
myapp/
├── Jenkinsfile                       # CI pipeline: build & push
├── flask-aws-monitor/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py                        # Flask app (port 5001)
│   └── flask-aws-monitor/
│       ├── Chart.yaml
│       ├── values.yaml               # Image, service, probes, etc.
│       └── templates/
│           └── deployment.yaml       # References ConfigMap ‘aws-config’
└── (optional supporting files)
```

yaml
Copy code

---

## ⚙️ Prerequisites

| Requirement | Description |
|-------------|-------------|
| 🟦 **AWS** | Active account with **EKS Cluster** |
| 🧠 **IAM** | Permissions for LoadBalancer creation |
| 🧰 **kubectl** | Configured to access your EKS cluster |
| 🧭 **Helm 3.x** | Installed locally |
| 🐋 **Docker Hub** | Repository (e.g. `yonatan009/flask-aws-monitor`) |
| 🔄 **Jenkins + Argo CD** | Installed via Helm |

---

## 🧪 Local Build (Optional)

Test locally before CI/CD:

```bash
cd flask-aws-monitor
docker build -t yonatan009/flask-aws-monitor:dev -f Dockerfile .
Jenkins + Kaniko handle builds automatically in CI.

⚡ Helm Configuration
File:
flask-aws-monitor/flask-aws-monitor/values.yaml

yaml
Copy code
image:
  repository: yonatan009/flask-aws-monitor
  tag: "0.1.0"

service:
  type: LoadBalancer
  port: 5001
  targetPort: 5001
🔐 Create Required ConfigMap
bash
Copy code
kubectl -n default create configmap aws-config \
  --from-literal=AWS_ACCESS_KEY_ID=YOUR_KEY_ID \
  --from-literal=AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY \
  --from-literal=AWS_DEFAULT_REGION=us-east-1
⚠️ For production, prefer IRSA or Secrets instead of ConfigMap.

🧰 Jenkins — Installation via Helm
bash
Copy code
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
helm install jenkins jenkinsci/jenkins
Check status:

bash
Copy code
kubectl get pods -n default -l "app.kubernetes.io/instance=jenkins"
helm status jenkins
🔑 Get Admin Password
bash
Copy code
kubectl exec -n default -it svc/jenkins -c jenkins \
  -- /bin/cat /run/secrets/additional/chart-admin-password && echo
Default user: admin

🌐 Access Jenkins
Option 1 — LoadBalancer (AWS):

bash
Copy code
kubectl -n default get svc jenkins
Open the EXTERNAL-IP in your browser.

Option 2 — Port Forward (Local):

bash
Copy code
kubectl -n default port-forward svc/jenkins 8080:8080
Go to http://localhost:8080

💡 Jenkins Setup
Go to Manage Jenkins → Credentials → System
Add Username/Password with ID: dockerhub-creds

Create Pipeline from Git

Repo: https://github.com/Yonatan009/myapp.git

Script Path: Jenkinsfile

🧭 Argo CD — Install & Deploy
bash
Copy code
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
Wait for pods:

bash
Copy code
kubectl get pods -n argocd -w
Expose ArgoCD:

bash
Copy code
kubectl patch svc argocd-server -n argocd \
  -p '{"spec":{"type":"LoadBalancer"}}'
kubectl get svc argocd-server -n argocd
Get password:

bash
Copy code
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
⚙️ Create ArgoCD Application
Setting	Value
Repo URL	https://github.com/Yonatan009/myapp.git
Revision	main (or dev)
Path	flask-aws-monitor
Cluster	https://kubernetes.default.svc
Namespace	default

After creation → click Sync → ✅ Deployment live!

🌍 Access the Application
bash
Copy code
kubectl -n default get svc myapp-flask-aws-monitor -o wide
Then open in browser:

cpp
Copy code
http://<ELB-DNS>:5001/
For clean URL (optional):

yaml
Copy code
service:
  port: 80
  targetPort: 5001
Commit → push → Argo Sync → access via http://<ELB-DNS>/

🧩 Branching & Environments
main → production

dev → testing (Argo tracks targetRevision: dev)

Jenkins tags images automatically (dev-<sha>)

🛠 Troubleshooting
Issue	Solution
CreateContainerConfigError	Ensure aws-config ConfigMap exists
ImagePullBackOff	Check image tag in values.yaml
Progressing forever	Align containerPort, service & probes (5001)
ELB not reachable	Open inbound TCP rule (5001) in AWS SG

✅ Clean • Cloud-ready • GitOps-driven.
This project showcases a full CI/CD pipeline: Jenkins → Docker Hub → Argo CD → EKS.

