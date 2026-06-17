<?php
// add_teacher.php
// Admin endpoint: create teacher account.

require_once __DIR__ . '/includes/admin_helpers.php';
require_role(['admin']);

$data = urams_admin_payload();
$fullName = urams_admin_required_string($data, 'full_name', 'Teacher name');
$email = strtolower(urams_admin_required_string($data, 'email', 'Email'));
$identifier = strtoupper(urams_admin_required_string($data, 'identifier', 'Teacher initial', 50));
$phone = urams_admin_optional_string($data, 'phone', 30);
$department = urams_admin_optional_string($data, 'department', 80);
$password = (string)($data['password'] ?? '');
if ($password === '') {
    $password = 'password123';
}
if (strlen($password) < 6) {
    urams_json_response(['success' => false, 'message' => 'Password must be at least 6 characters.'], 400);
}
urams_admin_validate_email($email);

try {
    urams_admin_check_duplicate_user($pdo, $email, $identifier);
    $stmt = $pdo->prepare(
        "INSERT INTO users (full_name, email, identifier, role, password_hash, phone, department, status)
         VALUES (:full_name, :email, :identifier, 'teacher', :password_hash, :phone, :department, 'active')"
    );
    $stmt->execute([
        ':full_name' => $fullName,
        ':email' => $email,
        ':identifier' => $identifier,
        ':password_hash' => password_hash($password, PASSWORD_DEFAULT),
        ':phone' => $phone,
        ':department' => $department,
    ]);
    $id = (int)$pdo->lastInsertId();
    write_audit_log($pdo, (int)$_SESSION['user_id'], 'ADD_TEACHER', 'users', $id, null, json_encode(['id' => $id, 'identifier' => $identifier], JSON_UNESCAPED_UNICODE));
    urams_json_response(['success' => true, 'message' => 'Teacher added successfully.', 'teacher' => urams_admin_json_user(urams_admin_user_row($pdo, $id))]);
} catch (Throwable $e) {
    urams_json_response(['success' => false, 'message' => 'Could not add teacher: ' . $e->getMessage()], 500);
}
