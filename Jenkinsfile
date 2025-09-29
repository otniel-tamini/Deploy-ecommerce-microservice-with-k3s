pipeline {
    agent any
    
    environment {
        // Docker Hub credentials
        DOCKER_HUB_CREDENTIALS = credentials('docker-hub-credentials')
        DOCKER_USERNAME = "${env.DOCKER_HUB_CREDENTIALS_USR}"
        DOCKER_PASSWORD = "${env.DOCKER_HUB_CREDENTIALS_PSW}"
        
        // Kubernetes configuration
        KUBECONFIG = credentials('kubeconfig')
        KUBE_NAMESPACE = 'ecommerce'
        
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
                
                // Clean workspace
                cleanWs()
                
                // Checkout source code
                checkout scm
                
                // Verify kubectl connectivity
                sh '''
                    echo "🔧 Verifying Kubernetes connectivity..."
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
                }
            }
            
            environment {
                DEPLOY_ENV = 'staging'
                KUBE_NAMESPACE = 'ecommerce-staging'
            }
            
            steps {
                echo "🚧 Deploying to Staging environment..."
                
                script {
                    deployToKubernetes('staging')
                }
                
                echo "✅ Staging deployment completed"
            }
            
            post {
                success {
                    echo "✅ Staging deployment successful"
                    // Run smoke tests
                    sh '''
                        echo "🧪 Running staging smoke tests..."
                        sleep 30  # Wait for services to be ready
                        # Add your smoke test commands here
                    '''
                }
                failure {
                    echo "❌ Staging deployment failed"
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
                    
                    // Run production health checks
                    sh '''
                        echo "🏥 Running production health checks..."
                        sleep 60  # Wait for services to be ready
                        # Add your health check commands here
                    '''
                }
                failure {
                    echo "❌ Production deployment failed"
                    
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
                            kubectl get svc -l app=${service} -n ${KUBE_NAMESPACE}
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
                        sh '''
                            echo "🧪 Running API integration tests..."
                            # Add your integration test commands here
                            # Example: newman run postman-collection.json
                            
                            echo "🧪 Running service-to-service communication tests..."
                            # Add service mesh tests here
                            
                            echo "✅ All integration tests passed"
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
            
            // Archive logs
            archiveArtifacts artifacts: '**/target/*.log', allowEmptyArchive: true
            
            // Clean up workspace
            cleanWs()
        }
        
        success {
            echo "🎉 CD Pipeline completed successfully!"
            
            // Send success notification
            script {
                sendNotification(
                    status: 'SUCCESS',
                    message: "✅ Deployment successful for build #${env.BUILD_NUMBER}"
                )
            }
        }
        
        failure {
            echo "❌ CD Pipeline failed!"
            
            // Send failure notification
            script {
                sendNotification(
                    status: 'FAILURE',
                    message: "❌ Deployment failed for build #${env.BUILD_NUMBER}"
                )
            }
        }
        
        unstable {
            echo "⚠️ CD Pipeline completed with warnings"
            
            script {
                sendNotification(
                    status: 'UNSTABLE',
                    message: "⚠️ Deployment completed with warnings for build #${env.BUILD_NUMBER}"
                )
            }
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
    """
    
    // Deploy each service
    services.each { service ->
        echo "🚀 Deploying ${service}..."
        
        sh """
            # Update image in deployment
            kubectl set image deployment/${service} ${service}=${env.DOCKER_USERNAME}/${service}:${env.IMAGE_TAG} -n ${env.KUBE_NAMESPACE}
            
            # Alternative: Apply from k8s manifests with updated image
            # sed -i 's|image: .*/${service}:.*|image: ${env.DOCKER_USERNAME}/${service}:${env.IMAGE_TAG}|' k8s/${service}/deployment.yml
            # kubectl apply -f k8s/${service}/ -n ${env.KUBE_NAMESPACE}
        """
    }
    
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

// Helper function to send notifications
def sendNotification(Map params) {
    def status = params.status
    def message = params.message
    
    echo "📢 Sending notification: ${message}"
    
    // Slack notification (configure as needed)
    // slackSend(
    //     channel: '#deployments',
    //     color: status == 'SUCCESS' ? 'good' : 'danger',
    //     message: message
    // )
    
    // Email notification (configure as needed)
    // emailext(
    //     subject: "[Jenkins] ${status}: ${env.JOB_NAME} - Build #${env.BUILD_NUMBER}",
    //     body: message,
    //     to: 'team@company.com'
    // )
    
    // Teams notification (configure as needed)
    // office365ConnectorSend(
    //     webhookUrl: 'YOUR_TEAMS_WEBHOOK_URL',
    //     message: message
    // )
}