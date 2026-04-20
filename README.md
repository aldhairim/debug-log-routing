# Alloy to Grafana / S3

A Kubernetes app with a dual log routing pipeline via Grafana Alloy:

- **info/warn/error** → Grafana Cloud Loki
- **debug** → AWS S3

No additional binaries — uses the existing Alloy deployment from the [k8s-monitoring Helm chart](https://github.com/grafana/k8s-monitoring-helm).

## Stack

- **App:** Node.js (Express) backend + React frontend
- **Observability:** Grafana Alloy v1.15.0, k8s-monitoring Helm chart v3.8.6
- **Log destinations:** Grafana Cloud Loki, AWS S3
- **Tracing:** OpenTelemetry (OTLP → Alloy → Grafana Cloud Tempo)
- **Runtime:** Minikube

## Repo structure

```
├── backend/          # Node.js/Express API (TypeScript)
├── frontend/         # React frontend (Vite)
├── k8s/              # Kubernetes manifests for the app
└── monitoring/       # Alloy config, Helm values, S3 pipeline
    ├── SETUP.md              # Full setup guide
    ├── k8s-monitoring-values.yaml   # Base Helm values
    ├── values-debug-s3.yaml         # Overlay: AWS env vars, debug filter
    ├── s3-pipeline.alloy            # Alloy River config for debug → S3
    ├── patch-s3-pipeline.sh         # Post-upgrade configmap patch script
    └── aws-s3-secret.yaml           # Secret template (fill in credentials)
```

## How it works

```
App (Winston logger)
  │
  ├── Console (all levels) → stdout → /var/log/pods
  │                               │
  │              ┌────────────────┴─────────────────┐
  │         file pipeline                      s3 pipeline
  │         (drops debug)                  (keeps only debug)
  │              │                                  │
  │       Grafana Cloud Loki                    AWS S3
  │
  └── OpenTelemetryTransportV3 (info+ only) → OTLP → Grafana Cloud
```

## Setup

See [monitoring/SETUP.md](monitoring/SETUP.md) for the full step-by-step guide.
