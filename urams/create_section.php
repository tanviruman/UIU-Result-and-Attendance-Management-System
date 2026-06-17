<?php
// create_section.php
// Admin JSON endpoint: create course section with teacher and default marks components.

require_once __DIR__ . '/includes/academic_helpers.php';
require_role(['admin']);

$data = urams_admin_payload();
$courseId = urams_academic_int($data, 'course_id', 'Course');
$trimesterId = urams_academic_int($data, 'trimester_id', 'Trimester');
$teacherId = urams_academic_int($data, 'teacher_id', 'Teacher');
$sectionName = strtoupper(urams_admin_required_string($data, 'section_name', 'Section name', 10));
$capacity = max(1, min(500, (int)($data['capacity'] ?? 40)));
$room = trim((string)($data['room'] ?? ''));
$classSchedule = trim((string)($data['class_schedule'] ?? ''));
$room = substr($room, 0, 100);
$classSchedule = substr($classSchedule, 0, 255);

try {
    $pdo->beginTransaction();

    $teacher = urams_admin_require_user($pdo, $teacherId, 'teacher');

    $sectionColumns = [];
    try {
        $sectionColumns = $pdo->query('SHOW COLUMNS FROM course_sections')->fetchAll(PDO::FETCH_COLUMN);
    } catch (Throwable $ignored) {
        $sectionColumns = [];
    }

    $insertColumns = ['course_id', 'trimester_id', 'teacher_id', 'section_name', 'capacity', 'status'];
    $insertValues = [':course_id', ':trimester_id', ':teacher_id', ':section_name', ':capacity', "'running'"];
    $params = [
        ':course_id' => $courseId,
        ':trimester_id' => $trimesterId,
        ':teacher_id' => $teacherId,
        ':section_name' => $sectionName,
        ':capacity' => $capacity,
    ];
    if (in_array('room', $sectionColumns, true)) {
        $insertColumns[] = 'room';
        $insertValues[] = ':room';
        $params[':room'] = $room;
    }
    if (in_array('class_schedule', $sectionColumns, true)) {
        $insertColumns[] = 'class_schedule';
        $insertValues[] = ':class_schedule';
        $params[':class_schedule'] = $classSchedule;
    }

    $stmt = $pdo->prepare(
        'INSERT INTO course_sections (' . implode(', ', $insertColumns) . ') VALUES (' . implode(', ', $insertValues) . ')'
    );
    $stmt->execute($params);
    $sectionId = (int)$pdo->lastInsertId();

    urams_academic_create_default_components($pdo, $sectionId, (int)$_SESSION['user_id']);
    $pdo->prepare("INSERT IGNORE INTO result_submissions (section_id, status) VALUES (:section_id, 'draft')")
        ->execute([':section_id' => $sectionId]);

    write_audit_log($pdo, (int)$_SESSION['user_id'], 'CREATE_SECTION', 'course_sections', $sectionId, null, json_encode([
        'course_id' => $courseId,
        'trimester_id' => $trimesterId,
        'teacher' => $teacher['identifier'],
        'section' => $sectionName,
        'room' => $room,
        'class_schedule' => $classSchedule,
    ], JSON_UNESCAPED_UNICODE));

    $pdo->commit();
    urams_json_response(['success' => true, 'message' => 'Section created successfully.', 'section_id' => $sectionId]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    $msg = str_contains($e->getMessage(), 'Duplicate') ? 'This course section already exists for the selected trimester.' : $e->getMessage();
    urams_json_response(['success' => false, 'message' => 'Could not create section: ' . $msg], 500);
}
