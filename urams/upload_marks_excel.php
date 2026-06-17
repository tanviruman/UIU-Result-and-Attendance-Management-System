<?php
// upload_marks_excel.php
// Uploads the CSV downloaded by download_marks_excel.php and saves raw marks.

require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/result_helpers.php';

if (!is_logged_in()) {
    urams_json_response(['success' => false, 'message' => 'Login required.'], 401);
}
if (!in_array($_SESSION['role'] ?? '', ['teacher'], true)) {
    urams_json_response(['success' => false, 'message' => 'Only teachers can upload marks.'], 403);
}

$sectionId = isset($_POST['section_id']) ? (int)$_POST['section_id'] : 0;
if ($sectionId <= 0) {
    urams_json_response(['success' => false, 'message' => 'Section ID is required.'], 400);
}
if (empty($_FILES['marks_file']['tmp_name']) || !is_uploaded_file($_FILES['marks_file']['tmp_name'])) {
    urams_json_response(['success' => false, 'message' => 'Please choose the downloaded CSV/Excel file.'], 400);
}

try {
    $teacherId = (int)($_SESSION['user_id'] ?? 0);
    $sectionStmt = $pdo->prepare('SELECT id, status FROM course_sections WHERE id = :section_id AND teacher_id = :teacher_id LIMIT 1');
    $sectionStmt->execute([':section_id' => $sectionId, ':teacher_id' => $teacherId]);
    $section = $sectionStmt->fetch();
    if (!$section) {
        urams_json_response(['success' => false, 'message' => 'Section not found or unauthorized.'], 404);
    }
    if (in_array((string)$section['status'], ['submitted', 'approved'], true)) {
        urams_json_response(['success' => false, 'message' => 'Submitted/approved result cannot be edited.'], 409);
    }

    $originalName = (string)($_FILES['marks_file']['name'] ?? '');
    $ext = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
    if ($ext === 'xlsx') {
        urams_json_response(['success' => false, 'message' => 'Upload the same CSV file downloaded from this page. If you edit it in Excel, use Save As -> CSV, not XLSX.'], 400);
    }
    if (!in_array($ext, ['csv', 'txt', 'xls'], true)) {
        urams_json_response(['success' => false, 'message' => 'Only CSV format is supported for upload. Download CSV (Excel), edit it, then upload the CSV file again.'], 400);
    }

    urams_ensure_default_components($pdo, $sectionId, $teacherId);
    urams_migrate_legacy_marks_for_section($pdo, $sectionId, $teacherId);
    $components = urams_get_components($pdo, $sectionId);
    $componentByKey = [];
    foreach ($components as $component) {
        $componentByKey[(string)$component['component_key']] = $component;
    }

    $studentStmt = $pdo->prepare(
        'SELECT e.id AS enrollment_id, u.identifier AS student_id
         FROM enrollments e
         JOIN users u ON u.id = e.student_id
         WHERE e.section_id = :section_id'
    );
    $studentStmt->execute([':section_id' => $sectionId]);
    $studentByIdentifier = [];
    foreach ($studentStmt->fetchAll() as $row) {
        $studentByIdentifier[(string)$row['student_id']] = (int)$row['enrollment_id'];
    }

    $handle = fopen($_FILES['marks_file']['tmp_name'], 'r');
    if (!$handle) {
        urams_json_response(['success' => false, 'message' => 'Could not read uploaded file.'], 400);
    }

    $header = null;
    while (($row = fgetcsv($handle)) !== false) {
        if (!$row || count(array_filter($row, fn($v) => trim((string)$v) !== '')) === 0) {
            continue;
        }
        $first = preg_replace('/^\xEF\xBB\xBF/', '', trim((string)($row[0] ?? '')));
        if (strcasecmp($first, 'Student ID') === 0) {
            $header = $row;
            break;
        }
    }
    if (!$header) {
        fclose($handle);
        urams_json_response(['success' => false, 'message' => 'Could not find the Student ID header. Use the downloaded CSV format.'], 400);
    }

    $componentColumns = [];
    foreach ($header as $idx => $label) {
        if ($idx < 2) {
            continue;
        }
        $text = trim((string)$label);
        if (in_array(strtolower($text), ['total', 'grade', 'grade point'], true)) {
            continue;
        }
        $key = '';
        if (preg_match('/\[([^\]]+)\]/', $text, $m)) {
            $key = trim($m[1]);
        } else {
            $key = urams_component_key($text);
        }
        if ($key !== '' && isset($componentByKey[$key])) {
            $componentColumns[$idx] = $componentByKey[$key];
        }
    }
    if (!$componentColumns) {
        fclose($handle);
        urams_json_response(['success' => false, 'message' => 'No valid assessment columns found in uploaded file.'], 400);
    }

    $upsertMark = $pdo->prepare(
        'INSERT INTO student_component_marks
         (enrollment_id, component_id, raw_marks, converted_marks, is_absent, updated_by)
         VALUES (:enrollment_id, :component_id, :raw_marks, :converted_marks, 0, :updated_by)
         ON DUPLICATE KEY UPDATE
            raw_marks = VALUES(raw_marks),
            converted_marks = VALUES(converted_marks),
            is_absent = 0,
            updated_by = VALUES(updated_by),
            updated_at = CURRENT_TIMESTAMP'
    );

    $pdo->beginTransaction();
    $updatedRows = 0;
    $skippedRows = 0;
    $affectedEnrollments = [];

    while (($row = fgetcsv($handle)) !== false) {
        if (!$row || count(array_filter($row, fn($v) => trim((string)$v) !== '')) === 0) {
            continue;
        }
        $studentIdentifier = preg_replace('/^\xEF\xBB\xBF/', '', trim((string)($row[0] ?? '')));
        if ($studentIdentifier === '' || !isset($studentByIdentifier[$studentIdentifier])) {
            $skippedRows++;
            continue;
        }
        $enrollmentId = $studentByIdentifier[$studentIdentifier];
        $rowHadUpdate = false;
        foreach ($componentColumns as $idx => $component) {
            if (!array_key_exists($idx, $row)) {
                continue;
            }
            $cell = trim((string)$row[$idx]);
            if ($cell === '') {
                continue;
            }
            $raw = (float)$cell;
            $takenOutOf = max(0.01, (float)$component['taken_out_of']);
            $convertTo = max(0.0, (float)$component['convert_to']);
            $raw = max(0.0, min($takenOutOf, $raw));
            $converted = $convertTo > 0 ? round(($raw / $takenOutOf) * $convertTo, 2) : 0.0;

            $upsertMark->execute([
                ':enrollment_id' => $enrollmentId,
                ':component_id' => (int)$component['id'],
                ':raw_marks' => $raw,
                ':converted_marks' => $converted,
                ':updated_by' => $teacherId,
            ]);
            $rowHadUpdate = true;
        }
        if ($rowHadUpdate) {
            $affectedEnrollments[$enrollmentId] = true;
            $updatedRows++;
        }
    }
    fclose($handle);

    foreach (array_keys($affectedEnrollments) as $enrollmentId) {
        urams_ensure_legacy_result($pdo, (int)$enrollmentId);
        urams_recalculate_result($pdo, (int)$enrollmentId);
    }

    if (function_exists('write_audit_log')) {
        write_audit_log($pdo, $teacherId, 'UPLOAD_MARKS_EXCEL', 'course_sections', $sectionId, null, json_encode(['updated_rows' => $updatedRows, 'skipped_rows' => $skippedRows], JSON_UNESCAPED_UNICODE));
    }

    $pdo->commit();

    urams_json_response([
        'success' => true,
        'message' => "Excel/CSV marks uploaded. Updated {$updatedRows} student row(s).",
        'updated_rows' => $updatedRows,
        'skipped_rows' => $skippedRows,
    ]);
} catch (Throwable $e) {
    if (isset($handle) && is_resource($handle)) {
        fclose($handle);
    }
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    urams_json_response(['success' => false, 'message' => 'Could not upload Excel file: ' . $e->getMessage()], 500);
}
