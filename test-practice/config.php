<?php
/**
 * Database Configuration
 * BUG LIST: This file contains 5 intentional bugs
 */

// Bug 1: Missing semicolon - FIXED
define('DB_HOST', 'localhost');

// Bug 2: Wrong variable name (missing $) - FIXED
$DB_USER = 'root';

// Bug 3: Typo in variable name ($databse vs $database) - FIXED
$database = 'interview_db';

// Bug 4: Missing closing quote - FIXED
$db_password = "secret_password";

// Bug 5: Wrong comparison operator (should be ==, not =) - FIXED
$environment = getenv('APP_ENV') ?: 'development'; // Define environment variable
if ($environment == 'production') {
    $debug = false;
} else {
    $debug = true;
}

// Correct variable (for reference)
$db_charset = 'utf8mb4';

?>
