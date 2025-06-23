#!/usr/bin/env bash
set -euo pipefail

# Variables
DEFAULT_IP=$(hostname -I | awk '{print $1}')
REGISTRY_PORT=${REGISTRY_PORT:-5000}
REGISTRY_IP=${REGISTRY_IP:-$DEFAULT_IP}
FULL_REGISTRY="${REGISTRY_IP}:${REGISTRY_PORT}"

echo "▶ Fixing registry configuration for k3s"
echo "  Registry: ${FULL_REGISTRY}"

# 1. Ensure local registry is running
echo "▶ Checking local Docker registry..."
if ! docker ps | grep -q registry; then
    echo "  Starting registry..."
    docker run -d --restart=always --name registry -p "${REGISTRY_PORT}:${REGISTRY_PORT}" registry:2
else
    echo "  Registry is already running"
fi

# 2. Configure Docker daemon for insecure registry
echo "▶ Configuring Docker for insecure registry..."
sudo mkdir -p /etc/docker
if [ -f /etc/docker/daemon.json ]; then
    # Backup existing daemon.json
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
fi
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "insecure-registries": ["${FULL_REGISTRY}"]
}
EOF
sudo systemctl restart docker

# 3. Configure k3s local registry
echo "▶ Configuring k3s registries..."
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

# 4. Restart k3s to apply configuration
echo "▶ Restarting k3s to apply registry configuration..."
sudo systemctl restart k3s

# Wait for k3s to be ready
echo "▶ Waiting for k3s to be ready..."
sleep 10
until kubectl get nodes | grep -q "Ready"; do
    sleep 5
    echo "  ...waiting for node to be ready"
done

# 5. Test registry connectivity
echo "▶ Testing registry connectivity..."
echo "  Pulling test image..."
docker pull hello-world:latest

echo "  Tagging for local registry..."
docker tag hello-world:latest ${FULL_REGISTRY}/hello-world:test

echo "  Pushing to local registry..."
if docker push ${FULL_REGISTRY}/hello-world:test; then
    echo "✅ Registry push successful!"
    
    # Clean up test image
    docker rmi ${FULL_REGISTRY}/hello-world:test
    
    # List registry contents
    echo ""
    echo "▶ Registry contents:"
    curl -s http://${FULL_REGISTRY}/v2/_catalog | jq '.' 2>/dev/null || echo "  No images in registry yet"
else
    echo "❌ Registry push failed. Please check the configuration."
    exit 1
fi

echo ""
echo "✅ Registry configuration fixed!"
echo ""
echo "You can now use the registry at: ${FULL_REGISTRY}"
echo ""
echo "To push images:"
echo "  docker tag <image>:tag ${FULL_REGISTRY}/<image>:tag"
echo "  docker push ${FULL_REGISTRY}/<image>:tag"