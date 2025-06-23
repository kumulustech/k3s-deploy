# K3s Deploy - Production-Ready K3s Deployment Framework

A comprehensive, reusable deployment framework for K3s (lightweight Kubernetes) with Traefik ingress controller, automatic SSL/TLS certificates via cert-manager, and a flexible Helm chart template supporting multiple workload types.

## 🎯 Features

- **K3s Installation**: Automated K3s cluster setup with prerequisites
- **SSL/TLS Support**: Automatic certificate management with Let's Encrypt
- **Traefik IngressRoute**: Native Traefik CRD support for advanced routing
- **Flexible Workloads**: Support for Deployments, StatefulSets, and CronJobs
- **Local Registry**: Built-in Docker registry support for development
- **Production Storage**: Optional Longhorn distributed storage for replicated volumes
- **RBAC Support**: Role-based access control templates
- **Best Practices**: Health checks, resource limits, security contexts, and more

## 📋 Requirements

- Linux system (Ubuntu/Debian recommended)
- Internet connection for downloading components
- Ports 80 and 443 available for ingress
- Valid domain name for SSL certificates (production)
- For Longhorn: At least 10GB free disk space per node

## 🚀 Quick Start

### 1. Install K3s with Traefik and cert-manager

```bash
# Clone the repository
git clone https://github.com/yourusername/k3s-deploy.git
cd k3s-deploy

# Set your email for Let's Encrypt (required)
export LETSENCRYPT_EMAIL="your-email@example.com"

# For development (using local-path storage)
./scripts/setup-k3s.sh

# For production (with Longhorn distributed storage)
export INSTALL_LONGHORN=true
./scripts/setup-k3s.sh
```

The setup script will:
- Install prerequisites (Docker, kubectl, helm, curl, wget, git, jq)
- Install K3s with custom configuration
- Configure kubectl for user access
- Set up a local Docker registry (port 5000)
- Install Traefik with IngressRoute CRD support
- Install cert-manager for automatic SSL certificates
- Create Let's Encrypt ClusterIssuers
- (Optional) Install Longhorn distributed storage

### 2. Deploy Your Application

```bash
# Deploy with default values
./scripts/deploy-app.sh

# Deploy with custom configuration
NAMESPACE=my-app VALUES_FILE=examples/production-app-values.yaml ./scripts/deploy-app.sh

# Deploy with custom release name
RELEASE_NAME=api-service NAMESPACE=backend ./scripts/deploy-app.sh
```

## 📁 Project Structure

```
k3s-deploy/
├── scripts/
│   ├── setup-k3s.sh        # K3s installation and setup
│   ├── deploy-app.sh       # Application deployment helper
│   └── fix-registry.sh     # Registry troubleshooting script
├── helm-chart/             # Generic Helm chart template
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── statefulset.yaml    # For stateful workloads
│       ├── cronjob.yaml        # For scheduled tasks
│       ├── service.yaml
│       ├── ingressroute.yaml   # Traefik IngressRoute CRD
│       ├── certificate.yaml    # cert-manager certificate
│       ├── role.yaml           # RBAC role
│       ├── rolebinding.yaml    # RBAC role binding
│       └── ...
├── config/
│   ├── clusterissuer.yaml         # Production Let's Encrypt
│   └── clusterissuer-staging.yaml # Staging Let's Encrypt
└── examples/               # Example values files
    ├── simple-app-values.yaml
    ├── production-app-values.yaml
    ├── development-app-values.yaml
    └── microservice-values.yaml
```

## 🔧 Configuration

### Basic Application Configuration

```yaml
# helm-chart/values.yaml
image:
  repository: nginx
  tag: "1.25-alpine"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 80

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

### Workload Types

#### Standard Deployment (Default)
```yaml
replicaCount: 3
```

#### StatefulSet (For Databases, etc.)
```yaml
statefulset:
  enabled: true
  replicaCount: 3
  persistence:
    enabled: true
    storageClass: "longhorn"
    size: 10Gi
    mountPath: /data
