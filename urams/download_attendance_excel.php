<?php
// download_attendance_excel.php
// Teacher/Admin attendance details CSV report for selected section.

require_once __DIR__ . '/includes/auth.php';
require_role(['teacher', 'admin']);

$sectionId = isset($_GET['section_id']) ? (int)$_GET['section_id'] : 0;
$classType = trim((string)($_GET['class_type'] ?? 'Regular'));
$classDate = trim((string)($_GET['class_date'] ?? ''));
if ($sectionId <= 0) {
    http_response_code(400);
    exit('Section ID is required.');
}

function urams_attendance_section(PDO $pdo, int $sectionId): array
{
    $stmt = $pdo->prepare(
        'SELECT cs.id AS section_id, cs.section_name, cs.status,
                c.course_code, c.course_name,
                tr.name AS trimester_name,
                u.full_name AS teacher_name, u.identifier AS teacher_initial
         FROM course_sections cs
         JOIN courses c ON c.id = cs.course_id
         JOIN trimesters tr ON tr.id = cs.trimester_id
         JOIN users u ON u.id = cs.teacher_id
         WHERE cs.id = :id
         LIMIT 1'
    );
    $stmt->execute([':id' => $sectionId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return $row ?: [];
}

function urams_attendance_status(?array $row): string
{
    if (!$row || $row['mark_id'] === null) {
        return 'Not Set';
    }
    if ((int)($row['is_absent'] ?? 0) === 1) {
        return 'Absent';
    }
    if ((float)($row['raw_marks'] ?? 0) > 0 || (float)($row['converted_marks'] ?? 0) > 0) {
        return 'Present';
    }
    return 'Not Set';
}

try {
    $section = urams_attendance_section($pdo, $sectionId);
    if (!$section) {
        http_response_code(404);
        exit('Section not found.');
    }

    if ($_SESSION['role'] === 'teacher') {
        $check = $pdo->prepare('SELECT id FROM course_sections WHERE id = :id AND teacher_id = :teacher_id LIMIT 1');
        $check->execute([':id' => $sectionId, ':teacher_id' => (int)$_SESSION['user_id']]);
        if (!$check->fetch()) {
            http_response_code(403);
            exit('Unauthorized section access.');
        }
    }

    $compStmt = $pdo->prepare(
        'SELECT id, component_name, taken_out_of, convert_to
         FROM assessment_components
         WHERE section_id = :section_id
           AND (component_type = "attendance" OR component_key = "attendance" OR component_name LIKE "%Attendance%")
         ORDER BY id
         LIMIT 1'
    );
    $compStmt->execute([':section_id' => $sectionId]);
    $component = $compStmt->fetch(PDO::FETCH_ASSOC) ?: null;
    $componentId = $component ? (int)$component['id'] : 0;

    $sql = 'SELECT e.id AS enrollment_id,
                   s.identifier AS student_id,
                   s.full_name AS student_name,
                   s.email,
                   scm.id AS mark_id,
                   scm.raw_marks,
                   scm.converted_marks,
                   scm.is_absent,
                   scm.remarks,
                   scm.updated_at
            FROM enrollments e
            JOIN users s ON s.id = e.student_id
            LEFT JOIN student_component_marks scm
              ON scm.enrollment_id = e.id AND scm.component_id = :component_id
            WHERE e.section_id = :section_id
            ORDER BY s.identifier';
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':component_id' => $componentId, ':section_id' => $sectionId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $filename = sprintf('attendance_%s_section_%s_%s.csv',
        preg_replace('/[^A-Za-z0-9_-]+/', '_', $section['course_code']),
        preg_replace('/[^A-Za-z0-9_-]+/', '_', $section['section_name']),
        $classDate !== '' ? preg_replace('/[^0-9-]+/', '_', $classDate) : date('Y-m-d')
    );

    header('Content-Type: text/csv; charset=UTF-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Pragma: no-cache');
    header('Expires: 0');

    echo "\xEF\xBB\xBF"; // UTF-8 BOM for Excel
    $out = fopen('php://output', 'w');
    fputcsv($out, ['URAMS Attendance Details Report']);
    fputcsv($out, ['Course', $section['course_code'] . ' - ' . $section['course_name']]);
    fputcsv($out, ['Section', $section['section_name']]);
    fputcsv($out, ['Trimester', $section['trimester_name']]);
    fputcsv($out, ['Teacher', $section['teacher_name'] . ' (' . $section['teacher_initial'] . ')']);
    fputcsv($out, ['Class Type', $classType]);
    fputcsv($out, ['Class Date', $classDate ?: date('Y-m-d')]);
    fputcsv($out, []);
    fputcsv($out, ['SL', 'Student ID', 'Student Name', 'Email', 'Course', 'Section', 'Status', 'Absent Count', 'Raw Marks', 'Converted Marks', 'Comment/Remarks', 'Last Updated']);

    $sl = 1;
    foreach ($rows as $row) {
        $status = urams_attendance_status($row);
        fputcsv($out, [
            $sl++,
            $row['student_id'],
            $row['student_name'],
            $row['email'],
            $section['course_code'],
            $section['section_name'],
            $status,
            $status === 'Absent' ? 1 : 0,
            $row['raw_marks'] !== null ? (float)$row['raw_marks'] : '',
            $row['converted_marks'] !== null ? (float)$row['converted_marks'] : '',
            $row['remarks'] ?? '',
            $row['updated_at'] ?? '',
        ]);
    }
    fclose($out);
    exit;
} catch (Throwable $e) {
    http_response_code(500);
    exit('Database error: ' . $e->getMessage());
}
