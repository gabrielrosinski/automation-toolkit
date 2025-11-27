#!/bin/bash

###############################################################################
# DevOps Interview Toolkit - Pre-flight Check
# Validates system requirements before installation
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

echo ""
echo "=========================================="
echo "  Pre-flight System Check"
echo "=========================================="
echo ""

PASSED=0
FAILED=0
WARNINGS=0

# Detect OS
log_info "Detecting operating system..."
if grep -qi microsoft /proc/version 2>/dev/null; then
    OS="WSL"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
else
    log_error "Unsupported operating system: $OSTYPE"
    exit 1
fi
log_success "OS: $OS"
echo ""

# Check disk space
log_info "Checking disk space..."
if [[ "$OS" == "macOS" ]]; then
    AVAILABLE=$(df -g . | awk 'NR==2 {print $4}')
else
    AVAILABLE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
fi

if [ "$AVAILABLE" -lt 10 ]; then
    log_error "Insufficient disk space: ${AVAILABLE}GB available (need 10GB minimum)"
    FAILED=$((FAILED + 1))
else
    log_success "Disk space: ${AVAILABLE}GB available"
    PASSED=$((PASSED + 1))
fi
echo ""

# Check RAM
log_info "Checking system memory..."
if [[ "$OS" == "macOS" ]]; then
    TOTAL_RAM=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
elif [[ "$OS" == "Linux" ]] || [[ "$OS" == "WSL" ]]; then
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
else
    TOTAL_RAM=0
fi

if [ "$TOTAL_RAM" -lt 8 ]; then
    log_warning "Low RAM: ${TOTAL_RAM}GB (recommended 16GB for interview setup)"
    WARNINGS=$((WARNINGS + 1))
elif [ "$TOTAL_RAM" -lt 16 ]; then
    log_warning "RAM: ${TOTAL_RAM}GB (recommended 16GB, but workable)"
    WARNINGS=$((WARNINGS + 1))
else
    log_success "RAM: ${TOTAL_RAM}GB"
    PASSED=$((PASSED + 1))
fi
echo ""

# Check CPU cores
log_info "Checking CPU cores..."
if [[ "$OS" == "macOS" ]]; then
    CPU_CORES=$(sysctl -n hw.ncpu)
else
    CPU_CORES=$(nproc)
fi

if [ "$CPU_CORES" -lt 2 ]; then
    log_warning "Low CPU cores: $CPU_CORES (recommended 4+)"
    WARNINGS=$((WARNINGS + 1))
else
    log_success "CPU cores: $CPU_CORES"
    PASSED=$((PASSED + 1))
fi
echo ""

# Check for virtualization (nested virtualization can cause issues)
log_info "Checking virtualization..."
if [[ "$OS" != "macOS" ]] && grep -q hypervisor /proc/cpuinfo 2>/dev/null; then
    log_warning "Running in VM (nested virtualization may cause minikube issues)"
    WARNINGS=$((WARNINGS + 1))
else
    log_success "Not running in VM or VM supports nested virtualization"
    PASSED=$((PASSED + 1))
fi
echo ""

# Check internet connection
log_info "Checking internet connection..."
INTERNET_OK=false

# Try multiple methods (ping may fail in WSL/restricted environments)
if command -v curl >/dev/null 2>&1; then
    if curl -s --connect-timeout 5 --max-time 10 https://www.google.com >/dev/null 2>&1; then
        INTERNET_OK=true
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -q --spider --timeout=5 --tries=1 https://www.google.com >/dev/null 2>&1; then
        INTERNET_OK=true
    fi
elif ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    INTERNET_OK=true
fi

if [ "$INTERNET_OK" = true ]; then
    log_success "Internet connection: OK"
    PASSED=$((PASSED + 1))
else
    log_error "No internet connection (required for downloading tools)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Check if running as root (not recommended)
log_info "Checking user privileges..."
if [ "$EUID" -eq 0 ]; then
    log_warning "Running as root (not recommended, use sudo when needed)"
    WARNINGS=$((WARNINGS + 1))
else
    log_success "Running as non-root user"
    PASSED=$((PASSED + 1))
fi
echo ""

# Check if Docker Desktop is running (macOS specific)
if [[ "$OS" == "macOS" ]]; then
    log_info "Checking Docker Desktop (macOS)..."
    if pgrep -x "Docker" > /dev/null; then
        log_success "Docker Desktop is running"
        PASSED=$((PASSED + 1))
    else
        log_warning "Docker Desktop not detected. Install from: https://www.docker.com/products/docker-desktop"
        WARNINGS=$((WARNINGS + 1))
    fi
    echo ""
fi

# Check for existing installations
log_info "Checking for existing installations..."
EXISTING=""
command -v docker >/dev/null 2>&1 && EXISTING="${EXISTING}Docker "
command -v kubectl >/dev/null 2>&1 && EXISTING="${EXISTING}kubectl "
command -v minikube >/dev/null 2>&1 && EXISTING="${EXISTING}minikube "
command -v php >/dev/null 2>&1 && EXISTING="${EXISTING}PHP "

if [ -n "$EXISTING" ]; then
    log_info "Found existing: $EXISTING(will be used if compatible)"
else
    log_info "No existing tools found (fresh installation)"
fi
echo ""

# Summary
echo "=========================================="
echo "  PRE-FLIGHT CHECK SUMMARY"
echo "=========================================="
echo -e "${GREEN}✓ Passed: $PASSED${NC}"
echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
echo -e "${RED}✗ Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    log_success "System is ready for toolkit installation!"
    echo ""
    echo "Next steps:"
    echo "  ./1-infra-setup.sh"
    echo ""
    exit 0
else
    log_error "System does not meet minimum requirements!"
    echo ""
    echo "Please fix the issues above before running 1-infra-setup.sh"
    echo ""
    exit 1
fi
