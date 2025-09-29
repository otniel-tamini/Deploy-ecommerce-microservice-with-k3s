# Complete CI/CD Pipeline Documentation

## 🎯 Overview

This document provides comprehensive guidance for the CI/CD pipeline implementation for the ecommerce microservices project. The pipeline combines GitHub Actions for Continuous Integration (CI) with Jenkins for Continuous Deployment (CD), providing a robust and scalable deployment workflow.

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Developer     │───▶│  GitHub Actions  │───▶│     Jenkins     │
│   Commits       │    │      (CI)        │    │      (CD)       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │                          │
                              ▼                          ▼
                       ┌──────────────┐           ┌─────────────┐
                       │ Docker Hub   │           │ Kubernetes  │
                       │  Registry    │           │   Cluster   │
                       └──────────────┘           └─────────────┘
```

## 📋 GitHub Actions CI Pipeline

### Required Secrets

Configure these secrets in your GitHub repository settings (`Settings > Secrets and variables > Actions`):

```
DOCKER_USERNAME: your-dockerhub-username (e.g., otniel217)
DOCKER_PASSWORD: your-dockerhub-password-or-token
```

### Pipeline Features

- **Multi-job workflow**: Maven build → Docker build → Security scan → Quality gate
- **Matrix strategy**: Builds all 6 microservices in parallel
- **Caching**: Maven dependencies and Docker layers
- **Multi-arch**: Supports linux/amd64 and linux/arm64
- **Security**: Trivy vulnerability scanning with SARIF upload
- **Artifacts**: JAR files uploaded for 7 days

### Triggers

- **Push** to `main` or `develop` branches
- **Pull Requests** to `main` branch

### Build Process

1. **Maven Build**: Compile, test, package all modules
2. **Docker Build**: Create and push images for each service (only on push)
3. **Security Scan**: Trivy vulnerability assessment
4. **Quality Gate**: Ensures all checks pass

### Docker Images

Images are pushed to Docker Hub with tags:
- `latest` (main branch only)
- `main-<sha>` or `develop-<sha>`
- `pr-<number>` (pull requests)

### Local Testing

Test the pipeline locally:

```bash
# Run Maven build
mvn clean test package

# Build a specific service image
cd product-service
docker build -t otniel217/product-service:test .

