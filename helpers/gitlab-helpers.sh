#!/bin/bash

###############################################################################
# GitLab Helper Commands - Quick Reference
# Common GitLab operations and troubleshooting commands
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Display usage
show_usage() {
    cat <<EOF

=========================================
GitLab Helper Commands
=========================================

USAGE: ./helpers/gitlab-helpers.sh [command]

COMMANDS:
  status      - Check GitLab status and health
  logs        - Show GitLab container logs (tail -100)
  logs-full   - Show full GitLab logs
  logs-live   - Follow GitLab logs in real-time
  restart     - Restart GitLab container
  stop        - Stop GitLab container
  start       - Start GitLab container
  health      - Check GitLab health endpoint
  info        - Display GitLab connection information
  test        - Test GitLab connectivity from Jenkins
  reset-password - Reset root password to 'interview2024'

EXAMPLES:
  ./helpers/gitlab-helpers.sh status
  ./helpers/gitlab-helpers.sh logs
  ./helpers/gitlab-helpers.sh health

=========================================

EOF
}

# Check GitLab container status
check_status() {
    echo ""
    log_info "Checking GitLab container status..."

    if docker ps | grep -q gitlab; then
        log_success "GitLab container is RUNNING"
        echo ""
        docker ps --filter "name=gitlab" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    elif docker ps -a | grep -q gitlab; then
        log_error "GitLab container exists but is NOT running"
        echo ""
        docker ps -a --filter "name=gitlab" --format "table {{.Names}}\t{{.Status}}"
        echo ""
        log_info "Start it with: docker start gitlab"
    else
        log_error "GitLab container not found"
        log_info "Deploy GitLab with: ./1-infra-setup.sh"
    fi
    echo ""
}

# Show GitLab logs
show_logs() {
    local lines="${1:-100}"
    echo ""
    log_info "GitLab container logs (last $lines lines)..."
    echo ""
    docker logs --tail "$lines" gitlab
    echo ""
}

# Show full logs
show_logs_full() {
    echo ""
    log_info "Full GitLab container logs..."
    echo ""
    docker logs gitlab
    echo ""
}

# Follow logs in real-time
follow_logs() {
    echo ""
    log_info "Following GitLab logs (Ctrl+C to stop)..."
    echo ""
    docker logs -f gitlab
}

# Restart GitLab
restart_gitlab() {
    echo ""
    log_info "Restarting GitLab container..."
    docker restart gitlab

    if [ $? -eq 0 ]; then
        log_success "GitLab restarted successfully"
        echo ""
        log_info "Waiting for GitLab to initialize (this may take 3-5 minutes)..."
        sleep 10
        check_health
    else
        log_error "Failed to restart GitLab"
    fi
    echo ""
}

# Stop GitLab
stop_gitlab() {
    echo ""
    log_info "Stopping GitLab container..."
    docker stop gitlab

    if [ $? -eq 0 ]; then
        log_success "GitLab stopped successfully"
    else
        log_error "Failed to stop GitLab"
    fi
    echo ""
}

# Start GitLab
start_gitlab() {
    echo ""
    log_info "Starting GitLab container..."
    docker start gitlab

    if [ $? -eq 0 ]; then
        log_success "GitLab started successfully"
        echo ""
        log_info "Waiting for GitLab to initialize (this may take 3-5 minutes)..."
        sleep 10
        check_health
    else
        log_error "Failed to start GitLab"
    fi
    echo ""
}

