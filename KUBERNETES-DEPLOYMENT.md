# Kubernetes Deployment Guide

This guide covers deploying the SMS Checker application to Kubernetes using either raw manifests or the Helm chart.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Shared Storage Setup](#shared-storage-setup)
3. [Deployment Methods](#deployment-methods)
   - [Method 1: Using Helm (Recommended)](#method-1-using-helm-recommended)
   - [Method 2: Using Raw Manifests](#method-2-using-raw-manifests)
4. [Accessing the Application](#accessing-the-application)
5. [Managing Secrets](#managing-secrets)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

Before deploying, ensure you have:

1. **Kubernetes cluster** running (see main README for cluster setup)
2. **kubectl** configured to access your cluster
3. **Helm 3.0+** (for Helm deployment method)
4. **Nginx Ingress Controller** installed in the cluster
5. **Model files** trained and available (see model-service/README.md)

Verify cluster access:

```bash
kubectl cluster-info
kubectl get nodes
```

## Shared Storage Setup

The application uses a VirtualBox shared folder for model storage across all pods.

### Step 1: Prepare Model Files

Run the setup script to prepare the shared storage:

```bash
cd operation
./scripts/setup-shared-storage.sh
```

This script will:
- Create the `k8s-models/` directory
- Optionally copy models from `models/` directory
- Verify model files are present

### Step 2: Place Model Files

Ensure these files exist in `operation/k8s-models/`:

```bash
ls -la k8s-models/
# Expected:
# model-0.0.1.joblib
# preprocessor.joblib
```

If you don't have model files, train them first:

```bash
cd ../model-service
docker run -it --rm -v ./:/root/sms/ python:3.12.9-slim bash
# Inside container:
cd /root/sms
pip install -r requirements.txt
mkdir -p output
python src/read_data.py
python src/text_preprocessing.py
python src/text_classification.py
exit

# Copy to k8s-models
cp output/model.joblib ../operation/k8s-models/model-0.0.1.joblib
cp output/preprocessor.joblib ../operation/k8s-models/
```

### Step 3: Verify Shared Folder Mount

After starting the Vagrant cluster, verify the shared folder is mounted:

```bash
vagrant ssh ctrl -c "ls -la /mnt/shared-models"
vagrant ssh node-1 -c "ls -la /mnt/shared-models"
```

## Deployment Methods

### Method 1: Using Helm (Recommended)

Helm provides the most flexibility and is the recommended deployment method.

#### Basic Installation

```bash
cd operation
helm install sms-checker ./helm-chart/sms-checker
```

#### Installation with Custom Configuration

Create a custom values file:

```bash
cat > custom-values.yaml <<EOF
# Custom configuration
appService:
  replicaCount: 3
  image:
    tag: "v1.0.0"

modelService:
  replicaCount: 2
  image:
    tag: "v1.0.0"
  model:
    version: "0.0.1"

ingress:
  nginx:
    host: sms-checker.local

storage:
  hostPath: /mnt/shared-models
EOF

helm install sms-checker ./helm-chart/sms-checker -f custom-values.yaml
```

#### Installation with Secrets

**IMPORTANT**: Never commit actual secrets to version control!

```bash
# Create a separate secrets file (add to .gitignore!)
cat > secrets.yaml <<EOF
secrets:
  registry:
    username: "your-registry-username"
    token: "your-registry-token"
  modelDownload:
    token: "your-model-download-token"
EOF

# Install with secrets
helm install sms-checker ./helm-chart/sms-checker \
  -f custom-values.yaml \
  -f secrets.yaml
```

Or pass secrets via command line:

```bash
helm install sms-checker ./helm-chart/sms-checker \
  --set secrets.registry.username="your-username" \
  --set secrets.registry.token="your-token"
```

#### Verify Helm Deployment

```bash
# Check Helm release
helm list

# Check all resources
kubectl get all -n sms-checker

# Check pods
kubectl get pods -n sms-checker

# Check services
kubectl get svc -n sms-checker

# Check ingress
kubectl get ingress -n sms-checker
```

#### Upgrading with Helm

```bash
# Update values and upgrade
helm upgrade sms-checker ./helm-chart/sms-checker -f custom-values.yaml

# View differences before upgrading
helm diff upgrade sms-checker ./helm-chart/sms-checker -f custom-values.yaml
```

#### Uninstalling Helm Release

```bash
helm uninstall sms-checker
kubectl delete namespace sms-checker
kubectl delete pv model-storage-pv
```

### Method 2: Using Raw Manifests

For more control or when Helm is not available, deploy using raw Kubernetes manifests.

#### Deploy Storage First

```bash
cd operation

# Create namespace
kubectl apply -f k8s/config/namespace.yaml

# Create PersistentVolume and PersistentVolumeClaim
kubectl apply -f k8s/storage/persistent-volume.yaml
```

#### Deploy Configuration

```bash
# Create ConfigMap
kubectl apply -f k8s/config/configmap.yaml

# Create Secret (edit first to add actual values!)
kubectl apply -f k8s/config/secret.yaml
```

#### Deploy Services

```bash
# Deploy model-service
kubectl apply -f k8s/model-service/deployment.yaml
kubectl apply -f k8s/model-service/service.yaml

# Deploy app-service
kubectl apply -f k8s/app-service/deployment.yaml
kubectl apply -f k8s/app-service/service.yaml
```

#### Deploy Ingress

Choose either Nginx Ingress or Istio Gateway:

**Option A: Nginx Ingress**

```bash
kubectl apply -f k8s/ingress/nginx-ingress.yaml
```

**Option B: Istio Gateway**

```bash
kubectl apply -f k8s/ingress/istio/gateway.yaml
```

#### Verify Raw Manifest Deployment

```bash
# Check all resources
kubectl get all -n sms-checker

# Check persistent volumes
kubectl get pv,pvc -n sms-checker

# Check pods are running
kubectl get pods -n sms-checker -w

# Check services
kubectl get svc -n sms-checker

# Check ingress
kubectl get ingress -n sms-checker
```

#### Uninstalling Raw Manifests

```bash
# Delete in reverse order
kubectl delete -f k8s/ingress/nginx-ingress.yaml
kubectl delete -f k8s/app-service/
kubectl delete -f k8s/model-service/
kubectl delete -f k8s/config/
kubectl delete -f k8s/storage/
kubectl delete namespace sms-checker
```

## Accessing the Application

### Step 1: Add Hostname to /etc/hosts

Get the Ingress Controller external IP:

```bash
kubectl get svc -n ingress-nginx
# Look for the EXTERNAL-IP (should be 192.168.56.95 for default setup)
```

Add to `/etc/hosts`:

**macOS/Linux:**

```bash
sudo sh -c 'echo "192.168.56.95 sms-checker.local" >> /etc/hosts'
```

**Windows (PowerShell - Run as Administrator):**

```powershell
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "192.168.56.95 sms-checker.local"
```

### Step 2: Access the Application

Open your browser to:

```
http://sms-checker.local/sms/
```

### Step 3: Test with curl

```bash
# Test the app-service
curl http://sms-checker.local/sms/

# Test prediction
curl -X POST http://sms-checker.local/sms/ \
  -H "Content-Type: application/json" \
  -d '{"sms": "Congratulations! You won a prize!"}'
```

## Managing Secrets

### Creating Secrets Manually

```bash
# Create secret from literal values
kubectl create secret generic sms-checker-secrets \
  --from-literal=REGISTRY_USERNAME='your-username' \
  --from-literal=REGISTRY_TOKEN='your-token' \
  --from-literal=MODEL_DOWNLOAD_TOKEN='your-model-token' \
  -n sms-checker

# Create secret from file
kubectl create secret generic sms-checker-secrets \
  --from-file=credentials.json \
  -n sms-checker

# Create secret for Docker registry
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=your-username \
  --docker-password=your-token \
  -n sms-checker
```

### Viewing Secrets

```bash
# List secrets
kubectl get secrets -n sms-checker

# Describe secret (values are hidden)
kubectl describe secret sms-checker-secrets -n sms-checker

# View secret values (base64 encoded)
kubectl get secret sms-checker-secrets -n sms-checker -o yaml

# Decode a specific value
kubectl get secret sms-checker-secrets -n sms-checker \
  -o jsonpath='{.data.REGISTRY_USERNAME}' | base64 -d
```

### Updating Secrets

```bash
# Delete and recreate
kubectl delete secret sms-checker-secrets -n sms-checker
kubectl create secret generic sms-checker-secrets \
  --from-literal=REGISTRY_USERNAME='new-username' \
  --from-literal=REGISTRY_TOKEN='new-token' \
  -n sms-checker

# Or edit directly
kubectl edit secret sms-checker-secrets -n sms-checker
```

After updating secrets, restart pods to pick up changes:

```bash
kubectl rollout restart deployment/app-service -n sms-checker
kubectl rollout restart deployment/model-service -n sms-checker
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n sms-checker

# Describe pod for events
kubectl describe pod <pod-name> -n sms-checker

# Check logs
kubectl logs <pod-name> -n sms-checker

# Check events
kubectl get events -n sms-checker --sort-by='.lastTimestamp'
```

### Storage Issues

```bash
# Check PersistentVolume status
kubectl get pv

# Check PersistentVolumeClaim status
kubectl get pvc -n sms-checker

# Describe PVC
kubectl describe pvc model-storage-pvc -n sms-checker

# Verify shared folder on nodes
vagrant ssh ctrl -c "ls -la /mnt/shared-models"
vagrant ssh node-1 -c "ls -la /mnt/shared-models"
```

### Model Service Fails to Start

If model-service pods are failing:

```bash
# Check logs
kubectl logs -l component=model-service -n sms-checker

# Common issues:
# 1. Missing model files - verify files in /mnt/shared-models
# 2. Wrong MODEL_VERSION - check ConfigMap matches filenames
# 3. Permission issues - verify shared folder permissions
```

Verify model files are accessible:

```bash
kubectl exec -it deployment/model-service -n sms-checker -- ls -la /models
kubectl exec -it deployment/model-service -n sms-checker -- ls -la /root/sms/output
```

### Ingress Not Working

```bash
# Check ingress status
kubectl get ingress -n sms-checker

# Describe ingress
kubectl describe ingress sms-checker-ingress -n sms-checker

# Check Ingress Controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Verify Ingress Controller service has external IP
kubectl get svc -n ingress-nginx
```

### Service Communication Issues

Test internal service connectivity:

```bash
# Exec into app-service pod
kubectl exec -it deployment/app-service -n sms-checker -- bash

# Inside pod, test model-service
curl http://model-service:8081/apidocs

# Test prediction endpoint
curl -X POST http://model-service:8081/predict \
  -H "Content-Type: application/json" \
  -d '{"sms": "test message"}'
```

### Configuration Issues

```bash
# View ConfigMap
kubectl get configmap sms-checker-config -n sms-checker -o yaml

# Edit ConfigMap
kubectl edit configmap sms-checker-config -n sms-checker

# After editing, restart pods
kubectl rollout restart deployment/app-service -n sms-checker
kubectl rollout restart deployment/model-service -n sms-checker
```

### Scaling Issues

```bash
# Scale deployments
kubectl scale deployment/app-service --replicas=3 -n sms-checker
kubectl scale deployment/model-service --replicas=2 -n sms-checker

# Check pod distribution across nodes
kubectl get pods -n sms-checker -o wide

# Check resource usage
kubectl top nodes
kubectl top pods -n sms-checker
```

### Complete Reset

If you need to start fresh:

```bash
# Using Helm
helm uninstall sms-checker
kubectl delete namespace sms-checker
kubectl delete pv model-storage-pv

# Using raw manifests
kubectl delete namespace sms-checker --cascade=foreground
kubectl delete pv model-storage-pv

# Then redeploy
```

## Additional Resources

- **Helm Chart README**: `helm-chart/sms-checker/README.md`
- **Main README**: `operation/README.md`
- **CLAUDE.md**: Project architecture and development guide
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Helm Documentation**: https://helm.sh/docs/
