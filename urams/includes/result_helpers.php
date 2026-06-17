<?php
// includes/result_helpers.php
// Shared backend helpers for normalized result/marks endpoints.

function urams_json_response(array $payload, int $statusCode = 200): void
{
    http_response_code($statusCode);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

function urams_read_json(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }

    $data = json_decode($raw, true);
    if (!is_array($data)) {
        urams_json_response(['success' => false, 'message' => 'Invalid JSON payload.'], 400);
    }

    return $data;
}

function urams_component_key(string $value): string
{
    $value = strtolower(trim($value));
    $value = str_replace(['attendance_marks', 'mid term', 'mid-term', 'final exam'], ['attendance', 'mid', 'mid', 'final'], $value);
    $value = preg_replace('/[^a-z0-9]+/', '_', $value);
    $value = trim((string)$value, '_');
    return $value !== '' ? $value : 'custom';
}

function urams_component_type(string $value): string
{
    $key = urams_component_key($value);

    if (preg_match('/^ct_?\d*$/', $key) || preg_match('/^class_test_?\d*$/', $key)) {
        return 'ct';
    }
    if (preg_match('/^assignment_?\d*$/', $key) || preg_match('/^assign_?\d*$/', $key)) {
        return 'assignment';
    }
    if (preg_match('/^quiz_?\d*$/', $key)) {
        return 'quiz';
    }
    if (preg_match('/^mid(_term)?_?\d*$/', $key)) {
        return 'mid';
    }
    if (preg_match('/^final(_exam)?_?\d*$/', $key)) {
        return 'final';
    }
    if (preg_match('/^attendance(_marks)?_?\d*$/', $key)) {
        return 'attendance';
    }

    $map = [
        'ct1' => 'ct',
        'ct2' => 'ct',
        'ct' => 'ct',
        'class_test' => 'ct',
        'assignment' => 'assignment',
        'assign' => 'assignment',
        'quiz' => 'quiz',
        'mid' => 'mid',
        'mid_term' => 'mid',
        'final' => 'final',
        'final_exam' => 'final',
        'attendance' => 'attendance',
        'attendance_marks' => 'attendance',
        'lab' => 'lab',
        'lab_report' => 'lab',
        'presentation' => 'presentation',
        'report' => 'custom',
    ];

    return $map[$key] ?? 'custom';
}

function urams_component_group_rank(string $componentType): int
{
    $ranks = [
        'ct' => 10,
        'quiz' => 20,
        'assignment' => 30,
        'mid' => 40,
        'final' => 50,
        'attendance' => 60,
        'lab' => 70,
        'presentation' => 80,
        'custom' => 90,
    ];

    return $ranks[$componentType] ?? 90;
}

function urams_component_group_key(array $component): string
{
    $type = (string)($component['component_type'] ?? 'custom');
    $bestGroup = trim((string)($component['best_of_group'] ?? ''));

    if (in_array($type, ['ct', 'assignment', 'mid', 'final', 'attendance'], true)) {
        return $type;
    }

    if ((int)($component['is_best_of_group'] ?? 0) === 1 && $bestGroup !== '') {
        return $bestGroup;
    }

    return 'single:' . (string)($component['component_key'] ?? $component['id'] ?? uniqid('component_', true));
}

function urams_group_uses_best(string $groupKey): bool
{
    return in_array($groupKey, ['ct', 'assignment', 'mid', 'final', 'attendance'], true)
        || strpos($groupKey, 'best_') === 0;
}

