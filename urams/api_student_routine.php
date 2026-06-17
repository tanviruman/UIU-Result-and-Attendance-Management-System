<?php
// api_student_routine.php
// Returns trimester-wise class routine for logged-in student.
require_once __DIR__ . '/includes/auth.php';
require_role(['student']);
header('Content-Type: application/json; charset=utf-8');

$studentId = (int)($_SESSION['user_id'] ?? 0);
if ($studentId <= 0) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Student not authenticated.']);
    exit;
}

try {
    $hasRoom = false;
    $hasSchedule = false;
    try {
        $cols = $pdo->query("SHOW COLUMNS FROM course_sections")->fetchAll(PDO::FETCH_COLUMN);
        $hasRoom = in_array('room', $cols, true);
        $hasSchedule = in_array('class_schedule', $cols, true);
    } catch (Throwable $ignored) {}

    $roomSelect = $hasRoom ? "cs.room" : "NULL AS room";
    $scheduleSelect = $hasSchedule ? "cs.class_schedule" : "NULL AS class_schedule";

    $sql = "SELECT c.course_code, c.course_name, cs.section_name, {$roomSelect}, {$scheduleSelect},
                   t.name AS trimester_name, t.id AS trimester_id
            FROM enrollments e
            JOIN course_sections cs ON e.section_id = cs.id
            JOIN courses c ON cs.course_id = c.id
            JOIN trimesters t ON cs.trimester_id = t.id
            WHERE e.student_id = :student_id
            ORDER BY COALESCE(t.start_date, '1900-01-01') DESC, c.course_code";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':student_id' => $studentId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $routine = [];
    foreach ($rows as $r) {
        $schedule = trim((string)($r['class_schedule'] ?? ''));
        $parts = $schedule !== '' ? preg_split('/\s*;\s*/', $schedule, -1, PREG_SPLIT_NO_EMPTY) : [''];
        foreach ($parts as $part) {
            $day = null;
            $time = null;
            if (preg_match('/^([A-Za-z]{2,9})\s+(.+)$/', trim($part), $m)) {
                $day = $m[1];
                $time = $m[2];
            } elseif (trim($part) !== '') {
                $time = trim($part);
            }
            $routine[] = [
                'course_code' => $r['course_code'],
                'course_name' => $r['course_name'],
                'section' => $r['section_name'],
                'room' => $r['room'] ?? '',
                'day' => $day,
                'time' => $time ?: 'TBD',
                'trimester_id' => (int)$r['trimester_id'],
                'trimester_name' => $r['trimester_name'],
            ];
        }
    }

    echo json_encode(['success' => true, 'routine' => $routine]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Unable to load class routine.']);
}
?>
