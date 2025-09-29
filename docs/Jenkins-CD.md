# Jenkins CD Pipeline Setup

## Overview

This Jenkins CD pipeline provides automated deployment to Kubernetes clusters with support for staging and production environments. It integrates with the GitHub Actions CI pipeline to create a complete CI/CD workflow.

## Prerequisites

### 1. Jenkins Server Setup

```bash
# Install Jenkins with Docker and Kubernetes support
# Ensure the following plugins are installed:
# - Pipeline
# - Docker Pipeline
# - Kubernetes CLI
# - Credentials Binding
# - Build Trigger Badge
# - Slack Notification (optional)
# - Email Extension (optional)
```

### 2. Required Credentials

Configure the following credentials in Jenkins:

#### Docker Hub Credentials
- **Credential ID**: `docker-hub-credentials`
- **Type**: Username with password
- **Username**: Your Docker Hub username
- **Password**: Your Docker Hub password or access token

#### Kubernetes Configuration
- **Credential ID**: `kubeconfig`
- **Type**: Secret file
- **File**: Your Kubernetes cluster configuration file

### 3. Kubernetes Cluster Access

Ensure Jenkins has access to your Kubernetes cluster:

```bash
# Test connectivity from Jenkins server
kubectl cluster-info
kubectl get nodes
```

## Pipeline Configuration

### 1. Create Jenkins Pipeline Job

1. Open Jenkins Dashboard
2. Click "New Item"
3. Enter job name: `ecommerce-cd-pipeline`
4. Select "Pipeline"
5. Click "OK"

### 2. Configure Pipeline

#### General Settings
- ✅ **GitHub project**: `https://github.com/YOUR_USERNAME/YOUR_REPO`
- ✅ **Discard old builds**: Keep 10 builds

#### Build Triggers
- ✅ **Build after other projects are built**: `GitHub-CI-Pipeline`
- ✅ **Trigger only if build is stable**

#### Pipeline Definition
- **Definition**: Pipeline script from SCM
- **SCM**: Git
- **Repository URL**: `https://github.com/YOUR_USERNAME/YOUR_REPO`
- **Branch**: `*/main` (for production) or `*/develop` (for staging)
- **Script Path**: `Jenkinsfile`

### 3. Environment Configuration

The pipeline uses the following environment variables:

```groovy
environment {
    DOCKER_HUB_CREDENTIALS = credentials('docker-hub-credentials')
    KUBECONFIG = credentials('kubeconfig')
    KUBE_NAMESPACE = 'ecommerce'
    DOCKER_REGISTRY = 'docker.io'
    IMAGE_TAG = "${env.BUILD_NUMBER}"
    SERVICES = 'product-service,order-service,inventory-service,discovery-server,api-gateway,notification-service'
}
```

## Pipeline Stages

### 1. Preparation
- Clean workspace
- Checkout source code
- Verify Kubernetes connectivity

### 2. Pull Latest Images
- Login to Docker Hub
- Pull latest images for all services

### 3. Deploy to Staging (develop/staging branches)
- Deploy to staging namespace
- Run smoke tests
- Verify deployment health

### 4. Deploy to Production (main branch)
- Require manual approval
- Deploy to production namespace
- Run health checks
- Automatic rollback on failure

### 5. Health Check
- Verify all deployments are ready
- Check service status

### 6. Integration Tests
- Run API integration tests
- Test service-to-service communication

## Deployment Strategies

### Rolling Deployment (Default)
```bash
kubectl set image deployment/service-name service-name=image:tag
kubectl rollout status deployment/service-name
```

### Blue-Green Deployment (Advanced)
```bash
# Switch traffic between blue and green deployments
kubectl patch service service-name -p '{"spec":{"selector":{"version":"green"}}}'
```

### Canary Deployment (Advanced)
```bash
# Deploy canary version and gradually shift traffic
kubectl apply -f canary-deployment.yaml
```

## Monitoring and Observability

### Health Checks
The pipeline includes automated health checks:

```bash
# Check pod status
kubectl get pods -l app=service-name

# Check service endpoints
kubectl get endpoints service-name

# Check deployment status
kubectl rollout status deployment/service-name
```

