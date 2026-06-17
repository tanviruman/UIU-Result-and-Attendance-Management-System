<?php
// check_prerequisites.php
// Admin JSON endpoint: check whether a student can enroll in a selected section.

require_once __DIR__ . '/includes/academic_helpers.php';
require_role(['admin']);

$data = $_SERVER['REQUEST_METHOD'] === 'POST' ? urams_admin_payload() : $_GET;
$studentId = urams_academic_int($data, 'student_id', 'Student');
$sectionId = urams_academic_int($data, 'section_id', 'Section');

try {
    $report = urams_academic_prerequisite_report($pdo, $studentId, $sectionId);
    urams_json_response(['success' => true] + $report);
} catch (Throwable $e) {
    urams_json_response(['success' => false, 'message' => 'Could not check prerequisite: ' . $e->getMessage()], 500);
}
