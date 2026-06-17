<?php
// enroll_student.php
// Admin JSON endpoint: enroll existing student in a course section with prerequisite enforcement.

require_once __DIR__ . '/includes/academic_helpers.php';
require_role(['admin']);

$data = urams_admin_payload();
$studentId = urams_academic_int($data, 'student_id', 'Student');
$sectionId = urams_academic_int($data, 'section_id', 'Section');
$parentIdentifier = urams_admin_optional_string($data, 'parent_identifier', 50);
$force = !empty($data['force']);

try {
    $student = urams_admin_require_user($pdo, $studentId, 'student');
    $pdo->beginTransaction();
    $parentId = urams_academic_create_parent($pdo, $parentIdentifier, $student['full_name']);
    $enroll = urams_academic_enroll($pdo, $studentId, $sectionId, $parentId, $force);
    if (!$enroll['success']) {
        $pdo->rollBack();
        urams_json_response(['success' => false, 'message' => 'Prerequisite missing. Enrollment blocked.', 'report' => $enroll['report']], 409);
    }
    write_audit_log($pdo, (int)$_SESSION['user_id'], 'ENROLL_STUDENT', 'enrollments', (int)$enroll['enrollment_id'], null, json_encode([
        'student_id' => $studentId,
        'section_id' => $sectionId,
        'forced' => $force,
    ], JSON_UNESCAPED_UNICODE));
    $pdo->commit();
    urams_json_response(['success' => true, 'message' => 'Student enrolled successfully.', 'enrollment_id' => (int)$enroll['enrollment_id'], 'report' => $enroll['report']]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    urams_json_response(['success' => false, 'message' => 'Could not enroll student: ' . $e->getMessage()], 500);
}
