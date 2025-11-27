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

# Get script directory (buged-php/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Parent directory (lab-toolkit/)
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Get target directory
if [ -z "$1" ]; then
    read -p "Enter target directory name [practice-php]: " TARGET_NAME
    TARGET_NAME=${TARGET_NAME:-practice-php}
else
    TARGET_NAME="$1"
fi

# Full path to target (next to buged-php/, not inside it)
TARGET_DIR="$PARENT_DIR/$TARGET_NAME"

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

# Copy only PHP files, README, and Dockerfile (not the solutions) from SCRIPT_DIR
cp "$SCRIPT_DIR"/*.php "$TARGET_DIR/" 2>/dev/null
cp "$SCRIPT_DIR"/README.md "$TARGET_DIR/" 2>/dev/null
cp "$SCRIPT_DIR"/Dockerfile "$TARGET_DIR/" 2>/dev/null

log_success "Files copied to: $TARGET_DIR/"
echo ""

# Show what was copied
echo "Copied files:"
ls -1 "$TARGET_DIR/"
echo ""

log_success "Ready to debug!"
echo ""
echo "Next steps:"
echo "  1. Navigate to practice directory:"
echo "     cd $TARGET_NAME"
echo ""
echo "  2. Run debug helper (optional):"
echo "     ../helpers/php-debug.sh"
echo ""
echo "  3. Fix the bugs in your editor"
echo ""
echo "  4. Test with PHP development server:"
echo "     php -S localhost:8000"
echo "     Then open: http://localhost:8000"
echo "     (Press Ctrl+C to stop the server)"
echo ""
echo "  Alternative: Run from current directory:"
echo "     php -S localhost:8000 -t $TARGET_NAME/"
echo ""
echo "Original buggy files preserved in: buged-php/"
echo ""