function urams_default_components(): array
{
    return [
        ['component_key' => 'ct1', 'component_name' => 'CT1', 'component_type' => 'ct', 'taken_out_of' => 30, 'convert_to' => 15, 'weight' => 15, 'sort_order' => 1, 'is_best_of_group' => 1, 'best_of_group' => 'ct'],
        ['component_key' => 'ct2', 'component_name' => 'CT2', 'component_type' => 'ct', 'taken_out_of' => 30, 'convert_to' => 15, 'weight' => 15, 'sort_order' => 2, 'is_best_of_group' => 1, 'best_of_group' => 'ct'],
        ['component_key' => 'assignment', 'component_name' => 'Assignment', 'component_type' => 'assignment', 'taken_out_of' => 10, 'convert_to' => 10, 'weight' => 10, 'sort_order' => 3, 'is_best_of_group' => 0, 'best_of_group' => null],
        ['component_key' => 'mid', 'component_name' => 'Mid Term', 'component_type' => 'mid', 'taken_out_of' => 50, 'convert_to' => 25, 'weight' => 25, 'sort_order' => 4, 'is_best_of_group' => 0, 'best_of_group' => null],
        ['component_key' => 'final', 'component_name' => 'Final Exam', 'component_type' => 'final', 'taken_out_of' => 80, 'convert_to' => 40, 'weight' => 40, 'sort_order' => 5, 'is_best_of_group' => 0, 'best_of_group' => null],
        ['component_key' => 'attendance', 'component_name' => 'Attendance', 'component_type' => 'attendance', 'taken_out_of' => 10, 'convert_to' => 10, 'weight' => 10, 'sort_order' => 6, 'is_best_of_group' => 0, 'best_of_group' => null],
    ];
}

function urams_ensure_default_components(PDO $pdo, int $sectionId, ?int $userId = null): void
{
    // Important: older sections may already have CT/Mid/Final components but miss Attendance.
    // So do NOT return when COUNT(*) > 0. Insert each default component safely if it is missing.
    $insert = $pdo->prepare(
        'INSERT IGNORE INTO assessment_components
         (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group, created_by)
         VALUES
         (:section_id, :component_key, :component_name, :component_type, :taken_out_of, :convert_to, :weight, :sort_order, :is_best_of_group, :best_of_group, :created_by)'
    );

    foreach (urams_default_components() as $component) {
        $insert->execute([
            ':section_id' => $sectionId,
            ':component_key' => $component['component_key'],
            ':component_name' => $component['component_name'],
            ':component_type' => $component['component_type'],
            ':taken_out_of' => $component['taken_out_of'],
            ':convert_to' => $component['convert_to'],
            ':weight' => $component['weight'],
            ':sort_order' => $component['sort_order'],
            ':is_best_of_group' => $component['is_best_of_group'],
            ':best_of_group' => $component['best_of_group'],
            ':created_by' => $userId,
        ]);
    }
}

function urams_get_components(PDO $pdo, int $sectionId): array
{
    $stmt = $pdo->prepare(
        'SELECT id, section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight,
                sort_order, is_best_of_group, best_of_group, exam_date
         FROM assessment_components
         WHERE section_id = :section_id
         ORDER BY
           CASE component_type
             WHEN "ct" THEN 10
             WHEN "quiz" THEN 20
             WHEN "assignment" THEN 30
             WHEN "mid" THEN 40
             WHEN "final" THEN 50
             WHEN "attendance" THEN 60
             WHEN "lab" THEN 70
             WHEN "presentation" THEN 80
             ELSE 90
           END,
           sort_order,
           id'
    );
    $stmt->execute([':section_id' => $sectionId]);
    $components = $stmt->fetchAll();

    foreach ($components as &$component) {
        $component['id'] = (int)$component['id'];
        $component['section_id'] = (int)$component['section_id'];
        $component['taken_out_of'] = (float)$component['taken_out_of'];
        $component['convert_to'] = (float)$component['convert_to'];
        $component['weight'] = (float)$component['weight'];
        $component['sort_order'] = (int)$component['sort_order'];
        $component['is_best_of_group'] = (int)$component['is_best_of_group'];
    }
    unset($component);

    return $components;
}

