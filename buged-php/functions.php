<?php
/**
 * Utility Functions
 * BUG LIST: This file contains 6 intentional bugs
 */

// Bug 1: Missing opening brace
function sanitize_input($data)
    $data = trim($data);
    $data = stripslashes($data);
    $data = htmlspecialchars($data);
    return $data;
}

// Bug 2: Undefined variable used before declaration
function calculate_total($price, $quantity) {
    $total = $price * $quantity;
    $discount = $total * $discount_rate; // $discount_rate is not defined
    return $total - $discount;
}

// Bug 3: Missing closing parenthesis
function format_date($timestamp {
    return date('Y-m-d H:i:s', $timestamp);
}

// Bug 4: Typo in function call (eco instead of echo)
function display_message($message) {
    eco "<div class='message'>$message</div>";
}

// Bug 5: Wrong array access (using . instead of ->)
function get_user_name($user) {
    return $user.name; // Should be $user['name'] or $user->name
}

// Bug 6: Missing return statement and logic error
function is_valid_email($email) {
    if (strpos($email, '@') !== false && strpos($email, '.') !== false) {
        $valid = true;
    } else {
        $valid = false;
    }
    // Missing return $valid;
}

// Correct function (for reference)
function get_current_time() {
    return date('Y-m-d H:i:s');
}

?>
