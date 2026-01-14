
# SMS Checker - Operation Repository

This repository contains the orchestration configuration for running the SMS Checker application using Docker Compose. The SMS Checker is a distributed system for detecting spam in SMS messages, demonstrating a microservice architecture with a Java/Spring Boot frontend and a Python/Flask backend.

## 🔍 Configuration Validation Framework

This repository includes an automated **Configuration Validation Framework** that prevents 90%+ of configuration-related deployment failures by validating at 6 layers before deployment.

**Quick start:**
```bash
# Install dependencies
bash k8s/validation/install-dependencies.sh

# Run validation
bash k8s/validation/validate-config.sh

# Pre-deployment check (validation + helm lint + kubectl dry-run)
bash k8s/validation/pre-deployment-check.sh

# Deploy
helm install sms-detector k8s/helm-chart/sms-spam-detector -n sms-spam-detection --create-namespace
```

**What it catches:**
- ✓ Port mismatches between `.env` and `values.yaml`
- ✓ Canary/shadow image tag conflicts
- ✓ Missing MODEL_VERSION environment variable
- ✓ URL construction errors
- ✓ Invalid Helm chart syntax

**Complete guide**: [k8s/validation/EXTENSION_PROPOSAL.md](k8s/validation/EXTENSION_PROPOSAL.md) - Full documentation including usage, verification steps, troubleshooting, and CI/CD integration

## System Architecture

The application consists of two microservices:

