<?php
// grade_process.php
// Final grade processing for the Excel-like teacher result sheet.

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
$grace = isset($data['grace_value']) ? (float)$data['grace_value'] : 0.0;
if ($sectionId <= 0) {
    urams_json_response(['success' => false, 'message' => 'Section ID is required.'], 400);
}
if ($grace < 0 || $grace > 5) {
    urams_json_response(['success' => false, 'message' => 'Grace must be between 0 and 5.'], 400);
}

try {
    $userId = (int)($_SESSION['user_id'] ?? 0);
    $role = (string)($_SESSION['role'] ?? '');

    if ($role === 'teacher') {
        $sectionStmt = $pdo->prepare('SELECT id, status FROM course_sections WHERE id = :section_id AND teacher_id = :teacher_id LIMIT 1');
        $sectionStmt->execute([':section_id' => $sectionId, ':teacher_id' => $userId]);
    } else {
        $sectionStmt = $pdo->prepare('SELECT id, status FROM course_sections WHERE id = :section_id LIMIT 1');
        $sectionStmt->execute([':section_id' => $sectionId]);
    }
    $section = $sectionStmt->fetch();
    if (!$section) {
        urams_json_response(['success' => false, 'message' => 'Section not found or unauthorized.'], 404);
    }
    if (in_array((string)$section['status'], ['submitted', 'approved'], true)) {
        urams_json_response(['success' => false, 'message' => 'Submitted/approved result cannot be edited.'], 409);
    }

    $pdo->beginTransaction();

    urams_ensure_default_components($pdo, $sectionId, $userId);
    urams_migrate_legacy_marks_for_section($pdo, $sectionId, $userId);

    $enrollStmt = $pdo->prepare('SELECT id FROM enrollments WHERE section_id = :section_id ORDER BY id');
    $enrollStmt->execute([':section_id' => $sectionId]);
    $enrollments = $enrollStmt->fetchAll();
    if (!$enrollments) {
        $pdo->rollBack();
        urams_json_response(['success' => false, 'message' => 'No students found in this section.'], 400);
    }

    $graceComponentId = null;
    $graceStmt = $pdo->prepare('SELECT id FROM assessment_components WHERE section_id = :section_id AND component_key = "grace" LIMIT 1');
    $graceStmt->execute([':section_id' => $sectionId]);
    $existingGrace = $graceStmt->fetch();

    if ($grace > 0) {
        if ($existingGrace) {
            $graceComponentId = (int)$existingGrace['id'];
            $upd = $pdo->prepare('UPDATE assessment_components SET component_name = "Grace", component_type = "custom", taken_out_of = :grace, convert_to = :grace, weight = :grace, sort_order = 999 WHERE id = :id');
            $upd->execute([':grace' => $grace, ':id' => $graceComponentId]);
        } else {
            $ins = $pdo->prepare('INSERT INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group, created_by) VALUES (:section_id, "grace", "Grace", "custom", :grace, :grace, :grace, 999, 0, NULL, :created_by)');
            $ins->execute([':section_id' => $sectionId, ':grace' => $grace, ':created_by' => $userId]);
            $graceComponentId = (int)$pdo->lastInsertId();
        }

        $upsertGrace = $pdo->prepare('INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, is_absent, updated_by) VALUES (:enrollment_id, :component_id, :raw_marks, :converted_marks, 0, :updated_by) ON DUPLICATE KEY UPDATE raw_marks = VALUES(raw_marks), converted_marks = VALUES(converted_marks), is_absent = 0, updated_by = VALUES(updated_by), updated_at = CURRENT_TIMESTAMP');
        foreach ($enrollments as $enrollment) {
            $upsertGrace->execute([
                ':enrollment_id' => (int)$enrollment['id'],
                ':component_id' => $graceComponentId,
                ':raw_marks' => $grace,
                ':converted_marks' => $grace,
                ':updated_by' => $userId,
            ]);
        }
    } elseif ($existingGrace) {
        $graceComponentId = (int)$existingGrace['id'];
        $pdo->prepare('DELETE FROM student_component_marks WHERE component_id = :component_id')->execute([':component_id' => $graceComponentId]);
        $pdo->prepare('DELETE FROM assessment_components WHERE id = :component_id')->execute([':component_id' => $graceComponentId]);
    }

    foreach ($enrollments as $enrollment) {
        $enrollmentId = (int)$enrollment['id'];
        urams_ensure_legacy_result($pdo, $enrollmentId);
        urams_recalculate_result($pdo, $enrollmentId);
    }

    if (function_exists('write_audit_log')) {
        write_audit_log($pdo, $userId, 'GRADE_PROCESS', 'course_sections', $sectionId, null, json_encode(['grace' => $grace, 'students' => count($enrollments)], JSON_UNESCAPED_UNICODE));
    }

    $pdo->commit();

    urams_json_response([
        'success' => true,
        'message' => 'Grade process completed successfully' . ($grace > 0 ? " with {$grace} grace mark(s)." : '.'),
        'updated' => count($enrollments),
        'grace' => $grace,
    ]);
} catch (Throwable $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    urams_json_response(['success' => false, 'message' => 'Could not process grade: ' . $e->getMessage()], 500);
}