function urams_find_component(PDO $pdo, int $sectionId, array $data): ?array
{
    urams_ensure_default_components($pdo, $sectionId, isset($_SESSION['user_id']) ? (int)$_SESSION['user_id'] : null);

    if (!empty($data['component_id'])) {
        $stmt = $pdo->prepare('SELECT * FROM assessment_components WHERE id = :id AND section_id = :section_id LIMIT 1');
        $stmt->execute([':id' => (int)$data['component_id'], ':section_id' => $sectionId]);
        $component = $stmt->fetch();
        return $component ?: null;
    }

    $raw = trim((string)($data['component'] ?? $data['component_key'] ?? $data['component_name'] ?? ''));
    if ($raw === '') {
        return null;
    }

    $key = urams_component_key($raw);
    $stmt = $pdo->prepare(
        'SELECT * FROM assessment_components
         WHERE section_id = :section_id AND (component_key = :component_key OR LOWER(component_name) = LOWER(:component_name))
         LIMIT 1'
    );
    $stmt->execute([
        ':section_id' => $sectionId,
        ':component_key' => $key,
        ':component_name' => $raw,
    ]);

    $component = $stmt->fetch();
    return $component ?: null;
}

function urams_ensure_legacy_result(PDO $pdo, int $enrollmentId): int
{
    $stmt = $pdo->prepare('SELECT id FROM results WHERE enrollment_id = :enrollment_id LIMIT 1');
    $stmt->execute([':enrollment_id' => $enrollmentId]);
    $row = $stmt->fetch();
    if ($row) {
        return (int)$row['id'];
    }

    $insert = $pdo->prepare('INSERT INTO results (enrollment_id, status) VALUES (:enrollment_id, :status)');
    $insert->execute([':enrollment_id' => $enrollmentId, ':status' => 'draft']);
    return (int)$pdo->lastInsertId();
}

function urams_get_grade(PDO $pdo, float $total): array
{
    try {
        $stmt = $pdo->prepare(
            'SELECT grade, grade_point
             FROM grade_rules
             WHERE is_active = 1 AND :total BETWEEN min_mark AND max_mark
             ORDER BY min_mark DESC
             LIMIT 1'
        );
        $stmt->execute([':total' => $total]);
        $row = $stmt->fetch();
        if ($row) {
            return ['grade' => $row['grade'], 'point' => (float)$row['grade_point']];
        }
    } catch (Throwable $e) {
        // Fallback below keeps the endpoint alive if grade_rules has not been imported yet.
    }

    if ($total >= 90) return ['grade' => 'A+', 'point' => 4.00];
    if ($total >= 85) return ['grade' => 'A', 'point' => 3.75];
    if ($total >= 80) return ['grade' => 'A-', 'point' => 3.50];
    if ($total >= 75) return ['grade' => 'B+', 'point' => 3.25];
    if ($total >= 70) return ['grade' => 'B', 'point' => 3.00];
    if ($total >= 65) return ['grade' => 'B-', 'point' => 2.75];
    if ($total >= 60) return ['grade' => 'C+', 'point' => 2.50];
    if ($total >= 55) return ['grade' => 'C', 'point' => 2.25];
    if ($total >= 50) return ['grade' => 'D', 'point' => 2.00];
    return ['grade' => 'F', 'point' => 0.00];
}

