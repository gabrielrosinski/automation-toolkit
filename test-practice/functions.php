<?php
/**
 * Utility Functions
 * BUG LIST: This file contains 6 intentional bugs
 */

// Bug 1: Missing opening brace - FIXED
function sanitize_input($data) {
    $data = trim($data);
    $data = stripslashes($data);
    $data = htmlspecialchars($data);
    return $data;
}

// Bug 2: Undefined variable used before declaration - FIXED
function calculate_total($price, $quantity) {
    $total = $price * $quantity;
    $discount_rate = 0.1; // Define discount rate
    $discount = $total * $discount_rate;
    return $total - $discount;
}

// Bug 3: Missing closing parenthesis - FIXED
function format_date($timestamp) {
    return date('Y-m-d H:i:s', $timestamp);
}

// Bug 4: Typo in function call (eco instead of echo) - FIXED
function display_message($message) {
    echo "<div class='message'>$message</div>";
}

// Bug 5: Wrong array access (using . instead of ->) - FIXED
function get_user_name($user) {
    return $user['name']; // Fixed to use array access
}

// Bug 6: Missing return statement and logic error - FIXED
function is_valid_email($email) {
    if (strpos($email, '@') !== false && strpos($email, '.') !== false) {
        $valid = true;
    } else {
        $valid = false;
    }
    return $valid; // Added return statement
}

// Correct function (for reference)
function get_current_time() {
    return date('Y-m-d H:i:s');
}

?>
