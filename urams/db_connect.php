<?php
// db_connect.php
// Legacy compatibility file. Do not create mysqli connections anywhere.
// Use $pdo from config/db.php in all new code.

require_once __DIR__ . '/config/db.php';

// Backward-compatible alias for old includes that might require db_connect.php.
// This is PDO, not mysqli.
$conn = $pdo;
