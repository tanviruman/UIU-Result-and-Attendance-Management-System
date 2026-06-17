<?php
// includes/approved_results_helpers.php
// Shared approved-result reader for Student and Parent panels.

function urams_float($value, int $decimals = 2): string
{
    return number_format((float)($value ?? 0), $decimals, '.', '');
}

function urams_initials_from_name(string $name): string
{
    $parts = preg_split('/\s+/', trim($name), -1, PREG_SPLIT_NO_EMPTY);
    $initials = '';
    foreach ($parts as $part) {
        $initials .= strtoupper(substr($part, 0, 1));
        if (strlen($initials) >= 2) {
            break;
        }
    }
    return $initials ?: 'ST';
}

function urams_default_components_from_legacy_row(array $row): array
{
    $defaults = [
        ['component_key' => 'ct1', 'component_name' => 'CT1', 'convert_to' => 15, 'value' => $row['ct1'] ?? 0, 'best_group' => 'ct'],
        ['component_key' => 'ct2', 'component_name' => 'CT2', 'convert_to' => 15, 'value' => $row['ct2'] ?? 0, 'best_group' => 'ct'],
        ['component_key' => 'assignment', 'component_name' => 'Assignment', 'convert_to' => 10, 'value' => $row['assignment'] ?? 0, 'best_group' => null],
        ['component_key' => 'mid', 'component_name' => 'Mid', 'convert_to' => 25, 'value' => $row['mid'] ?? 0, 'best_group' => null],
        ['component_key' => 'final', 'component_name' => 'Final', 'convert_to' => 40, 'value' => $row['final'] ?? 0, 'best_group' => null],
        ['component_key' => 'attendance', 'component_name' => 'Attendance', 'convert_to' => 10, 'value' => $row['att'] ?? 0, 'best_group' => null],
    ];

    $components = [];
    foreach ($defaults as $item) {
        $components[] = [
            'component_id' => null,
            'component_key' => $item['component_key'],
            'component_name' => $item['component_name'],
            'component_type' => $item['component_key'],
            'taken_out_of' => (float)$item['convert_to'],
            'convert_to' => (float)$item['convert_to'],
            'raw_marks' => (float)$item['value'],
            'converted_marks' => (float)$item['value'],
            'is_best_of_group' => $item['best_group'] ? 1 : 0,
            'best_of_group' => $item['best_group'],
        ];
    }
    return $components;
}

