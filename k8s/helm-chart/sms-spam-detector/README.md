# SMS Spam Detector - Helm Chart

This Helm chart deploys the SMS Spam Detection application to Kubernetes with both Nginx Ingress and Istio service mesh support.

## Architecture

- **Frontend**: Spring Boot web application (app-service)
- **Backend**: Flask ML API (model-service)
- **Storage**: VirtualBox shared folder for ML model files
- **Ingress**: Nginx Ingress Controller for external access
- **Service Mesh**: Istio for mTLS and advanced traffic management

## Prerequisites

1. **Kubernetes cluster** with:
   - MetalLB load balancer
   - Nginx Ingress Controller (192.168.56.95)
   - Istio installed (192.168.56.96)

2. **VirtualBox shared folder** mounted at `/mnt/shared/models` on all nodes

3. **Model files** in `operation/models/` directory

4. **kubectl** and **helm** installed and configured

## Pre-Installation Setup

### 1. Prepare VirtualBox Shared Folder

Ensure the Vagrantfile has been modified to include the shared folder configuration:

```bash
cd /Users/atharva/DODA/operation
vagrant reload  # Apply shared folder changes
```

Verify the shared folder is mounted on all nodes:

```bash
vagrant ssh ctrl -c "ls -la /mnt/shared/models"
vagrant ssh node-1 -c "ls -la /mnt/shared/models"
vagrant ssh node-2 -c "ls -la /mnt/shared/models"
```

### 2. Set Kubeconfig

```bash
export KUBECONFIG=/Users/atharva/DODA/operation/kubeconfig-fresh
kubectl get nodes  # Verify cluster connectivity
```

### 3. Configure Container Registry Credentials (Required)

The chart includes a placeholder for Docker registry credentials. You must replace this before installation.

#### Option A: Update values.yaml

Generate the base64-encoded Docker config:

```bash
kubectl create secret docker-registry temp-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT \
  --docker-email=YOUR_EMAIL \
  --dry-run=client -o yaml | grep '\.dockerconfigjson:' | awk '{print $2}'
```

Copy the output and replace the placeholder in `values.yaml`:

```yaml
secrets:
  dockerConfigJson: "ewoJImF1dGhzIjp7CgkJImdoY3IuaW8iOnsKCQkJInVzZXJuYW1lIjoi..."
```

#### Option B: Use --set during installation

```bash
DOCKER_CONFIG=$(kubectl create secret docker-registry temp-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PAT \
  --docker-email=YOUR_EMAIL \
  --dry-run=client -o yaml | grep '\.dockerconfigjson:' | awk '{print $2}')

helm install sms-detector . --set secrets.dockerConfigJson="$DOCKER_CONFIG"
```

**Note:** If the GHCR repository is public, you can disable image pull secrets:

```yaml
imagePullSecrets:
  enabled: false
```

## Installation

### Basic Installation

```bash
cd /Users/atharva/DODA/operation/k8s/helm-chart

# Lint the chart
helm lint sms-spam-detector

# Preview rendered manifests
helm install --dry-run --debug sms-detector sms-spam-detector

# Install the chart
helm install sms-detector sms-spam-detector

# Check status
helm status sms-detector
helm list
```

### Development Installation (Lower Resources)

```bash
helm install sms-dev sms-spam-detector -f sms-spam-detector/values-dev.yaml
```

### Custom Values Installation

```bash
helm install sms-detector sms-spam-detector \
  --set modelService.replicas=3 \
  --set appService.replicas=3 \
  --set ingress.host=sms-custom.local
```

## Post-Installation

### 1. Wait for Pods to be Ready

```bash
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=sms-spam-detector \
  -n sms-spam-detection \
  --timeout=180s
```

### 2. Verify Istio Sidecar Injection

Pods should show 2/2 READY (main container + istio-proxy):

```bash
kubectl get pods -n sms-spam-detection
```

Expected output:
```
NAME                             READY   STATUS    RESTARTS   AGE
app-service-xxxxxxxxxx-xxxxx     2/2     Running   0          2m
model-service-xxxxxxxxxx-xxxxx   2/2     Running   0          2m
```

### 3. Configure DNS

Add entries to `/etc/hosts`:

```bash
echo "192.168.56.95 sms.local" | sudo tee -a /etc/hosts
echo "192.168.56.96 sms-istio.local" | sudo tee -a /etc/hosts
```

### 4. Access the Application

- **Nginx Ingress**: http://sms.local
- **Istio Gateway**: http://sms-istio.local

## Verification

### Check All Resources

```bash
kubectl get all,pv,pvc,ingress -n sms-spam-detection
```

### View Logs

```bash
# Application logs
kubectl logs -n sms-spam-detection -l app=app-service -c app-service --tail=50
kubectl logs -n sms-spam-detection -l app=model-service -c model-service --tail=50

# Istio sidecar logs
kubectl logs -n sms-spam-detection -l app=app-service -c istio-proxy --tail=50
```

### Test Functionality

