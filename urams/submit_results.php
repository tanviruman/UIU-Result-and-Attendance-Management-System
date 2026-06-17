<?php
// submit_results.php
// Teacher submits a section result to Admin.

require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/result_helpers.php';
require_role(['teacher']);

$data = urams_read_json();
$sectionId = isset($data['section_id']) ? (int)$data['section_id'] : 0;
if ($sectionId <= 0) {
    urams_json_response(['success' => false, 'message' => 'Section ID is required.'], 400);
}

try {
    $teacherId = (int)$_SESSION['user_id'];

    $sectionStmt = $pdo->prepare(
        'SELECT id, status
         FROM course_sections
         WHERE id = :section_id AND teacher_id = :teacher_id
         LIMIT 1'
    );
    $sectionStmt->execute([':section_id' => $sectionId, ':teacher_id' => $teacherId]);
    $section = $sectionStmt->fetch();

    if (!$section) {
        urams_json_response(['success' => false, 'message' => 'Section not found for this teacher.'], 404);
    }
    if ($section['status'] === 'approved') {
        urams_json_response(['success' => false, 'message' => 'Approved result cannot be submitted again.'], 409);
    }
    if ($section['status'] === 'submitted') {
        urams_json_response(['success' => false, 'message' => 'Result is already submitted.'], 409);
    }

    $enrollStmt = $pdo->prepare('SELECT id FROM enrollments WHERE section_id = :section_id ORDER BY id');
    $enrollStmt->execute([':section_id' => $sectionId]);
    $enrollments = $enrollStmt->fetchAll();
    if (empty($enrollments)) {
        urams_json_response(['success' => false, 'message' => 'No students found in this section.'], 400);
    }

    $pdo->beginTransaction();

    urams_ensure_default_components($pdo, $sectionId, $teacherId);
    urams_migrate_legacy_marks_for_section($pdo, $sectionId, $teacherId);

    foreach ($enrollments as $enrollment) {
        $enrollmentId = (int)$enrollment['id'];
        urams_ensure_legacy_result($pdo, $enrollmentId);
        urams_recalculate_result($pdo, $enrollmentId);
    }

    $submission = $pdo->prepare(
        'INSERT INTO result_submissions
         (section_id, status, submitted_by, submitted_at, approved_by, rejected_by, approved_at, rejected_at, rejection_reason)
         VALUES (:section_id, "submitted", :submitted_by, NOW(), NULL, NULL, NULL, NULL, NULL)
         ON DUPLICATE KEY UPDATE
            status = "submitted",
            submitted_by = VALUES(submitted_by),
            submitted_at = NOW(),
            approved_by = NULL,
            rejected_by = NULL,
            approved_at = NULL,
            rejected_at = NULL,
            rejection_reason = NULL,
            updated_at = CURRENT_TIMESTAMP'
    );
    $submission->execute([
        ':section_id' => $sectionId,
        ':submitted_by' => $teacherId,
    ]);

    $updateSection = $pdo->prepare('UPDATE course_sections SET status = "submitted" WHERE id = :section_id');
    $updateSection->execute([':section_id' => $sectionId]);

    $updateLegacy = $pdo->prepare(
        'UPDATE results
         SET status = "submitted", submitted_by = :teacher_id, submitted_at = NOW(), approved_by = NULL, approved_at = NULL
         WHERE enrollment_id IN (SELECT id FROM enrollments WHERE section_id = :section_id)'
    );
    $updateLegacy->execute([':teacher_id' => $teacherId, ':section_id' => $sectionId]);

    write_audit_log(
        $pdo,
        $teacherId,
        'SUBMIT_RESULTS',
        'result_submissions',
        $sectionId,
        json_encode(['status' => $section['status']], JSON_UNESCAPED_UNICODE),
        json_encode(['status' => 'submitted'], JSON_UNESCAPED_UNICODE)
    );

    $pdo->commit();

    urams_json_response([
        'success' => true,
        'message' => 'Results submitted to Admin for approval.',
        'section_id' => $sectionId,
        'status' => 'submitted',
    ]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    urams_json_response(['success' => false, 'message' => 'Could not submit results: ' . $e->getMessage()], 500);
}
