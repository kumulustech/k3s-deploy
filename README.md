# K3s Deploy - Generic K3s Deployment with Traefik IngressRoute

A complete solution for deploying applications on K3s with Traefik ingress controller, automatic SSL/TLS certificates via cert-manager, and properly configured IngressRoute CRD support.

## Features

- 🚀 **K3s Installation**: Automated K3s cluster setup with custom configuration
- 🔒 **SSL/TLS Support**: Automatic certificate management with Let's Encrypt
- 🌐 **Traefik IngressRoute**: Native Traefik CRD support for advanced routing
- 📦 **Helm Chart Template**: Generic, customizable Helm chart for applications
- 🔧 **Local Registry**: Built-in Docker registry support for development
- ⚡ **Production Ready**: HPA, persistence, health checks, and more

## Quick Start

### 1. Install K3s with Traefik and cert-manager

```bash
# Set your email for Let's Encrypt (required)
export LETSENCRYPT_EMAIL="your-email@example.com"

# Run the setup script
./scripts/setup-k3s.sh
```

This will:
- Install K3s with Traefik disabled (to install custom configuration)
- Set up a local Docker registry
- Install Traefik with IngressRoute CRD support
- Install cert-manager for automatic SSL certificates
- Create Let's Encrypt ClusterIssuers (staging and production)

### 2. Deploy Your Application

```bash
# Deploy using the included Helm chart
./scripts/deploy-app.sh

# Or deploy with custom values
NAMESPACE=my-app VALUES_FILE=custom-values.yaml ./scripts/deploy-app.sh
```

## Project Structure

```
k3s-deploy/
├── scripts/
│   ├── setup-k3s.sh      # K3s installation and setup
│   └── deploy-app.sh     # Application deployment helper
├── helm-chart/           # Generic Helm chart template
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingressroute.yaml  # Traefik IngressRoute CRD
│       ├── certificate.yaml   # cert-manager certificate
│       └── ...
└── config/
    ├── clusterissuer.yaml         # Production Let's Encrypt
    └── clusterissuer-staging.yaml # Staging Let's Encrypt
```

## Helm Chart Configuration

### Basic Configuration

Edit `helm-chart/values.yaml` to configure your application:

```yaml
image:
  repository: your-app
  tag: "1.0.0"

service:
  port: 80
  targetPort: 8080

ingress:
  enabled: true
  useIngressRoute: true  # Use Traefik IngressRoute CRD
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    enabled: true
    certManager:
      enabled: true
      clusterIssuer: "letsencrypt-prod"
```

### Advanced Features

#### Environment Variables
```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://user:pass@host:5432/db"
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: api-secrets
        key: api-key
```

#### Persistence
```yaml
persistence:
  enabled: true
  storageClass: "local-path"
  size: 10Gi
  mountPath: /data
```

#### Auto-scaling
```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

#### ConfigMaps and Secrets
```yaml
configMaps:
  app-config:
    data:
      config.yaml: |
        server:
          port: 8080
          host: 0.0.0.0

secrets:
  app-secrets:
    data:
      api-key: "your-secret-key"
```

## Using IngressRoute

The Helm chart includes both standard Kubernetes Ingress and Traefik IngressRoute support. By default, IngressRoute is enabled for advanced Traefik features.

### Example IngressRoute Configuration

For more complex routing needs, you can customize the IngressRoute template:

```yaml
# values.yaml
ingress:
  enabled: true
  useIngressRoute: true
  hosts:
    - host: api.example.com
      paths:
        - path: /v1
        - path: /v2
    - host: app.example.com
      paths:
        - path: /
```

This creates routes for multiple hosts and paths using Traefik's native CRD.

## SSL/TLS Certificates

### Automatic Certificates (Recommended)

The setup includes cert-manager with Let's Encrypt integration:

```yaml
ingress:
  tls:
    enabled: true
    certManager:
      enabled: true
      clusterIssuer: "letsencrypt-prod"  # or "letsencrypt-staging" for testing
```

### Manual Certificates

To use existing certificates:

```yaml
ingress:
  tls:
    enabled: true
    certManager:
      enabled: false
    secretName: "my-tls-secret"
```

## Environment Variables

### Setup Script Variables
- `REGISTRY_PORT`: Local registry port (default: 5000)
- `REGISTRY_IP`: Registry IP address (default: auto-detected)
- `CERT_MANAGER_VERSION`: cert-manager version (default: v1.13.3)
- `LETSENCRYPT_EMAIL`: Email for Let's Encrypt (required)

### Deployment Variables
- `NAMESPACE`: Kubernetes namespace (default: default)
- `RELEASE_NAME`: Helm release name (default: my-app)
- `CHART_PATH`: Path to Helm chart (default: ./helm-chart)
- `VALUES_FILE`: Custom values file path (optional)

## Customization

### Adding Custom Resources

Add new templates to `helm-chart/templates/` for additional Kubernetes resources:

1. Create a new template file (e.g., `cronjob.yaml`)
2. Use Helm templating with the provided helpers
3. Add corresponding values to `values.yaml`

### Modifying Traefik Configuration

To customize Traefik, modify the Helm values in `scripts/setup-k3s.sh`:

```bash
# Example: Enable Traefik dashboard
ingressRoute:
  dashboard:
    enabled: true
```

## Troubleshooting

### Check K3s Status
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### Check Traefik
```bash
kubectl get pods -n traefik
kubectl logs -n traefik deployment/traefik
```

### Check Certificates
```bash
kubectl get certificates --all-namespaces
kubectl describe certificate <cert-name>
```

### Debug IngressRoute
```bash
kubectl get ingressroute
kubectl describe ingressroute <name>
```

## Best Practices

1. **Use staging certificates first**: Test with `letsencrypt-staging` before production
2. **Resource limits**: Always set resource requests and limits for production
3. **Health checks**: Configure proper liveness and readiness probes
4. **Secrets management**: Use Kubernetes secrets for sensitive data
5. **Persistence**: Use persistent volumes for stateful data
6. **Monitoring**: Add Prometheus annotations for metrics collection

## Requirements

- Linux system (Ubuntu/Debian recommended)
- Docker installed and running
- curl and basic Unix tools
- Port 80 and 443 available for ingress
- Valid domain name for SSL certificates

## License

MIT License - feel free to use this template for your projects!

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.