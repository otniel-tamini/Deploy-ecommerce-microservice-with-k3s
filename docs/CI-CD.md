# CI/CD Pipeline Configuration

## GitHub Actions CI

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

## Jenkins CD (Coming Next)

The CD pipeline will:
- Deploy to K3s cluster
- Update Kubernetes manifests
- Perform health checks
- Rollback on failure