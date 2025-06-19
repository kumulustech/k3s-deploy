# Application Deployment Analysis Prompt for K3s/Helm

Use this prompt template when analyzing an application for deployment on K3s using the provided Helm chart. Copy and customize this prompt with your application details.

## Prompt Template

```
I need to deploy [APPLICATION_NAME] on K3s using a Helm chart. Please analyze the application architecture and recommend the appropriate Kubernetes services and Helm configurations for scalability and resilience.

### Application Details:

**Technology Stack:**
- Runtime: [e.g., Node.js 18, Python 3.11, Java 17]
- Framework: [e.g., Express, Django, Spring Boot]
- Database: [e.g., PostgreSQL, MongoDB, Redis]
- Message Queue: [e.g., RabbitMQ, Kafka, Redis Pub/Sub]
- Storage Requirements: [e.g., file uploads, static assets, logs]

**Application Components:**
1. [Component 1 - e.g., API Server]
   - Purpose: [what it does]
   - Port: [default port]
   - Stateless/Stateful: [choose one]
   - Dependencies: [what it needs]

2. [Component 2 - e.g., Background Worker]
   - Purpose: [what it does]
   - Port: [if applicable]
   - Stateless/Stateful: [choose one]
   - Dependencies: [what it needs]

**External Dependencies:**
- [List any external services, APIs, databases]

**Current Configuration (if migrating):**
- Current deployment method: [e.g., Docker Compose, VM, bare metal]
- Environment variables used: [list key ones, mask secrets]
- Volume mounts: [current persistent data locations]
- Exposed ports: [list all]

**Development & Build Process:**
- Dockerfile location: [path if exists]
- Build command: [e.g., docker build -t myapp:latest .]
- Build arguments: [any ARGs used]
- Multi-stage build: [yes/no, describe stages]
- Base image: [e.g., node:18-alpine, python:3.11-slim]
- Build dependencies: [what's needed at build time vs runtime]
- Local development setup: [e.g., docker-compose.yml file]

**Traffic Patterns:**
- Expected requests per second: [number or range]
- Peak traffic times: [when]
- Geographic distribution: [where users are]
- Session affinity required: [yes/no]

**Data & State Management:**
- Session storage: [where/how]
- File uploads: [size, frequency, storage needs]
- Cache requirements: [what needs caching]
- Database connections: [pooling needs, connection limits]

### Please provide:

1. **Service Architecture Mapping:**
   - Which components should be separate Deployments
   - Service types needed (ClusterIP, NodePort, LoadBalancer)
   - Inter-service communication requirements

2. **Container & Build Configuration:**
   - Optimized Dockerfile (if improvements needed)
   - Build process for K3s deployment
   - Registry configuration (local vs remote)
   - Image tagging strategy
   - CI/CD pipeline recommendations

3. **Helm values.yaml Configuration:**
   - Recommended resource requests/limits
   - Replica counts for each component
   - HPA (Horizontal Pod Autoscaler) settings
   - Persistence configuration
   - Environment variable structure

4. **Resilience Recommendations:**
   - Health check configurations (liveness/readiness probes)
   - Pod disruption budgets
   - Anti-affinity rules
   - Rollout strategies

5. **Scaling Considerations:**
   - Which components can scale horizontally
   - Database connection pooling settings
   - Caching strategy (Redis, in-memory, etc.)
   - CDN/static asset recommendations

6. **Security & Networking:**
   - Ingress/IngressRoute configuration
   - TLS/SSL requirements
   - Network policies needed
   - Secret management approach

7. **Monitoring & Observability:**
   - Key metrics to monitor
   - Log aggregation needs
   - Tracing requirements
   - Prometheus annotations

Please format the response as:
- Dockerfile optimization (if needed)
- Specific values.yaml entries (YAML format)
- Additional Kubernetes resources needed beyond the base Helm chart
- Build and push commands for the container registry
- Step-by-step deployment commands
- Post-deployment validation steps
```

## Example Usage

Here's a filled example for a typical web application:

```
I need to deploy a Django e-commerce application on K3s using a Helm chart. Please analyze the application architecture and recommend the appropriate Kubernetes services and Helm configurations for scalability and resilience.

### Application Details:

**Technology Stack:**
- Runtime: Python 3.11
- Framework: Django 4.2 with Gunicorn
- Database: PostgreSQL 15
- Message Queue: Redis for Celery tasks
- Storage Requirements: Product images, user uploads (up to 100GB)

**Application Components:**
1. Web Server
   - Purpose: Serves Django application via Gunicorn
   - Port: 8000
   - Stateless/Stateful: Stateless
   - Dependencies: PostgreSQL, Redis, S3-compatible storage

2. Celery Worker
   - Purpose: Processes background tasks (emails, image processing)
   - Port: N/A
   - Stateless/Stateful: Stateless
   - Dependencies: PostgreSQL, Redis

3. Celery Beat Scheduler
   - Purpose: Schedules periodic tasks
   - Port: N/A
   - Stateless/Stateful: Stateful (single instance)
   - Dependencies: Redis

**External Dependencies:**
- Stripe API for payments
- SendGrid for emails
- S3 for object storage

**Development & Build Process:**
- Dockerfile location: ./Dockerfile
- Build command: docker build -t ecommerce:latest .
- Build arguments: None
- Multi-stage build: Yes (builder stage for static files)
- Base image: python:3.11-slim
- Build dependencies: Node.js for frontend build, Python packages
- Local development setup: docker-compose.yml with Django, PostgreSQL, Redis

**Traffic Patterns:**
- Expected requests per second: 50-200 RPS
- Peak traffic times: Black Friday, flash sales
- Geographic distribution: Primarily US East/West coast
- Session affinity required: No (using Redis for sessions)

[... continue with the rest of the template ...]
```

## Tips for Better Analysis

1. **Be Specific**: Include actual port numbers, package versions, and configuration details
2. **Mention Constraints**: Include any regulatory requirements (HIPAA, PCI-DSS, etc.)
3. **Current Pain Points**: Describe what problems you're trying to solve
4. **Budget Considerations**: Mention if you need to optimize for cost
5. **Team Expertise**: Note your team's Kubernetes experience level

## Common Patterns to Consider

### Microservices
- Each service gets its own Deployment
- Use Service mesh for complex communication
- Consider API gateway pattern

### Monolithic Applications
- Single Deployment with multiple replicas
- Focus on horizontal scaling
- External caching layer

### Event-Driven Architecture
- Message queue as separate StatefulSet
- Worker pools with different scaling rules
- Dead letter queues for resilience

### Real-time Applications
- WebSocket support in Ingress
- Session affinity configuration
- Consider vertical scaling for connection limits