function urams_recalculate_result(PDO $pdo, int $enrollmentId): array
{
    $stmt = $pdo->prepare(
        'SELECT ac.id,
                ac.component_key,
                ac.component_name,
                ac.component_type,
                ac.convert_to,
                ac.weight,
                ac.is_best_of_group,
                ac.best_of_group,
                scm.converted_marks
         FROM student_component_marks scm
         JOIN assessment_components ac ON ac.id = scm.component_id
         WHERE scm.enrollment_id = :enrollment_id
         ORDER BY
           CASE ac.component_type
             WHEN "ct" THEN 10
             WHEN "quiz" THEN 20
             WHEN "assignment" THEN 30
             WHEN "mid" THEN 40
             WHEN "final" THEN 50
             WHEN "attendance" THEN 60
             WHEN "lab" THEN 70
             WHEN "presentation" THEN 80
             ELSE 90
           END,
           ac.sort_order,
           ac.id'
    );
    $stmt->execute([':enrollment_id' => $enrollmentId]);
    $marks = $stmt->fetchAll();

    $groups = [];
    foreach ($marks as $mark) {
        $converted = max(0.0, (float)($mark['converted_marks'] ?? 0));
        $groupKey = urams_component_group_key($mark);
        $cap = (float)($mark['weight'] ?: $mark['convert_to'] ?: 0);

        if (!isset($groups[$groupKey])) {
            $groups[$groupKey] = [
                'values' => [],
                'sum' => 0.0,
                'cap' => 0.0,
                'use_best' => urams_group_uses_best($groupKey),
            ];
        }

        $groups[$groupKey]['values'][] = $converted;
        $groups[$groupKey]['sum'] += $converted;
        $groups[$groupKey]['cap'] = max($groups[$groupKey]['cap'], $cap);
    }

    $normalTotal = 0.0;
    foreach ($groups as $group) {
        if ($group['use_best']) {
            $part = empty($group['values']) ? 0.0 : max($group['values']);
        } else {
            $part = $group['sum'];
        }

        if ($group['cap'] > 0) {
            $part = min($part, (float)$group['cap']);
        }

        $normalTotal += $part;
    }

    // Result sheet total must never exceed 100 even after teachers add extra DB components.
    $total = round(min(100.0, max(0.0, $normalTotal)), 2);
    $grade = urams_get_grade($pdo, $total);

    $upsert = $pdo->prepare(
        'INSERT INTO student_section_results (enrollment_id, total_marks, grade, grade_point, calculated_at)
         VALUES (:enrollment_id, :total_marks, :grade, :grade_point, NOW())
         ON DUPLICATE KEY UPDATE
            total_marks = VALUES(total_marks),
            grade = VALUES(grade),
            grade_point = VALUES(grade_point),
            calculated_at = NOW()'
    );
    $upsert->execute([
        ':enrollment_id' => $enrollmentId,
        ':total_marks' => $total,
        ':grade' => $grade['grade'],
        ':grade_point' => $grade['point'],
    ]);

    urams_sync_legacy_result($pdo, $enrollmentId, $total, $grade['grade'], $grade['point']);

    return [
        'total_marks' => $total,
        'grade' => $grade['grade'],
        'grade_point' => $grade['point'],
    ];
}

function urams_get_component_mark_map(PDO $pdo, int $enrollmentId): array
{
    $stmt = $pdo->prepare(
        'SELECT ac.id AS component_id,
                ac.component_key,
                ac.component_type,
                scm.raw_marks,
                scm.converted_marks,
                scm.is_absent,
                scm.remarks
         FROM assessment_components ac
         LEFT JOIN student_component_marks scm
           ON scm.component_id = ac.id AND scm.enrollment_id = :mark_enrollment_id
         JOIN enrollments e ON e.section_id = ac.section_id
         WHERE e.id = :join_enrollment_id
         ORDER BY
           CASE ac.component_type
             WHEN "ct" THEN 10
             WHEN "quiz" THEN 20
             WHEN "assignment" THEN 30
             WHEN "mid" THEN 40
             WHEN "final" THEN 50
             WHEN "attendance" THEN 60
             WHEN "lab" THEN 70
             WHEN "presentation" THEN 80
             ELSE 90
           END,
           ac.sort_order,
           ac.id'
    );
    $stmt->execute([
        ':mark_enrollment_id' => $enrollmentId,
        ':join_enrollment_id' => $enrollmentId,
    ]);

    $map = [];
    foreach ($stmt->fetchAll() as $row) {
        $key = $row['component_key'];
        $map[$key] = [
            'component_id' => (int)$row['component_id'],
            'component_type' => $row['component_type'],
            'raw_marks' => $row['raw_marks'] === null ? 0.0 : (float)$row['raw_marks'],
            'converted_marks' => $row['converted_marks'] === null ? 0.0 : (float)$row['converted_marks'],
            'is_absent' => (int)($row['is_absent'] ?? 0),
            'remarks' => $row['remarks'],
        ];
    }

    return $map;
}

