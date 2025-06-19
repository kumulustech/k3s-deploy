#!/usr/bin/env bash
set -euo pipefail

# Variables
DEFAULT_IP=$(hostname -I | awk '{print $1}')
REGISTRY_PORT=${REGISTRY_PORT:-5000}
REGISTRY_IP=${REGISTRY_IP:-$DEFAULT_IP}
FULL_REGISTRY="${REGISTRY_IP}:${REGISTRY_PORT}"
CERT_MANAGER_VERSION=${CERT_MANAGER_VERSION:-v1.13.3}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-admin@example.com}
INSTALL_LONGHORN=${INSTALL_LONGHORN:-false}
LONGHORN_VERSION=${LONGHORN_VERSION:-v1.5.3}

# Install prerequisites
echo "▶ Installing prerequisites..."

# Update package list
sudo apt-get update -qq

# Install Docker if not present
if ! command -v docker >/dev/null; then
    echo "  Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    # Start Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
fi

# Install other dependencies
sudo apt-get install -y curl wget git jq

# Install kubectl if not present
if ! command -v kubectl >/dev/null; then
    echo "  Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

# Install Helm if not present
if ! command -v helm >/dev/null; then
    echo "  Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
fi

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

# Configure kubectl for the user
echo "▶ Configuring kubectl for user access..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Also ensure kubectl works for the script
export KUBECONFIG=~/.kube/config

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
until kubectl get nodes | grep -q "Ready"; do
    sleep 5
    echo "  ...waiting for node to be ready"
done

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

# Install Longhorn if requested
if [ "$INSTALL_LONGHORN" = "true" ]; then
    echo "▶ Installing Longhorn distributed storage"
    
    # Install Longhorn prerequisites
    sudo apt-get install -y open-iscsi nfs-common
    sudo systemctl enable iscsid
    sudo systemctl start iscsid
    
    # Create Longhorn namespace
    kubectl create namespace longhorn-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Longhorn
    helm repo add longhorn https://charts.longhorn.io
    helm repo update
    
    cat <<EOF | helm upgrade --install longhorn longhorn/longhorn \
        --namespace longhorn-system \
        --create-namespace \
        --version ${LONGHORN_VERSION} \
        -f -
persistence:
  defaultClass: true
  defaultClassReplicaCount: 2
defaultSettings:
  defaultReplicaCount: 2
  createDefaultDiskLabeledNodes: true
  defaultDataPath: "/var/lib/longhorn"
  replicaSoftAntiAffinity: true
  storageOverProvisioningPercentage: 100
  storageMinimalAvailablePercentage: 10
  upgradeChecker: false
  defaultLonghornStaticStorageClass: longhorn-static
  nodeDownPodDeletionPolicy: delete-both-statefulset-and-deployment-pod
ingress:
  enabled: false
EOF
    
    # Wait for Longhorn to be ready
    echo "Waiting for Longhorn to be ready..."
    kubectl wait --for=condition=ready pod -l app=longhorn-manager -n longhorn-system --timeout=300s
    
    # Make Longhorn the default storage class
    kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' || true
    kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
fi

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

if [ "$INSTALL_LONGHORN" = "true" ]; then
    echo -e "\nLonghorn Status:"
    echo "----------------"
    kubectl get pods -n longhorn-system
    echo -e "\nStorage Classes:"
    echo "----------------"
    kubectl get storageclass
fi