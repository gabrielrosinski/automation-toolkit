#!/bin/bash

###############################################################################
# Copy Buggy PHP App for Practice
# Creates a clean copy of the buggy code in a new directory
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=========================================="
echo "  Copy Buggy PHP for Practice"
echo "=========================================="
echo ""

# Get target directory
if [ -z "$1" ]; then
    read -p "Enter target directory name [practice-php]: " TARGET_DIR
    TARGET_DIR=${TARGET_DIR:-practice-php}
else
    TARGET_DIR="$1"
fi

# Check if target already exists
if [ -d "$TARGET_DIR" ]; then
    log_error "Directory '$TARGET_DIR' already exists!"
    read -p "Overwrite? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log_info "Cancelled."
        exit 0
    fi
    rm -rf "$TARGET_DIR"
fi

# Copy files
log_info "Copying buggy PHP files to '$TARGET_DIR'..."
mkdir -p "$TARGET_DIR"

# Copy only PHP files and README (not the solutions)
cp *.php "$TARGET_DIR/" 2>/dev/null
cp README.md "$TARGET_DIR/" 2>/dev/null

log_success "Files copied to: $TARGET_DIR/"
echo ""

# Show what was copied
echo "Copied files:"
ls -1 "$TARGET_DIR/"
echo ""

log_success "Ready to debug!"
echo ""
echo "Next steps:"
echo "  cd $TARGET_DIR"
echo "  ../helpers/php-debug.sh"
echo "  # Fix the bugs and test with: php -S localhost:8000"
echo ""
echo "Original buggy files preserved in: buged-php/"
echo ""
