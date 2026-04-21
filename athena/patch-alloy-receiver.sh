#!/bin/bash
# Removes the duplicate `cluster` attribute from the gc_otlp_endpoint transform
# in the alloy-receiver configmap. Keeps only k8s.cluster.name (OTel semantic
# convention) to prevent App O11y showing x2 for cluster/k8s.cluster.name.
#
# Re-run this after every helm upgrade.
set -e

CM="grafana-k8s-monitoring-alloy-receiver"
NS="monitoring"

CURRENT=$(kubectl get configmap "$CM" -n "$NS" -o jsonpath='{.data.config\.alloy}')

if ! echo "$CURRENT" | grep -q 'set(attributes\["cluster"\], "minikube")'; then
  echo "cluster alias already removed, skipping."
  exit 0
fi

kubectl get configmap "$CM" -n "$NS" -o json | python3 -c "
import json, sys, re

cm = json.load(sys.stdin)
config = cm['data']['config.alloy']

# Remove lines that set the Prometheus-style 'cluster' alias alongside k8s.cluster.name.
# k8s.cluster.name (OTel convention) is kept; cluster= for Prometheus dashboards is
# handled by the alloy-metrics Prometheus scraping pipeline, not this OTLP path.
config = re.sub(r'[ \t]*\x60set\(attributes\[\"cluster\"\], \"minikube\"\)\x60,\n', '', config)

cm['data']['config.alloy'] = config
cm['metadata'].pop('managedFields', None)
print(json.dumps(cm))
" | kubectl replace -f -

echo "Configmap patched. Restarting alloy-receiver daemonset..."
kubectl rollout restart daemonset/grafana-k8s-monitoring-alloy-receiver -n monitoring
kubectl rollout status daemonset/grafana-k8s-monitoring-alloy-receiver -n monitoring
echo "Done."
