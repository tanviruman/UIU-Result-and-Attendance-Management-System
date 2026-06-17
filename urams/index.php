<?php
// index.php
// Step: Entry point. Logged-in user dashboard e, otherwise login e.
require_once __DIR__ . '/includes/auth.php';
header('Location: ' . (is_logged_in() ? 'dashboard.php' : 'login.php'));
exit;
?>