```

#### CronJob (For Scheduled Tasks)
```yaml
cronjob:
  enabled: true
  schedule: "0 2 * * *"  # Daily at 2 AM
  concurrencyPolicy: Forbid
  command: ["/bin/sh"]
  args: ["-c", "echo 'Running backup job'"]
```

### Advanced Features

#### RBAC Configuration
```yaml
serviceAccount:
  create: true
  name: "my-app"

rbac:
  create: true
  rules:
    - apiGroups: [""]
      resources: ["pods", "services"]
      verbs: ["get", "list", "watch"]
```

#### Environment Variables
```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: url
  - name: LOG_LEVEL
    value: "info"
```

#### Persistence
```yaml
persistence:
  enabled: true
  storageClass: "local-path"  # or "longhorn" for production
  size: 10Gi
  mountPath: /data
```

#### Auto-scaling
```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

#### Health Checks
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
```

## 📚 Examples

See the `examples/` directory for complete configuration examples:

- **simple-app-values.yaml**: Basic web application
- **production-app-values.yaml**: Production setup with all features
- **development-app-values.yaml**: Development configuration with hot reload
- **microservice-values.yaml**: Microservice in a service mesh

## 🔐 SSL/TLS Certificates

### Automatic Certificates (Recommended)

```yaml
ingress:
  tls:
    enabled: true
    certManager:
      enabled: true
      clusterIssuer: "letsencrypt-staging"  # Use for testing
      # clusterIssuer: "letsencrypt-prod"   # Use for production
```

### Manual Certificates

```yaml
ingress:
  tls:
    enabled: true
    certManager:
      enabled: false
    secretName: "my-tls-secret"
```

## 🐳 Local Docker Registry

The setup includes a local Docker registry for development:

```bash
# Tag and push images
docker tag myapp:latest localhost:5000/myapp:latest
docker push localhost:5000/myapp:latest

# Use in deployments
image:
  repository: localhost:5000/myapp
  tag: latest
```

If you encounter registry issues:
```bash
./scripts/fix-registry.sh
```

## 🛠️ Troubleshooting

### Check Component Status

```bash
# K3s cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Traefik
kubectl get pods -n traefik
kubectl logs -n traefik deployment/traefik

# Certificates
kubectl get certificates --all-namespaces
kubectl describe certificate <cert-name> -n <namespace>

# IngressRoutes
kubectl get ingressroute --all-namespaces
kubectl describe ingressroute <name> -n <namespace>

# Longhorn (if installed)
kubectl get pods -n longhorn-system
kubectl get storageclass
```

### Common Issues

1. **Certificate not issuing**: Check domain DNS and Let's Encrypt rate limits
2. **Ingress not working**: Verify Traefik pod is running and check logs
3. **Storage issues**: Ensure Longhorn pods are healthy if using Longhorn
4. **Registry push fails**: Run `./scripts/fix-registry.sh`

## 🌟 Best Practices

1. **Start with staging certificates**: Test with `letsencrypt-staging` first
2. **Set resource limits**: Always define requests and limits for production
3. **Use health checks**: Configure proper liveness and readiness probes
4. **Secure secrets**: Use Kubernetes secrets or external secret managers
5. **Enable RBAC**: Use least privilege principle for service accounts
6. **Monitor resources**: Add Prometheus annotations for metrics
7. **Use namespaces**: Isolate applications in separate namespaces
8. **Regular backups**: Implement backup strategy for persistent data

## 🔄 Updating Components

```bash
# Update cert-manager
export CERT_MANAGER_VERSION=v1.14.0
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version ${CERT_MANAGER_VERSION}

# Update Traefik
helm upgrade traefik traefik/traefik \
  --namespace traefik \
  --reuse-values
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- K3s by Rancher Labs
- Traefik by Traefik Labs
- cert-manager by Jetstack
- Longhorn by Rancher Labs