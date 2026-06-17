<?php
// api_get_students_by_trimester.php
// Step: Admin request kore specific trimester er sab students fetch kora endpoint.
require_once __DIR__ . '/includes/auth.php';
require_role(['admin']);

header('Content-Type: application/json');

// Step: Query param check.
$trimesterId = isset($_GET['trimester_id']) ? (int)$_GET['trimester_id'] : 0;
$sectionFilter = isset($_GET['section']) ? trim($_GET['section']) : '';

if ($trimesterId <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid trimester ID.']);
    exit;
}

try {
    // Step: SQL query - trimester er sab students group by section.
    $sql = "SELECT e.id AS enrollment_id, u.id AS student_id, u.full_name, u.identifier, u.email,
                   c.course_code, c.course_name,
                   cs.section_name, cs.id AS section_id,
                   ut.full_name AS teacher_name, ut.identifier AS teacher_identifier,
                   r.id AS result_id, r.status, r.grade, r.total_marks
            FROM enrollments e
            JOIN course_sections cs ON e.section_id = cs.id
            JOIN courses c ON cs.course_id = c.id
            JOIN users u ON e.student_id = u.id
            JOIN users ut ON cs.teacher_id = ut.id
            LEFT JOIN results r ON r.enrollment_id = e.id
            WHERE cs.trimester_id = :trimester_id";
    
    if ($sectionFilter !== '') {
        $sql .= " AND cs.section_name = :section";
    }
    
    $sql .= " ORDER BY cs.section_name, u.full_name";
    
    $stmt = $pdo->prepare($sql);
    $params = [':trimester_id' => $trimesterId];
    if ($sectionFilter !== '') {
        $params[':section'] = $sectionFilter;
    }
    $stmt->execute($params);
    $students = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Step: Data reorganize kori - section wise group.
    $groupedBySection = [];
    foreach ($students as $student) {
        $sectionKey = $student['section_name'];
        if (!isset($groupedBySection[$sectionKey])) {
            $groupedBySection[$sectionKey] = [
                'section_name' => $sectionKey,
                'section_id' => (int)$student['section_id'],
                'course_code' => $student['course_code'],
                'course_name' => $student['course_name'],
                'teacher_name' => $student['teacher_name'],
                'teacher_identifier' => $student['teacher_identifier'],
                'students' => []
            ];
        }
        $groupedBySection[$sectionKey]['students'][] = $student;
    }

    // Audit log.
    write_audit_log($pdo, (int)$_SESSION['user_id'], 'ADMIN_VIEW_TRIMESTER_STUDENTS', 'trimesters', 
                    $trimesterId, null, 
                    json_encode(['students_count' => count($students), 'section_filter' => $sectionFilter], 
                                JSON_UNESCAPED_UNICODE));

    echo json_encode([
        'success' => true,
        'trimester_id' => $trimesterId,
        'total_students' => count($students),
        'sections' => array_values($groupedBySection)
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Server error: ' . $e->getMessage()]);
}
?>
