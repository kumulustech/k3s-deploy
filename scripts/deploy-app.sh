#!/usr/bin/env bash
set -euo pipefail

# Default values
NAMESPACE=${NAMESPACE:-default}
RELEASE_NAME=${RELEASE_NAME:-my-app}
CHART_PATH=${CHART_PATH:-./helm-chart}
VALUES_FILE=${VALUES_FILE:-}

# Validate chart path exists
if [ ! -d "$CHART_PATH" ]; then
    echo "❌ Error: Chart path does not exist: $CHART_PATH"
    exit 1
fi

# Validate values file if provided
if [ -n "$VALUES_FILE" ] && [ ! -f "$VALUES_FILE" ]; then
    echo "❌ Error: Values file does not exist: $VALUES_FILE"
    exit 1
fi

# Validate kubectl connectivity
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Error: Cannot connect to Kubernetes cluster"
    echo "  Please ensure kubectl is configured and the cluster is accessible"
    exit 1
fi

echo "▶ Deploying application to k3s"
echo "  Namespace: $NAMESPACE"
echo "  Release: $RELEASE_NAME"
echo "  Chart: $CHART_PATH"
if [ -n "$VALUES_FILE" ]; then
    echo "  Values: $VALUES_FILE"
fi

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Deploy using Helm
if [ -n "$VALUES_FILE" ]; then
    helm upgrade --install $RELEASE_NAME $CHART_PATH \
        --namespace $NAMESPACE \
        --create-namespace \
        -f $VALUES_FILE
else
    helm upgrade --install $RELEASE_NAME $CHART_PATH \
        --namespace $NAMESPACE \
        --create-namespace
fi

echo "✅ Application deployed successfully!"

# Show deployment status
echo -e "\nDeployment Status:"
kubectl get all -n $NAMESPACE