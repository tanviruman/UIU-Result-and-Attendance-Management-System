<?php
// download_marks_excel.php
// Downloads current section marks as CSV that opens in Excel.

require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/result_helpers.php';

if (!is_logged_in()) {
    urams_json_response(['success' => false, 'message' => 'Login required.'], 401);
}
if (!in_array($_SESSION['role'] ?? '', ['teacher', 'admin'], true)) {
    urams_json_response(['success' => false, 'message' => 'You do not have permission.'], 403);
}

$sectionId = isset($_GET['section_id']) ? (int)$_GET['section_id'] : 0;
if ($sectionId <= 0) {
    urams_json_response(['success' => false, 'message' => 'Section ID is required.'], 400);
}

try {
    $userId = (int)($_SESSION['user_id'] ?? 0);
    $role = (string)($_SESSION['role'] ?? '');

    if ($role === 'teacher') {
        $sectionStmt = $pdo->prepare(
            'SELECT cs.id, cs.section_name, c.course_code, c.course_name, t.name AS trimester_name
             FROM course_sections cs
             JOIN courses c ON c.id = cs.course_id
             JOIN trimesters t ON t.id = cs.trimester_id
             WHERE cs.id = :section_id AND cs.teacher_id = :teacher_id
             LIMIT 1'
        );
        $sectionStmt->execute([':section_id' => $sectionId, ':teacher_id' => $userId]);
    } else {
        $sectionStmt = $pdo->prepare(
            'SELECT cs.id, cs.section_name, c.course_code, c.course_name, t.name AS trimester_name
             FROM course_sections cs
             JOIN courses c ON c.id = cs.course_id
             JOIN trimesters t ON t.id = cs.trimester_id
             WHERE cs.id = :section_id
             LIMIT 1'
        );
        $sectionStmt->execute([':section_id' => $sectionId]);
    }
    $section = $sectionStmt->fetch();
    if (!$section) {
        urams_json_response(['success' => false, 'message' => 'Section not found or unauthorized.'], 404);
    }

    urams_ensure_default_components($pdo, $sectionId, $userId);
    urams_migrate_legacy_marks_for_section($pdo, $sectionId, $userId);
    $components = urams_get_components($pdo, $sectionId);

    $studentsStmt = $pdo->prepare(
        'SELECT e.id AS enrollment_id, u.identifier AS student_id, u.full_name AS student_name,
                COALESCE(ssr.total_marks, r.total_marks, 0) AS total_marks,
                COALESCE(ssr.grade, r.grade, "-") AS grade
         FROM enrollments e
         JOIN users u ON u.id = e.student_id
         LEFT JOIN results r ON r.enrollment_id = e.id
         LEFT JOIN student_section_results ssr ON ssr.enrollment_id = e.id
         WHERE e.section_id = :section_id
         ORDER BY u.identifier, u.full_name'
    );
    $studentsStmt->execute([':section_id' => $sectionId]);
    $students = $studentsStmt->fetchAll();

    $marksStmt = $pdo->prepare(
        'SELECT scm.enrollment_id, ac.component_key, scm.raw_marks
         FROM student_component_marks scm
         JOIN assessment_components ac ON ac.id = scm.component_id
         JOIN enrollments e ON e.id = scm.enrollment_id
         WHERE e.section_id = :section_id'
    );
    $marksStmt->execute([':section_id' => $sectionId]);
    $marksMap = [];
    foreach ($marksStmt->fetchAll() as $row) {
        $marksMap[(int)$row['enrollment_id']][(string)$row['component_key']] = (float)$row['raw_marks'];
    }

    $safeName = preg_replace('/[^A-Za-z0-9_-]+/', '_', (string)$section['course_code'] . '_' . (string)$section['section_name']);
    $filename = 'URAMS_Marks_' . $safeName . '.csv';

    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Pragma: no-cache');
    header('Expires: 0');

    $out = fopen('php://output', 'w');
    // UTF-8 BOM helps Excel open Bangla/Unicode text correctly.
    fwrite($out, "\xEF\xBB\xBF");

    fputcsv($out, ['URAMS Marks Sheet']);
    fputcsv($out, ['Course', $section['course_code'] . ' - ' . $section['course_name']]);
    fputcsv($out, ['Trimester', $section['trimester_name']]);
    fputcsv($out, ['Section', $section['section_name']]);
    fputcsv($out, []);

    $header = ['Student ID', 'Student Name'];
    foreach ($components as $component) {
        $header[] = $component['component_name'] . ' [' . $component['component_key'] . ']';
    }
    $header[] = 'Total';
    $header[] = 'Grade';
    fputcsv($out, $header);

    foreach ($students as $student) {
        $enrollmentId = (int)$student['enrollment_id'];
        $row = [$student['student_id'], $student['student_name']];
        foreach ($components as $component) {
            $key = (string)$component['component_key'];
            $row[] = isset($marksMap[$enrollmentId][$key]) ? number_format((float)$marksMap[$enrollmentId][$key], 2, '.', '') : '0.00';
        }
        $row[] = number_format((float)$student['total_marks'], 2, '.', '');
        $row[] = $student['grade'];
        fputcsv($out, $row);
    }
    fclose($out);
    exit;
} catch (Throwable $e) {
    urams_json_response(['success' => false, 'message' => 'Could not download Excel file: ' . $e->getMessage()], 500);
}
