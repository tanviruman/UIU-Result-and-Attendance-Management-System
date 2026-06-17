<?php
// delete_student.php
// Admin endpoint: deactivate student account while preserving academic records.

require_once __DIR__ . '/includes/admin_helpers.php';
require_role(['admin']);

$data = urams_admin_payload();
$id = (int)($data['id'] ?? 0);
if ($id <= 0) {
    urams_json_response(['success' => false, 'message' => 'Student ID is required.'], 400);
}
$old = urams_admin_require_user($pdo, $id, 'student');

try {
    $stmt = $pdo->prepare("UPDATE users SET status = 'inactive', updated_at = CURRENT_TIMESTAMP WHERE id = :id AND role = 'student'");
    $stmt->execute([':id' => $id]);
    write_audit_log($pdo, (int)$_SESSION['user_id'], 'DELETE_STUDENT', 'users', $id, json_encode($old, JSON_UNESCAPED_UNICODE), json_encode(['status' => 'inactive'], JSON_UNESCAPED_UNICODE));
    urams_json_response(['success' => true, 'message' => 'Student removed successfully.']);
} catch (Throwable $e) {
    urams_json_response(['success' => false, 'message' => 'Could not delete student: ' . $e->getMessage()], 500);
}
