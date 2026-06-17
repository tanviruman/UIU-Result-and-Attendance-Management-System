<?php
// api_student_attendance.php
// Returns attendance summary for the logged-in student (per enrolled course)
require_once __DIR__ . '/includes/auth.php';
require_role(['student']);

header('Content-Type: application/json');

$studentId = (int)($_SESSION['user_id'] ?? 0);
if (!$studentId) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Student not authenticated.']);
    exit;
}

try {
    $sql = "SELECT c.course_code, c.course_name, cs.section_name, r.attendance_marks
            FROM enrollments e
            JOIN course_sections cs ON e.section_id = cs.id
            JOIN courses c ON cs.course_id = c.id
            LEFT JOIN results r ON r.enrollment_id = e.id
            WHERE e.student_id = :student_id
            ORDER BY c.course_name";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':student_id' => $studentId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $out = [];
    foreach ($rows as $r) {
        $att = isset($r['attendance_marks']) ? (float)$r['attendance_marks'] : 0.0;
        // attendance_marks stored as 0-10 in this schema — convert to percent
        $percent = min(100, max(0, round(($att / 10.0) * 100)));
        $out[] = [
            'course_code' => $r['course_code'],
            'course_name' => $r['course_name'],
            'section' => $r['section_name'],
            'attendance_percent' => $percent,
        ];
    }

    echo json_encode(['success' => true, 'data' => $out]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Server error']);
}

?>