# Run security scan
docker run --rm -v $(pwd):/workspace aquasec/trivy:latest fs /workspace
```

## 🚀 Jenkins CD Pipeline

### Features

- **Environment-specific deployments**: Staging and Production
- **Automated health checks**: Liveness and readiness probes
- **Rolling updates**: Zero-downtime deployments
- **Automatic rollback**: On deployment failures
- **Manual approval gates**: For production deployments
- **Integration testing**: Post-deployment validation

### Prerequisites

1. **Jenkins Setup**: Install required plugins (Pipeline, Docker, Kubernetes CLI)
2. **Credentials Configuration**: Docker Hub and Kubernetes access
3. **RBAC Setup**: Apply `k8s/jenkins-rbac.yml`
4. **Environment Setup**: Apply `k8s/staging-config.yml`

### Deployment Environments

#### Staging Environment
- **Namespace**: `ecommerce-staging`
- **Trigger**: Push to `develop` or `staging` branches
- **Features**: Automated deployment, smoke tests, reduced resources

#### Production Environment
- **Namespace**: `ecommerce`
- **Trigger**: Push to `main` branch
- **Features**: Manual approval required, comprehensive health checks, automatic rollback

### Pipeline Stages

1. **Preparation**: Workspace setup, Kubernetes connectivity check
2. **Pull Images**: Latest tested images from Docker Hub
3. **Deploy to Staging**: Automated staging deployment (develop/staging branches)
4. **Deploy to Production**: Manual approval required (main branch only)
5. **Health Check**: Verify all services are healthy
6. **Integration Tests**: API and service-to-service testing

## 🛠️ Configuration Details

### Kubernetes Enhancements

Our Kubernetes deployments include:

- ✅ **Health Probes**: Liveness, readiness, and startup probes
- ✅ **Security**: Non-root containers, read-only filesystems
- ✅ **Resource Management**: Proper CPU/memory limits
- ✅ **Rolling Updates**: Zero-downtime deployment strategy
- ✅ **Monitoring**: Prometheus annotations
- ✅ **Observability**: Distributed tracing labels

### Environment Variables

#### CI Environment (GitHub Actions)
- `DOCKER_USERNAME`: Docker Hub username
- `DOCKER_PASSWORD`: Docker Hub access token

#### CD Environment (Jenkins)
- `DOCKER_HUB_CREDENTIALS`: Jenkins credential ID
- `KUBECONFIG`: Kubernetes configuration file
- `KUBE_NAMESPACE`: Target namespace for deployment

### Service Configuration

| Service | Port | Database | External Dependencies |
|---------|------|----------|----------------------|
| product-service | 8080 | MongoDB | Eureka |
| order-service | 8081 | MySQL | Eureka, Kafka |
| inventory-service | 8082 | MySQL | Eureka |
| discovery-server | 8761 | None | None |
| api-gateway | 8080 | None | Eureka |
| notification-service | 8083 | None | Eureka, Kafka |

## 🔒 Security Features

### CI Security
- **Vulnerability Scanning**: Trivy scans with SARIF reports
- **Secret Management**: GitHub encrypted secrets
- **Multi-arch Builds**: Support for different architectures
- **Dependency Scanning**: Maven dependency check

### CD Security
- **RBAC**: Kubernetes role-based access control
- **Security Contexts**: Non-privileged containers
- **Network Policies**: Controlled inter-service communication
- **Secret Management**: Kubernetes secrets for sensitive data

## 📊 Monitoring and Health Checks

### Health Endpoints
- **Liveness**: `/actuator/health/liveness`
- **Readiness**: `/actuator/health/readiness`
- **Metrics**: `/actuator/prometheus`

### Monitoring Integration
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Jaeger**: Distributed tracing
- **Log Aggregation**: Centralized logging

## 🔧 Troubleshooting

### Common CI Issues

1. **Test Failures**: Check H2 database configuration
2. **Docker Build Failures**: Verify Dockerfile and build context
3. **Security Scan Failures**: Update base images or add exceptions

### Common CD Issues

1. **Kubernetes Connection**: Verify kubeconfig and RBAC
2. **Image Pull Errors**: Check Docker Hub credentials
3. **Deployment Failures**: Review pod logs and events

### Debug Commands

```bash
# CI Debugging
mvn test -pl order-service  # Test specific module
docker build --no-cache .  # Force rebuild

# CD Debugging
kubectl get pods -n ecommerce
kubectl describe deployment service-name
kubectl logs -f deployment/service-name
kubectl rollout status deployment/service-name
```

## 🚀 Quick Start

### 1. Setup GitHub Actions
```bash
# Configure repository secrets
DOCKER_USERNAME: your-username
DOCKER_PASSWORD: your-token
```

### 2. Setup Jenkins
```bash
# Apply RBAC
kubectl apply -f k8s/jenkins-rbac.yml

# Configure staging
kubectl apply -f k8s/staging-config.yml

# Create Jenkins pipeline job pointing to Jenkinsfile
```

### 3. Test Pipeline
```bash
# Trigger CI by pushing to develop
git push origin develop

# Check pipeline status in GitHub Actions and Jenkins
```

## 📈 Success Metrics

- ✅ **All tests passing**: 100% test success rate
- ✅ **Security scans clean**: No critical vulnerabilities
- ✅ **Deployment automation**: Zero-touch staging deployments
- ✅ **Production safety**: Manual approval gates
- ✅ **Rollback capability**: Automatic failure recovery
- ✅ **Health monitoring**: Real-time service health

## 🔮 Future Enhancements

### Planned Improvements
- **GitOps Integration**: ArgoCD for deployment management
- **Progressive Delivery**: Canary and blue-green deployments
- **Chaos Engineering**: Automated resilience testing
- **Multi-cluster Support**: Deploy across multiple regions
- **Advanced Monitoring**: SLI/SLO tracking and alerting

---

*This CI/CD pipeline provides a production-ready foundation for microservices deployment with comprehensive testing, security, and monitoring capabilities.*