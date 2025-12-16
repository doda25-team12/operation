# Quickstart — Provision, Finalize, Deploy

This quickstart runs the Vagrant cluster, applies the finalization Ansible playbook, and installs the Helm chart for the SMS Spam Detector. It assumes you are in the repository root (`operation`). See the full docs: [README.md](README.md) and [k8s/helm-chart/sms-spam-detector/README.md](k8s/helm-chart/sms-spam-detector/README.md).

**Prerequisites**
- **Host:** Linux/macOS with VirtualBox, Vagrant, Ansible, kubectl and Helm installed.
- **From repo root:** run commands below in the repository root directory.
- **SSH key:** Vagrant uses the default insecure key unless configured otherwise.

**1. Start the Vagrant cluster**

Run from the repository root:

```bash
vagrant up
```

Wait until VMs are created and provisioned. Check status:

```bash
vagrant status
```

**2. Configure kubectl (set KUBECONFIG)**

On your host (macOS/Linux):

```bash
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

Expected: the control node (`ctrl`) and worker nodes are `Ready`.

**3. Run the finalization Ansible playbook**

This playbook installs MetalLB, Nginx Ingress, Istio, Dashboard, etc.

Find the Vagrant control node SSH key (optional):

```bash
vagrant ssh-config ctrl | grep IdentityFile
```

Run the playbook (replace the key path if needed):

```bash
ansible-playbook -u vagrant \
  --private-key=~/.vagrant.d/insecure_private_key \
  -i 192.168.56.100, \
  ansible/playbooks/finalization.yml
```

You can run tags to limit work (e.g., `--tags metallb`, `--tags ingress`, `--tags istio`).

**4. Verify cluster components**

```bash
kubectl get nodes
kubectl get pods -A
kubectl get svc -A | grep LoadBalancer
```

Expected external IPs (from docs):
- Nginx Ingress: `192.168.56.95`
- Istio Gateway: `192.168.56.96`

Add hosts entries on your host if you want to use hostnames:

```bash
sudo sh -c 'echo "192.168.56.95 sms.local" >> /etc/hosts'
sudo sh -c 'echo "192.168.56.96 sms-istio.local" >> /etc/hosts'
```

**5. Prepare Helm chart values (optional but recommended for quick test)**

Create a lightweight values file to disable monitoring and image pull secrets (saves resources):

```bash
cat > ~/helm-install-values.yaml <<'EOF'
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
```

If your images are private (GHCR), create a registry secret and either insert the base64 `dockerConfigJson` into the chart values or enable `imagePullSecrets` and create the Kubernetes secret in the target namespace.

Create a docker-registry secret (example):

```bash
kubectl create secret docker-registry container-registry-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GH_USER \
  --docker-password=YOUR_GH_TOKEN \
  --docker-email=you@example.com -n sms-spam-detection --dry-run=client -o yaml | kubectl apply -f -
```

**6. Install the Helm chart**

Copy the chart to the control node if you prefer running helm inside the VM, or run from host if `kubectl` is configured.

From repo root (host):

```bash
cd k8s/helm-chart/sms-spam-detector
helm dependency update
helm lint .
helm install sms-detector . -f ~/helm-install-values.yaml
```

To preview manifests first:

```bash
helm install --dry-run --debug sms-detector . -f ~/helm-install-values.yaml
```

**7. Verify the deployment**

```bash
kubectl get all,pv,pvc,ingress,gateway,virtualservice -n sms-spam-detection
kubectl get pods -n sms-spam-detection
kubectl logs -n sms-spam-detection -l app=model-service -c model-service --tail=50
kubectl logs -n sms-spam-detection -l app=app-service -c app-service --tail=50
```

Wait for pods to be `READY` (with Istio sidecars they typically show `2/2`).

**8. Access the app**

- Nginx Ingress: http://sms.local
- Istio Gateway: http://sms-istio.local

If Ingress isn't responding, port-forward as a fallback:

```bash
kubectl port-forward -n sms-spam-detection svc/app-service 8080:8080
# then open http://localhost:8080/sms
```

**Quick verification endpoints**

```bash
# check metrics
curl http://sms.local/metrics

# test model API from inside app container
docker compose exec app-service curl -X POST http://model-service:8081/predict -H "Content-Type: application/json" -d '{"sms":"Congratulations!"}'
```

**Tips & Troubleshooting**
- If Pods stuck `Pending`: ensure VirtualBox shared folder `/mnt/shared/models` is mounted and PVC/PV bound (`vagrant reload` on VMs may help).
- `ImagePullBackOff`: check registry credentials and `imagePullSecrets`.
- `1/2 Containers Ready`: label namespace for Istio injection: `kubectl label namespace sms-spam-detection istio-injection=enabled --overwrite` and rollout restart.

For full details and longer instructions, see the project READMEs: [README.md](README.md) and [k8s/helm-chart/sms-spam-detector/README.md](k8s/helm-chart/sms-spam-detector/README.md).
