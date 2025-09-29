# Kubernetes Deployment Strategy for CI/CD

This directory contains enhanced Kubernetes manifests optimized for CI/CD pipeline integration.

## Features

- ✅ Health checks and readiness probes
- ✅ Resource limits and requests
- ✅ Rolling update strategy
- ✅ Environment-specific configurations
- ✅ Service mesh ready
- ✅ Monitoring labels
- ✅ Security contexts

## Deployment Environments

### 1. Staging Environment
- Namespace: `ecommerce-staging`
- Replicas: 1 per service
- Resource limits: Reduced
- External services: Mock/staging versions

### 2. Production Environment
- Namespace: `ecommerce`
- Replicas: 2+ per service
- Resource limits: Production-ready
- External services: Production versions

## Usage with Jenkins CD

The Jenkins pipeline automatically:

1. Updates image tags using `kubectl set image`
2. Applies configurations using `kubectl apply -f`
3. Monitors rollout status
4. Performs health checks
5. Rolls back on failure

## Monitoring Integration

All deployments include labels for:
- Prometheus monitoring
- Grafana dashboards
- Jaeger tracing
- Log aggregation

## Security Features

- Non-root containers
- Read-only file systems
- Security contexts
- Network policies
- RBAC configurations