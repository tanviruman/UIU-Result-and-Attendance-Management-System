<?php
// apply_grace.php
// Apply grace marks to all students in the teacher's section
require_once __DIR__ . '/includes/auth.php';
require_role(['teacher']);

header('Content-Type: application/json');

$body = file_get_contents('php://input');
$data = json_decode($body, true);

if (!isset($data['grace_value'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Grace value is required.']);
    exit;
}

function calculateGrade(float $total): array
{
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

$graceValue = floatval($data['grace_value']);
if ($graceValue < 0 || $graceValue > 5) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Grace must be between 0 and 5.']);
    exit;
}

$sectionId = isset($data['section_id']) ? (int)$data['section_id'] : null;
if (!$sectionId) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Section ID is required.']);
    exit;
}

try {
    $pdo->beginTransaction();
    $teacherId = (int)$_SESSION['user_id'];
    
    // Get all result IDs for the teacher's courses
    $sql = "SELECT r.id, r.attendance_marks, r.total_marks
            FROM results r
            JOIN enrollments e ON r.enrollment_id = e.id
            JOIN course_sections cs ON e.section_id = cs.id
            WHERE cs.teacher_id = :teacher_id AND cs.id = :section_id";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':teacher_id' => $teacherId, ':section_id' => $sectionId]);
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($results)) {
        $pdo->rollBack();
        echo json_encode(['success' => false, 'message' => 'No students found in your sections.']);
        exit;
    }
    
    $updateStmt = $pdo->prepare(
        "UPDATE results SET attendance_marks = :new_att, total_marks = :new_total, grade = :grade, grade_point = :grade_point WHERE id = :result_id"
    );
    
    foreach ($results as $row) {
        $newAtt = min(10, (float)$row['attendance_marks'] + $graceValue);
        $newTotal = (float)$row['total_marks'] + ($newAtt - (float)$row['attendance_marks']);
        $gradeInfo = calculateGrade($newTotal);
        
        $updateStmt->execute([
            ':new_att' => $newAtt,
            ':new_total' => $newTotal,
            ':grade' => $gradeInfo['grade'],
            ':grade_point' => $gradeInfo['point'],
            ':result_id' => (int)$row['id']
        ]);
        
        write_audit_log(
            $pdo,
            $teacherId,
            'APPLY_GRACE',
            'results',
            (int)$row['id'],
            json_encode(['attendance_marks' => $row['attendance_marks'], 'total_marks' => $row['total_marks']], JSON_UNESCAPED_UNICODE),
            json_encode(['attendance_marks' => $newAtt, 'total_marks' => $newTotal, 'grade' => $gradeInfo['grade'], 'grade_point' => $gradeInfo['point']], JSON_UNESCAPED_UNICODE)
        );
    }
    
    $pdo->commit();
    echo json_encode(['success' => true, 'message' => "Grace $graceValue applied to all students."]);
} catch (Exception $e) {
    $pdo->rollBack();
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Could not apply grace marks.']);
}
