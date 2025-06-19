#!/usr/bin/env bash
set -euo pipefail

# Default values
NAMESPACE=${NAMESPACE:-default}
RELEASE_NAME=${RELEASE_NAME:-my-app}
CHART_PATH=${CHART_PATH:-./helm-chart}
VALUES_FILE=${VALUES_FILE:-}

echo "▶ Deploying application to k3s"

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