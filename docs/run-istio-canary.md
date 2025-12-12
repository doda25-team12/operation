# Run Istio Canary (GHCR-enabled) from Scratch

Use this guide if you can pull `ghcr.io/doda25-team12/*` images. It deploys the Helm chart with Istio canary (90/10) and sticky sessions.

## Prereqs
- Kubernetes cluster reachable with `kubectl`.
- Istio installed (ingressgateway running). Example host/IP: `192.168.56.96 sms-istio.local` (adjust to your cluster).
- helm installed.
- Enough capacity (minikube typically needs `--memory=8192 --cpus=4` or higher for app+model+Prometheus).

## Steps
1) Namespace + sidecar injection
```bash
kubectl create namespace sms-spam-detection --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace sms-spam-detection istio-injection=enabled --overwrite
```

2) GHCR pull secret (for private images)
```bash
kubectl create secret docker-registry container-registry-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GHCR_USERNAME \
  --docker-password=YOUR_GHCR_PAT_with_read:packages \
  --docker-email=you@example.com \
  -n sms-spam-detection
```
If images are public, skip the secret and set `imagePullSecrets.enabled=false` in Helm.

3) Helm deploy with canary + sticky (90/10)
```bash
cd ./operation/k8s/helm-chart/sms-spam-detector
helm dependency update
helm upgrade --install sms-detector . \
  --namespace sms-spam-detection \
  --set imagePullSecrets.enabled=true \
  --set appService.canary.enabled=true \
  --set modelService.canary.enabled=true \
  --set istio.traffic.app.stableWeight=90 \
  --set istio.traffic.app.canaryWeight=10 \
  --set istio.traffic.sticky.enabled=true
```

4) Verify pods
```bash
kubectl get pods -n sms-spam-detection
```
All app/model pods should be Running; Prometheus should schedule if the node has enough resources.

5) Test routing
- Weighted 90/10 (no cookie):
```bash
for i in {1..20}; do
  curl -s -H "Host: sms-istio.local" http://192.168.56.96/ | grep -i version
done
```
- Sticky sessions:
```bash
# Canary only
curl -s -H "Host: sms-istio.local" --cookie "experiment=canary" http://192.168.56.96/ | grep -i version
# Stable only
curl -s -H "Host: sms-istio.local" --cookie "experiment=stable" http://192.168.56.96/ | grep -i version
```

6) Teardown
```bash
helm uninstall sms-detector -n sms-spam-detection
```

## Notes
- Ensure `/etc/hosts` matches your Istio ingress IP/host.
- If pulls still fail, re-create the secret with a PAT that has `read:packages`.
- If scheduling is Pending, increase cluster resources or lower requests in `values.yaml`.


