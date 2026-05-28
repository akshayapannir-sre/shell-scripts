#!/bin/bash
# stuck-namespace-cleaner.sh
# Force delete Kubernetes namespaces stuck in Terminating state
#
# Usage: ./stuck-namespace-cleaner.sh <namespace>

set -euo pipefail

NAMESPACE="${1:-}"

if [ -z "$NAMESPACE" ]; then
  echo "Usage: $0 <namespace>"
  echo "Example: $0 my-stuck-namespace"
  exit 1
fi

echo "Checking namespace: $NAMESPACE"

STATE=$(kubectl get namespace "$NAMESPACE" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

if [ "$STATE" != "Terminating" ]; then
  echo "Namespace '$NAMESPACE' is not in Terminating state (current: $STATE)"
  exit 0
fi

echo "Namespace is stuck in Terminating — force removing finalizers..."

# Remove finalizers via API server proxy
kubectl get namespace "$NAMESPACE" -o json \
  | python3 -c "
import sys, json
ns = json.load(sys.stdin)
ns['spec']['finalizers'] = []
print(json.dumps(ns))
" \
  | kubectl replace --raw "/api/v1/namespaces/$NAMESPACE/finalize" -f -

echo "Done. Verifying..."
sleep 2

if kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo "Namespace still exists — may need manual intervention"
else
  echo "Namespace '$NAMESPACE' successfully deleted"
fi
