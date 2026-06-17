<?php
// save_marks.php
// Save marks for any assessment component using normalized tables.
// Backward compatible with current UI payload: {result_id, component, marks}.

require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/result_helpers.php';
require_role(['teacher']);

$data = urams_read_json();
if (empty($data)) {
    urams_json_response(['success' => false, 'message' => 'Invalid JSON payload.'], 400);
}

$updates = [];
if (isset($data['updates']) && is_array($data['updates'])) {
    $updates = $data['updates'];
} elseif (isset($data['result_id']) || isset($data['enrollment_id'])) {
    $updates[] = $data;
} else {
    urams_json_response(['success' => false, 'message' => 'No marks updates provided.'], 400);
}

$teacherId = (int)$_SESSION['user_id'];
$response = ['success' => true, 'updated' => [], 'skipped' => []];

try {
    $pdo->beginTransaction();

    $upsertMark = $pdo->prepare(
        'INSERT INTO student_component_marks
         (enrollment_id, component_id, raw_marks, converted_marks, is_absent, remarks, updated_by)
         VALUES (:enrollment_id, :component_id, :raw_marks, :converted_marks, :is_absent, :remarks, :updated_by)
         ON DUPLICATE KEY UPDATE
            raw_marks = VALUES(raw_marks),
            converted_marks = VALUES(converted_marks),
            is_absent = VALUES(is_absent),
            remarks = VALUES(remarks),
            updated_by = VALUES(updated_by),
            updated_at = CURRENT_TIMESTAMP'
    );

    $oldMarkStmt = $pdo->prepare(
        'SELECT raw_marks, converted_marks, is_absent, remarks
         FROM student_component_marks
         WHERE enrollment_id = :enrollment_id AND component_id = :component_id
         LIMIT 1'
    );

    foreach ($updates as $index => $item) {
        if (!is_array($item)) {
            $response['skipped'][] = ['index' => $index, 'reason' => 'Invalid update row.'];
            continue;
        }

        $lookupItem = $item;
        if (isset($data['component']) && !isset($lookupItem['component'])) {
            $lookupItem['component'] = $data['component'];
        }
        if (isset($data['component_id']) && !isset($lookupItem['component_id'])) {
            $lookupItem['component_id'] = $data['component_id'];
        }

        $enrollment = urams_fetch_enrollment_for_save($pdo, $lookupItem, $teacherId);
        if (!$enrollment) {
            $response['skipped'][] = ['index' => $index, 'reason' => 'Enrollment/result not found for this teacher.'];
            continue;
        }

        if ($enrollment['section_status'] === 'approved' || $enrollment['section_status'] === 'submitted') {
            $response['skipped'][] = ['index' => $index, 'reason' => 'Result is submitted/approved and cannot be edited.'];
            continue;
        }

        $sectionId = (int)$enrollment['section_id'];
        $component = urams_find_component($pdo, $sectionId, $lookupItem);
        if (!$component) {
            $response['skipped'][] = ['index' => $index, 'reason' => 'Component not found. Add it first.'];
            continue;
        }

        $takenOutOf = max(0.01, (float)$component['taken_out_of']);
        $convertTo = max(0.0, (float)$component['convert_to']);
        $isAbsent = !empty($item['is_absent']) ? 1 : 0;
        $remarks = isset($item['remarks']) ? trim((string)$item['remarks']) : null;

        if ($isAbsent === 1) {
            $rawMarks = 0.0;
            $convertedMarks = 0.0;
        } elseif (isset($item['raw_marks']) || isset($item['actual_marks'])) {
            $rawMarks = isset($item['raw_marks']) ? (float)$item['raw_marks'] : (float)$item['actual_marks'];
            $rawMarks = max(0.0, min($takenOutOf, $rawMarks));
            $convertedMarks = $convertTo > 0 ? round(($rawMarks / $takenOutOf) * $convertTo, 2) : 0.0;
        } else {
            $convertedMarks = isset($item['converted_marks']) ? (float)$item['converted_marks'] : (float)($item['marks'] ?? $item['ct1'] ?? 0);
            $convertedMarks = max(0.0, min($convertTo, $convertedMarks));
            $rawMarks = $convertTo > 0 ? round(($convertedMarks / $convertTo) * $takenOutOf, 2) : $convertedMarks;
        }

        $enrollmentId = (int)$enrollment['enrollment_id'];
        $componentId = (int)$component['id'];
        $oldMarkStmt->execute([
            ':enrollment_id' => $enrollmentId,
            ':component_id' => $componentId,
        ]);
        $oldMark = $oldMarkStmt->fetch(PDO::FETCH_ASSOC) ?: null;

        $upsertMark->execute([
            ':enrollment_id' => $enrollmentId,
            ':component_id' => $componentId,
            ':raw_marks' => $rawMarks,
            ':converted_marks' => $convertedMarks,
            ':is_absent' => $isAbsent,
            ':remarks' => $remarks,
            ':updated_by' => $teacherId,
        ]);

        $summary = urams_recalculate_result($pdo, $enrollmentId);
        $updated = urams_build_updated_student_payload($pdo, $enrollmentId);
        $updated['component_id'] = (int)$component['id'];
        $updated['component_key'] = $component['component_key'];
        $updated['raw_marks'] = $rawMarks;
        $updated['converted_marks'] = $convertedMarks;
        $updated['total_marks'] = $summary['total_marks'];
        $updated['grade'] = $summary['grade'];
        $updated['grade_point'] = $summary['grade_point'];
        $response['updated'][] = $updated;

        write_audit_log(
            $pdo,
            $teacherId,
            'SAVE_COMPONENT_MARK',
            'student_component_marks',
            $componentId,
            $oldMark ? json_encode($oldMark, JSON_UNESCAPED_UNICODE) : null,
            json_encode([
                'enrollment_id' => $enrollmentId,
                'component_key' => $component['component_key'],
                'raw_marks' => $rawMarks,
                'converted_marks' => $convertedMarks,
                'is_absent' => $isAbsent,
                'remarks' => $remarks,
            ], JSON_UNESCAPED_UNICODE)
        );
    }

    $pdo->commit();

    if (empty($response['updated']) && !empty($response['skipped'])) {
        $response['success'] = false;
        $response['message'] = $response['skipped'][0]['reason'];
        urams_json_response($response, 400);
    }

    $response['message'] = 'Marks saved successfully.';
    urams_json_response($response);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    urams_json_response(['success' => false, 'message' => 'Could not save marks: ' . $e->getMessage()], 500);
}
