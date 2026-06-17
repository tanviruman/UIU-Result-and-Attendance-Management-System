<?php
// fetch_student_results.php
// JSON endpoint: logged-in student approved results only.

require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/approved_results_helpers.php';

header('Content-Type: application/json; charset=utf-8');

try {
    require_role(['student']);

    $payload = urams_fetch_approved_result_payload($pdo, (int)$_SESSION['user_id'], 'student');

    echo json_encode([
        'success' => true,
        'message' => 'Approved results loaded.',
        'data' => $payload,
    ], JSON_UNESCAPED_UNICODE);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Could not load approved student results.',
    ], JSON_UNESCAPED_UNICODE);
}
