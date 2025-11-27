<?php
/**
 * Main Application Entry Point
 * BUG LIST: This file contains 8 intentional bugs
 */

// Bug 1: Missing quotes around filename - FIXED
require_once 'config.php';
require_once 'functions.php';
require_once 'user.php';

// Enable error reporting
ini_set('display_errors', 1);
error_reporting(E_ALL);

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>User Management System</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .error { color: red; }
        .success { color: green; }
        table { border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
    </style>
</head>
<body>
    <h1>User Management System</h1>

    <?php
    // Bug 2: Missing semicolon - FIXED
    $message = "";

    // Bug 3: Using undefined variable - FIXED
    if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'POST') {
        // Bug 4: Wrong variable name (usrname vs username) - FIXED
        $username = $_POST['username'] ?? '';
        $email = $_POST['email'] ?? '';

        // Bug 5: Missing closing parenthesis - FIXED
        if (empty($username) || empty($email)) {
            $message = "Username and email are required!";
        } else {
            // Bug 6: Typo in function name (sanityze vs sanitize) - FIXED
            $username = sanitize_input($username);
            $email = sanitize_input($email);

            // Create user
            $user = create_user($username, $email);
            $message = "User created successfully!";
        }
    }

    // Bug 7: Wrong comparison (= instead of ==) - FIXED
    if ($message != "") {
        if (strpos($message, 'required') !== false || strpos($message, 'failed') !== false) {
            echo "<p class='error'>$message</p>";
        } else {
            echo "<p class='success'>$message</p>";
        }
    }
    ?>

    <h2>Add New User</h2>
    <form method="POST" action="">
        <label for="username">Username:</label><br>
        <input type="text" id="username" name="username" required><br><br>

        <label for="email">Email:</label><br>
        <input type="email" id="email" name="email" required><br><br>

        <button type="submit">Add User</button>
    </form>

    <h2>User List</h2>
    <?php
    // Sample users array
    $users = [
        ['id' => 1, 'username' => 'john_doe', 'email' => 'john@example.com'],
        ['id' => 2, 'username' => 'jane_smith', 'email' => 'jane@example.com'],
        ['id' => 3, 'username' => 'bob_jones', 'email' => 'bob@example.com']
    ];

    // Bug 8: Wrong array syntax (missing $) - FIXED
    echo "<table>";
    echo "<tr><th>ID</th><th>Username</th><th>Email</th></tr>";
    foreach ($users as $user) {
        echo "<tr>";
        echo "<td>{$user['id']}</td>";
        echo "<td>{$user['username']}</td>";
        echo "<td>{$user['email']}</td>";
        echo "</tr>";
    }
    echo "</table>";
    ?>

</body>
</html>
