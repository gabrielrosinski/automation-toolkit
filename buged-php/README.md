# Buggy PHP Application - Test Sample

## ⚠️ WARNING: THIS CODE IS INTENTIONALLY BUGGY!

This is a sample buggy PHP application designed for testing the DevOps Interview Toolkit scripts.

## Purpose

- Test the `helpers/php-debug.sh` script
- Practice debugging PHP code during interview preparation
- Simulate real-world interview scenarios

## Important Notes

**DO NOT MODIFY THESE FILES DIRECTLY!**

When debugging:
1. **Copy the folder** to a new location first
2. Work on the copy, not the original
3. This preserves the buggy version for future practice

## How to Use

### For Testing

```bash
# Copy the buggy code to a test directory
cp -r buged-php test-php-app
cd test-php-app

# Run the debug helper
../helpers/php-debug.sh

# Fix the bugs manually in your editor
# Test your fixes with: php -S localhost:8000
```

### For Interview Practice

```bash
# Simulate interview scenario
cd lab-toolkit
cp -r buged-php ~/interview-practice
cd ~/interview-practice

# Start debugging (time yourself!)
php -l *.php
# Fix bugs...
```

## Application Description

This is a simple user management system with:
- `index.php` - Main entry point
- `config.php` - Database configuration
- `functions.php` - Utility functions
- `user.php` - User management class

All files contain intentional bugs of various types!

## Bug Types Included

- Syntax errors (missing semicolons, brackets)
- Undefined variables
- Wrong operators (= vs ==)
- Typos in variable names
- Missing quotes
- Array access issues
- Logic errors

## Expected Behavior (After Fixing)

The application should:
1. Load without syntax errors
2. Connect to database (if configured)
3. Display a simple user management interface
4. Allow adding/listing users

---

**Remember: This is practice code. Keep the bugs for future testing!**
