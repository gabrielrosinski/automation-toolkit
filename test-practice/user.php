<?php
/**
 * User Management Class
 * BUG LIST: This file contains 7 intentional bugs
 */

require_once 'config.php';
require_once 'functions.php';

// Bug 1: Missing closing brace for class
class User {
    private $id;
    private $username;
    private $email;
    private $status = 'active'; // Default status

    // Bug 2: Wrong syntax for constructor (missing function keyword) - FIXED
    public function __construct($id, $username, $email) {
        $this->id = $id;
        $this->username = $username;
        $this->email = $email;
    }

    // Bug 3: Typo in variable name ($usrname vs $username) - FIXED
    public function setUsername($username) {
        $this->username = $username;
    }

    // Bug 4: Using = instead of == in comparison - FIXED
    public function isActive() {
        if ($this->status == 'active') {
            return true;
        }
        return false;
    }

    // Bug 5: Missing semicolon - FIXED
    public function getEmail() {
        return $this->email;
    }

    // Bug 6: Wrong array syntax (missing quotes around key) - FIXED
    public function toArray() {
        return [
            'id' => $this->id,
            'username' => $this->username,
            'email' => $this->email
        ];
    }

    // Correct method (for reference)
    public function getId() {
        return $this->id;
    }
// Bug 7: Extra closing brace (class already closed by Bug 1 fix) - FIXED
}

// Bug 8: Using undefined variable - FIXED
function create_user($username, $email) {
    $user = new User(null, $username, $email); // Fixed typo
    return $user;
}

?>
