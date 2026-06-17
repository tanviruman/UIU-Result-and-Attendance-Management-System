<?php
// fetch_parent_results.php
// JSON endpoint: logged-in parent linked-child approved results only.

require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/approved_results_helpers.php';

header('Content-Type: application/json; charset=utf-8');

try {
    require_role(['parent']);

    $payload = urams_fetch_approved_result_payload($pdo, (int)$_SESSION['user_id'], 'parent');

    echo json_encode([
        'success' => true,
        'message' => 'Approved child results loaded.',
        'data' => $payload,
    ], JSON_UNESCAPED_UNICODE);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Could not load approved parent results.',
    ], JSON_UNESCAPED_UNICODE);
}