1. Access http://sms.local in browser
2. Submit spam text: "Congratulations! You won a prize!"
3. Verify classification: "spam"
4. Submit ham text: "Meeting at 3pm tomorrow"
5. Verify classification: "ham"

### Verify Istio mTLS

Check service-to-service communication is encrypted:

```bash
kubectl exec -n sms-spam-detection deploy/app-service -c istio-proxy -- \
  pilot-agent request GET http://model-service:8081/apidocs
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Kubernetes namespace | `sms-spam-detection` |
| `imageRegistry` | Container registry | `ghcr.io` |
| `imageOrganization` | Registry organization | `doda25-team12` |
| `modelService.replicas` | Model service replicas | `2` |
| `appService.replicas` | App service replicas | `2` |
| `persistence.hostPath.path` | Model files path | `/mnt/shared/models` |
| `ingress.host` | Nginx Ingress hostname | `sms.local` |
| `istio.gateway.host` | Istio Gateway hostname | `sms-istio.local` |
| `istio.enabled` | Enable Istio service mesh | `true` |

### Resource Limits

**Model Service (Python/Flask/ML):**
- Requests: 512Mi RAM, 250m CPU
- Limits: 1Gi RAM, 500m CPU

**App Service (Spring Boot):**
- Requests: 256Mi RAM, 100m CPU
- Limits: 512Mi RAM, 500m CPU

## Upgrading

```bash
# Upgrade with new values
helm upgrade sms-detector sms-spam-detector

# Upgrade with specific values
helm upgrade sms-detector sms-spam-detector --set modelService.replicas=3

# Upgrade from values file
helm upgrade sms-detector sms-spam-detector -f custom-values.yaml
```

## Rollback

```bash
# View release history
helm history sms-detector

# Rollback to previous version
helm rollback sms-detector

# Rollback to specific revision
helm rollback sms-detector 1
```

## Uninstallation

```bash
# Uninstall the release
helm uninstall sms-detector

# Manually delete namespace (if needed)
kubectl delete namespace sms-spam-detection

# Remove /etc/hosts entries
sudo sed -i '' '/sms.local/d' /etc/hosts
sudo sed -i '' '/sms-istio.local/d' /etc/hosts
```

## Troubleshooting

### Pods Stuck in Pending

**Cause**: PVC not bound (VirtualBox shared folder not mounted)

**Solution**:
```bash
vagrant reload
vagrant ssh ctrl -c "ls -la /mnt/shared/models"
kubectl describe pvc -n sms-spam-detection model-files-pvc
```

### ImagePullBackOff

**Cause**: Invalid or missing registry credentials

**Solution**:
```bash
kubectl create secret docker-registry container-registry-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PAT \
  -n sms-spam-detection --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment -n sms-spam-detection
```

### Only 1/2 Containers Ready

**Cause**: Istio sidecar not injected

**Solution**:
```bash
kubectl get namespace sms-spam-detection --show-labels
kubectl label namespace sms-spam-detection istio-injection=enabled --overwrite
kubectl rollout restart deployment -n sms-spam-detection
```

### Ingress Returns 404

**Cause**: /etc/hosts not configured or Ingress misconfigured

**Solution**:
```bash
cat /etc/hosts | grep sms.local
curl -v -H "Host: sms.local" http://192.168.56.95
kubectl describe ingress -n sms-spam-detection
```

### Model Files Not Loading

**Cause**: Model files missing or wrong path

**Solution**:
```bash
kubectl exec -n sms-spam-detection deploy/model-service -c model-service -- ls -la /models
cp /path/to/model.joblib /Users/atharva/DODA/operation/models/
vagrant reload
```

## Advanced Features

### Manual Scaling

```bash
kubectl scale deployment/model-service -n sms-spam-detection --replicas=3
kubectl scale deployment/app-service -n sms-spam-detection --replicas=3
```

### Horizontal Pod Autoscaler

```bash
kubectl autoscale deployment model-service -n sms-spam-detection --cpu-percent=70 --min=2 --max=5
kubectl autoscale deployment app-service -n sms-spam-detection --cpu-percent=70 --min=2 --max=5
```

### Port Forwarding (Direct Access)

```bash
kubectl port-forward -n sms-spam-detection svc/app-service 8080:8080
kubectl port-forward -n sms-spam-detection svc/model-service 8081:8081
```

## Migration from Docker Compose

This Helm chart provides several advantages over Docker Compose:

- ✅ High availability with multiple replicas
- ✅ Zero-downtime rolling updates
- ✅ Health-based traffic routing
- ✅ Service mesh with automatic mTLS
- ✅ Horizontal pod autoscaling
- ✅ Infrastructure as code
- ✅ Multi-environment support
- ✅ Easy rollback capability

## Support

For issues and questions:
- Check the troubleshooting section above
- View logs: `kubectl logs -n sms-spam-detection <pod-name>`
- Describe resources: `kubectl describe <resource> -n sms-spam-detection <name>`

## License

Copyright DODA Team 12