function urams_fetch_approved_result_payload(PDO $pdo, int $viewerId, string $viewerRole): array
{
    if (!in_array($viewerRole, ['student', 'parent'], true)) {
        return [
            'courses' => [],
            'summary' => ['cgpa' => '0.00', 'last_gpa' => '0.00', 'trimesters' => 0, 'credits_done' => '0.0'],
            'trimester_results' => [],
            'student_profile' => null,
        ];
    }

    $where = $viewerRole === 'student' ? 'e.student_id = :viewer_id' : 'e.parent_user_id = :viewer_id';

    $sql = "SELECT
                e.id AS enrollment_id,
                e.student_id,
                su.full_name AS student_full_name,
                su.identifier AS student_identifier,
                cs.id AS section_id,
                cs.section_name,
                cs.status AS section_status,
                c.course_code,
                c.course_name,
                c.credit,
                t.name AS trimester_name,
                t.start_date AS trimester_start_date,
                tu.full_name AS teacher_name,
                tu.identifier AS teacher_identifier,
                r.ct1,
                r.ct2,
                r.best_ct,
                r.assignment,
                r.mid,
                r.final,
                r.attendance_marks AS att,
                COALESCE(ssr.total_marks, r.total_marks) AS total_marks,
                COALESCE(ssr.grade, r.grade) AS grade,
                COALESCE(ssr.grade_point, r.grade_point) AS grade_point,
                r.status AS result_status,
                COALESCE(rs.status, r.status, cs.status) AS submission_status,
                COALESCE(rs.approved_at, r.approved_at) AS approved_at
            FROM enrollments e
            JOIN users su ON su.id = e.student_id AND su.role = 'student' AND su.status = 'active'
            JOIN course_sections cs ON cs.id = e.section_id
            JOIN courses c ON c.id = cs.course_id
            JOIN trimesters t ON t.id = cs.trimester_id
            JOIN users tu ON tu.id = cs.teacher_id
            JOIN results r ON r.enrollment_id = e.id AND r.status = 'approved'
            LEFT JOIN student_section_results ssr ON ssr.enrollment_id = e.id
            LEFT JOIN result_submissions rs ON rs.section_id = cs.id
            WHERE {$where}
              AND cs.status = 'approved'
              AND COALESCE(rs.status, 'approved') = 'approved'
            ORDER BY COALESCE(t.start_date, '1900-01-01') DESC, c.course_code ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute([':viewer_id' => $viewerId]);
    $courses = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $profile = null;
    if (!empty($courses)) {
        $profile = [
            'id' => (int)$courses[0]['student_id'],
            'full_name' => $courses[0]['student_full_name'],
            'identifier' => $courses[0]['student_identifier'],
            'program' => 'BSc Program',
            'department' => 'CSE',
            'initials' => urams_initials_from_name($courses[0]['student_full_name']),
        ];
    } elseif ($viewerRole === 'student') {
        $stmt = $pdo->prepare("SELECT id, full_name, identifier FROM users WHERE id = :id AND role = 'student' LIMIT 1");
        $stmt->execute([':id' => $viewerId]);
        $student = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($student) {
            $profile = [
                'id' => (int)$student['id'],
                'full_name' => $student['full_name'],
                'identifier' => $student['identifier'],
                'program' => 'BSc Program',
                'department' => 'CSE',
                'initials' => urams_initials_from_name($student['full_name']),
            ];
        }
    } else {
        $stmt = $pdo->prepare("SELECT DISTINCT su.id, su.full_name, su.identifier
                               FROM enrollments e
                               JOIN users su ON su.id = e.student_id
                               WHERE e.parent_user_id = :parent_id AND su.role = 'student'
                               ORDER BY su.full_name ASC LIMIT 1");
        $stmt->execute([':parent_id' => $viewerId]);
        $student = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($student) {
            $profile = [
                'id' => (int)$student['id'],
                'full_name' => $student['full_name'],
                'identifier' => $student['identifier'],
                'program' => 'BSc Program',
                'department' => 'CSE',
                'initials' => urams_initials_from_name($student['full_name']),
            ];
        }
    }

    $componentsByEnrollment = [];
    $enrollmentIds = array_values(array_unique(array_map(static fn($row) => (int)$row['enrollment_id'], $courses)));

    if ($enrollmentIds) {
        $placeholders = implode(',', array_fill(0, count($enrollmentIds), '?'));
        $componentSql = "SELECT
                            e.id AS enrollment_id,
                            ac.id AS component_id,
                            ac.component_key,
                            ac.component_name,
                            ac.component_type,
                            ac.taken_out_of,
                            ac.convert_to,
                            ac.sort_order,
                            ac.is_best_of_group,
                            ac.best_of_group,
                            scm.raw_marks,
                            scm.converted_marks,
                            scm.is_absent,
                            scm.remarks
                         FROM enrollments e
                         JOIN assessment_components ac ON ac.section_id = e.section_id
                         LEFT JOIN student_component_marks scm
                           ON scm.enrollment_id = e.id AND scm.component_id = ac.id
                         WHERE e.id IN ({$placeholders})
                         ORDER BY e.id, ac.sort_order ASC, ac.id ASC";
        $componentStmt = $pdo->prepare($componentSql);
        $componentStmt->execute($enrollmentIds);
        while ($component = $componentStmt->fetch(PDO::FETCH_ASSOC)) {
            $eid = (int)$component['enrollment_id'];
            $componentsByEnrollment[$eid][] = [
                'component_id' => (int)$component['component_id'],
                'component_key' => $component['component_key'],
                'component_name' => $component['component_name'],
                'component_type' => $component['component_type'],
                'taken_out_of' => (float)$component['taken_out_of'],
                'convert_to' => (float)$component['convert_to'],
                'raw_marks' => $component['raw_marks'] === null ? null : (float)$component['raw_marks'],
                'converted_marks' => $component['converted_marks'] === null ? null : (float)$component['converted_marks'],
                'is_absent' => (int)($component['is_absent'] ?? 0),
                'remarks' => $component['remarks'],
                'is_best_of_group' => (int)$component['is_best_of_group'],
                'best_of_group' => $component['best_of_group'],
            ];
        }
    }

    foreach ($courses as &$course) {
        $eid = (int)$course['enrollment_id'];
        $course['components'] = $componentsByEnrollment[$eid] ?? urams_default_components_from_legacy_row($course);
        $course['enrollment_id'] = $eid;
        $course['section_id'] = (int)$course['section_id'];
        $course['student_id'] = (int)$course['student_id'];
        $course['credit'] = (float)$course['credit'];
        $course['total_marks'] = (float)($course['total_marks'] ?? 0);
        $course['grade_point'] = $course['grade_point'] === null ? null : (float)$course['grade_point'];
        $course['status'] = 'approved';
    }
    unset($course);

    $summary = urams_calculate_approved_summary($courses);

    return [
        'courses' => $courses,
        'summary' => $summary['summary'],
        'trimester_results' => $summary['trimester_results'],
        'student_profile' => $profile,
    ];
}

function urams_calculate_approved_summary(array $courses): array
{
    $summary = [
        'cgpa' => '0.00',
        'last_gpa' => '0.00',
        'trimesters' => 0,
        'credits_done' => '0.0',
    ];

    if (!$courses) {
        return ['summary' => $summary, 'trimester_results' => []];
    }

    $trimesterBuckets = [];
    $creditsDone = 0.0;
    $totalWeightedPoints = 0.0;
    $totalCredits = 0.0;

    foreach ($courses as $course) {
        if ($course['grade_point'] === null || $course['grade'] === null) {
            continue;
        }
        $tri = $course['trimester_name'] ?: 'Unknown Trimester';
        if (!isset($trimesterBuckets[$tri])) {
            $trimesterBuckets[$tri] = [
                'tri' => $tri,
                'start_date' => $course['trimester_start_date'] ?? null,
                'credits' => 0.0,
                'weighted_points' => 0.0,
            ];
        }
        $credit = (float)$course['credit'];
        $point = (float)$course['grade_point'];
        $trimesterBuckets[$tri]['credits'] += $credit;
        $trimesterBuckets[$tri]['weighted_points'] += ($credit * $point);
        $creditsDone += $credit;
        $totalCredits += $credit;
        $totalWeightedPoints += ($credit * $point);
    }

    $summary['trimesters'] = count($trimesterBuckets);
    $summary['credits_done'] = number_format($creditsDone, 1);
    $summary['cgpa'] = $totalCredits > 0 ? number_format($totalWeightedPoints / $totalCredits, 2) : '0.00';

    uasort($trimesterBuckets, static function ($a, $b) {
        return strcmp((string)($b['start_date'] ?? ''), (string)($a['start_date'] ?? ''));
    });

    $trimesterResults = [];
    $runningCredits = 0.0;
    $runningWeightedPoints = 0.0;
    $chronological = array_reverse($trimesterBuckets, true);
    foreach ($chronological as $bucket) {
        if ($bucket['credits'] <= 0) {
            continue;
        }
        $gpa = $bucket['weighted_points'] / $bucket['credits'];
        $runningCredits += $bucket['credits'];
        $runningWeightedPoints += $bucket['weighted_points'];
        $cgpa = $runningCredits > 0 ? $runningWeightedPoints / $runningCredits : 0.0;
        $trimesterResults[] = [
            'tri' => $bucket['tri'],
            'gpa' => (float)number_format($gpa, 2, '.', ''),
            'cgpa' => (float)number_format($cgpa, 2, '.', ''),
            'status' => 'approved',
        ];
    }

    $descendingResults = array_reverse($trimesterResults);
    if ($descendingResults) {
        $summary['last_gpa'] = number_format((float)$descendingResults[0]['gpa'], 2);
    }

    return ['summary' => $summary, 'trimester_results' => $descendingResults];
}