### Logging
```bash
# View deployment logs
kubectl logs -l app=service-name --tail=100

# View Jenkins pipeline logs
# Available in Jenkins build console
```

## Rollback Procedures

### Automatic Rollback
The pipeline automatically rolls back on production deployment failure:

```groovy
post {
    failure {
        script {
            rollbackDeployment()
        }
    }
}
```

### Manual Rollback
```bash
# Rollback to previous version
kubectl rollout undo deployment/service-name

# Rollback to specific revision
kubectl rollout undo deployment/service-name --to-revision=2

# Check rollout history
kubectl rollout history deployment/service-name
```

## Security Considerations

### 1. Credential Management
- Use Jenkins credential store
- Rotate credentials regularly
- Limit credential scope

### 2. Kubernetes RBAC
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: jenkins-deployer
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["services", "pods"]
  verbs: ["get", "list", "watch"]
```

### 3. Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ecommerce-network-policy
spec:
  podSelector:
    matchLabels:
      app: ecommerce
  policyTypes:
  - Ingress
  - Egress
```

## Notifications

### Slack Integration
```groovy
slackSend(
    channel: '#deployments',
    color: 'good',
    message: '✅ Deployment successful'
)
```

### Email Notifications
```groovy
emailext(
    subject: "[Jenkins] Deployment Status",
    body: "Deployment completed successfully",
    to: 'team@company.com'
)
```

### Microsoft Teams
```groovy
office365ConnectorSend(
    webhookUrl: 'YOUR_TEAMS_WEBHOOK_URL',
    message: 'Deployment notification'
)
```

## Troubleshooting

### Common Issues

#### 1. Docker Authentication Failed
```bash
# Check Docker credentials
docker login -u username

# Verify credentials in Jenkins
# Go to Manage Jenkins > Manage Credentials
```

#### 2. Kubernetes Connection Issues
```bash
# Test from Jenkins server
kubectl cluster-info
kubectl auth can-i create deployments --namespace=ecommerce
```

#### 3. Image Pull Errors
```bash
# Check image exists
docker pull username/service-name:tag

# Verify image registry credentials
kubectl get secret regcred -o yaml
```

#### 4. Service Not Ready
```bash
# Check pod status
kubectl describe pod pod-name

# Check service endpoints
kubectl describe service service-name

# Check ingress configuration
kubectl describe ingress ingress-name
```

### Debug Commands

```bash
# View pipeline logs
tail -f /var/log/jenkins/jenkins.log

# Check Kubernetes events
kubectl get events --sort-by='.lastTimestamp'

# Debug failed deployments
kubectl logs deployment/service-name
kubectl describe deployment service-name

# Check resource usage
kubectl top pods
kubectl top nodes
```

## Best Practices

### 1. Pipeline Design
- Keep stages atomic and idempotent
- Use proper error handling
- Implement proper cleanup
- Add comprehensive logging

### 2. Deployment Strategy
- Use rolling deployments for zero-downtime
- Implement proper health checks
- Use resource limits and requests
- Test deployments in staging first

### 3. Security
- Scan images for vulnerabilities
- Use least privilege principle
- Regularly update dependencies
- Monitor security events

### 4. Monitoring
- Set up alerts for failed deployments
- Monitor application metrics
- Track deployment frequency and success rate
- Use distributed tracing

## Integration with CI Pipeline

The CD pipeline integrates with the GitHub Actions CI pipeline:

1. **CI Pipeline** (GitHub Actions):
   - Build and test code
   - Build and push Docker images
   - Run security scans
   - Trigger CD pipeline on success

2. **CD Pipeline** (Jenkins):
   - Pull tested images
   - Deploy to environments
   - Run integration tests
   - Monitor deployments

This separation provides:
- ✅ Fast feedback from CI
- ✅ Controlled deployment process
- ✅ Environment-specific configurations
- ✅ Manual approval gates
- ✅ Automated rollback capabilities

## Maintenance

### Regular Tasks
- Update Jenkins plugins
- Rotate credentials
- Clean up old builds
- Review and update pipeline scripts
- Monitor resource usage
- Update Kubernetes configurations

### Backup Strategy
- Backup Jenkins configuration
- Backup Kubernetes manifests
- Document deployment procedures
- Maintain runbooks for incidents