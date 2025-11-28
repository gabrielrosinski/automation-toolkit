pipeline {
    agent any

    environment {
        APP_NAME = 'automation-toolkit'
        IMAGE_NAME = 'automation-toolkit'
        IMAGE_TAG = "${BUILD_NUMBER}"
        K8S_NAMESPACE = 'default'
        GIT_REPO = 'https://github.com/gabrielrosinski/automation-toolkit/'
        // Minikube Docker env file path
        MINIKUBE_DOCKER_ENV = '/var/jenkins_home/minikube-docker-env.sh'
    }

    stages {
        stage('Verify Minikube Docker') {
            steps {
                script {
                    echo "Verifying minikube Docker connection..."
                    sh '''#!/bin/bash
                        MINIKUBE_ENV="/var/jenkins_home/minikube-docker-env.sh"
                        if [ ! -f "$MINIKUBE_ENV" ]; then
                            echo "============================================="
                            echo "ERROR: Minikube Docker env file not found!"
                            echo "File: $MINIKUBE_ENV"
                            echo "============================================="
                            echo "This means Jenkins cannot build images in minikube's Docker."
                            echo "Images will be built in host Docker and K8s won't find them."
                            echo ""
                            echo "To fix, run: ./jenkins-init-scripts/deploy-jenkins.sh"
                            echo "============================================="
                            exit 1
                        fi
                        source "$MINIKUBE_ENV"
                        echo "DOCKER_HOST: $DOCKER_HOST"
                        echo "DOCKER_CERT_PATH: $DOCKER_CERT_PATH"

                        # Verify connection to minikube Docker
                        if docker info --format "Connected to Docker daemon: {{.Name}}" 2>/dev/null; then
                            echo "SUCCESS: Jenkins can build images in minikube's Docker"
                        else
                            echo "ERROR: Cannot connect to minikube Docker daemon!"
                            echo "Check if minikube is running: minikube status"
                            exit 1
                        fi
                    '''
                }
            }
        }

        stage('Find PHP App Directory') {
            steps {
                script {
                    // Find directory containing index.php (exclude buged-php, vendor, templates, node_modules)
                    def appDir = sh(
                        script: '''#!/bin/bash
                            INDEX_FILE=$(find . -name "index.php" \
                                -not -path "./buged-php/*" \
                                -not -path "./vendor/*" \
                                -not -path "./templates/*" \
                                -not -path "./node_modules/*" \
                                -type f | head -1)

                            if [ -z "$INDEX_FILE" ]; then
                                echo "."
                            else
                                dirname "$INDEX_FILE"
                            fi
                        ''',
                        returnStdout: true
                    ).trim()

                    env.APP_DIR = appDir
                    echo "PHP app directory: ${env.APP_DIR}"
                }
            }
        }

        stage('PHP Syntax Check') {
            steps {
                script {
                    echo "Running PHP syntax check in ${env.APP_DIR}..."
                    def result = sh(script: """#!/bin/bash
                        set +e
                        ERROR_COUNT=0
                        APP_DIR="${env.APP_DIR}"

                        for file in \$(find "\$APP_DIR" -name "*.php" -not -path "*/vendor/*"); do
                            if ! php -l "\$file" 2>&1; then
                                ERROR_COUNT=\$((ERROR_COUNT + 1))
                            fi
                        done

                        if [ \$ERROR_COUNT -gt 0 ]; then
                            echo "Found \$ERROR_COUNT PHP syntax error(s)"
                            exit 1
                        fi

                        echo "All PHP files passed syntax check"
                    """, returnStatus: true)

                    if (result != 0) {
                        error("PHP syntax check failed")
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image in minikube Docker: ${IMAGE_NAME}:${IMAGE_TAG}"
                    echo "Build context: ${env.APP_DIR}"
                    sh """#!/bin/bash
                        set -e
                        APP_DIR="${env.APP_DIR}"

                        # Source minikube Docker environment (REQUIRED)
                        MINIKUBE_ENV="/var/jenkins_home/minikube-docker-env.sh"
                        if [ -f "\$MINIKUBE_ENV" ]; then
                            source "\$MINIKUBE_ENV"
                            echo "Using minikube Docker daemon: \$DOCKER_HOST"
                        else
                            echo "ERROR: minikube Docker env not found!"
                            echo "Images will be built in wrong Docker - K8s won't find them!"
                            exit 1
                        fi

                        # Remove old :latest tag to prevent stale image issues
                        docker rmi ${IMAGE_NAME}:latest 2>/dev/null || echo "No old :latest tag found"

                        # Build from app directory (where index.php is)
                        echo "Building from: \$APP_DIR"
                        docker build -t ${IMAGE_NAME}:${IMAGE_TAG} "\$APP_DIR"
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest

                        # Verify image exists in minikube's Docker
                        echo "Verifying image in minikube Docker..."
                        docker images | grep "${IMAGE_NAME}" || {
                            echo "ERROR: Image not found after build!"
                            exit 1
                        }
                        echo "Image built successfully in minikube's Docker"
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

                    // Get service URL (NodePort)
                    def nodePort = sh(
                        script: "kubectl get svc ${APP_NAME} -n ${K8S_NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}'",
                        returnStdout: true
                    ).trim()

                    echo "Application deployed successfully!"
                    echo "Access via: minikube service ${APP_NAME} -n ${K8S_NAMESPACE} --url"
                    echo "Or: curl http://\$(minikube ip):${nodePort}"
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
            // Cleanup old Docker images (keep last 5) - must use minikube Docker
            sh '''#!/bin/bash
                if [ -f /var/jenkins_home/minikube-docker-env.sh ]; then
                    source /var/jenkins_home/minikube-docker-env.sh
                fi
                docker images | grep "${IMAGE_NAME}" | tail -n +6 | awk '{print $3}' | xargs -r docker rmi 2>/dev/null || true
            '''
        }
    }
}