- **app-service** (Frontend): Spring Boot web application that provides a user interface for SMS spam detection
   - Exposes port 8080 to the host machine
   - Communicates with the model-service via internal Docker network
   - Source code: [doda25-team12/app](https://github.com/doda25-team12/app)

- **model-service** (Backend): Python/Flask REST API serving a machine learning model
   - Runs on internal port 8081 (not exposed to host)
   - Provides `/predict` endpoint for spam classification
   - Requires trained model files to be mounted or downloaded
   - Source code: [doda25-team12/model-service](https://github.com/doda25-team12/model-service)

## Container Images and Model Artifacts

### Automated Releases

Container images and model artifacts are **automatically generated** by the model-service repository via GitHub Actions whenever code is pushed to the `main` branch or any branch starting with `test`.

**Each automated release includes:**
- **Docker Images** in GitHub Container Registry (GHCR):
  - `ghcr.io/doda25-team12/app-service:v{VERSION}`
  - `ghcr.io/doda25-team12/model-service:v{VERSION}`
  - Multi-architecture: linux/amd64 and linux/arm64
  - Tagged as `latest` for main branch releases

- **Model Files** in [GitHub Releases](https://github.com/doda25-team12/model-service/releases):
  - `model-{VERSION}.joblib` (trained Decision Tree classifier)
  - `preprocessor.joblib` (text preprocessing pipeline)

### Using Latest Versions

To use the most recent automatically-built images:

```bash
# Update .env to use latest tag
VERSION=latest

# Pull latest images
docker compose pull

# Restart services
docker compose up -d
```

### Using Specific Versions

To pin to a specific release version:

```bash
# Update .env
VERSION=v1.0.2

# Pull specific version
docker compose pull
docker compose up -d
```

### Manual Training (Optional)

While automated releases provide pre-trained models and container images, you can still train models manually for development or experimentation. See the sections below for manual training instructions.

## Prerequisites

1. **Docker Desktop**: Install from [docker.com](https://www.docker.com/)
2. **Model Files**: The model-service requires trained ML model files. You have two options:
   - **Option A (Volume Mount)**: Place model files in the `models/` directory (see "Preparing Model Files" below)
   - **Option B (Download)**: Configure `MODEL_VERSION` and `MODEL_BASE_URL` environment variables for automatic download

## Preparing Model Files

The model-service expects the following files:
- `model-{VERSION}.joblib` - Trained decision tree classifier
- `preprocessor.joblib` - Text preprocessing pipeline

### Training Models Locally

If you want to train models from scratch:

1. Clone the model-service repository:
   ```bash
   git clone [https://github.com/doda25-team12/model-service.git](https://github.com/doda25-team12/model-service.git)
   cd model-service


2.  Train using Docker (recommended):

    ```bash
    docker run -it --rm -v ./:/root/sms python:3.12.9-slim bash
    # Inside container:
    cd /root/sms
    pip install -r requirements.txt
    mkdir -p output
    python src/read_data.py
    python src/text_preprocessing.py
    python src/text_classification.py
    exit
    ```

3.  Copy the generated `.joblib` files from `model-service/output/` to `operation/models/`:

    ```bash
    cp output/model.joblib ../models/model-0.0.1.joblib
    cp output/preprocessor.joblib ../models/
    ```

### Using Pre-trained Models

If pre-trained models are available from a release URL, configure the download in `.env`:

```bash
MODEL_VERSION=0.0.1
MODEL_BASE_URL=[https://github.com/doda25-team12/model-service/releases/download](https://github.com/doda25-team12/model-service/releases/download)
```

## Configuration

All configuration is managed through the `.env` file:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `HOST_PORT` | Port exposed on host machine for web UI | 8080 | No |
| `APP_INTERNAL_PORT` | Internal port for app-service | 8080 | No |
| `MODEL_INTERNAL_PORT` | Internal port for model-service | 8081 | No |
| `ORG_NAME` | GitHub organization for container images | doda25-team12 | Yes |
| `VERSION` | Docker image tag to use | latest | Yes |
| `MODEL_VERSION` | Model version for file naming | - | Yes (if using download) |
| `MODEL_BASE_URL` | Base URL for downloading model files | - | Yes (if using download) |

### Customizing Ports

If port 8080 is already in use on your machine, modify `HOST_PORT` in `.env`:

```bash
HOST_PORT=9090
```

## How to Run

1.  **Navigate to the operation directory**:

    ```bash
    cd operation
    ```

2.  **Ensure model files are available** (see "Preparing Model Files" section above)

3.  **Start the application**:

    ```bash
    docker compose up -d
    ```

4.  **Verify services are running**:

    ```bash
    docker compose ps
    ```

    Expected output:

    ```
    NAME                      STATUS
    operation-app-service-1   Up
    operation-model-service-1 Up
    ```

5.  **Access the web interface**:
    Open your browser to [http://localhost:8080/sms](https://www.google.com/search?q=http://localhost:8080/sms)

6.  **Stop the application**:

    ```bash
    docker compose down
    ```

## Verification and Testing

### Check Service Health

View logs to ensure services started correctly:

```bash
# View all logs
docker compose logs

# View specific service logs
docker compose logs app-service
docker compose logs model-service

# Follow logs in real-time
docker compose logs -f
```

### Test the Model Service API

While the model-service is not exposed to the host, you can test it via the app-service container:

```bash
docker compose exec app-service curl -X POST http://model-service:8081/predict \
  -H "Content-Type: application/json" \
  -d '{"sms": "Congratulations! You won a prize!"}'
```

Expected response:

```json
{
  "classifier": "decision tree",
  "result": "spam",
  "sms": "Congratulations! You won a prize!"
}
```

### Test the Web UI

1.  Navigate to [http://localhost:8080/sms](https://www.google.com/search?q=http://localhost:8080/sms)
2.  Enter an SMS message (e.g., "Win a free iPhone now\!")
3.  Click submit
4.  Verify the classification result is displayed

## Troubleshooting

### Service fails to start

**Problem**: `Cannot connect to the Docker daemon...`

**Solution**: The Docker service is likely not running.
- Start it: `sudo systemctl start docker`
- Enable on boot: `sudo systemctl enable docker`

**Problem**: Model-service exits immediately

**Solution**: Check that model files are present:

```bash
ls -la models/
docker compose logs model-service
```

Ensure either:

  - Model files exist in `models/` directory, OR
  - `MODEL_VERSION` and `MODEL_BASE_URL` are set in `.env`

### Port conflict

**Problem**: Error "port is already allocated"

**Solution**: Change `HOST_PORT` in `.env` to an available port

### Cannot access web UI

**Problem**: Browser shows connection error

**Solution**:

1.  Verify services are running: `docker compose ps`
2.  Check logs: `docker compose logs app-service`
3.  Ensure you're using the correct port from `.env`

### Model predictions fail

**Problem**: Frontend shows error when submitting SMS

**Solution**:

1.  Check model-service logs: `docker compose logs model-service`
2.  Verify model files are valid `.joblib` files
3.  Ensure `MODEL_VERSION` matches the model filename

## Development and Maintenance

### Updating to Latest Images

To pull and use the latest container images:

```bash
docker compose pull
docker compose up -d
```

### Using Specific Versions

To run a specific release, update `.env`:

```bash
VERSION=v1.2.3
```

Then restart:

```bash
docker compose down
docker compose up -d
```

### Viewing Resource Usage

Monitor container resource consumption:

```bash
docker stats
```

## Kubernetes Cluster Setup

This section covers provisioning a complete Kubernetes cluster using Vagrant, VirtualBox, and Ansible.

### Quick Start

```bash
# 1. Start the cluster
cd operation
vagrant up

# 2. Configure kubectl (macOS/Linux)
export KUBECONFIG=$(pwd)/kubeconfig

# 3. Run finalization playbook
ansible-playbook -u vagrant \
  --private-key=~/.vagrant.d/insecure_private_keys/vagrant.key.ed25519 \
  -i 192.168.56.100, \
  ansible/playbooks/finalization.yml

# 4. Verify
vagrant ssh ctrl
kubectl get nodes
kubectl get pods -A

# 5. Access dashboard (Tunnel Method)
exit
vagrant ssh -- -L 8001:127.0.0.1:8001
# Inside VM:
sudo systemctl restart systemd-timesyncd
kubectl proxy
# On Host: Open http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard-web:8000/proxy/
```

### Prerequisites

1.  **VirtualBox**: Install from [virtualbox.org](https://www.virtualbox.org/)
2.  **Vagrant**: Install from [vagrantup.com](https://www.vagrantup.com/)
3.  **Ansible**:
      - macOS: `brew install ansible`
      - Linux: `sudo apt install ansible` or `sudo yum install ansible`
      - Windows: Use WSL2 with Linux installation method
4.  **kubectl**: Install from [kubernetes.io](https://kubernetes.io/docs/tasks/tools/)

### Step 1: Provision the Cluster

From the `operation` directory:

```bash
cd operation
vagrant up
```

This will create and configure:

  - 1 control plane node (`ctrl`) at `192.168.56.100`
  - 2 worker nodes (`node-1`, `node-2`) at `192.168.56.101+`
  - Kubernetes 1.32.4 with Flannel networking

Provisioning takes approximately 5-10 minutes.

### Step 2: Configure kubectl Access

Set the KUBECONFIG environment variable to access the cluster:

**macOS/Linux:**

```bash
export KUBECONFIG=$(pwd)/kubeconfig
```

**Windows (PowerShell):**

```powershell
$env:KUBECONFIG="$PWD\kubeconfig"
```

**Windows (CMD):**

```cmd
set KUBECONFIG=%CD%\kubeconfig
```

Verify cluster access:

```bash
kubectl get nodes
```

Expected output:

```
NAME     STATUS   ROLES           AGE   VERSION
ctrl     Ready    control-plane   10m   v1.32.4
node-1   Ready    <none>          8m    v1.32.4
node-2   Ready    <none>          7m    v1.32.4
```

### Step 3: Run the Finalization Playbook

The finalization playbook installs MetalLB, Nginx Ingress Controller, Kubernetes Dashboard, and Istio.

**Cross-Platform Command:**

Find your Vagrant SSH key path first:

```bash
vagrant ssh-config ctrl | grep IdentityFile
```

Then run the finalization playbook (replace the key path with output from above):

**macOS/Linux:**

```bash
ansible-playbook -u vagrant \
  --private-key=~/.vagrant.d/insecure_private_keys/vagrant.key.ed25519 \
  -i 192.168.56.100, \
  ansible/playbooks/finalization.yml
```

**Windows (PowerShell/CMD):**

```bash
ansible-playbook -u vagrant --private-key=%USERPROFILE%\.vagrant.d\insecure_private_keys\vagrant.key.ed25519 -i 192.168.56.100, ansible/playbooks/finalization.yml
```

**Note**: The comma (`,`) after the IP address is important\!

### What Gets Installed

The finalization playbook installs and configures:

1.  **MetalLB (v0.14.9)**: Network load balancer for bare-metal Kubernetes

      - IP Address Pool: `192.168.56.90-192.168.56.99`
      - Provides LoadBalancer service support

2.  **Nginx Ingress Controller**: HTTP/HTTPS ingress controller

      - LoadBalancer IP: `192.168.56.95`
      - Enables Ingress resources for routing

3.  **Kubernetes Dashboard**: Web-based UI for cluster management

      - Accessible at: `http://dashboard.local` (requires /etc/hosts entry)
      - Includes admin user with cluster-admin privileges

4.  **Istio (v1.25.2)**: Service mesh for advanced traffic management

      - Istio Gateway IP: `192.168.56.96`
      - istioctl binary available in PATH for vagrant user

### Step 4: Access the Kubernetes Dashboard

Accessing the dashboard on a local Vagrant cluster requires port forwarding and precise token management.

**1. Create a Secure Tunnel**
From your Mac/Host terminal, SSH into the Vagrant VM with port forwarding:

```bash
vagrant ssh -- -L 8001:127.0.0.1:8001
```

**2. Sync Time & Start Proxy (Inside VM)**
Time drift in VMs often causes "401 Unauthorized" errors. Run these commands inside the `vagrant ssh` session:

```bash
# Force time sync (Crucial for token validity)
sudo systemctl restart systemd-timesyncd

# Start the proxy (Keep this running)
kubectl proxy
```

**3. Generate Admin Token (Inside VM)**
Open a **new** terminal window, SSH into vagrant (`vagrant ssh`), and run this block to ensure a fresh, valid admin token:

```bash
# Create Service Account
kubectl -n kubernetes-dashboard create serviceaccount admin-user

# Bind to Cluster Admin Role
kubectl create clusterrolebinding admin-user-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:admin-user

# Generate Token
kubectl -n kubernetes-dashboard create token admin-user
```

*Copy the token output carefully (avoid trailing % symbols).*

**4. Login**
Open this exact URL in your **Host** browser:
[http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard-web:8000/proxy/](https://www.google.com/search?q=http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard-web:8000/proxy/)

*(If that fails, try the alternative v3 URL: `.../services/https:kubernetes-dashboard-kong-proxy:443/proxy/`)*

### Running Specific Sections

You can run specific sections using tags:

```bash
# Install only MetalLB
ansible-playbook -u vagrant -i 192.168.56.100, ansible/playbooks/finalization.yml --tags metallb

# Install only Ingress Controller
ansible-playbook -u vagrant -i 192.168.56.100, ansible/playbooks/finalization.yml --tags ingress

# Install only Dashboard
ansible-playbook -u vagrant -i 192.168.56.100, ansible/playbooks/finalization.yml --tags dashboard

# Install only Istio
ansible-playbook -u vagrant -i 192.168.56.100, ansible/playbooks/finalization.yml --tags istio
```

### Step 5: Verify the Installation

After running the finalization playbook, verify all components:

```bash
# Check all nodes are ready
kubectl get nodes

# Check all pods are running
kubectl get pods -A

# Check LoadBalancer services have external IPs
kubectl get svc -A | grep LoadBalancer

# Check Ingress resources
kubectl get ingress -A
```

Expected LoadBalancer IPs:

  - Nginx Ingress Controller: `192.168.56.95`
  - Istio Gateway: `192.168.56.96`

### Step 6: Test with a Simple Deployment

Deploy a test application to verify the cluster:

```bash
# Deploy test nginx
kubectl create deployment nginx-test --image=nginx
kubectl expose deployment nginx-test --port=80
kubectl create ingress nginx-test --class=nginx --rule="test.local/*=nginx-test:80"

# Add to hosts file
# macOS/Linux:
sudo sh -c 'echo "192.168.56.95 test.local" >> /etc/hosts'

# Windows (PowerShell - Run as Administrator):
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "192.168.56.95 test.local"

# Wait for deployment
kubectl wait --for=condition=available --timeout=60s deployment/nginx-test

# Test
curl [http://test.local](http://test.local)
```

Expected response: `Welcome to nginx!`

### Cleanup Test Deployment

```bash
kubectl delete ingress nginx-test
kubectl delete svc nginx-test
kubectl delete deployment nginx-test
```

### Common Cluster Management Commands

```bash
# View cluster status
vagrant status

# SSH into nodes
vagrant ssh ctrl      # Control plane
vagrant ssh node-1    # Worker node 1
vagrant ssh node-2    # Worker node 2

# Stop the cluster
vagrant halt

# Start the cluster
vagrant up

# Restart a node
vagrant reload ctrl

# Destroy the cluster (WARNING: deletes all data)
vagrant destroy -f

# Re-provision without destroying
vagrant provision
```

### Troubleshooting

**Problem**: `kubectl` says "connection refused" or "localhost:8080"

**Solution**: Set the KUBECONFIG environment variable:

```bash
# macOS/Linux
export KUBECONFIG=$(pwd)/kubeconfig

# Windows PowerShell
$env:KUBECONFIG="$PWD\kubeconfig"
```

**Problem**: Playbook fails with "Permission denied (publickey)"

**Solution**: Use the Vagrant SSH key explicitly:

```bash
vagrant ssh-config ctrl | grep IdentityFile
# Then use the path shown in the ansible-playbook command
```

**Problem**: Playbook fails with connection timeout

**Solution**: Ensure the Vagrant VMs are running and accessible:

```bash
vagrant status
ping 192.168.56.100
```

**Problem**: Istio installation fails with "Exec format error"

**Solution**: Architecture mismatch. The playbook should automatically detect ARM64 vs x86\_64, but if it fails:

1.  Check VM architecture: `vagrant ssh ctrl -c "uname -m"`
2.  Ensure the correct Istio binary is downloaded (linux-arm64 or linux-amd64)

**Problem**: MetalLB pods not starting

**Solution**: Check that the IP range doesn't conflict with your VirtualBox network:

```bash
kubectl logs -n metallb-system -l app=metallb
```

**Problem**: Cannot access dashboard (401 Unauthorized or 404)

**Solution**:

1.  **Check Time**: Run `date` inside Vagrant. If it's incorrect, run `sudo systemctl restart systemd-timesyncd`.
2.  **Check Proxy**: Ensure you are using `vagrant ssh -- -L 8001:127.0.0.1:8001` and running `kubectl proxy`.
3.  **Check URL**: Do not use `localhost:8001` directly. Use the full API URL listed in Step 4.

## Deploying SMS Application to Kubernetes with Helm

After setting up the Kubernetes cluster (see sections above), you can deploy the SMS Spam Detection application using the included Helm chart.

### Prerequisites

1.  **Kubernetes cluster running** (see "Kubernetes Cluster Setup" section)
2.  **kubectl configured** with KUBECONFIG
3.  **Helm installed**: [helm.sh/docs/intro/install](https://helm.sh/docs/intro/install/)
4.  **VirtualBox shared folder** configured at `/mnt/shared/models`
5.  **Model files** in `operation/models/` directory

### Quick Start 

```bash
# 1. SSH to control node
vagrant ssh ctrl

# 2. Copy Helm chart to control node (from host machine in another terminal)
scp -r k8s/helm-chart/sms-spam-detector vagrant@127.0.0.1:~/helm-chart

# 3. Create custom values file to disable image pull secrets (for testing)
cat > ~/helm-install-values.yaml << 'EOF'
imagePullSecrets:
  enabled: false
monitoring:
  enabled: false
prometheus:
  prometheusOperator:
    enabled: false
  prometheus:
    enabled: false
  alertmanager:
    enabled: false
modelService:
  replicas: 1
appService:
  replicas: 1
EOF

# 4. Add Helm repositories (if not already added)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 5. Build Helm dependencies
cd ~/helm-chart
helm dependency build

# 6. Lint the chart to validate
helm lint .

# 7. Perform dry-run to preview manifests
helm install --dry-run sms-detector . -f ~/helm-install-values.yaml

# 8. Install the Helm chart
helm install sms-detector . -f ~/helm-install-values.yaml

# 9. Verify installation
helm list
helm status sms-detector
```

### Cluster Verification Commands

After installation, verify all components are deployed correctly:

```bash
# Check Kubernetes nodes are Ready
vagrant ssh ctrl -c "kubectl get nodes"
# Expected: 3/3 nodes Ready (ctrl, node-1, node-2)

# Check all system pods
vagrant ssh ctrl -c "kubectl get pods -A"
# Expected: All system pods running (24+ pods)

# Check SMS deployment namespace and pods
vagrant ssh ctrl -c "kubectl get pods -n sms-spam-detection"
# Expected: app-service and model-service pods created with Istio sidecars (1/2 ready)

# Check all SMS resources
vagrant ssh ctrl -c "kubectl get all,pv,pvc,ingress,gateway,virtualservice -n sms-spam-detection"
# Expected: Services, Deployments, PV/PVC bound, Ingress with IP, Istio Gateway/VirtualService

# Verify persistent storage is configured
vagrant ssh ctrl -c "kubectl describe pv model-files-pv"
# Expected: HostPath /mnt/shared/models, Status: Bound

# Verify shared folder is accessible on all nodes
vagrant ssh ctrl -c "ls -la /mnt/shared/models"
vagrant ssh node-1 -c "ls -la /mnt/shared/models"
vagrant ssh node-2 -c "ls -la /mnt/shared/models"
# Expected: All nodes can access the shared folder
```

### Helm Management Commands

```bash
# View release status
helm status sms-detector
helm list

# View deployment history
helm history sms-detector

# View applied values
helm get values sms-detector

# Upgrade with new configuration
helm upgrade sms-detector . -f ~/helm-install-values.yaml

# Rollback to previous version
helm rollback sms-detector

# Uninstall release
helm uninstall sms-detector
```

### Configure Container Registry Credentials (For Production)

If using private GitHub Container Registry (GHCR), create credentials:

```bash
# Inside control node
kubectl create secret docker-registry container-registry-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT \
  --docker-email=YOUR_EMAIL \
  -n sms-spam-detection

# Then update Helm release
helm upgrade sms-detector . \
  -f ~/helm-install-values.yaml \
  --set imagePullSecrets.enabled=true
```

### Add DNS Entries

On your host machine, add the following to `/etc/hosts`:

```bash
# For Nginx Ingress
echo "192.168.56.95 sms.local" | sudo tee -a /etc/hosts

# For Istio Gateway
echo "192.168.56.96 sms-istio.local" | sudo tee -a /etc/hosts
```

Then access:
- Nginx: http://sms.local
- Istio: http://sms-istio.local


# 7. Access the application
open [http://sms.local](http://sms.local)           # Nginx Ingress
open [http://sms-istio.local](http://sms-istio.local)     # Istio Gateway
```

### Architecture

The Helm chart deploys:

  - **app-service**: Spring Boot frontend (2 replicas)
  - **model-service**: Flask ML backend (2 replicas)
  - **Nginx Ingress**: External HTTP access at `sms.local` (192.168.56.95)
  - **Istio Service Mesh**: Automatic mTLS between services, Gateway at `sms-istio.local` (192.168.56.96)
  - **Shared Storage**: VirtualBox shared folder for ML model files
  - **ConfigMaps**: Non-sensitive configuration
  - **Secrets**: Container registry credentials (placeholder)

### Container Registry Credentials

**Important**: The chart includes a placeholder for container registry credentials. If your GHCR repository is private:

```bash
# Generate Docker config secret
kubectl create secret docker-registry temp-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT \
  --docker-email=YOUR_EMAIL \
  --dry-run=client -o yaml | grep '\.dockerconfigjson:' | awk '{print $2}'

# Copy output and replace placeholder in k8s/helm-chart/sms-spam-detector/values.yaml
# OR use --set during installation:
helm install sms-detector sms-spam-detector --set secrets.dockerConfigJson="<base64-output>"
```

If GHCR is public, disable image pull secrets in `values.yaml`:

```yaml
imagePullSecrets:
  enabled: false
```

### Verification

```bash
# Check deployment status
kubectl get pods -n sms-spam-detection
kubectl get svc -n sms-spam-detection
kubectl get ingress -n sms-spam-detection

# Verify Istio sidecar injection (should show 2/2 READY)
kubectl get pods -n sms-spam-detection

# View logs
kubectl logs -n sms-spam-detection -l app=app-service -c app-service
kubectl logs -n sms-spam-detection -l app=model-service -c model-service
```

### Testing

1.  Access http://sms.local in browser
2.  Submit spam: "Congratulations\! You won a prize\!"
3.  Verify classification: "spam"
4.  Submit ham: "Meeting at 3pm tomorrow"
5.  Verify classification: "ham"

### Helm Management

```bash
# Upgrade deployment
helm upgrade sms-detector k8s/helm-chart/sms-spam-detector

# Rollback to previous version
helm rollback sms-detector

# View release history
helm history sms-detector

# Uninstall
helm uninstall sms-detector
```

### Development Environment

For lower resource usage during development:

```bash
helm install sms-dev sms-spam-detector -f sms-spam-detector/values-dev.yaml
```

This uses 1 replica per service with reduced memory/CPU limits.

### Troubleshooting

See the comprehensive troubleshooting guide in `k8s/helm-chart/sms-spam-detector/README.md`.

**Common issues:**

  - **Pods stuck in Pending**: VirtualBox shared folder not mounted → `vagrant reload`
  - **ImagePullBackOff**: Registry credentials missing → Configure secrets
  - **1/2 containers ready**: Istio sidecar not injected → Check namespace labels
  - **404 on Ingress**: /etc/hosts not configured → Add DNS entries

For detailed documentation, see:

  - **Helm Chart README**: [k8s/helm-chart/sms-spam-detector/README.md](https://www.google.com/search?q=./k8s/helm-chart/sms-spam-detector/README.md)
  - **Deployment Plan**: Refer to planning documentation for architecture details

## Additional Resources

  - **Frontend Repository**: [doda25-team12/app](https://github.com/doda25-team12/app) - Spring Boot application source
  - **Backend Repository**: [doda25-team12/model-service](https://github.com/doda25-team12/model-service) - ML model service source
  - **Shared Library**: [doda25-team12/lib-version](https://github.com/doda25-team12/lib-version) - Version management
  - **Docker Compose File**: [docker-compose.yml](https://www.google.com/search?q=./docker-compose.yml) - Service orchestration configuration
  - **Environment Config**: [.env](https://www.google.com/search?q=./.env) - Configuration parameters
  - **Helm Chart**: [k8s/helm-chart/sms-spam-detector/](https://www.google.com/search?q=./k8s/helm-chart/sms-spam-detector/) - Kubernetes deployment via Helm

## Contributing

This operation repository should remain runnable with the latest image versions. When adding new infrastructure components (Vagrant, Ansible, Kubernetes, etc.), ensure backward compatibility with the Docker Compose deployment.
