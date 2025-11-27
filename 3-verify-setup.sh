#!/bin/bash

###############################################################################
# DevOps Interview Toolkit - Setup Verification
# Verifies all components are installed and working correctly
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

PASSED=0
FAILED=0

# Test function
check_test() {
    local name="$1"
    local command="$2"

    echo -n "Testing $name... "
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

echo ""
echo "=========================================="
echo "  Infrastructure Verification"
echo "=========================================="
echo ""
echo "This will test all components installed by 1-infra-setup.sh"
echo ""

# Docker tests
log_info "Docker Tests"
echo "----------------------------------------"
check_test "Docker installed" "command -v docker"
check_test "Docker running" "docker ps"
check_test "Docker pull test" "docker pull hello-world:latest"
check_test "Docker run test" "docker run --rm hello-world"
echo ""

# kubectl tests
log_info "kubectl Tests"
echo "----------------------------------------"
check_test "kubectl installed" "command -v kubectl"
check_test "kubectl version" "kubectl version --client"
if check_test "kubectl cluster connection" "kubectl cluster-info"; then
    check_test "kubectl list nodes" "kubectl get nodes"
else
    log_warning "Cluster not accessible (minikube may not be started)"
fi
echo ""

# minikube tests
log_info "minikube Tests"
echo "----------------------------------------"
check_test "minikube installed" "command -v minikube"
if check_test "minikube status" "minikube status | grep -q 'host: Running'"; then
    check_test "minikube registry addon" "minikube addons list | grep registry | grep -q enabled"
    check_test "minikube ingress addon" "minikube addons list | grep ingress | grep -q enabled"
    check_test "minikube IP accessible" "minikube ip"
else
    log_warning "minikube is not running (run: minikube start)"
fi
echo ""

# Jenkins tests
log_info "Jenkins Tests"
echo "----------------------------------------"
if check_test "Jenkins container exists" "docker ps -a | grep -q jenkins"; then
    check_test "Jenkins container running" "docker ps | grep -q jenkins"
    if check_test "Jenkins UI port 8080" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080 | grep -qE '200|403'"; then
        log_success "Jenkins UI accessible at http://localhost:8080"
    fi
    check_test "Jenkins has Docker CLI" "docker exec jenkins which docker"
    check_test "Jenkins can run Docker" "docker exec jenkins docker ps"
    check_test "Jenkins has kubectl" "docker exec jenkins which kubectl"
    if check_test "Jenkins can access K8s" "docker exec jenkins kubectl get nodes"; then
        log_success "Jenkins can deploy to Kubernetes"
    fi
else
    log_warning "Jenkins container not found (run: ./1-infra-setup.sh)"
fi
echo ""

# PHP tests
log_info "PHP Tests"
echo "----------------------------------------"
check_test "PHP installed" "command -v php"
if check_test "PHP version" "php --version"; then
    PHP_VERSION=$(php --version | head -n1)
    log_info "Installed: $PHP_VERSION"
fi
check_test "PHP syntax check works" "echo '<?php echo \"test\"; ?>' | php -l"
echo ""

# Git tests
log_info "Git Tests"
echo "----------------------------------------"
check_test "Git installed" "command -v git"
if check_test "Git configured (user.name)" "git config --global user.name"; then
    GIT_USER=$(git config --global user.name)
    log_info "Git user: $GIT_USER"
else
    log_warning "Git user not configured (run: git config --global user.name 'Your Name')"
fi
if check_test "Git configured (user.email)" "git config --global user.email"; then
    GIT_EMAIL=$(git config --global user.email)
    log_info "Git email: $GIT_EMAIL"
else
    log_warning "Git email not configured (run: git config --global user.email 'you@example.com')"
fi
echo ""

# Integration test
log_info "Integration Tests"
echo "----------------------------------------"
if docker ps | grep -q jenkins && minikube status | grep -q "host: Running"; then
    check_test "End-to-end: Jenkins → Docker → K8s" "docker exec jenkins sh -c 'docker ps && kubectl get nodes'"
else
    log_warning "Skipping integration test (Jenkins or minikube not running)"
fi
echo ""

# Summary
echo "=========================================="
echo "  VERIFICATION RESULTS"
echo "=========================================="
echo -e "${GREEN}✓ Passed: $PASSED${NC}"
echo -e "${RED}✗ Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}=========================================="
    echo -e "  ✅ ALL SYSTEMS OPERATIONAL!"
    echo -e "==========================================${NC}"
    echo ""
    echo "You're ready for the interview!"
    echo ""
    echo "Next steps:"
    echo "  1. Clone the GitLab repository"
    echo "  2. Run: ./2-generate-project.sh"
    echo "  3. Deploy and test"
    echo ""
    exit 0
else
    echo -e "${RED}=========================================="
    echo -e "  ❌ SOME TESTS FAILED"
    echo -e "==========================================${NC}"
    echo ""
    echo "Please check the failures above and:"
    echo "  1. Review TROUBLESHOOTING.md"
    echo "  2. Re-run: ./1-infra-setup.sh"
    echo "  3. Verify again: ./3-verify-setup.sh"
    echo ""
    exit 1
fi
