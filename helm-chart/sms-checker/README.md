# SMS Checker Helm Chart

This Helm chart deploys the SMS Spam Detection application to a Kubernetes cluster.

## Features

- **Deployments** for both app-service and model-service with configurable replicas
- **Services** (ClusterIP) for internal communication
- **Ingress** support for both Nginx Ingress Controller and Istio Gateway
- **ConfigMaps** for application configuration
- **Secrets** for sensitive data with placeholder values
- **PersistentVolume** using VirtualBox shared folders for model storage
- Fully templated and customizable via `values.yaml`

## Prerequisites

- Kubernetes cluster (1.20+)
- Helm 3.0+
- Nginx Ingress Controller or Istio (for ingress)
- VirtualBox shared folder configured (for model storage)

## Installation

### 1. Basic Installation

Install with default values:

```bash
helm install sms-checker ./helm-chart/sms-checker
```

### 2. Installation with Custom Values

Create a custom values file:

```bash
cat > custom-values.yaml <<EOF
appService:
  replicaCount: 3
modelService:
  replicaCount: 2
  model:
    version: "0.0.2"
ingress:
  nginx:
    host: my-sms-checker.local
EOF

helm install sms-checker ./helm-chart/sms-checker -f custom-values.yaml
```

### 3. Installation with Secrets

**IMPORTANT**: Never commit actual secrets to version control!

Override secrets during installation:

```bash
helm install sms-checker ./helm-chart/sms-checker \
  --set secrets.registry.username="actual-username" \
  --set secrets.registry.token="actual-token" \
  --set secrets.modelDownload.token="actual-model-token"
```

Or use a separate secrets file (not committed to git):

```bash
cat > secrets.yaml <<EOF
secrets:
  registry:
    username: "actual-username"
    token: "actual-token"
  modelDownload:
    token: "actual-model-token"
EOF

helm install sms-checker ./helm-chart/sms-checker -f secrets.yaml
```

### 4. Dry Run (Test Before Installing)

```bash
helm install sms-checker ./helm-chart/sms-checker --dry-run --debug
```

## Configuration

See `values.yaml` for all configurable parameters. Key parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Kubernetes namespace | `sms-checker` |
| `appService.replicaCount` | Number of app-service replicas | `2` |
| `modelService.replicaCount` | Number of model-service replicas | `2` |
| `modelService.model.version` | Model version | `0.0.1` |
| `storage.hostPath` | VirtualBox shared folder path | `/mnt/shared-models` |
| `ingress.nginx.enabled` | Enable Nginx Ingress | `true` |
| `ingress.nginx.host` | Ingress hostname | `sms-checker.local` |
| `ingress.istio.enabled` | Enable Istio Gateway | `false` |

## Upgrading

```bash
helm upgrade sms-checker ./helm-chart/sms-checker -f custom-values.yaml
```

## Uninstalling

```bash
helm uninstall sms-checker
kubectl delete namespace sms-checker
```

## Storage Configuration

The chart uses a PersistentVolume backed by a VirtualBox shared folder. Ensure the shared folder is configured on all cluster nodes before installing.

See the main README for VirtualBox shared folder setup instructions.
