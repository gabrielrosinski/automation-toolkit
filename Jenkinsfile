pipeline {
    agent any

    environment {
        APP_NAME = 'buged-php'
        IMAGE_NAME = 'localhost:5000/buged-php'
        IMAGE_TAG = "${BUILD_NUMBER}"
        K8S_NAMESPACE = 'default'
        GIT_REPO = 'https://github.com/gabrielrosinski/automation-toolkit/tree/main/buged-php'
    }

    stages {
        stage('Checkout') {
            steps {
                echo "Checking out code from ${GIT_REPO}"
                git branch: 'main', url: env.GIT_REPO
            }
        }

        stage('PHP Syntax Check') {
            steps {
                script {
                    echo "Running PHP syntax check..."
                    sh '''
                        ERROR_COUNT=0
                        find . -name "*.php" -not -path "./vendor/*" | while read file; do
                            if ! php -l "$file"; then
                                ERROR_COUNT=$((ERROR_COUNT + 1))
                            fi
                        done

                        if [ $ERROR_COUNT -gt 0 ]; then
                            echo "Found $ERROR_COUNT PHP syntax errors"
                            exit 1
                        fi

                        echo "All PHP files passed syntax check"
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
                    sh """
                        docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Push to Registry') {
            steps {
                script {
                    // For minikube, images are built directly in minikube's Docker
                    // No push needed when using minikube docker-env
                    echo "Image available in minikube Docker: ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    echo "Deploying to Kubernetes namespace: ${K8S_NAMESPACE}"

                    // Check if deployment exists
                    def deploymentExists = sh(
                        script: "kubectl get deployment ${APP_NAME} -n ${K8S_NAMESPACE} 2>/dev/null",
                        returnStatus: true
                    ) == 0

                    if (deploymentExists) {
                        echo "Deployment exists, updating image..."
                        sh """
                            kubectl set image deployment/${APP_NAME} \
                                ${APP_NAME}=${IMAGE_NAME}:${IMAGE_TAG} \
                                -n ${K8S_NAMESPACE}
                        """
                    } else {
                        echo "Deployment does not exist, creating new..."
                        sh """
                            kubectl apply -f k8s/namespace.yaml
                            kubectl apply -f k8s/
                        """
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    echo "Verifying deployment..."
                    sh """
                        kubectl rollout status deployment/${APP_NAME} -n ${K8S_NAMESPACE} --timeout=5m
                        kubectl get pods -n ${K8S_NAMESPACE}
                        kubectl get svc -n ${K8S_NAMESPACE}
                    """

                    // Get service URL
                    def serviceUrl = sh(
                        script: "minikube service ${APP_NAME} --url -n ${K8S_NAMESPACE}",
                        returnStdout: true
                    ).trim()

                    echo "Application deployed successfully!"
                    echo "Access URL: ${serviceUrl}"
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully!"
            echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
            echo "Namespace: ${K8S_NAMESPACE}"
        }
        failure {
            echo "Pipeline failed!"
            echo "Check logs above for details"
        }
        always {
            // Cleanup old Docker images (keep last 5)
            sh '''
                docker images | grep ${IMAGE_NAME} | tail -n +6 | awk '{print $3}' | xargs -r docker rmi || true
            '''
        }
    }
}
