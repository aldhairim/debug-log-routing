# Debug Logs → S3 via Grafana Alloy

Routes logs from Kubernetes pods through two parallel pipelines:
- **info/warn/error** → Grafana Cloud Loki (existing)
- **debug** → AWS S3 (`aldhair-debug-logs`, `us-east-1`)

No new binaries — uses the existing Alloy deployment via k8s-monitoring Helm chart v3.8.6.

---

## Files in this directory

| File | Purpose |
|------|---------|
| `k8s-monitoring-values.yaml` | Base Helm values for the full k8s-monitoring deployment |
| `values-debug-s3.yaml` | Overlay: experimental stability, AWS env vars, drops debug from Grafana Cloud |
| `s3-pipeline.alloy` | Alloy River config for the debug → S3 parallel pipeline |
| `patch-s3-pipeline.sh` | Appends `s3-pipeline.alloy` to the Helm-managed configmap after each upgrade |
| `aws-s3-secret.yaml` | Template for the AWS credentials secret (do not commit real credentials) |

---

## Prerequisites

- Minikube running
- `kubectl` configured for the Minikube context
- `helm` installed
- `aws-vault` configured with a profile (`default`) that has S3 write access
- S3 bucket `aldhair-debug-logs` created in `us-east-1`
- k8s-monitoring Helm repo added:
  ```bash
  helm repo add grafana https://grafana.github.io/helm-charts
  helm repo update
  ```

---

## One-time setup

### 1. Create the monitoring namespace (if it doesn't exist)

```bash
kubectl create namespace monitoring
```

### 2. Create the AWS credentials secret

Get temporary credentials from aws-vault:

```bash
aws-vault exec default -- env | grep AWS
```

Fill in the values and apply:

```bash
aws-vault exec default -- sh -c '
kubectl create secret generic aws-s3-credentials \
  -n monitoring \
  --from-literal=access-key-id=$AWS_ACCESS_KEY_ID \
  --from-literal=secret-access-key=$AWS_SECRET_ACCESS_KEY \
  --from-literal=session-token=$AWS_SESSION_TOKEN
'
```

> **Note:** STS temporary credentials expire. Re-run this command (after deleting the old secret) whenever credentials rotate.

```bash
kubectl delete secret aws-s3-credentials -n monitoring
# then re-run the create command above
```

### 3. Create the Grafana Cloud API key secret

This secret is required by the base k8s-monitoring chart:

```bash
kubectl create secret generic alloy-logs-remote-cfg-grafana-k8s-monitoring \
  -n monitoring \
  --from-literal=password=<YOUR_GRAFANA_CLOUD_API_KEY>
```

---

## Deploy / upgrade

Run these three steps every time you upgrade the chart or rotate credentials.

### Step 1 — Delete the Helm-managed configmap

Avoids field manager conflicts between Helm SSA and kubectl:

```bash
kubectl delete configmap grafana-k8s-monitoring-alloy-logs -n monitoring
```

### Step 2 — Helm upgrade

```bash
cd /Users/aldhair/Grafana/count-down/CountDown/monitoring
helm upgrade --install grafana-k8s-monitoring grafana/k8s-monitoring \
  --version 3.8.6 \
  -n monitoring \
  -f k8s-monitoring-values.yaml \
  -f values-debug-s3.yaml
```

### Step 3 — Patch the configmap with the S3 pipeline

```bash
bash /Users/aldhair/Grafana/count-down/CountDown/monitoring/patch-s3-pipeline.sh
```

This script is idempotent — it skips patching if the S3 pipeline is already present.

### Step 4 — Patch alloy-receiver to remove duplicate cluster label

The k8s-monitoring chart's generated config adds both `cluster` and `k8s.cluster.name` to every OTLP signal, causing x2 duplicates in App O11y. This patch removes the `cluster` alias (Prometheus-style) from the OTLP pipeline, keeping only `k8s.cluster.name` (OTel semantic convention). The `cluster` label for Prometheus dashboards is handled by the alloy-metrics scraping pipeline and is unaffected.

```bash
bash /Users/aldhair/Grafana/count-down/CountDown/monitoring/patch-alloy-receiver.sh
```

This script is idempotent — it skips patching if the alias is already removed.

---

## App setup (countdown-backend)

To emit debug logs from the Node.js backend:

### 1. Make the log level configurable (`backend/src/logger.ts`)

```typescript
level: process.env.LOG_LEVEL || 'info',
```

Also set `level: 'info'` on the OTel transport so debug logs are **not** sent via OTLP (which bypasses the file-based filter and would leak debug into Grafana Cloud):

```typescript
new OpenTelemetryTransportV3({ level: 'info' }),
```

### 2. Add `logger.debug()` calls where useful (`backend/src/index.ts`)

```typescript
logger.debug('request headers', { headers: req.headers });
logger.debug('health check');
logger.debug('releases response', { releases });
```

### 3. Add `LOG_LEVEL` env var to the deployment (`k8s/backend-deployment.yaml`)

```yaml
env:
  - name: LOG_LEVEL
    value: debug
```

### 4. Rebuild and redeploy

```bash
eval $(minikube docker-env)
cd /Users/aldhair/Grafana/count-down/CountDown/backend
docker build -t countdown-backend:latest .
kubectl apply -f ../k8s/backend-deployment.yaml
kubectl rollout restart deployment/countdown-backend -n countdown
```

---

## Start / stop the app

```bash
# Stop
kubectl scale deployment/countdown-backend -n countdown --replicas=0

# Start
kubectl scale deployment/countdown-backend -n countdown --replicas=1
```

---

## Verify

Check S3 for new objects:

```bash
aws-vault exec default -- aws s3 ls s3://aldhair-debug-logs/logs/debug/ --recursive | tail -20
```

Check Alloy is healthy:

```bash
kubectl logs -n monitoring daemonset/grafana-k8s-monitoring-alloy-logs --tail=50
```

Check backend is emitting debug logs:

```bash
kubectl logs -n countdown deployment/countdown-backend --tail=30
```

---

## How it works

```
App (Winston)
  │
  ├─── Console (all levels) ──► stdout ──► /var/log/pods/<pod>/*.log
  │                                               │
  │                               ┌───────────────┴───────────────┐
  │                               │                               │
  │                    [existing pipeline]               [s3 pipeline]
  │                    loki.process                      loki.process
  │                    (drops debug)                     (keeps only debug)
  │                         │                                   │
  │                  Grafana Cloud Loki              otelcol.receiver.loki
  │                                                             │
  │                                                  otelcol.exporter.awss3
  │                                                             │
  │                                               s3://aldhair-debug-logs/
  │
  └─── OpenTelemetryTransportV3 (info+ only) ──► OTLP :4317 ──► Grafana Cloud Loki
```

The OTel transport is capped at `info` level to prevent debug logs leaking to Grafana Cloud via the OTLP path (which has no debug filter). The S3 pipeline is a second `loki.source.file` reading the same log files in parallel. Alloy's `otelcol.exporter.awss3` is an experimental component, which is why `stabilityLevel: "experimental"` is required in the Helm values.
