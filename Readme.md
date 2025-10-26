# 🚀 Flask AWS Monitor — Quickstart (EKS + Jenkins + Argo CD)

A concise end‑to‑end guide to run the project on **AWS EKS** with **Jenkins (Pod Templates)** and **Argo CD**.

---

## 🧰 Prerequisites

* Active **AWS** account and a working **EKS cluster** (your `kubectl` context points to it)
* **kubectl** and **Helm 3.x** installed locally
* **Docker Hub** account + repository (e.g., `YOUR_USER/flask-aws-monitor`)
* **Jenkins** and **Argo CD** will be installed below via Helm/Kubernetes

> Tip: Ensure EKS subnets/SGs allow creating external **LoadBalancers**.

---

## 📦 Clone & Explore

```bash
# 1) Clone the repo
git clone https://github.com/Yonatan009/myapp.git
cd myapp

# 2) Explore structure
# myapp/
# ├── Jenkinsfile
# └── flask-aws-monitor/
#     ├── Dockerfile
#     ├── requirements.txt
#     ├── app.py                   # Flask app (port 5001)
#     └── flask-aws-monitor/
#         ├── Chart.yaml
#         ├── values.yaml          # Image, service, probes, etc.
#         └── templates/deployment.yaml
```

---

## ⚙️ Basic Configuration (Helm values & ConfigMap)

1. Edit **values.yaml** (path: `flask-aws-monitor/flask-aws-monitor/values.yaml`):

```yaml
image:
  repository: YOUR_DOCKERHUB_USER/flask-aws-monitor
  tag: "0.1.0"

service:
  type: LoadBalancer
  port: 5001
  targetPort: 5001
```

2. Create a **ConfigMap** for demo purposes (for production prefer IRSA/Secrets):

```bash
# Namespace: default (adjust if needed)
kubectl -n default create configmap aws-config \
  --from-literal=AWS_ACCESS_KEY_ID=YOUR_KEY_ID \
  --from-literal=AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY \
  --from-literal=AWS_DEFAULT_REGION=us-east-1
```

---

## 🧑‍🔧 Install Jenkins (Pod Templates‑Ready)

```bash
# Jenkins namespace
kubectl create namespace jenkins || true

# Helm repo for Jenkins
helm repo add jenkinsci https://charts.jenkins.io
helm repo update

# Install Jenkins with required plugins and a LoadBalancer
helm upgrade --install jenkins jenkinsci/jenkins \
  -n jenkins \
  --set controller.serviceType=LoadBalancer \
  --set controller.installPlugins="kubernetes:4263,workflow-aggregator:596.v8c21c963d92d,git:5.5.2,configuration-as-code:1912.v02c0c0e09125" \
  --set persistence.enabled=true \
  --set persistence.size=20Gi

# Get admin password
kubectl -n jenkins get secret jenkins \
  -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode; echo

# Get Jenkins ELB DNS
kubectl -n jenkins get svc jenkins -o wide
# Open http://<ELB-DNS>:8080 (user: admin)
```

### Configure Kubernetes Cloud + Pod Template (Jenkins UI)

1. **Manage Jenkins → Tools & Cloud → Clouds → Add new cloud → Kubernetes**

   * Kubernetes URL: `https://kubernetes.default:443`
   * Credentials: **Kubernetes Service Account**
   * Namespace: `jenkins`
   * Jenkins URL: your Jenkins ELB URL
2. Add a **Pod Template**:

   * Labels: `k8s-agent`
   * Container `jnlp`: `jenkins/inbound-agent:latest`
   * Build container (example): `python:3.11-slim` with `Command: cat`, `TTY: true`

### RBAC for agents (required)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: jenkins-agent-role
  namespace: jenkins
rules:
- apiGroups: [""]
  resources: ["pods","pods/exec","pods/log","services","configmaps","secrets","endpoints"]
  verbs: ["get","list","watch","create","delete","patch","update"]
- apiGroups: ["apps"]
  resources: ["deployments","replicasets"]
  verbs: ["get","list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jenkins-agent-bind
  namespace: jenkins
subjects:
- kind: ServiceAccount
  name: jenkins
  namespace: jenkins
roleRef:
  kind: Role
  name: jenkins-agent-role
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f rbac-jenkins.yaml
```

### Docker Hub credentials in Jenkins

* **Manage Jenkins → Credentials → System → Global → New credentials**
  Type: **Username with password**
  ID: `dockerhub-creds`

---

## 🧪 Create a Pipeline in Jenkins

* **New Item → Pipeline → Pipeline script from SCM**

  * SCM: **Git**
  * Repo: `https://github.com/Yonatan009/myapp.git`
  * Branch: `main` (or `dev`)
  * Script Path: `Jenkinsfile`

> The Jenkinsfile builds with **Kaniko** (no Docker‑in‑Docker) and pushes to Docker Hub. Ensure credential ID matches (`dockerhub-creds`).

Quick agent check:

```groovy
pipeline {
  agent { label 'k8s-agent' }
  stages {
    stage('Check') {
      steps { sh 'uname -a' }
    }
  }
}
```

---

## 🧭 Install Argo CD & Deploy

```bash
kubectl create namespace argocd || true
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose Argo CD
kubectl patch svc argocd-server -n argocd \
  -p '{"spec":{"type":"LoadBalancer"}}'

# Get Argo admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

**Application (UI or YAML):**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: flask-aws-monitor
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Yonatan009/myapp.git
    targetRevision: main
    path: flask-aws-monitor
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

```bash
kubectl apply -f app-flask-aws-monitor.yaml
# then: open Argo UI → Sync
```

---

## 🌍 Access the Application

```bash
kubectl -n default get svc myapp-flask-aws-monitor -o wide
# Open in browser: http://<ELB-DNS>:5001/
```

> Prefer port‑less URL? Change `service.port: 80` and keep `targetPort: 5001` in `values.yaml`.

---

## 🔁 Daily Flow

1. Code change → `git push`
2. Jenkins (Kaniko) builds & pushes image to Docker Hub
3. Update tag in `values.yaml` (or auto‑tag) → Argo CD syncs to EKS
4. Access the Service/Ingress and verify the version

---

## 🛠 Troubleshooting

| Issue                        | Fix                                                               |
| ---------------------------- | ----------------------------------------------------------------- |
| `CreateContainerConfigError` | Ensure `aws-config` ConfigMap exists in the target namespace      |
| `ImagePullBackOff`           | Verify image tag in `values.yaml` and Docker Hub pull permissions |
| ELB not reachable            | Open inbound TCP rule in the AWS SG (port 5001/80)                |
| Agents not starting          | Check RBAC, Pod Template container names, and Pipeline label      |
| Argo not syncing             | Check repo path/branch, permissions, and health status            |

---

## 🧹 Cleanup (optional)

```bash
# Remove Argo CD app (if applied)
kubectl delete -f app-flask-aws-monitor.yaml || true

# Uninstall charts
helm uninstall jenkins -n jenkins || true
helm uninstall myapp -n default || true

# Delete demo ConfigMap
kubectl -n default delete configmap aws-config || true
```

---

✅ You now have a clear path: Clone → Jenkins (K8s Pod Templates) → Kaniko build → Docker Hub → Argo CD Sync → EKS Service.
