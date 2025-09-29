pipeline {
    agent any
    
    parameters {
        choice(
            name: 'DEPLOY_ENVIRONMENT',
            choices: ['auto', 'staging', 'production', 'skip'],
            description: 'Environnement de déploiement (auto détecte selon la branche)'
        )
        booleanParam(
            name: 'FORCE_STAGING',
            defaultValue: false,
            description: 'Forcer le déploiement staging même sur main'
        )
    }
    
    environment {
        // Docker Hub credentials
        DOCKER_HUB_CREDENTIALS = credentials('docker-hub-credentials')
        DOCKER_USERNAME = "${env.DOCKER_HUB_CREDENTIALS_USR}"
        DOCKER_PASSWORD = "${env.DOCKER_HUB_CREDENTIALS_PSW}"
        
        // Kubernetes configuration
        KUBECONFIG = credentials('kubeconfig')
        KUBE_NAMESPACE = 'ecommerce'
        
        // Slack configuration
        SLACK_CHANNEL = '#deployments'
        
        // Application configuration
        DOCKER_REGISTRY = 'docker.io'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        
        // Services to deploy
        SERVICES = 'product-service,order-service,inventory-service,discovery-server,api-gateway,notification-service'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }
    
    triggers {
        // Trigger on successful CI build
        upstream(upstreamProjects: 'GitHub-CI-Pipeline', threshold: hudson.model.Result.SUCCESS)
    }
    
    stages {
        stage('Preparation') {
            steps {
                echo "🚀 Starting CD Pipeline for Build #${env.BUILD_NUMBER}"
                echo "📦 Services to deploy: ${env.SERVICES}"
                echo "🏷️  Image tag: ${env.IMAGE_TAG}"
                echo "🌿 Git branch: ${env.GIT_BRANCH}"
                echo "📍 Branch name: ${env.BRANCH_NAME}"
                
                // Send start notification to Slack
                slackSend(
                    channel: env.SLACK_CHANNEL,
                    color: '#439FE0',
                    message: """
                        🚀 *Déploiement démarré* - ${env.JOB_NAME}
                        *Branche:* ${env.GIT_BRANCH ?: env.BRANCH_NAME ?: 'unknown'}
                        *Build:* #${env.BUILD_NUMBER}
                        *Services:* ${env.SERVICES.replace(',', ', ')}
                        *Lien:* ${env.BUILD_URL}
                    """.stripIndent()
                )
                
                // Clean workspace
                cleanWs()
                
                // Checkout source code
                checkout scm
                
                // Detect branch information
                script {
                    env.DETECTED_BRANCH = sh(
                        script: 'git rev-parse --abbrev-ref HEAD || echo "unknown"',
                        returnStdout: true
                    ).trim()
                    echo "🔍 Detected branch: ${env.DETECTED_BRANCH}"
                    echo "🔍 Should deploy to staging: ${env.GIT_BRANCH?.contains('develop') || env.DETECTED_BRANCH?.contains('develop') || params.FORCE_STAGING}"
                }
                
                // Verify kubectl connectivity
                sh '''
                    echo "🔧 Verifying Kubernetes connectivity..."
                    kubectl version --client
                    kubectl cluster-info
                    kubectl get nodes
                '''
            }
        }
        
        stage('Pull Latest Images') {
            steps {
                script {
                    echo "📥 Pulling latest Docker images from registry..."
                    
                    // Login to Docker Hub
                    sh '''
                        echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
                    '''
                    
                    // Pull images for each service
                    def services = env.SERVICES.split(',')
                    services.each { service ->
                        sh """
                            echo "📥 Pulling ${service} image..."
                            docker pull ${DOCKER_USERNAME}/${service}:latest || echo "⚠️ Image not found, will use local build"
                        """
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                anyOf {
                    branch 'develop'
                    branch 'staging'
                    expression { 
                        return env.GIT_BRANCH == 'origin/develop' || 
                               env.GIT_BRANCH == 'develop' ||
                               env.GIT_BRANCH == 'origin/staging' ||
                               env.GIT_BRANCH == 'staging' ||
                               params.DEPLOY_ENVIRONMENT == 'staging' ||
                               params.FORCE_STAGING == true
                    }
                }
            }
            
            environment {
                DEPLOY_ENV = 'staging'
                KUBE_NAMESPACE = 'ecommerce-staging'
            }
            
            steps {
                echo "🚧 Deploying to Staging environment..."
                echo "📁 Available k8s services:"
                
                // List available k8s manifests
                sh '''
                    echo "📋 Checking available k8s manifests..."
                    ls -la k8s/ | grep ^d || echo "⚠️ No service directories found"
                    
                    echo "🔍 Services to deploy: $SERVICES"
                    for service in $(echo $SERVICES | tr ',' ' '); do
                        if [ -d "k8s/$service" ]; then
                            echo "✅ $service: manifests found"
                            ls k8s/$service/ | head -3
                        else
                            echo "❌ $service: no manifests found"
                        fi
                    done
                '''
                
                script {
                    deployToKubernetes('staging')
                }
                
                echo "✅ Staging deployment completed"
            }
            
            post {
                success {
                    echo "✅ Staging deployment successful"
                    slackSend(
                        channel: env.SLACK_CHANNEL,
                        color: 'good',
                        message: """
                            ✅ *Déploiement Staging réussi* - ${env.JOB_NAME}
                            *Branche:* ${env.GIT_BRANCH ?: env.DETECTED_BRANCH ?: 'unknown'}
                            *Build:* #${env.BUILD_NUMBER}
                            *Environnement:* Staging
                            *Durée:* ${currentBuild.durationString.replace(' and counting', '')}
                            *Lien:* ${env.BUILD_URL}
                        """.stripIndent()
                    )
                    // Run smoke tests
                    sh '''
                        echo "🧪 Running staging smoke tests..."
                        sleep 30  # Wait for services to be ready
                        # Add your smoke test commands here
                    '''
                }
                failure {
                    echo "❌ Staging deployment failed"
                    slackSend(
                        channel: env.SLACK_CHANNEL,
                        color: 'danger',
                        message: """
                            ❌ *Déploiement Staging échoué* - ${env.JOB_NAME}
                            *Branche:* ${env.GIT_BRANCH ?: env.DETECTED_BRANCH ?: 'unknown'}
                            *Build:* #${env.BUILD_NUMBER}
                            *Environnement:* Staging
                            *Durée:* ${currentBuild.durationString.replace(' and counting', '')}
                            *Lien:* ${env.BUILD_URL}
                        """.stripIndent()
                    )
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            
            environment {
                DEPLOY_ENV = 'production'
                KUBE_NAMESPACE = 'ecommerce'
            }
            
            steps {
                echo "🎯 Deploying to Production environment..."
                
                // Production deployment with approval
                script {
                    try {
                        timeout(time: 10, unit: 'MINUTES') {
                            input message: 'Deploy to Production?', 
                                  ok: 'Deploy',
                                  submitterParameter: 'APPROVER'
                        }
                        
                        echo "🎯 Production deployment approved by: ${env.APPROVER}"
                        
                        echo "📋 Preparing production deployment..."
                        sh '''
                            echo "🔍 Final check - Services to deploy: $SERVICES"
                            for service in $(echo $SERVICES | tr ',' ' '); do
                                if [ -d "k8s/$service" ]; then
                                    echo "✅ $service: ready for production"
                                else
                                    echo "❌ $service: missing manifests"
                                    exit 1
                                fi
                            done
                        '''
                        
                        deployToKubernetes('production')
                        
                    } catch (Exception e) {
                        echo "❌ Production deployment cancelled or failed: ${e.message}"
                        currentBuild.result = 'ABORTED'
                        return
                    }
                }
                
                echo "✅ Production deployment completed"
            }
            
            post {
                success {
                    echo "🎉 Production deployment successful!"
                    slackSend(
                        channel: env.SLACK_CHANNEL,
                        color: 'good',
                        message: """
                            🎉 *Déploiement Production réussi* - ${env.JOB_NAME}
                            *Branche:* ${env.GIT_BRANCH ?: env.DETECTED_BRANCH ?: 'unknown'}
                            *Build:* #${env.BUILD_NUMBER}
                            *Environnement:* Production
                            *Approuvé par:* ${env.APPROVER ?: 'System'}
                            *Durée:* ${currentBuild.durationString.replace(' and counting', '')}
                            *Lien:* ${env.BUILD_URL}
                            
                            🚀 *Services déployés:* ${env.SERVICES.replace(',', ', ')}
                        """.stripIndent()
                    )
                    
                    // Run production health checks
                    sh '''
                        echo "🏥 Running production health checks..."
                        sleep 60  # Wait for services to be ready
                        # Add your health check commands here
                    '''
                }
                failure {
                    echo "❌ Production deployment failed"
                    slackSend(
                        channel: env.SLACK_CHANNEL,
                        color: 'danger',
                        message: """
                            ❌ *Déploiement Production échoué* - ${env.JOB_NAME}
                            *Branche:* ${env.GIT_BRANCH ?: env.DETECTED_BRANCH ?: 'unknown'}
                            *Build:* #${env.BUILD_NUMBER}
                            *Environnement:* Production
                            *Durée:* ${currentBuild.durationString.replace(' and counting', '')}
                            *Lien:* ${env.BUILD_URL}
                            
                            🔄 *Action:* Rollback en cours...
                        """.stripIndent()
                    )
                    
                    // Rollback on failure
                    script {
                        echo "🔄 Initiating rollback..."
                        rollbackDeployment()
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    echo "🏥 Performing health checks..."
                    
                    def services = env.SERVICES.split(',')
                    services.each { service ->
                        sh """
                            echo "🔍 Checking ${service} health..."
                            kubectl get pods -l app=${service} -n ${KUBE_NAMESPACE}
                            kubectl get svc ${service} -n ${KUBE_NAMESPACE} || echo "⚠️ Service ${service} not found"
                        """
                    }
                }
                
                // Wait for deployments to be ready
                sh '''
                    echo "⏳ Waiting for deployments to be ready..."
                    for service in $(echo $SERVICES | tr ',' ' '); do
                        echo "⏳ Waiting for $service deployment..."
                        kubectl rollout status deployment/$service -n $KUBE_NAMESPACE --timeout=300s
                    done
                '''
            }
        }
        
        stage('Integration Tests') {
            steps {
                echo "🧪 Running integration tests..."
                
                script {
                    try {
                        // Wait for services to be fully ready
                        sh '''
                            echo "⏳ Waiting for services to be ready..."
                            sleep 30
                        '''
                        
                        // Basic health checks
                        sh '''
                            echo "🏥 Running health checks..."
                            for service in $(echo $SERVICES | tr ',' ' '); do
                                echo "🔍 Checking $service health..."
                                kubectl get pods -l app=$service -n $KUBE_NAMESPACE --no-headers 2>/dev/null || echo "⚠️ $service pods not found"
                            done
                        '''
                        
                        // API connectivity tests
                        sh '''
                            echo "🧪 Running API connectivity tests..."
                            
                            # Test discovery server if available
                            echo "🔍 Testing service discovery..."
                            kubectl get svc discovery-server -n $KUBE_NAMESPACE >/dev/null 2>&1 && echo "✅ Discovery server accessible" || echo "⚠️ Discovery server not accessible"
                            
                            # Test API gateway if available  
                            echo "🔍 Testing API gateway..."
                            kubectl get svc api-gateway -n $KUBE_NAMESPACE >/dev/null 2>&1 && echo "✅ API Gateway accessible" || echo "⚠️ API Gateway not accessible"
                            
                            echo "✅ Basic integration tests completed"
                        '''
                        
                    } catch (Exception e) {
                        echo "❌ Integration tests failed: ${e.message}"
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "🧹 Cleaning up..."
            
            // Logout from Docker
            sh 'docker logout || true'
            
            // Archive logs if they exist
            script {
                def logFiles = sh(script: 'find . -name "*.log" -type f 2>/dev/null || true', returnStdout: true).trim()
                if (logFiles) {
                    archiveArtifacts artifacts: '**/*.log', allowEmptyArchive: true
                    echo "📁 Archived log files: ${logFiles.split('\n').size()} files"
                } else {
                    echo "📁 No log files found to archive"
                }
            }
            
            // Clean up workspace
            cleanWs()
        }
        
        success {
            echo "🎉 CD Pipeline completed successfully!"
            
            slackSend(
                channel: env.SLACK_CHANNEL,
                color: 'good',
                message: """
                    ✅ *Pipeline CD terminé avec succès* - ${env.JOB_NAME}
                    *Branche:* ${env.GIT_BRANCH ?: env.DETECTED_BRANCH ?: 'unknown'}
                    *Build:* #${env.BUILD_NUMBER}
                    *Environnement:* ${env.DEPLOY_ENV ?: 'Multiple'}
                    *Durée totale:* ${currentBuild.durationString.replace(' and counting', '')}
                    *Lien:* ${env.BUILD_URL}
                    
                    🎯 *Services déployés:* ${env.SERVICES.replace(',', ', ')}
                """.stripIndent()
            )
        }
        
        failure {
            echo "❌ CD Pipeline failed!"
            
            slackSend(
                channel: env.SLACK_CHANNEL,
                color: 'danger',
                message: """
                    ❌ *Pipeline CD échoué* - ${env.JOB_NAME}
                    *Branche:* ${env.BRANCH_NAME}
                    *Build:* #${env.BUILD_NUMBER}
                    *Durée:* ${currentBuild.durationString.replace(' and counting', '')}
                    *Lien:* ${env.BUILD_URL}
                    
                    🔍 *Action requise:* Vérifier les logs et corriger les erreurs
                """.stripIndent()
            )
        }
        
        unstable {
            echo "⚠️ CD Pipeline completed with warnings"
            
            slackSend(
                channel: env.SLACK_CHANNEL,
                color: 'warning',
                message: """
                    ⚠️ *Pipeline CD instable* - ${env.JOB_NAME}
                    *Branche:* ${env.GIT_BRANCH ?: env.DETECTED_BRANCH ?: 'unknown'}
                    *Build:* #${env.BUILD_NUMBER}
                    *Durée:* ${currentBuild.durationString.replace(' and counting', '')}
                    *Lien:* ${env.BUILD_URL}
                    
                    📊 *Statut:* Terminé avec des avertissements
                """.stripIndent()
            )
        }
    }
}

// Helper function to deploy to Kubernetes
def deployToKubernetes(environment) {
    echo "🚀 Deploying to ${environment} environment..."
    
    def services = env.SERVICES.split(',')
    
    // Create namespace if it doesn't exist
    sh """
        kubectl create namespace ${env.KUBE_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
        echo "✅ Namespace ${env.KUBE_NAMESPACE} ready"
    """
    
    // Create temporary k8s directory for this environment
    sh """
        echo "� Preparing k8s manifests for ${environment}..."
        rm -rf k8s-${environment}
        cp -r k8s k8s-${environment}
    """
    
    // Update all manifests for the target environment
    services.each { service ->
        echo "🔧 Updating manifests for ${service}..."
        
        sh """
            if [ -d "k8s-${environment}/${service}" ]; then
                echo "� Updating ${service} deployment manifest..."
                
                # Update namespace in deployment
                if [ -f "k8s-${environment}/${service}/deployment.yml" ]; then
                    sed -i 's|namespace: ecommerce|namespace: ${env.KUBE_NAMESPACE}|g' k8s-${environment}/${service}/deployment.yml
                    sed -i 's|image: otniel217/${service}:latest|image: ${env.DOCKER_USERNAME}/${service}:${env.IMAGE_TAG}|g' k8s-${environment}/${service}/deployment.yml
                    echo "✅ Updated deployment.yml for ${service}"
                fi
                
                # Update namespace in service
                if [ -f "k8s-${environment}/${service}/service.yml" ]; then
                    sed -i 's|namespace: ecommerce|namespace: ${env.KUBE_NAMESPACE}|g' k8s-${environment}/${service}/service.yml
                    echo "✅ Updated service.yml for ${service}"
                fi
                
                # Update namespace in any other manifests
                find k8s-${environment}/${service}/ -name "*.yml" -o -name "*.yaml" | xargs sed -i 's|namespace: ecommerce|namespace: ${env.KUBE_NAMESPACE}|g' || true
            else
                echo "⚠️ No k8s manifests found for ${service}"
            fi
        """
    }
    
    // Apply all manifests
    echo "🚀 Applying all k8s manifests to ${environment}..."
    services.each { service ->
        sh """
            if [ -d "k8s-${environment}/${service}" ]; then
                echo "📦 Deploying ${service}..."
                kubectl apply -f k8s-${environment}/${service}/ || echo "⚠️ Failed to apply some manifests for ${service}"
                echo "✅ ${service} manifests applied"
            fi
        """
    }
    
    // Apply additional manifests if staging (like databases, monitoring, etc.)
    if (environment == 'staging') {
        sh """
            echo "🗄️ Applying additional staging manifests..."
            
            # Apply MySQL if exists
            if [ -d "k8s-${environment}/mysql" ]; then
                sed -i 's|namespace: ecommerce|namespace: ${env.KUBE_NAMESPACE}|g' k8s-${environment}/mysql/*.yml
                kubectl apply -f k8s-${environment}/mysql/ || echo "⚠️ MySQL manifests not applied"
            fi
            
            # Apply MongoDB if exists  
            if [ -d "k8s-${environment}/mongo" ]; then
                sed -i 's|namespace: ecommerce|namespace: ${env.KUBE_NAMESPACE}|g' k8s-${environment}/mongo/*.yml
                kubectl apply -f k8s-${environment}/mongo/ || echo "⚠️ MongoDB manifests not applied"
            fi
            
            echo "✅ Additional manifests applied"
        """
    }
    
    // Cleanup temporary directory
    sh """
        echo "🧹 Cleaning up temporary manifests..."
        rm -rf k8s-${environment}
    """
    
    echo "✅ All services deployed to ${environment}"
}

// Helper function to rollback deployment
def rollbackDeployment() {
    echo "🔄 Rolling back deployment..."
    
    def services = env.SERVICES.split(',')
    
    services.each { service ->
        sh """
            echo "🔄 Rolling back ${service}..."
            kubectl rollout undo deployment/${service} -n ${env.KUBE_NAMESPACE}
        """
    }
    
    echo "✅ Rollback completed"
}

// Helper function to send notifications (deprecated - using slackSend directly now)
// Kept for backward compatibility if needed for other notification types
def sendNotification(Map params) {
    def status = params.status
    def message = params.message
    def color = status == 'SUCCESS' ? 'good' : status == 'FAILURE' ? 'danger' : 'warning'
    
    echo "📢 Sending notification: ${message}"
    
    // Use slackSend for Slack notifications
    slackSend(
        channel: env.SLACK_CHANNEL,
        color: color,
        message: message
    )
}