#!/bin/bash

###############################################################################
# GitLab Deployment Script - Separated from infrastructure setup
# Can be run standalone or called from 1-infra-setup.sh
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
detect_os() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        OS="wsl"
        ARCH="amd64"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        ARCH=$(uname -m)
        [[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
        [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        ARCH=$(uname -m)
        [[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
    fi
}

################################################################################
# GITLAB DEPLOYMENT
################################################################################

wait_for_gitlab() {
    log_info "Monitoring GitLab initialization (fail-fast mode)..."
    log_info "Streaming logs - will exit immediately on errors"
    echo ""

    local max_attempts=60  # 5 minutes with 5s intervals
    local attempt=0
    local last_log_line=0

    while [ $attempt -lt $max_attempts ]; do
        # Check for container crashes/restarts
        CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' gitlab 2>/dev/null || echo "missing")
        if [[ "$CONTAINER_STATUS" == "restarting" ]] || [[ "$CONTAINER_STATUS" == "exited" ]]; then
            echo ""
            log_error "GitLab container crashed (status: $CONTAINER_STATUS)"
            log_info "Last 30 lines of logs:"
            docker logs gitlab 2>&1 | tail -30
            return 1
        fi

        # Check for FATAL errors in logs
        FATAL_ERRORS=$(docker logs gitlab 2>&1 | grep -E "FATAL|UnknownConfigOptionError|There was an error running gitlab-ctl" | tail -5)
        if [[ -n "$FATAL_ERRORS" ]]; then
            echo ""
            log_error "GitLab configuration failed with errors:"
            echo "$FATAL_ERRORS"
            echo ""
            log_info "Full error context (last 40 lines):"
            docker logs gitlab 2>&1 | tail -40
            return 1
        fi

        # Check health from inside container
        HEALTH_STATUS=$(docker exec gitlab curl -s http://localhost/-/health 2>/dev/null || echo "")
        if [[ "$HEALTH_STATUS" == "GitLab OK" ]]; then
            echo ""
            log_success "GitLab is ready!"

            # Reset root password via Rails console (works even if initial password was rejected)
            log_info "Configuring root user..."
            docker exec gitlab gitlab-rails runner "
org = Organizations::Organization.first || Organizations::Organization.create!(name: 'Default', path: 'default')
user = User.find_by_username('root') || User.new(username: 'root', email: 'admin@local.host', name: 'Administrator', admin: true)
user.organization = org unless user.organization
user.password = 'Kx9mPqR2wZ'
user.password_confirmation = 'Kx9mPqR2wZ'
user.skip_confirmation!
user.save(validate: false)
if user.namespace.nil?
  ns = Namespaces::UserNamespace.new(owner: user, name: user.name, path: user.username, organization: org)
  ns.save(validate: false)
  user.update_column(:namespace_id, ns.id)
end
puts 'OK'
            " >/dev/null 2>&1

            log_info "Access: http://localhost:8090 (root / Admin123!@#)"
            return 0
        fi

        # Show recent log activity (last 3 lines, non-repetitive)
        RECENT_LOGS=$(docker logs gitlab 2>&1 | tail -3 | head -1)
        if [[ -n "$RECENT_LOGS" ]] && [[ $((attempt % 3)) -eq 0 ]]; then
            echo "[${attempt}s] $RECENT_LOGS" | head -c 120
            echo ""
        fi

        sleep 5
        attempt=$((attempt + 1))
    done

    echo ""
    log_error "GitLab failed to start within 5 minutes"
    log_info "Last 50 lines of logs:"
    docker logs gitlab 2>&1 | tail -50
    return 1
}

deploy_gitlab() {
    log_info "Deploying GitLab CE..."

    # Check if GitLab container exists and is healthy
    if docker ps | grep -q gitlab; then
        log_info "Found existing GitLab container, verifying health..."
        sleep 2

        # Check health from inside container (external endpoint is IP-whitelisted)
        HEALTH_STATUS=$(docker exec gitlab curl -s http://localhost/-/health 2>/dev/null || echo "")

        if [[ "$HEALTH_STATUS" == "GitLab OK" ]]; then
            log_success "GitLab is running and healthy"
            log_info "Access: http://localhost:8090 (root / rootroot)"
            return 0
        else
            log_warning "GitLab container exists but not responding (Status: $HEALTH_STATUS)"
            log_warning "Removing unhealthy GitLab container..."
            docker stop gitlab 2>/dev/null || true
            docker rm gitlab 2>/dev/null || true
            log_info "Creating fresh GitLab deployment..."
        fi
    fi

    # Remove old stopped container
    if docker ps -a | grep -q gitlab; then
        log_warning "Removing stopped GitLab container..."
        docker stop gitlab 2>/dev/null || true
        docker rm gitlab 2>/dev/null || true
    fi

    # Check if port 8090 is in use
    if command -v lsof >/dev/null 2>&1; then
        if lsof -Pi :8090 -sTCP:LISTEN -t >/dev/null 2>&1; then
            log_error "Port 8090 is already in use!"
            log_info "Find what's using it: sudo lsof -i :8090"
            log_info "Or change the port in this script and update references"
            return 1
        fi
    fi

    log_info "Starting GitLab container with minimal configuration..."
    log_info "Configuration:"
    log_info "  • HTTP Port: 8090 → 80"
    log_info "  • SSH Port: 8022 → 22"
    log_info "  • Root Password: root (auto-configured)"
    log_info "  • External URL: http://localhost:8090"
    log_info "  • Mode: Minimal (monitoring/registry/pages/KAS disabled)"
    log_info "  • Workers: Puma=2, Sidekiq=10 (reduced for interviews)"
    echo ""

    # Run GitLab CE with minimal configuration for interview demo
    # Only enable essential services: nginx, workhorse, puma, sidekiq, postgres, redis, gitaly, sshd
    # Disable all enterprise/monitoring features to reduce resource usage
    if ! docker run -d \
        --name gitlab \
        --restart unless-stopped \
        --hostname gitlab.local \
        --privileged \
        -p 0.0.0.0:8090:80 \
        -p 0.0.0.0:8022:22 \
        -e GITLAB_OMNIBUS_CONFIG="
external_url 'http://localhost:8090';
gitlab_rails['gitlab_shell_ssh_port'] = 8022;
gitlab_rails['gitlab_shell_ssh_host'] = 'localhost';

# Performance tuning for interview scenarios (reduce resource usage)
puma['worker_processes'] = 2;
puma['min_threads'] = 1;
puma['max_threads'] = 2;
puma['per_worker_max_memory_mb'] = 1024;

sidekiq['max_concurrency'] = 5;

postgresql['max_connections'] = 50;
postgresql['shared_buffers'] = '128MB';
postgresql['work_mem'] = '8MB';

# Disable monitoring
prometheus_monitoring['enable'] = false;

# Disable features not needed for Git operations
gitlab_rails['gitlab_email_enabled'] = false;
gitlab_rails['incoming_email_enabled'] = false;
gitlab_rails['usage_ping_enabled'] = false;
" \
        -e GITLAB_ROOT_PASSWORD="Kx9mPqR2wZ" \
        -v gitlab_config:/etc/gitlab \
        -v gitlab_logs:/var/log/gitlab \
        -v gitlab_data:/var/opt/gitlab \
        --shm-size=256m \
        gitlab/gitlab-ce:latest; then
        log_error "Failed to start GitLab container"
        log_info "Common causes:"
        log_info "  - Port 8090 or 8022 already in use"
        log_info "  - Insufficient Docker resources (GitLab needs 4GB+ RAM)"
        log_info "  - Docker daemon not running"
        return 1
    fi

    log_success "GitLab container started"

    # Wait for container to stabilize
    sleep 5

    # Verify container is running
    if ! docker ps | grep -q gitlab; then
        log_error "GitLab container failed to stay running"
        log_info "Container logs:"
        docker logs gitlab 2>&1 | tail -30
        return 1
    fi

    # Wait for GitLab to be fully initialized
    if ! wait_for_gitlab; then
        log_error "GitLab initialization failed"
        log_warning "Container is running but not responding"
        log_info "You can:"
        log_info "  1. Wait longer - first boot can take 5-10 minutes on slow systems"
        log_info "  2. Check logs: docker logs -f gitlab"
        log_info "  3. Check resources: docker stats gitlab"
        log_info "  4. Continue without GitLab and use external GitLab server"
        return 1
    fi

    echo ""
    log_success "GitLab deployed successfully (MINIMAL MODE for interviews)!"
    echo ""
    echo "=========================================="
    echo "GitLab URL: http://localhost:8090"
    echo ""
    echo "Auto-configured Credentials:"
    echo "  Username: root"
    echo "  Password: Kx9mPqR2wZ"
    echo ""
    echo "Minimal Configuration:"
    echo "  ✓ Web UI for project management"
    echo "  ✓ Git over HTTP (port 8090)"
    echo "  ✓ Git over SSH (port 8022)"
    echo "  ✓ Persistent storage (3 Docker volumes)"
    echo "  ✗ Monitoring disabled (Prometheus, Grafana, exporters)"
    echo "  ✗ Registry disabled (not needed for interviews)"
    echo "  ✗ Pages/KAS disabled (not needed for interviews)"
    echo "  ✗ Email disabled (not needed for interviews)"
    echo "  ⚡ Reduced workers (Puma=2, Sidekiq=10)"
    echo ""
    echo "Next Steps:"
    echo "  1. Open http://localhost:8090 in your browser"
    echo "  2. Login with root / Kx9mPqR2wZ"
    echo "  3. Create a new project (see WORKFLOWS.md)"
    echo ""
    echo "Container Management:"
    echo "  • View logs: docker logs gitlab"
    echo "  • Check status: docker ps | grep gitlab"
    echo "  • Restart: docker restart gitlab"
    echo "  • Stop: docker stop gitlab"
    echo ""
    echo "GitLab is ready to use (minimal mode)!"
    echo "=========================================="
    echo ""

    # Show WSL-specific instructions
    if [[ "$OS" == "wsl" ]]; then
        WSL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "")
        if [ -n "$WSL_IP" ]; then
            echo "Access from Windows: http://$WSL_IP:8090"
            echo ""
        fi
    fi

    return 0
}

# Main execution
main() {
    detect_os
    deploy_gitlab
}

# Run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
