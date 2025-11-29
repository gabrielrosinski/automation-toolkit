#!/bin/bash

###############################################################################
# Kubernetes Helper
# Common kubectl commands and troubleshooting
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

cat << 'EOF'

==============================================
  KUBERNETES QUICK REFERENCE
==============================================

CLUSTER INFO
------------
kubectl cluster-info                    # Show cluster info
kubectl get nodes                       # List nodes
kubectl version                         # Show kubectl and cluster version
minikube status                         # Check minikube status
minikube ip                             # Get minikube IP

NAMESPACES
----------
kubectl get namespaces                  # List all namespaces
kubectl create namespace <name>         # Create namespace
kubectl config set-context --current --namespace=<name>  # Set default namespace

PODS
----
kubectl get pods                        # List pods in current namespace
kubectl get pods -A                     # List pods in all namespaces
kubectl get pods -o wide                # Show more details (node, IP)
kubectl describe pod <pod-name>         # Detailed pod info
kubectl logs <pod-name>                 # Show pod logs
kubectl logs <pod-name> -f              # Follow logs (tail -f)
kubectl exec -it <pod-name> -- /bin/bash  # Shell into pod
kubectl delete pod <pod-name>           # Delete pod

DEPLOYMENTS
-----------
kubectl get deployments                 # List deployments
kubectl describe deployment <name>      # Detailed deployment info
kubectl scale deployment <name> --replicas=3  # Scale deployment
kubectl rollout status deployment/<name>  # Check rollout status
kubectl rollout restart deployment/<name>  # Restart deployment
kubectl set image deployment/<name> container=image:tag  # Update image
kubectl delete deployment <name>        # Delete deployment

SERVICES
--------
kubectl get services                    # List services
kubectl get svc                         # Short form
kubectl describe service <name>         # Detailed service info
kubectl delete service <name>           # Delete service
minikube service <name> --url           # Get service URL in minikube

APPLY/CREATE/DELETE RESOURCES
------------------------------
kubectl apply -f <file.yaml>            # Create/update resources
kubectl apply -f k8s/                   # Apply all files in directory
kubectl delete -f <file.yaml>           # Delete resources from file
kubectl create -f <file.yaml>           # Create resources (fails if exists)

TROUBLESHOOTING
---------------
kubectl get events                      # Show cluster events
kubectl get events --sort-by='.lastTimestamp'  # Sort by time
kubectl describe pod <pod-name>         # Check pod events/errors
kubectl logs <pod-name> --previous      # Logs from previous pod instance
kubectl top nodes                       # Node resource usage
kubectl top pods                        # Pod resource usage

DEBUGGING COMMANDS
------------------
# Check why pod is not running
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Check service connectivity
kubectl get svc
kubectl describe svc <service-name>
kubectl get endpoints <service-name>

# Check deployment issues
kubectl get deployments
kubectl describe deployment <name>
kubectl rollout status deployment/<name>

# Port forward for testing
kubectl port-forward pod/<pod-name> 8080:80
kubectl port-forward service/<service-name> 8080:80

MINIKUBE SPECIFIC
-----------------
minikube start                          # Start cluster
minikube stop                           # Stop cluster (preserves data)
minikube delete --all --purge           # Delete cluster (complete removal)
minikube dashboard                      # Open K8s dashboard
minikube service list                   # List all services
minikube service <name> --url           # Get service URL
minikube addons list                    # List available addons
minikube addons enable <addon>          # Enable addon
eval $(minikube docker-env)             # Use minikube's Docker daemon

QUICK DEPLOY WORKFLOW
---------------------
1. Build image (in minikube Docker):
   eval $(minikube docker-env)
   docker build -t myapp:latest .

2. Apply manifests:
   kubectl apply -f k8s/

3. Check deployment:
   kubectl get pods
   kubectl get svc

4. Access service:
   minikube service myapp --url

5. Check logs:
   kubectl logs -l app=myapp -f

COMMON ISSUES & FIXES
---------------------
Issue: ImagePullBackOff
Fix: Image not found. Check:
  - Image name/tag correct?
  - Using minikube Docker daemon? eval $(minikube docker-env)
  - Image exists? docker images

Issue: CrashLoopBackOff
Fix: Container keeps crashing. Check:
  kubectl logs <pod-name>
  kubectl describe pod <pod-name>

Issue: Service not accessible
Fix: Check service type and port:
  kubectl get svc
  minikube service <name> --url
  Check firewall/security groups

Issue: Pending pods
Fix: Not enough resources or scheduling issue:
  kubectl describe pod <pod-name>
  kubectl top nodes
  Check node capacity

Issue: Error from server (NotFound)
Fix: Resource doesn't exist:
  kubectl get all
  Check namespace: kubectl get pods -A

==============================================

EOF

# Interactive helper
echo ""
read -p "Want to run a quick diagnostic? [y/N]: " run_diag
if [[ "$run_diag" =~ ^[Yy]$ ]]; then
    echo ""
    log_info "Running Kubernetes diagnostics..."
    echo ""
    
    echo "========== CLUSTER STATUS =========="
    kubectl cluster-info || log_warning "Cannot connect to cluster"
    echo ""
    
    echo "========== NODES =========="
    kubectl get nodes || log_warning "Cannot get nodes"
    echo ""
    
    echo "========== NAMESPACES =========="
    kubectl get namespaces
    echo ""
    
    echo "========== PODS (All Namespaces) =========="
    kubectl get pods -A
    echo ""
    
    echo "========== SERVICES (All Namespaces) =========="
    kubectl get svc -A
    echo ""
    
    echo "========== DEPLOYMENTS (All Namespaces) =========="
    kubectl get deployments -A
    echo ""
    
    echo "========== RECENT EVENTS =========="
    kubectl get events --sort-by='.lastTimestamp' | tail -20
    echo ""
    
    log_success "Diagnostic complete!"
fi

echo ""
log_info "Reference the commands above for common operations."
echo ""
