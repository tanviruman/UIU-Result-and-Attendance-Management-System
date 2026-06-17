<?php
// edit_teacher.php
// Admin endpoint: update teacher account.

require_once __DIR__ . '/includes/admin_helpers.php';
require_role(['admin']);

$data = urams_admin_payload();
$id = (int)($data['id'] ?? 0);
if ($id <= 0) {
    urams_json_response(['success' => false, 'message' => 'Teacher ID is required.'], 400);
}
$old = urams_admin_require_user($pdo, $id, 'teacher');
$fullName = urams_admin_required_string($data, 'full_name', 'Teacher name');
$email = strtolower(urams_admin_required_string($data, 'email', 'Email'));
$identifier = strtoupper(urams_admin_required_string($data, 'identifier', 'Teacher initial', 50));
$phone = urams_admin_optional_string($data, 'phone', 30);
$department = urams_admin_optional_string($data, 'department', 80);
$password = (string)($data['password'] ?? '');
urams_admin_validate_email($email);

try {
    urams_admin_check_duplicate_user($pdo, $email, $identifier, $id);

    if ($password !== '') {
        if (strlen($password) < 6) {
            urams_json_response(['success' => false, 'message' => 'Password must be at least 6 characters.'], 400);
        }
        $stmt = $pdo->prepare(
            "UPDATE users
             SET full_name = :full_name, email = :email, identifier = :identifier, phone = :phone,
                 department = :department, password_hash = :password_hash, updated_at = CURRENT_TIMESTAMP
             WHERE id = :id AND role = 'teacher'"
        );
        $params = [
            ':full_name' => $fullName,
            ':email' => $email,
            ':identifier' => $identifier,
            ':phone' => $phone,
            ':department' => $department,
            ':password_hash' => password_hash($password, PASSWORD_DEFAULT),
            ':id' => $id,
        ];
    } else {
        $stmt = $pdo->prepare(
            "UPDATE users
             SET full_name = :full_name, email = :email, identifier = :identifier, phone = :phone,
                 department = :department, updated_at = CURRENT_TIMESTAMP
             WHERE id = :id AND role = 'teacher'"
        );
        $params = [
            ':full_name' => $fullName,
            ':email' => $email,
            ':identifier' => $identifier,
            ':phone' => $phone,
            ':department' => $department,
            ':id' => $id,
        ];
    }

    $stmt->execute($params);
    write_audit_log($pdo, (int)$_SESSION['user_id'], 'EDIT_TEACHER', 'users', $id, json_encode($old, JSON_UNESCAPED_UNICODE), json_encode(['identifier' => $identifier, 'email' => $email], JSON_UNESCAPED_UNICODE));
    urams_json_response(['success' => true, 'message' => 'Teacher updated successfully.', 'teacher' => urams_admin_json_user(urams_admin_user_row($pdo, $id))]);
} catch (Throwable $e) {
    urams_json_response(['success' => false, 'message' => 'Could not update teacher: ' . $e->getMessage()], 500);
}
