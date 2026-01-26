# SMS Spam Detection - Deployment Documentation

This document describes the deployment structure and data flow of the SMS Spam Detection system deployed on Kubernetes. It provides a conceptual overview for new team members to understand the overall design and contribute to design discussions.

**Repository**: [operation](../)

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Deployment Structure](#deployment-structure)
3. [Request Flow](#request-flow)
4. [Traffic Routing (Canary Deployment)](#traffic-routing-canary-deployment)
5. [Access Configuration](#access-configuration)
6. [Component Details](#component-details)
7. [Diagrams](#diagrams)

---

## System Overview

The SMS Spam Detection application is a microservices-based system consisting of:

- **App Service (Frontend)**: Spring Boot application serving the web UI and REST API
- **Model Service (Backend)**: Flask application running the ML classification model (Decision Tree)

The system is deployed on Kubernetes with optional Istio service mesh for advanced traffic management, canary deployments, and observability.

### Architecture Summary

![System Architecture](./diagrams/05-system-architecture.svg)

*Diagram: Complete system architecture showing all components and connections*

---

## Deployment Structure

All resources are deployed in the `sms-spam-detection` namespace with optional Istio sidecar injection.

### Deployed Kubernetes Resources

| Resource Type | Name | Purpose |
|--------------|------|---------|
| **Namespace** | `sms-spam-detection` | Isolates application resources; enables Istio injection |
| **Deployment** | `app-service` | Frontend pods (2 replicas, version: v1) |
| **Deployment** | `app-service-canary` | Canary frontend (1 replica, version: v2) - *optional* |
| **Deployment** | `model-service` | ML backend pods (2 replicas, version: v1) |
| **Deployment** | `model-service-canary` | Canary ML backend (1 replica, version: v2) - *optional* |
| **Deployment** | `model-service-shadow` | Shadow ML backend for traffic mirroring (1 replica, version: v-shadow) - *optional* |
| **Service** | `app-service` | ClusterIP service for frontend (port 8080) |
| **Service** | `model-service` | ClusterIP service for backend (port 8081) |
| **Ingress** | `sms-app-ingress` | Nginx ingress for external HTTP access |
| **ConfigMap** | `app-config` | Environment variables for both services |
| **Secret** | `container-registry-secret` | Docker registry credentials - *optional* |
| **PersistentVolume** | `model-files-pv` | Shared storage for ML model files |
| **PersistentVolumeClaim** | `model-files-pvc` | Claims storage for model-service |

### Istio Resources (when enabled)

| Resource Type | Name | Purpose |
|--------------|------|---------|
| **Gateway** | `sms-gateway` | External entry point for Istio traffic |
| **VirtualService** | `sms-virtualservice` | Traffic routing rules for app-service |
| **VirtualService** | `model-service-vs` | Traffic routing rules for model-service |
| **DestinationRule** | `app-service-dr` | Defines subsets (v1, v2) and traffic policies |
| **DestinationRule** | `model-service-dr` | Defines subsets (v1, v2, v-shadow) |

### Monitoring Resources (when enabled)

| Resource Type | Name | Purpose |
|--------------|------|---------|
| **ServiceMonitor** | `app-service-monitor` | Prometheus scrape config for frontend metrics |
| **ServiceMonitor** | `model-service-monitor` | Prometheus scrape config for backend metrics |
| **PrometheusRule** | `sms-prometheusrules` | Alert rules (e.g., high request rate) |
| **AlertmanagerConfig** | `sms-alertmanager-config` | Email notification routing |

### Deployment Structure Diagram

![Deployment Structure](./diagrams/01-deployment-structure.svg)

*Diagram: All Kubernetes resources deployed in the cluster with their connections*

---

## Request Flow

### Typical Request Path

A request to classify an SMS message follows this path:

![Request Flow](./diagrams/02-request-flow.svg)

*Diagram: Step-by-step flow of an SMS classification request*

### Request Path Details

| Step | Component | Action |
|------|-----------|--------|
| 1 | **User Browser** | Sends HTTP POST to `http://sms.local/predict` with JSON body |
| 2 | **Nginx Ingress** | Applies rate limiting (10 req/min), routes to app-service |
| 3 | **App Service** | Receives request, extracts SMS text from JSON body |
| 4 | **Internal Call** | App-service calls `http://model-service:8081/predict` via K8s DNS |
| 5 | **Model Service** | Loads ML model, preprocesses text, runs classification |
| 6 | **Response** | Returns JSON with classification result (spam/ham) |

### Example Request/Response

**Request:**
```bash
curl -X POST http://sms.local/predict \
  -H "Content-Type: application/json" \
  -d '{"sms": "You won a free iPhone!"}'
```

**Response:**
```json
{
  "classifier": "decision tree",
  "result": "spam",
  "sms": "You won a free iPhone!"
}
```

### With Istio Service Mesh

When Istio is enabled, the request path includes additional routing logic:

1. **Istio Gateway** receives the request at `sms-istio.local`
2. **VirtualService** applies traffic routing rules (90/10 split, cookie-based routing)
3. **Envoy Sidecar** proxies the request with mTLS encryption
4. **DestinationRule** determines which subset (v1/v2) handles the request

---

## Traffic Routing (Canary Deployment)

### Where is the 90/10 Split Configured?

The traffic split is configured in **two places**:

1. **values.yaml** (default weights):
   ```yaml
   # k8s/helm-chart/sms-spam-detector/values.yaml
   # Lines 144-151
   istio:
     traffic:
       app:
         stableWeight: 90    # 90% to stable (v1)
         canaryWeight: 10    # 10% to canary (v2)
   ```

2. **VirtualService template** (routing logic):
   ```yaml
   # templates/istio-gateway.yaml
   # Lines 69-83
   route:
   - destination:
       host: app-service
       subset: v1
     weight: 90
   - destination:
       host: app-service
       subset: v2
     weight: 10
   ```

### Where is the Routing Decision Taken?

The routing decision is made by **Istio's Envoy sidecar proxy** based on:

1. **VirtualService rules** (evaluated in order):
   - Cookie match `experiment=canary` → Route to v2
   - Cookie match `experiment=stable` → Route to v1
   - Default → Weighted split (90/10)

2. **DestinationRule subsets**:
   - Subset `v1`: pods with labels `{app: app-service, version: v1}`
   - Subset `v2`: pods with labels `{app: app-service, version: v2}`

### Traffic Routing Diagram

![Traffic Routing](./diagrams/03-traffic-routing.svg)

*Diagram: 90/10 canary traffic split configuration and routing rules*

### Sticky Sessions

Users can be pinned to a specific version using cookies:

| Cookie | Behavior |
|--------|----------|
| `experiment=canary` | Always routes to v2 (canary) |
| `experiment=stable` | Always routes to v1 (stable) |

The cookie is set via VirtualService response headers and persists for the session.

### Shadow Deployment (Model Mirroring)

For evaluating new model versions without affecting users:

![Model Traffic with Shadow](./diagrams/04-model-traffic-shadow.svg)

*Diagram: Shadow deployment receiving mirrored traffic for model evaluation*

- **Configuration**: `modelService.shadow.enabled: true`
- **Mirror percentage**: Configurable (default 100%)
- **Purpose**: Compare model performance without impacting users

---

## Access Configuration

### Hostnames, Ports, and Paths

| Entry Point | Hostname | IP Address | Port | Path |
|-------------|----------|------------|------|------|
| **Nginx Ingress** | `sms.local` | `192.168.56.95` | 80 | `/` (all paths) |
| **Istio Gateway** | `sms-istio.local` | `192.168.56.96` | 80 | `/` (all paths) |
| **Metrics** | `sms.local` | `192.168.56.95` | 80 | `/metrics` |

### Required Headers

| Header | Value | When Required |
|--------|-------|---------------|
| `Host` | `sms.local` or `sms-istio.local` | Always (for routing) |
| `Content-Type` | `application/json` | POST requests |
| `Cookie` | `experiment=canary` or `experiment=stable` | Sticky sessions |

### Local Access Setup

Add to `/etc/hosts`:
```
192.168.56.95  sms.local
192.168.56.96  sms-istio.local
```

### Example Requests

**Web UI**: `http://sms.local/sms`

**API Request**:
```bash
curl -X POST http://sms.local/predict \
  -H "Content-Type: application/json" \
  -d '{"sms": "Congratulations! You won a prize!"}'
```

**Canary Testing** (with Istio):
```bash
curl -X POST http://sms-istio.local/predict \
  -H "Content-Type: application/json" \
  --cookie "experiment=canary" \
  -d '{"sms": "Test message"}'
```

---

## Component Details

### App Service (Frontend)

| Property | Value |
|----------|-------|
| **Image** | `ghcr.io/doda25-team12/app-service:latest` |
| **Technology** | Spring Boot (Java 25+) |
| **Port** | 8080 |
| **Replicas** | 2 (stable) + 1 (canary) |
| **Environment** | `MODEL_SERVICE_URL=http://model-service:8081` |
| **Health Probes** | Liveness/Readiness: `GET /sms` |
| **Metrics** | `GET /metrics` (Prometheus format) |

### Model Service (Backend)

| Property | Value |
|----------|-------|
| **Image** | `ghcr.io/doda25-team12/model-service:latest` |
| **Technology** | Flask (Python 3.12.9) |
| **Port** | 8081 |
| **Replicas** | 2 (stable) + 1 (canary) + 1 (shadow) |
| **Environment** | `MODEL_VERSION=1.0.2` |
| **ML Model** | Decision Tree Classifier |
| **Volume** | `/models-readonly` (PVC mount) |
| **Health Probes** | Liveness/Readiness: `GET /apidocs` |
| **Metrics** | `GET /metrics` (Prometheus format) |

### ConfigMap (app-config)

Contains environment variables for both services:

| Key | Value | Used By |
|-----|-------|---------|
| `APP_INTERNAL_PORT` | `8080` | app-service |
| `MODEL_INTERNAL_PORT` | `8081` | model-service |
| `MODEL_SERVICE_URL` | `http://model-service:8081` | app-service |
| `MODEL_VERSION` | `1.0.2` | model-service |
| `MODEL_BASE_URL` | GitHub releases URL | model-service |

### Storage

| Resource | Path | Access | Purpose |
|----------|------|--------|---------|
| **PersistentVolume** | `/mnt/shared/models` | ReadOnlyMany | VirtualBox shared folder |
| **PersistentVolumeClaim** | bound to PV | ReadOnlyMany | Mounted by model-service |
| **Model Files** | `model-{version}.joblib` | Read | ML model artifacts |

---

## Diagrams

All diagrams are provided in D2 format and can be rendered to SVG.

### Diagram Files

| Diagram | D2 Source | Description |
|---------|-----------|-------------|
| Deployment Structure | [`diagrams/01-deployment-structure.d2`](./diagrams/01-deployment-structure.d2) | All K8s resources and connections |
| Request Flow | [`diagrams/02-request-flow.d2`](./diagrams/02-request-flow.d2) | Step-by-step request processing |
| Traffic Routing | [`diagrams/03-traffic-routing.d2`](./diagrams/03-traffic-routing.d2) | 90/10 canary split configuration |
| Model Traffic | [`diagrams/04-model-traffic-shadow.d2`](./diagrams/04-model-traffic-shadow.d2) | Shadow deployment and mirroring |
| System Architecture | [`diagrams/05-system-architecture.d2`](./diagrams/05-system-architecture.d2) | Complete end-to-end view |

### Rendering Diagrams

```bash
# Install D2
brew install d2

# Render all diagrams
cd operation/docs/diagrams
for f in *.d2; do d2 "$f" "${f%.d2}.svg"; done

# Or render individually
d2 01-deployment-structure.d2 01-deployment-structure.svg
d2 02-request-flow.d2 02-request-flow.svg
d2 03-traffic-routing.d2 03-traffic-routing.svg
d2 04-model-traffic-shadow.d2 04-model-traffic-shadow.svg
d2 05-system-architecture.d2 05-system-architecture.svg
```

---

## Summary

### Quick Reference

| Question | Answer |
|----------|--------|
| **Access hostname?** | `sms.local` (Nginx) or `sms-istio.local` (Istio) |
| **Access port?** | 80 (HTTP) |
| **API path?** | `/predict` (POST) or `/sms` (Web UI) |
| **90/10 split location?** | `values.yaml` lines 144-151; `istio-gateway.yaml` lines 69-83 |
| **Routing decision?** | Istio Envoy sidecar via VirtualService rules |
| **Additional use case?** | Shadow deployment for model evaluation (`model-service-shadow`) |

### Repository Links

- **Helm Chart**: `k8s/helm-chart/sms-spam-detector/`
- **Values Configuration**: `k8s/helm-chart/sms-spam-detector/values.yaml`
- **Istio Templates**: `k8s/helm-chart/sms-spam-detector/templates/istio-gateway.yaml`
- **Validation Framework**: `k8s/validation/` (see [extension.md](./extension.md))