function urams_sync_legacy_result(PDO $pdo, int $enrollmentId, ?float $total = null, ?string $grade = null, ?float $gradePoint = null): void
{
    $legacyId = urams_ensure_legacy_result($pdo, $enrollmentId);
    $markMap = urams_get_component_mark_map($pdo, $enrollmentId);

    $ctValues = [];
    $assignmentValues = [];
    $midValues = [];
    $finalValues = [];
    $attendanceValues = [];

    foreach ($markMap as $key => $mark) {
        $type = (string)($mark['component_type'] ?? 'custom');
        $value = (float)($mark['converted_marks'] ?? 0);
        if ($type === 'ct') {
            $ctValues[$key] = $value;
        } elseif ($type === 'assignment') {
            $assignmentValues[$key] = $value;
        } elseif ($type === 'mid') {
            $midValues[$key] = $value;
        } elseif ($type === 'final') {
            $finalValues[$key] = $value;
        } elseif ($type === 'attendance') {
            $attendanceValues[$key] = $value;
        }
    }

    $ct1 = (float)($markMap['ct1']['converted_marks'] ?? 0);
    $ct2 = (float)($markMap['ct2']['converted_marks'] ?? 0);
    $assignment = $assignmentValues ? max($assignmentValues) : (float)($markMap['assignment']['converted_marks'] ?? 0);
    $mid = $midValues ? max($midValues) : (float)($markMap['mid']['converted_marks'] ?? 0);
    $final = $finalValues ? max($finalValues) : (float)($markMap['final']['converted_marks'] ?? 0);
    $attendance = $attendanceValues ? max($attendanceValues) : (float)($markMap['attendance']['converted_marks'] ?? $markMap['attendance_marks']['converted_marks'] ?? 0);
    $bestCt = $ctValues ? max($ctValues) : max($ct1, $ct2);

    if ($total === null || $grade === null || $gradePoint === null) {
        $stmt = $pdo->prepare('SELECT total_marks, grade, grade_point FROM student_section_results WHERE enrollment_id = :enrollment_id LIMIT 1');
        $stmt->execute([':enrollment_id' => $enrollmentId]);
        $summary = $stmt->fetch();
        $total = $summary ? (float)$summary['total_marks'] : min(100.0, ($bestCt + $assignment + $mid + $final + $attendance));
        $gradeInfo = $summary && $summary['grade'] !== null ? ['grade' => $summary['grade'], 'point' => (float)$summary['grade_point']] : urams_get_grade($pdo, (float)$total);
        $grade = $gradeInfo['grade'];
        $gradePoint = $gradeInfo['point'];
    }

    $update = $pdo->prepare(
        'UPDATE results
         SET ct1 = :ct1,
             ct2 = :ct2,
             best_ct = :best_ct,
             assignment = :assignment,
             mid = :mid,
             final = :final,
             attendance_marks = :attendance_marks,
             total_marks = :total_marks,
             grade = :grade,
             grade_point = :grade_point
         WHERE id = :id'
    );
    $update->execute([
        ':ct1' => $ct1,
        ':ct2' => $ct2,
        ':best_ct' => $bestCt,
        ':assignment' => $assignment,
        ':mid' => $mid,
        ':final' => $final,
        ':attendance_marks' => $attendance,
        ':total_marks' => min(100.0, (float)$total),
        ':grade' => $grade,
        ':grade_point' => $gradePoint,
        ':id' => $legacyId,
    ]);
}

