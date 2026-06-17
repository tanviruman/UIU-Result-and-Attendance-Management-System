<?php
// update_component_config.php
// Update an existing assessment component configuration and recalculate saved marks.

require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/result_helpers.php';
require_role(['teacher', 'admin']);

$data = urams_read_json();
$sectionId = isset($data['section_id']) ? (int)$data['section_id'] : 0;
$componentId = isset($data['component_id']) ? (int)$data['component_id'] : 0;
$takenOutOf = isset($data['taken_out_of']) ? (float)$data['taken_out_of'] : 0.0;
$convertTo = isset($data['convert_to']) ? (float)$data['convert_to'] : 0.0;
$addGrace = isset($data['add_grace']) ? (float)$data['add_grace'] : 0.0;

if ($sectionId <= 0 || $componentId <= 0 || $takenOutOf <= 0 || $convertTo <= 0) {
    urams_json_response([
        'success' => false,
        'message' => 'section_id, component_id, taken_out_of and convert_to are required.'
    ], 400);
}

if ($addGrace < 0) {
    urams_json_response(['success' => false, 'message' => 'Grace cannot be negative.'], 400);
}

try {
    $userId = (int)($_SESSION['user_id'] ?? 0);
    $role = (string)($_SESSION['role'] ?? '');

    if ($role === 'teacher') {
        $sectionStmt = $pdo->prepare(
            'SELECT id, status FROM course_sections WHERE id = :section_id AND teacher_id = :teacher_id LIMIT 1'
        );
        $sectionStmt->execute([':section_id' => $sectionId, ':teacher_id' => $userId]);
    } else {
        $sectionStmt = $pdo->prepare('SELECT id, status FROM course_sections WHERE id = :section_id LIMIT 1');
        $sectionStmt->execute([':section_id' => $sectionId]);
    }

    $section = $sectionStmt->fetch();
    if (!$section) {
        urams_json_response(['success' => false, 'message' => 'Section not found or unauthorized.'], 403);
    }

    if (in_array((string)$section['status'], ['submitted', 'approved'], true)) {
        urams_json_response(['success' => false, 'message' => 'Submitted/approved result cannot be edited.'], 409);
    }

    $componentStmt = $pdo->prepare(
        'SELECT * FROM assessment_components WHERE id = :component_id AND section_id = :section_id LIMIT 1'
    );
    $componentStmt->execute([':component_id' => $componentId, ':section_id' => $sectionId]);
    $oldComponent = $componentStmt->fetch();

    if (!$oldComponent) {
        urams_json_response(['success' => false, 'message' => 'Component not found.'], 404);
    }

    $pdo->beginTransaction();

    $update = $pdo->prepare(
        'UPDATE assessment_components
         SET taken_out_of = :taken_out_of,
             convert_to = :convert_to,
             weight = :weight
         WHERE id = :component_id AND section_id = :section_id'
    );
    $update->execute([
        ':taken_out_of' => $takenOutOf,
        ':convert_to' => $convertTo,
        ':weight' => $convertTo,
        ':component_id' => $componentId,
        ':section_id' => $sectionId,
    ]);

    // Recalculate existing marks for this component using the new configuration.
    // Raw mark remains the teacher-entered actual mark, optionally plus grace, clamped to new taken_out_of.
    $marksStmt = $pdo->prepare(
        'SELECT scm.id, scm.enrollment_id, scm.raw_marks
         FROM student_component_marks scm
         JOIN enrollments e ON e.id = scm.enrollment_id
         WHERE scm.component_id = :component_id AND e.section_id = :section_id'
    );
    $marksStmt->execute([':component_id' => $componentId, ':section_id' => $sectionId]);
    $marksRows = $marksStmt->fetchAll();

    $markUpdate = $pdo->prepare(
        'UPDATE student_component_marks
         SET raw_marks = :raw_marks,
             converted_marks = :converted_marks,
             updated_by = :updated_by,
             updated_at = NOW()
         WHERE id = :id'
    );

    $affectedEnrollments = [];
    foreach ($marksRows as $row) {
        $raw = max(0.0, (float)$row['raw_marks'] + $addGrace);
        $raw = min($raw, $takenOutOf);
        $converted = $takenOutOf > 0 ? round(($raw / $takenOutOf) * $convertTo, 2) : 0.0;
        $converted = min($converted, $convertTo);

        $markUpdate->execute([
            ':raw_marks' => $raw,
            ':converted_marks' => $converted,
            ':updated_by' => $userId,
            ':id' => (int)$row['id'],
        ]);

        $affectedEnrollments[(int)$row['enrollment_id']] = true;
    }

    foreach (array_keys($affectedEnrollments) as $enrollmentId) {
        urams_recalculate_result($pdo, (int)$enrollmentId);
    }

    $newStmt = $pdo->prepare('SELECT * FROM assessment_components WHERE id = :component_id LIMIT 1');
    $newStmt->execute([':component_id' => $componentId]);
    $component = $newStmt->fetch();

    if (function_exists('write_audit_log')) {
        write_audit_log(
            $pdo,
            $userId,
            'UPDATE_ASSESSMENT_COMPONENT_CONFIG',
            'assessment_components',
            $componentId,
            json_encode($oldComponent, JSON_UNESCAPED_UNICODE),
            json_encode($component, JSON_UNESCAPED_UNICODE)
        );
    }

    $pdo->commit();

    $component['id'] = (int)$component['id'];
    $component['section_id'] = (int)$component['section_id'];
    $component['taken_out_of'] = (float)$component['taken_out_of'];
    $component['convert_to'] = (float)$component['convert_to'];
    $component['weight'] = (float)$component['weight'];
    $component['sort_order'] = (int)$component['sort_order'];
    $component['is_best_of_group'] = (int)$component['is_best_of_group'];

    urams_json_response([
        'success' => true,
        'message' => 'Component config updated successfully.',
        'component' => $component,
        'updated_marks' => count($marksRows),
    ]);
} catch (Throwable $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    urams_json_response(['success' => false, 'message' => 'Could not update component config: ' . $e->getMessage()], 500);
}
