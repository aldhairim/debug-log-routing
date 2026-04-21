#!/bin/bash
# Patches the alloy-logs configmap to add the debug → Loki OSS pipeline.
# Re-run this after every helm upgrade.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PIPELINE_FILE="$SCRIPT_DIR/loki-pipeline.alloy"

CURRENT=$(kubectl get configmap grafana-k8s-monitoring-alloy-logs -n monitoring -o jsonpath='{.data.config\.alloy}')

if echo "$CURRENT" | grep -q "pods_loki_oss"; then
  echo "Loki OSS pipeline already present, skipping."
  exit 0
fi

kubectl get configmap grafana-k8s-monitoring-alloy-logs -n monitoring -o json | \
  python3 -c "
import json, sys
with open('$PIPELINE_FILE') as f:
    pipeline = f.read()
cm = json.load(sys.stdin)
cm['data']['config.alloy'] += pipeline
cm['metadata'].pop('managedFields', None)
print(json.dumps(cm))
" | kubectl replace -f -

echo "Configmap patched. Restarting alloy-logs pod..."
kubectl rollout restart daemonset/grafana-k8s-monitoring-alloy-logs -n monitoring
echo "Done."
