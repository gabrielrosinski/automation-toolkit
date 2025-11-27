# Complete Bug List - Buggy PHP Application

## Summary
- **Total Bugs:** 34 intentional bugs across 4 files
- **Syntax Errors:** 15 (can be caught by `php -l`)
- **Logic Errors:** 11 (runtime/logic issues)
- **Typos/Naming:** 8 (variable name mistakes)

---

## config.php (5 bugs)

### Bug 1 - Line 8: Missing Semicolon
```php
define('DB_HOST', 'localhost')  // Missing ;
```
**Fix:** Add semicolon
```php
define('DB_HOST', 'localhost');
```

### Bug 2 - Line 11: Missing $ for Variable
```php
DB_USER = 'root';  // Should be $DB_USER
```
**Fix:**
```php
$DB_USER = 'root';
```

### Bug 3 - Line 14: Typo in Variable Name
```php
$databse = 'interview_db';  // Should be $database
```
**Fix:**
```php
$database = 'interview_db';
```

### Bug 4 - Line 17: Missing Closing Quote
```php
$db_password = "secret_password;  // Missing closing "
```
**Fix:**
```php
$db_password = "secret_password";
```

### Bug 5 - Line 20: Wrong Comparison Operator
```php
if ($environment = 'production') {  // Assignment, not comparison
```
**Fix:**
```php
if ($environment == 'production') {  // or ===
```

---

## functions.php (6 bugs)

### Bug 1 - Line 8: Missing Opening Brace
```php
function sanitize_input($data)  // Missing {
    $data = trim($data);
```
**Fix:**
```php
function sanitize_input($data) {
```

### Bug 2 - Line 15: Undefined Variable
```php
$discount = $total * $discount_rate; // $discount_rate not defined
```
**Fix:**
```php
$discount_rate = 0.1; // Define before use
$discount = $total * $discount_rate;
```

### Bug 3 - Line 20: Missing Closing Parenthesis
```php
function format_date($timestamp {  // Missing )
```
**Fix:**
```php
function format_date($timestamp) {
```

### Bug 4 - Line 25: Typo in Function Name
```php
eco "<div class='message'>$message</div>";  // Should be echo
```
**Fix:**
```php
echo "<div class='message'>$message</div>";
```

### Bug 5 - Line 30: Wrong Object/Array Access
```php
return $user.name; // Wrong syntax
```
**Fix:**
```php
return $user['name']; // or $user->name for objects
```

### Bug 6 - Line 36: Missing Return Statement
```php
function is_valid_email($email) {
    if (strpos($email, '@') !== false && strpos($email, '.') !== false) {
        $valid = true;
    } else {
        $valid = false;
    }
    // Missing: return $valid;
}
```
**Fix:** Add `return $valid;` at the end

---

## user.php (8 bugs)

### Bug 1 - Line 11: Missing Closing Brace
```php
class User {
    // ... properties and methods
// Missing } before line 52
```
**Fix:** Add closing brace at end of class

### Bug 2 - Line 17: Missing 'function' Keyword
```php
public __construct($id, $username, $email) {  // Missing 'function'
```
**Fix:**
```php
public function __construct($id, $username, $email) {
```

### Bug 3 - Line 24: Typo in Variable Name
```php
$this->usrname = $username;  // Should be $this->username
```
**Fix:**
```php
$this->username = $username;
```

### Bug 4 - Line 29: Assignment Instead of Comparison
```php
if ($this->status = 'active') {  // Assignment, not comparison
```
**Fix:**
```php
if ($this->status == 'active') {
```

### Bug 5 - Line 36: Missing Semicolon
```php
return $this->email  // Missing ;
```
**Fix:**
```php
return $this->email;
```

### Bug 6 - Line 41: Missing Quotes in Array Keys
```php
return [
    id => $this->id,  // Keys need quotes
    username => $this->username,
    email => $this->email
];
```
**Fix:**
```php
return [
    'id' => $this->id,
    'username' => $this->username,
    'email' => $this->email
];
```

### Bug 7 - Line 52: Extra Closing Brace
```php
}}  // Double closing braces
```
**Fix:** Remove one brace

### Bug 8 - Line 56: Typo in Variable Name
```php
$user = new User(null, $usernme, $email); // Should be $username
```
**Fix:**
```php
$user = new User(null, $username, $email);
```

---

## index.php (8 bugs)

### Bug 1 - Line 8: Missing Quotes Around Filename
```php
require_once config.php;  // Missing quotes
```
**Fix:**
```php
require_once 'config.php';
```

### Bug 2 - Line 31: Missing Semicolon
```php
$message = ""  // Missing ;
```
**Fix:**
```php
$message = "";
```

### Bug 3 - Line 36: Wrong POST Variable Name
```php
$username = $_POST['usrname'] ?? '';  // Should be 'username'
```
**Fix:**
```php
$username = $_POST['username'] ?? '';
```

### Bug 4 - Line 40: Missing Closing Parenthesis
```php
if (empty($username) || empty($email) {  // Missing )
```
**Fix:**
```php
if (empty($username) || empty($email)) {
```

### Bug 5 - Line 43: Typo in Function Name
```php
$username = sanityze_input($username);  // Should be sanitize_input
```
**Fix:**
```php
$username = sanitize_input($username);
```

### Bug 6 - Line 52: Wrong Comparison Operator
```php
if ($message = "") {  // Assignment, not comparison
```
**Fix:**
```php
if ($message == "") {  // or === ""
```

### Bug 7 - Line 73: Missing $ Before Array Variable
```php
foreach (users as $user) {  // Missing $
```
**Fix:**
```php
foreach ($users as $user) {
```

### Bug 8 - Logic Error: Messages Display Backwards
The condition on line 52-56 is backwards - it shows error class when message is empty.

---

## Bug Categories

### Syntax Errors (Caught by php -l)
1. Missing semicolons (3 instances)
2. Missing/extra braces (3 instances)
3. Missing parentheses (2 instances)
4. Missing quotes (3 instances)
5. Missing keywords (1 instance)
6. Wrong syntax (3 instances)

### Runtime/Logic Errors
1. Undefined variables (3 instances)
2. Wrong operators (4 instances)
3. Typos in function/method names (2 instances)
4. Missing return statements (1 instance)
5. Wrong array/object access (2 instances)

### Variable Name Typos
1. $databse vs $database
2. $usrname vs $username (2 instances)
3. $usernme vs $username
4. DB_USER vs $DB_USER
5. users vs $users

---

## Testing Strategy

### Step 1: Syntax Check
```bash
php -l *.php
```
This will catch ~15 bugs

### Step 2: Runtime Test
```bash
php -S localhost:8000
```
Visit http://localhost:8000 and test functionality

### Step 3: Logic Review
Review code for logic errors and variable typos

---

## Expected Time to Fix

- **Quick (Syntax only):** 10-15 minutes
- **Complete (All bugs):** 20-30 minutes
- **Interview Scenario:** 15-20 minutes (focus on critical bugs)

---

**Good luck debugging! 🐛🔍**
