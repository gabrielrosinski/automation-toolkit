<?php
/**
 * Database Configuration
 * BUG LIST: This file contains 5 intentional bugs
 */

// Bug 1: Missing semicolon
define('DB_HOST', 'localhost')

// Bug 2: Wrong variable name (missing $)
DB_USER = 'root';

// Bug 3: Typo in variable name ($databse vs $database)
$databse = 'interview_db';

// Bug 4: Missing closing quote
$db_password = "secret_password;

// Bug 5: Wrong comparison operator (should be ==, not =)
if ($environment = 'production') {
    $debug = false;
} else {
    $debug = true;
}

// Correct variable (for reference)
$db_charset = 'utf8mb4';

?>
