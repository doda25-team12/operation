# SMS Checker - Operation Repository

This repository contains the orchestration configuration for running the SMS Checker application using Docker Compose. The SMS Checker is a distributed system for detecting spam in SMS messages, demonstrating a microservice architecture with a Java/Spring Boot frontend and a Python/Flask backend.

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
   git clone https://github.com/doda25-team12/model-service.git
   cd model-service
   ```

2. Train using Docker (recommended):
   ```bash
   docker run -it --rm -v ./:/root/sms python:3.12.9-slim bash
   # Inside container:
   cd /root/sms
   pip install -r requirements.txt
   mkdir -p output
   python src/read_data.py
   python src/text_preprocessing.py
   python src/text_classification.py
   ```

3. Copy the generated `.joblib` files from `model-service/output/` to `operation/models/`:
   ```bash
   cp output/model.joblib ../operation/models/model-0.0.1.joblib
   cp output/preprocessor.joblib ../operation/models/
   ```

### Using Pre-trained Models

If pre-trained models are available from a release URL, configure the download in `.env`:
```bash
MODEL_VERSION=0.0.1
MODEL_BASE_URL=https://github.com/doda25-team12/model-service/releases/download
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

1. **Navigate to the operation directory**:
   ```bash
   cd operation
   ```

2. **Ensure model files are available** (see "Preparing Model Files" section above)

3. **Start the application**:
   ```bash
   docker compose up -d
   ```

4. **Verify services are running**:
   ```bash
   docker compose ps
   ```

   Expected output:
   ```
   NAME                      STATUS
   operation-app-service-1   Up
   operation-model-service-1 Up
   ```

5. **Access the web interface**:
   Open your browser to [http://localhost:8080/sms](http://localhost:8080/sms)

6. **Stop the application**:
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

1. Navigate to [http://localhost:8080/sms](http://localhost:8080/sms)
2. Enter an SMS message (e.g., "Win a free iPhone now!")
3. Click submit
4. Verify the classification result is displayed

## Troubleshooting

### Service fails to start

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
1. Verify services are running: `docker compose ps`
2. Check logs: `docker compose logs app-service`
3. Ensure you're using the correct port from `.env`

### Model predictions fail

**Problem**: Frontend shows error when submitting SMS

**Solution**:
1. Check model-service logs: `docker compose logs model-service`
2. Verify model files are valid `.joblib` files
3. Ensure `MODEL_VERSION` matches the model filename

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
kubectl get nodes
kubectl get pods -A

# 5. Access dashboard
sudo sh -c 'echo "192.168.56.95 dashboard.local" >> /etc/hosts'
kubectl -n kubernetes-dashboard create token admin-user
# Open http://dashboard.local and paste the token
```

### Prerequisites

1. **VirtualBox**: Install from [virtualbox.org](https://www.virtualbox.org/)
2. **Vagrant**: Install from [vagrantup.com](https://www.vagrantup.com/)
3. **Ansible**:
   - macOS: `brew install ansible`
   - Linux: `sudo apt install ansible` or `sudo yum install ansible`
   - Windows: Use WSL2 with Linux installation method
4. **kubectl**: Install from [kubernetes.io](https://kubernetes.io/docs/tasks/tools/)

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

**Note**: The comma (`,`) after the IP address is important!

### What Gets Installed

The finalization playbook installs and configures:

1. **MetalLB (v0.14.9)**: Network load balancer for bare-metal Kubernetes
   - IP Address Pool: `192.168.56.90-192.168.56.99`
   - Provides LoadBalancer service support

2. **Nginx Ingress Controller**: HTTP/HTTPS ingress controller
   - LoadBalancer IP: `192.168.56.95`
   - Enables Ingress resources for routing

3. **Kubernetes Dashboard**: Web-based UI for cluster management
   - Accessible at: `http://dashboard.local` (requires /etc/hosts entry)
   - Includes admin user with cluster-admin privileges

4. **Istio (v1.25.2)**: Service mesh for advanced traffic management
   - Istio Gateway IP: `192.168.56.96`
   - istioctl binary available in PATH for vagrant user

### Step 4: Access the Kubernetes Dashboard

1. **Add hostname to hosts file** (on your host machine):

   **macOS/Linux:**
   ```bash
   sudo sh -c 'echo "192.168.56.95 dashboard.local" >> /etc/hosts'
   ```

   **Windows (PowerShell - Run as Administrator):**
   ```powershell
   Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "192.168.56.95 dashboard.local"
   ```

2. **Get the admin token**:
   ```bash
   kubectl -n kubernetes-dashboard create token admin-user
   ```

3. **Access the dashboard**:
   - Open `http://dashboard.local` in your browser
   - Paste the token from step 2
   - Click "Sign in"

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
curl http://test.local
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

**Solution**: Architecture mismatch. The playbook should automatically detect ARM64 vs x86_64, but if it fails:
1. Check VM architecture: `vagrant ssh ctrl -c "uname -m"`
2. Ensure the correct Istio binary is downloaded (linux-arm64 or linux-amd64)

**Problem**: MetalLB pods not starting

**Solution**: Check that the IP range doesn't conflict with your VirtualBox network:
```bash
kubectl logs -n metallb-system -l app=metallb
```

**Problem**: Cannot access dashboard.local

**Solution**:
1. Verify /etc/hosts entry exists (macOS/Linux: `cat /etc/hosts | grep dashboard`, Windows: `type C:\Windows\System32\drivers\etc\hosts | findstr dashboard`)
2. Check Ingress is created: `kubectl get ingress -n kubernetes-dashboard`
3. Verify Nginx Ingress has external IP: `kubectl get svc -n ingress-nginx`
4. Check browser can reach the IP: `curl http://192.168.56.95`

## Additional Resources
- **Frontend Repository**: [doda25-team12/app](https://github.com/doda25-team12/app) - Spring Boot application source
- **Backend Repository**: [doda25-team12/model-service](https://github.com/doda25-team12/model-service) - ML model service source
- **Shared Library**: [doda25-team12/lib-version](https://github.com/doda25-team12/lib-version) - Version management
- **Docker Compose File**: [docker-compose.yml](./docker-compose.yml) - Service orchestration configuration
- **Environment Config**: [.env](./.env) - Configuration parameters

## Contributing

This operation repository should remain runnable with the latest image versions. When adding new infrastructure components (Vagrant, Ansible, Kubernetes, etc.), ensure backward compatibility with the Docker Compose deployment.
