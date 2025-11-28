# PHP Quick Reference for Interview Debugging

## Instant Bug Finder

Run this first:
```bash
# Check ALL PHP files for syntax errors
find . -name "*.php" -exec php -l {} \; 2>&1 | grep -v "No syntax errors"

# Or one by one
php -l config.php
php -l index.php
php -l functions.php
```

---

## The 10 Most Common Bugs (In Order of Frequency)

### 1. Missing Semicolon
```php
$name = "John"     // WRONG - missing ;
$name = "John";    // CORRECT
```
**php -l says:** `Parse error: syntax error, unexpected...`

### 2. Wrong Comparison Operator
```php
if ($x = 5)   // WRONG - this is assignment, always true!
if ($x == 5)  // CORRECT - loose comparison
if ($x === 5) // BEST - strict comparison (checks type too)
```
**php -l:** Won't catch this - it's valid syntax!

### 3. Missing $ Before Variable
```php
name = "John";   // WRONG
$name = "John";  // CORRECT

foreach (items as $item)   // WRONG
foreach ($items as $item)  // CORRECT
```
**php -l says:** `Parse error: syntax error, unexpected '='`

### 4. Typos in Variable Names (Case Sensitive!)
```php
$userName = "John";
echo $username;    // WRONG - different variable! (lowercase n)
echo $userName;    // CORRECT
```
**php -l:** Won't catch this - both are valid variables

### 5. Missing Quotes
```php
require_once config.php;      // WRONG
require_once 'config.php';    // CORRECT
require_once "config.php";    // ALSO CORRECT

$arr = [key => 'value'];      // WRONG (unless key is a constant)
$arr = ['key' => 'value'];    // CORRECT
```

### 6. Missing/Extra Braces { }
```php
function test()    // WRONG - missing {
    return true;
}

function test() {  // CORRECT
    return true;
}

if ($x) {
    echo "yes";
}}  // WRONG - extra }
```
**php -l says:** `Parse error: syntax error, unexpected end of file`

### 7. Missing Parentheses ( )
```php
if (empty($name) || empty($email) {   // WRONG - missing )
if (empty($name) || empty($email)) {  // CORRECT

function test($arg {   // WRONG
function test($arg) {  // CORRECT
```

### 8. String Concatenation (Dot, Not Plus!)
```php
echo "Hello " + $name;   // WRONG - PHP uses dot, not plus
echo "Hello " . $name;   // CORRECT
echo "Hello $name";      // ALSO CORRECT (in double quotes)
echo 'Hello $name';      // WRONG - won't interpolate in single quotes
```

### 9. Array vs Object Access
```php
// For arrays:
$user['name']    // CORRECT
$user->name      // WRONG (that's for objects)
$user.name       // WRONG (that's JavaScript!)

// For objects:
$user->name      // CORRECT
$user['name']    // WRONG (unless implements ArrayAccess)
```

### 10. Missing Return Statement
```php
function add($a, $b) {
    $result = $a + $b;
    // WRONG - forgot to return!
}

function add($a, $b) {
    $result = $a + $b;
    return $result;  // CORRECT
}
```

---

## Quick Debugging Commands

```bash
# Check syntax
php -l file.php

# Start test server
php -S localhost:8000

# Show PHP info/extensions
php -i | grep -i extension
php -m  # List all modules

# Run PHP interactively
php -a

# Execute code inline
php -r "echo phpversion();"

# Check error log (Apache)
tail -f /var/log/apache2/error.log

# Check error log (Docker)
docker logs <container> 2>&1 | grep -i error
```

---

## Add This to PHP File for Debug Output

```php
<?php
// Put at top of file to see ALL errors
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Debug a variable
var_dump($variable);  // Shows type and value
print_r($array);      // Better for arrays

// Quick debug and die
echo "<pre>"; var_dump($var); die();

// Debug with context
echo "DEBUG Line " . __LINE__ . ": ";
var_dump($var);
```

---

## Fix Cheatsheet

| Error Message | Likely Cause | Quick Fix |
|---------------|--------------|-----------|
| `unexpected end of file` | Missing `}` or `?>` | Count braces, add closing |
| `unexpected T_VARIABLE` | Missing `;` on previous line | Add semicolon |
| `unexpected '='` | Missing `$` before variable | Add `$` |
| `undefined variable` | Typo in var name or uninitialized | Check spelling, initialize |
| `undefined function` | Typo in function name or missing include | Check spelling, add require |
| `call to member function on null` | Object doesn't exist | Check object creation/query |
| `cannot use string offset as array` | String treated as array | Check variable type |

---

## Interview Speed Run

When you get buggy PHP code:

1. **Run `php -l *.php`** - catches ~50% of bugs instantly
2. **Look for `=` in if statements** - common trick
3. **Check variable spelling** - `$usrname` vs `$username`
4. **Verify quotes** - `require config.php` needs quotes
5. **Count braces** - every `{` needs a `}`
6. **Check function names** - `sanityze` vs `sanitize`

```bash
# One-liner to check all PHP files
for f in *.php; do echo "=== $f ==="; php -l "$f"; done
```

---

## PHP Syntax Cheatsheet

```php
// Variables
$name = "John";
$age = 30;
$isActive = true;

// Arrays
$arr = ['a', 'b', 'c'];           // Indexed
$map = ['key' => 'value'];        // Associative
$arr[] = 'new item';              // Append

// Conditionals
if ($x == 1) {
    // ...
} elseif ($x == 2) {
    // ...
} else {
    // ...
}

// Loops
foreach ($arr as $item) { }
foreach ($map as $key => $value) { }
for ($i = 0; $i < 10; $i++) { }
while ($condition) { }

// Functions
function greet($name) {
    return "Hello, $name";
}

// Classes
class User {
    public $name;

    public function __construct($name) {
        $this->name = $name;
    }

    public function greet() {
        return "Hello, " . $this->name;
    }
}

// Null coalescing (PHP 7+)
$name = $_POST['name'] ?? 'default';

// Type declarations (PHP 7+)
function add(int $a, int $b): int {
    return $a + $b;
}
```

---

## Common PHP Functions for Web Apps

```php
// Input sanitization
htmlspecialchars($input);          // Prevent XSS
trim($input);                      // Remove whitespace
strip_tags($input);                // Remove HTML

// String functions
strlen($str);                      // Length
strpos($str, 'needle');           // Find position
substr($str, 0, 10);              // Substring
explode(',', $str);               // Split to array
implode(',', $arr);               // Join array

// Array functions
count($arr);                      // Length
in_array('value', $arr);          // Check if exists
array_push($arr, 'item');         // Add to end
array_key_exists('key', $arr);    // Check key

// Validation
empty($var);                      // True if empty/null/0/''
isset($var);                      // True if exists and not null
is_array($var);                   // Type check
filter_var($email, FILTER_VALIDATE_EMAIL);  // Validate email
```