# Check GitLab health endpoint
check_health() {
    echo ""
    log_info "Checking GitLab health..."

    # Check from inside container (external endpoint is IP-whitelisted)
    local health_status=$(docker exec gitlab curl -s http://localhost/-/health 2>/dev/null || echo "ERROR")

    if [ "$health_status" = "GitLab OK" ]; then
        log_success "GitLab is HEALTHY"
        echo ""
        echo "Health Status: $health_status"
        echo "Web UI: http://localhost:8090"
        echo "Login: root / root"
    elif [ "$health_status" = "ERROR" ]; then
        log_error "GitLab is NOT responding (container may not be running)"
        log_info "Check status: docker ps | grep gitlab"
    else
        log_warning "GitLab health check returned: $health_status"
        log_info "GitLab may still be initializing. Check logs: docker logs gitlab"
    fi
    echo ""
}

# Display GitLab connection info
show_info() {
    echo ""
    echo "=========================================="
    echo "GitLab Connection Information"
    echo "=========================================="
    echo ""
    echo "Web UI (Browser):"
    echo "  URL:      http://localhost:8090"
    echo "  Username: root"
    echo "  Password: root"
    echo ""
    echo "Git Clone (HTTP):"
    echo "  URL:      http://localhost:8090/root/your-project.git"
    echo "  Username: root"
    echo "  Password: <personal-access-token> (NOT 'root'!)"
    echo ""
    echo "IMPORTANT:"
    echo "  For Git operations, you MUST create and use a Personal Access Token"
    echo "  Create at: http://localhost:8090/-/user_settings/personal_access_tokens"
    echo ""
    echo "Git Clone (SSH):"
    echo "  URL:      ssh://git@localhost:8022/root/your-project.git"
    echo "  Port:     8022 (not default 22)"
    echo ""
    echo "Health Endpoint:"
    echo "  URL:      http://localhost:8090/-/health"
    echo ""
    echo "From Jenkins Container:"
    echo "  URL:      http://gitlab:80 (internal port)"
    echo "  (Uses container name instead of localhost)"
    echo ""
    echo "=========================================="
    echo ""
}

# Test connectivity from Jenkins
test_jenkins_connectivity() {
    echo ""
    log_info "Testing GitLab connectivity from Jenkins container..."

    if ! docker ps | grep -q jenkins; then
        log_error "Jenkins container is not running"
        return 1
    fi

    echo ""
    log_info "1. Testing DNS resolution (gitlab hostname)..."
    if docker exec jenkins ping -c 1 gitlab >/dev/null 2>&1; then
        log_success "Jenkins can resolve 'gitlab' hostname"
    else
        log_error "Jenkins cannot resolve 'gitlab' hostname"
        log_info "Check network: docker network inspect gitlab-jenkins-network"
        return 1
    fi

    echo ""
    log_info "2. Testing HTTP connectivity to GitLab health endpoint..."
    local response=$(docker exec jenkins curl -s -o /dev/null -w "%{http_code}" http://gitlab:80/-/health 2>/dev/null)

    if [ "$response" = "200" ]; then
        log_success "Jenkins can reach GitLab (HTTP 200)"
        docker exec jenkins curl -s http://gitlab:80/-/health
    else
        log_error "Jenkins cannot reach GitLab (HTTP $response)"
        log_info "Troubleshooting steps:"
        echo "  1. Check both containers are on the network:"
        echo "     docker network inspect gitlab-jenkins-network"
        echo "  2. Reconnect if needed:"
        echo "     docker network connect gitlab-jenkins-network gitlab"
        echo "     docker network connect gitlab-jenkins-network jenkins"
        return 1
    fi

    echo ""
    log_success "GitLab connectivity from Jenkins: OK"
    echo ""
}

# Reset root password
reset_password() {
    echo ""
    log_warning "Resetting GitLab root password to 'root'..."
    echo ""

    read -p "This will reset the root password. Continue? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Password reset cancelled"
        return 0
    fi

    echo ""
    log_info "Executing password reset in GitLab container..."

    docker exec gitlab bash -c "gitlab-rails runner \"user = User.find_by_username('root'); user.password = 'root'; user.password_confirmation = 'root'; user.save\""

    if [ $? -eq 0 ]; then
        log_success "Root password reset to 'root'"
    else
        log_error "Password reset failed"
        log_info "You can manually reset by running:"
        echo "  docker exec gitlab bash -c \"gitlab-rails runner \\\"user = User.find_by_username('root'); user.password = 'root'; user.password_confirmation = 'root'; user.save\\\"\""
    fi
    echo ""
}

# Main command dispatcher
case "${1:-}" in
    status)
        check_status
        ;;
    logs)
        show_logs "${2:-100}"
        ;;
    logs-full)
        show_logs_full
        ;;
    logs-live)
        follow_logs
        ;;
    restart)
        restart_gitlab
        ;;
    stop)
        stop_gitlab
        ;;
    start)
        start_gitlab
        ;;
    health)
        check_health
        ;;
    info)
        show_info
        ;;
    test)
        test_jenkins_connectivity
        ;;
    reset-password)
        reset_password
        ;;
    *)
        show_usage
        ;;
esac
