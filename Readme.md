🛰️ AWS Dashboard App (Flask + Kubernetes + Helm)

This is a Python Flask web application that displays AWS resources using the boto3 SDK.
The app is containerized with Docker and deployed on Kubernetes using Helm.

It fetches real-time data about:

EC2 Instances

VPCs

Load Balancers

AMIs owned by the account

The app is exposed on port 5001.

🚀 How to Run
1. Clone the Repository
git clone git@github.com:Yonatan009/flask-aws-monitor.git
cd myapp

2. Create a ConfigMap with AWS Credentials

Before deploying, create a ConfigMap with your AWS credentials and region:

kubectl create configmap aws-config \
  --from-literal=AWS_ACCESS_KEY_ID=YOUR_KEY_ID \
  --from-literal=AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY \
  --from-literal=AWS_DEFAULT_REGION=us-east-1


⚠️ Do not commit real credentials to GitHub.

3. Build and Push the Docker Image
docker build -t yonatan009/flask-aws-monitor:latest .
docker push yonatan009/flask-aws-monitor:latest

4. Deploy with Helm

Move into the chart directory:

cd flask-aws-monitor
helm install flask-aws-monitor .


To update changes:

helm upgrade flask-aws-monitor .


To uninstall:

helm uninstall flask-aws-monitor

5. Verify Deployment

Check pods:

kubectl get pods


Check services:

kubectl get svc


If ingress.enabled=false, the service type will be LoadBalancer.
For Minikube, run:

minikube service flask-aws-monitor


Local URL (default):

http://localhost:5001

🧠 About the Project

This app uses Flask + boto3 to display AWS resources in simple HTML tables:

EC2: Instance ID, Type, State, Public IP

VPCs: VPC ID, CIDR Block

Load Balancers: Name, DNS Name

AMIs: AMI ID, Name

The backend handles:

AWS client setup

Rendering HTML with Flask

Error handling for missing or invalid credentials

🛡️ Security Notes

Do not hardcode AWS credentials in values.yaml.

Use ConfigMap, Secrets, or IAM roles for production.

Credentials shown here are examples only.

📁 Project Structure
myapp/
├── Dockerfile             # Build instructions for the image
├── Readme.md              # Documentation
├── app.py                 # Flask application
├── requirements.txt       # Dependencies (Flask, boto3)
└── flask-aws-monitor/     # Helm chart
    ├── Chart.yaml         # Helm chart metadata
    ├── values.yaml        # Configurable values
    └── templates/         # Templates for K8s manifests
        ├── _helpers.tpl
        ├── deployment.yaml
        ├── ingress.yaml
        └── service.yaml

✅ Example Output

When deployed, the dashboard shows:

EC2 Instances

ID	State	Type	Public IP
i-123abc	running	t3.micro	34.12.45.67

VPCs

VPC ID	CIDR
vpc-789xyz	172.31.0.0/16


