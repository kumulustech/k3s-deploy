#!/usr/bin/env bash
set -euo pipefail

# Variables
DEFAULT_IP=$(hostname -I | awk '{print $1}')
REGISTRY_PORT=${REGISTRY_PORT:-5000}
REGISTRY_IP=${REGISTRY_IP:-$DEFAULT_IP}
FULL_REGISTRY="${REGISTRY_IP}:${REGISTRY_PORT}"
CERT_MANAGER_VERSION=${CERT_MANAGER_VERSION:-v1.13.3}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-admin@example.com}

# Clean up any existing k3s installation if it exists
if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    echo "▶ Cleaning up existing k3s installation..."
    sudo /usr/local/bin/k3s-uninstall.sh
fi

# 1. Start local registry if not running
echo "▶ Setting up local Docker registry"
docker stop registry || true
docker rm registry || true
docker run -d --restart=always --name registry -p "${REGISTRY_PORT}:${REGISTRY_PORT}" registry:2

# 2. Configure k3s local registry
sudo mkdir -p /etc/rancher/k3s
cat <<EOF | sudo tee /etc/rancher/k3s/registries.yaml
mirrors:
  "${FULL_REGISTRY}":
    endpoint:
      - "http://${FULL_REGISTRY}"
configs:
  "${FULL_REGISTRY}":
    tls:
      insecure_skip_verify: true
EOF

# 3. Install k3s with disabled Traefik
echo "▶ Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik --disable=metrics-server" sh -

# Ensure kubectl
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo chmod 644 "$KUBECONFIG"

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
until kubectl get nodes | grep -q "Ready"; do
    sleep 5
    echo "  ...waiting for node to be ready"
done

# Install Helm if not present
if ! command -v helm >/dev/null; then
    echo "▶ Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
fi

# Clean up any existing Helm repos
helm repo remove traefik || true
helm repo remove jetstack || true

# Install Traefik with CRD support
echo "▶ Installing Traefik"
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Create traefik namespace
kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -

# Install Traefik with custom values
cat <<EOF | helm upgrade --install traefik traefik/traefik \
    --namespace traefik \
    --create-namespace \
    -f -
deployment:
  enabled: true
ingressRoute:
  dashboard:
    enabled: false
additionalArguments:
  - "--providers.kubernetesingress.allowexternalnameservices=true"
  - "--providers.kubernetescrd.allowexternalnameservices=true"
  - "--providers.kubernetescrd.allowCrossNamespace=true"
ports:
  web:
    port: 80
    expose: {}
    exposedPort: 80
    protocol: TCP
  websecure:
    port: 443
    expose: {}
    exposedPort: 443
    protocol: TCP
service:
  enabled: true
  type: LoadBalancer
providers:
  kubernetesCRD:
    enabled: true
  kubernetesIngress:
    enabled: true
EOF

# Wait for Traefik
echo "Waiting for Traefik pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=traefik -n traefik --timeout=120s

echo "▶ Installing cert-manager CRDs"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml

echo "▶ Installing cert-manager"
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version ${CERT_MANAGER_VERSION}

# Wait for cert-manager
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s

# Create ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${LETSENCRYPT_EMAIL}
    privateKeySecretRef:
      name: le-prod-key
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

echo "✅ setup-k3s complete!"

# Display status
echo -e "\nSystem Status:"
echo "----------------"
kubectl get nodes
echo -e "\nTraefik Status:"
echo "---------------"
kubectl get pods -n traefik
echo -e "\nCert-manager Status:"
echo "--------------------"
kubectl get pods -n cert-manager