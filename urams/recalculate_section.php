<?php
// recalculate_section.php
// Recalculate all student totals/grades for a selected teacher section.

require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/result_helpers.php';

if (!is_logged_in()) {
    urams_json_response(['success' => false, 'message' => 'Login required.'], 401);
}
if (!in_array($_SESSION['role'] ?? '', ['teacher', 'admin'], true)) {
    urams_json_response(['success' => false, 'message' => 'You do not have permission.'], 403);
}

$data = urams_read_json();
$sectionId = isset($data['section_id']) ? (int)$data['section_id'] : 0;
if ($sectionId <= 0) {
    urams_json_response(['success' => false, 'message' => 'Section ID is required.'], 400);
}

try {
    $userId = (int)($_SESSION['user_id'] ?? 0);
    $role = (string)($_SESSION['role'] ?? '');

    if ($role === 'teacher') {
        $stmt = $pdo->prepare('SELECT id, status FROM course_sections WHERE id = :section_id AND teacher_id = :teacher_id LIMIT 1');
        $stmt->execute([':section_id' => $sectionId, ':teacher_id' => $userId]);
    } else {
        $stmt = $pdo->prepare('SELECT id, status FROM course_sections WHERE id = :section_id LIMIT 1');
        $stmt->execute([':section_id' => $sectionId]);
    }
    $section = $stmt->fetch();
    if (!$section) {
        urams_json_response(['success' => false, 'message' => 'Section not found or unauthorized.'], 404);
    }

    urams_ensure_default_components($pdo, $sectionId, $userId);
    urams_migrate_legacy_marks_for_section($pdo, $sectionId, $userId);

    $enrollStmt = $pdo->prepare('SELECT id FROM enrollments WHERE section_id = :section_id ORDER BY id');
    $enrollStmt->execute([':section_id' => $sectionId]);
    $enrollments = $enrollStmt->fetchAll();

    foreach ($enrollments as $enrollment) {
        $enrollmentId = (int)$enrollment['id'];
        urams_ensure_legacy_result($pdo, $enrollmentId);
        urams_recalculate_result($pdo, $enrollmentId);
    }

    if (function_exists('write_audit_log')) {
        write_audit_log($pdo, $userId, 'RECALCULATE_SECTION_RESULT', 'course_sections', $sectionId, null, json_encode(['enrollments' => count($enrollments)], JSON_UNESCAPED_UNICODE));
    }

    urams_json_response([
        'success' => true,
        'message' => 'Attendance/result totals recalculated successfully.',
        'updated' => count($enrollments),
    ]);
} catch (Throwable $e) {
    urams_json_response(['success' => false, 'message' => 'Could not recalculate section: ' . $e->getMessage()], 500);
}