function urams_migrate_legacy_marks_for_section(PDO $pdo, int $sectionId, ?int $userId = null): void
{
    $components = urams_get_components($pdo, $sectionId);
    $byKey = [];
    foreach ($components as $component) {
        $byKey[$component['component_key']] = $component;
    }

    $stmt = $pdo->prepare(
        'SELECT r.enrollment_id, r.ct1, r.ct2, r.assignment, r.mid, r.final, r.attendance_marks
         FROM results r
         JOIN enrollments e ON e.id = r.enrollment_id
         WHERE e.section_id = :section_id'
    );
    $stmt->execute([':section_id' => $sectionId]);

    $insert = $pdo->prepare(
        'INSERT INTO student_component_marks
         (enrollment_id, component_id, raw_marks, converted_marks, updated_by)
         VALUES (:enrollment_id, :component_id, :raw_marks, :converted_marks, :updated_by)
         ON DUPLICATE KEY UPDATE
            raw_marks = raw_marks,
            converted_marks = converted_marks'
    );

    $legacyMap = [
        'ct1' => 'ct1',
        'ct2' => 'ct2',
        'assignment' => 'assignment',
        'mid' => 'mid',
        'final' => 'final',
        'attendance_marks' => 'attendance',
    ];

    foreach ($stmt->fetchAll() as $row) {
        foreach ($legacyMap as $column => $componentKey) {
            if (!isset($byKey[$componentKey])) {
                continue;
            }
            $converted = (float)$row[$column];
            if ($converted <= 0) {
                continue;
            }
            $component = $byKey[$componentKey];
            $convertTo = (float)$component['convert_to'];
            $takenOutOf = (float)$component['taken_out_of'];
            $raw = $convertTo > 0 ? round(($converted / $convertTo) * $takenOutOf, 2) : $converted;

            $insert->execute([
                ':enrollment_id' => (int)$row['enrollment_id'],
                ':component_id' => (int)$component['id'],
                ':raw_marks' => $raw,
                ':converted_marks' => $converted,
                ':updated_by' => $userId,
            ]);
        }
        urams_recalculate_result($pdo, (int)$row['enrollment_id']);
    }
}

function urams_fetch_enrollment_for_save(PDO $pdo, array $item, int $teacherId): ?array
{
    if (!empty($item['enrollment_id'])) {
        $stmt = $pdo->prepare(
            'SELECT e.id AS enrollment_id, e.section_id, cs.status AS section_status
             FROM enrollments e
             JOIN course_sections cs ON cs.id = e.section_id
             WHERE e.id = :enrollment_id AND cs.teacher_id = :teacher_id
             LIMIT 1'
        );
        $stmt->execute([':enrollment_id' => (int)$item['enrollment_id'], ':teacher_id' => $teacherId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    if (!empty($item['result_id'])) {
        $stmt = $pdo->prepare(
            'SELECT r.id AS result_id, r.enrollment_id, e.section_id, cs.status AS section_status
             FROM results r
             JOIN enrollments e ON e.id = r.enrollment_id
             JOIN course_sections cs ON cs.id = e.section_id
             WHERE r.id = :result_id AND cs.teacher_id = :teacher_id
             LIMIT 1'
        );
        $stmt->execute([':result_id' => (int)$item['result_id'], ':teacher_id' => $teacherId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    return null;
}

function urams_build_updated_student_payload(PDO $pdo, int $enrollmentId): array
{
    $stmt = $pdo->prepare(
        'SELECT r.id AS result_id, r.enrollment_id, r.ct1, r.ct2, r.best_ct, r.assignment, r.mid, r.final,
                r.attendance_marks, r.total_marks, r.grade, r.grade_point
         FROM results r
         WHERE r.enrollment_id = :enrollment_id
         LIMIT 1'
    );
    $stmt->execute([':enrollment_id' => $enrollmentId]);
    $row = $stmt->fetch();

    return [
        'result_id' => (int)$row['result_id'],
        'enrollment_id' => (int)$row['enrollment_id'],
        'ct1' => (float)$row['ct1'],
        'ct2' => (float)$row['ct2'],
        'assignment' => (float)$row['assignment'],
        'mid' => (float)$row['mid'],
        'final' => (float)$row['final'],
        'attendance_marks' => (float)$row['attendance_marks'],
        'best_ct' => (float)$row['best_ct'],
        'total_marks' => (float)$row['total_marks'],
        'grade' => $row['grade'],
        'grade_point' => (float)$row['grade_point'],
    ];
}
