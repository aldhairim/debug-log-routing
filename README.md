# debug-log-routing

A demo project showcasing cost-efficient debug log routing using Grafana Alloy on Kubernetes. Debug logs are separated from higher-severity logs and shipped to AWS S3, with two different query options.

## Use case

Grafana Cloud bills on log ingestion volume. For teams with high-volume debug logging, this project demonstrates how to route debug logs to S3 for cost-efficient storage while keeping info/warn/error in Grafana Cloud — with two different approaches for querying the archived logs.

## Two approaches

### `athena/` — Raw JSON → S3 → Athena SQL
Alloy writes raw log bodies (Serilog compact JSON) directly to S3 with Hive-compatible partitioning. AWS Athena queries them with SQL via the Grafana Athena data source.

```
App (Serilog)
  ├── debug → Alloy → S3 (raw JSON, partitioned by year/month/day/hour/minute)
  │                        └── AWS Athena → Grafana
  └── info/warn/error → Alloy → Grafana Cloud
```

### `loki-oss/` — Loki OSS → S3 chunks → LogQL
Alloy ships debug logs to a self-hosted Loki OSS instance (deployed in-cluster). Loki stores chunks on S3 and exposes LogQL querying via Grafana using a Private Data Source Connect (PDC) tunnel.

```
App (Serilog)
  ├── debug → Alloy → Loki OSS → S3 (Loki chunks)
  │                      └── Grafana Cloud (via PDC) → LogQL
  └── info/warn/error → Alloy → Grafana Cloud
```

## Stack

- **App:** .NET 8 / ASP.NET Core minimal API, Serilog (compact JSON → stdout)
- **Observability:** Grafana Alloy v1.15.0, k8s-monitoring Helm chart v3.8.6
- **Log destinations:** AWS S3, Grafana Cloud, Loki OSS (Helm chart v6.55.0)
- **Query tools:** AWS Athena + Grafana Athena data source, LogQL via Grafana + PDC
- **Tracing:** OpenTelemetry (OTLP → Alloy → Grafana Cloud)
- **Runtime:** Minikube

## Repo structure

```
├── app/                        # .NET 8 demo app (Serilog, OTel)
├── k8s/                        # Kubernetes manifests
├── athena/                     # Approach 1: debug → S3 raw JSON → Athena
│   ├── k8s-monitoring-values.yaml   # Base Helm values
│   ├── values-debug-s3.yaml         # Overlay: AWS creds, drop debug from Loki
│   ├── s3-pipeline.alloy            # Alloy pipeline: debug → S3
│   ├── patch-s3-pipeline.sh         # Post-upgrade configmap patch
│   ├── patch-alloy-receiver.sh      # Removes duplicate cluster label
│   └── aws-s3-secret.yaml           # Secret template
└── loki-oss/                   # Approach 2: debug → Loki OSS → S3 chunks
    ├── loki-values.yaml             # Loki Helm chart (SingleBinary, S3 backend)
    ├── k8s-monitoring-values.yaml   # Base Helm values
    ├── values-debug-loki.yaml       # Overlay: drop debug from Grafana Cloud
    ├── loki-pipeline.alloy          # Alloy pipeline: debug → Loki OSS
    ├── patch-loki-pipeline.sh       # Post-upgrade configmap patch
    └── patch-alloy-receiver.sh      # Removes duplicate cluster label
```

## Comparison

| | `athena/` | `loki-oss/` |
|---|---|---|
| S3 format | Raw JSON (human-readable) | Loki binary chunks |
| Query language | SQL | LogQL |
| Query tool | AWS Athena + Grafana | Loki OSS + Grafana |
| Infrastructure | S3 only | S3 + Loki pod |
| Grafana access | Direct (public AWS API) | Via PDC tunnel |
| Real-time | No (partition-based) | Yes |
