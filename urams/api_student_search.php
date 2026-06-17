<?php
// api_student_search.php
// Step: Comprehensive student search API - filter by section, trimester, course.
require_once __DIR__ . '/includes/auth.php';
require_role(['admin', 'teacher']);

header('Content-Type: application/json');

$teacherId = (int)$_SESSION['user_id'];
$role = $_SESSION['role'];

// Step: Query parameters get kori.
$searchType = $_GET['type'] ?? 'sections'; // 'sections', 'students_in_section', 'all_students'
$sectionId = isset($_GET['section_id']) ? (int)$_GET['section_id'] : 0;
$trimesterId = isset($_GET['trimester_id']) ? (int)$_GET['trimester_id'] : 0;
$courseId = isset($_GET['course_id']) ? (int)$_GET['course_id'] : 0;
$searchTerm = isset($_GET['q']) ? trim($_GET['q']) : '';

try {
    // Teacher-specific: sudhu nij sections dekh'te parbe.
    $teacherFilter = '';
    if ($role === 'teacher') {
        $teacherFilter = "AND cs.teacher_id = :teacher_id";
    }

    // Case 1: Teacher er sob sections - with student count.
    if ($searchType === 'sections') {
        $sql = "SELECT DISTINCT cs.id AS section_id, c.course_code, c.course_name, 
                       cs.section_name, t.name AS trimester_name,
                       COUNT(e.id) AS student_count
                FROM course_sections cs
                JOIN courses c ON cs.course_id = c.id
                JOIN trimesters t ON cs.trimester_id = t.id
                LEFT JOIN enrollments e ON e.section_id = cs.id
                WHERE 1=1 {$teacherFilter}
                GROUP BY cs.id
                ORDER BY t.start_date DESC, cs.section_name";
        
        $stmt = $pdo->prepare($sql);
        if ($role === 'teacher') {
            $stmt->execute([':teacher_id' => $teacherId]);
        } else {
            $stmt->execute([]);
        }
        $sections = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($sections as &$sec) {
            $sec['section_id'] = (int)$sec['section_id'];
            $sec['student_count'] = (int)$sec['student_count'];
        }
        unset($sec);

        echo json_encode(['success' => true, 'type' => 'sections', 'data' => $sections]);
    }

    // Case 2: Specific section er students.
    elseif ($searchType === 'students_in_section' && $sectionId > 0) {
        $sql = "SELECT e.id AS enrollment_id, u.id AS student_id, u.full_name, u.identifier,
                       u.email, u.phone,
                       r.id AS result_id, r.status, r.grade, r.total_marks
                FROM enrollments e
                JOIN users u ON e.student_id = u.id
                LEFT JOIN results r ON r.enrollment_id = e.id
                JOIN course_sections cs ON e.section_id = cs.id
                WHERE e.section_id = :section_id {$teacherFilter}
                ORDER BY u.full_name";
        
        $stmt = $pdo->prepare($sql);
        $params = [':section_id' => $sectionId];
        if ($role === 'teacher') {
            $params[':teacher_id'] = $teacherId;
        }
        $stmt->execute($params);
        $students = $stmt->fetchAll(PDO::FETCH_ASSOC);

        foreach ($students as &$st) {
            $st['enrollment_id'] = (int)$st['enrollment_id'];
            $st['student_id'] = (int)$st['student_id'];
            $st['result_id'] = $st['result_id'] ? (int)$st['result_id'] : null;
        }
        unset($st);

        echo json_encode(['success' => true, 'type' => 'students_in_section', 'data' => $students]);
    }

    // Case 3: Search all students (admin only).
    elseif ($searchType === 'all_students' && $role === 'admin') {
        $sql = "SELECT DISTINCT u.id AS student_id, u.full_name, u.identifier, u.email,
                       COUNT(e.id) AS enrollment_count,
                       GROUP_CONCAT(DISTINCT cs.section_name) AS sections,
                       GROUP_CONCAT(DISTINCT c.course_code) AS courses
                FROM users u
                LEFT JOIN enrollments e ON e.student_id = u.id
                LEFT JOIN course_sections cs ON e.section_id = cs.id
                LEFT JOIN courses c ON cs.course_id = c.id
                WHERE u.role = 'student'";
        
        if ($searchTerm !== '') {
            $sql .= " AND (u.full_name LIKE :q OR u.identifier LIKE :q OR u.email LIKE :q)";
        }
        
        $sql .= " GROUP BY u.id ORDER BY u.full_name";

        $stmt = $pdo->prepare($sql);
        if ($searchTerm !== '') {
            $stmt->execute([':q' => "%{$searchTerm}%"]);
        } else {
            $stmt->execute([]);
        }
        $students = $stmt->fetchAll(PDO::FETCH_ASSOC);

        foreach ($students as &$st) {
            $st['student_id'] = (int)$st['student_id'];
            $st['enrollment_count'] = (int)$st['enrollment_count'];
        }
        unset($st);

        echo json_encode(['success' => true, 'type' => 'all_students', 'data' => $students]);
    }

    else {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid search type or parameters.']);
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Server error: ' . $e->getMessage()]);
}
?>
