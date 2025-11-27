#!/bin/bash

###############################################################################
# PHP Debugging Helper
# Common PHP debugging commands and checklist
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
echo "  PHP Debugging Helper"
echo "=========================================="
echo ""

# Check if PHP is installed
if ! command -v php >/dev/null 2>&1; then
    log_error "PHP is not installed!"
    echo "Run 1-infra-setup.sh first to install PHP."
    exit 1
fi

# Check if we're in a PHP project
if ! ls *.php >/dev/null 2>&1; then
    log_warning "No PHP files found in current directory"
    echo "Usage: Run this script from your PHP project directory"
    exit 1
fi

log_info "PHP Version: $(php --version | head -n1)"
echo ""

# Function to run syntax check
check_syntax() {
    echo "=========================================="
    echo "1. PHP SYNTAX CHECK"
    echo "=========================================="
    echo ""

    log_info "Checking all PHP files for syntax errors..."

    local error_count=0
    while IFS= read -r file; do
        if ! php -l "$file" > /dev/null 2>&1; then
            log_warning "Syntax error in: $file"
            php -l "$file"
            error_count=$((error_count + 1))
        fi
    done < <(find . -name "*.php" -not -path "./vendor/*")

    if [ $error_count -eq 0 ]; then
        log_success "✓ All PHP files passed syntax check"
    else
        log_error "✗ Found $error_count file(s) with syntax errors"
    fi
    echo ""
}

# Function to start local PHP server
start_server() {
    echo "=========================================="
    echo "2. LOCAL PHP SERVER"
    echo "=========================================="
    echo ""
    
    log_info "Starting PHP built-in server..."
    log_info "Access at: http://localhost:8000"
    log_info "Press Ctrl+C to stop"
    echo ""
    
    php -S localhost:8000
}

# Function to show common bugs checklist
show_checklist() {
    cat << 'EOF'

==========================================
COMMON PHP BUGS CHECKLIST
==========================================

1. SYNTAX ERRORS:
   □ Missing semicolons (;)
   □ Unclosed brackets { } [ ] ( )
   □ Mismatched quotes (' vs ")
   □ Missing $ before variables
   
2. UNDEFINED VARIABLES:
   □ Typos in variable names ($usre vs $user)
   □ Using variables before initialization
   □ Scope issues (using outside function/class)
   
3. UNDEFINED FUNCTIONS:
   □ Typos in function names
   □ Missing require/include statements
   □ Function called before defined
   
4. ARRAY/OBJECT ERRORS:
   □ Accessing undefined array keys
   □ Using -> vs :: incorrectly
   □ Array vs Object confusion
   
5. FILE/PATH ISSUES:
   □ Incorrect file paths in require/include
   □ File permissions (chmod 644 for files, 755 for dirs)
   □ Case sensitivity in filenames
   
6. DATABASE ERRORS:
   □ Wrong credentials in config
   □ SQL syntax errors
   □ Missing PDO/mysqli extensions
   
7. LOGIC ERRORS:
   □ Wrong comparison operators (= vs ==)
   □ Incorrect conditional logic
   □ Off-by-one errors in loops

==========================================
DEBUGGING COMMANDS
==========================================

# Syntax check single file
php -l filename.php

# Syntax check all files
find . -name "*.php" -exec php -l {} \;

# Display errors (add to PHP file)
ini_set('display_errors', 1);
error_reporting(E_ALL);

# Debug variable contents
var_dump($variable);
print_r($array);

# Check PHP configuration
php -i | grep -i error

# Check loaded extensions
php -m

# Start local server
php -S localhost:8000

# Check Apache error logs
tail -f /var/log/apache2/error.log

# In Docker container
docker logs <container-name>

==========================================
QUICK FIXES
==========================================

# Fix file permissions
chmod 644 *.php
chmod 755 .

# Check if extension is loaded
php -m | grep <extension>

# Install missing extension (Debian/Ubuntu)
sudo apt-get install php-<extension>

# Restart PHP-FPM (if using)
sudo systemctl restart php-fpm

# Clear PHP cache
php -r "opcache_reset();"

==========================================
EOF
}

# Interactive menu
while true; do
    echo ""
    echo "Choose an option:"
    echo "1) Run syntax check on all PHP files"
    echo "2) Start local PHP development server"
    echo "3) Show common bugs checklist"
    echo "4) Exit"
    echo ""
    read -p "Enter choice [1-4]: " choice
    
    case $choice in
        1)
            check_syntax
            ;;
        2)
            start_server
            ;;
        3)
            show_checklist
            ;;
        4)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            log_warning "Invalid choice. Please enter 1-4."
            ;;
    esac
done
