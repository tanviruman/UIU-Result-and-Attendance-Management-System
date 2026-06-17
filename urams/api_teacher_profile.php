<?php
// api_teacher_profile.php
// Returns the logged-in teacher's profile and teaching statistics
require_once __DIR__ . '/includes/auth.php';
require_role(['teacher']);

header('Content-Type: application/json');

$teacherId = (int)($_SESSION['user_id'] ?? 0);
if (!$teacherId) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Teacher not authenticated.']);
    exit;
}

try {
    // Get teacher profile
    $sqlProfile = "SELECT id, full_name, identifier, email, phone, department, status, created_at FROM users WHERE id = :teacher_id LIMIT 1";
    $stmtProfile = $pdo->prepare($sqlProfile);
    $stmtProfile->execute([':teacher_id' => $teacherId]);
    $profile = $stmtProfile->fetch(PDO::FETCH_ASSOC);

    if (!$profile) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Teacher profile not found.']);
        exit;
    }

    // Count courses taught
    $sqlCourses = "SELECT COUNT(DISTINCT c.id) as total_courses
                   FROM courses c
                   JOIN course_sections cs ON cs.course_id = c.id
                   WHERE cs.teacher_id = :teacher_id";
    $stmtCourses = $pdo->prepare($sqlCourses);
    $stmtCourses->execute([':teacher_id' => $teacherId]);
    $coursesData = $stmtCourses->fetch(PDO::FETCH_ASSOC);

    // Count total students taught
    $sqlStudents = "SELECT COUNT(DISTINCT e.student_id) as total_students
                    FROM enrollments e
                    JOIN course_sections cs ON e.section_id = cs.id
                    WHERE cs.teacher_id = :teacher_id";
    $stmtStudents = $pdo->prepare($sqlStudents);
    $stmtStudents->execute([':teacher_id' => $teacherId]);
    $studentsData = $stmtStudents->fetch(PDO::FETCH_ASSOC);

    // Count submitted results
    $sqlSubmitted = "SELECT COUNT(DISTINCT cs.id) as submitted_results
                     FROM course_sections cs
                     JOIN results r ON r.enrollment_id IN (
                       SELECT id FROM enrollments WHERE section_id = cs.id
                     )
                     WHERE cs.teacher_id = :teacher_id
                     AND r.status IN ('submitted', 'approved')";
    $stmtSubmitted = $pdo->prepare($sqlSubmitted);
    $stmtSubmitted->execute([':teacher_id' => $teacherId]);
    $submittedData = $stmtSubmitted->fetch(PDO::FETCH_ASSOC);

    // List current courses
    $sqlCurrentCourses = "SELECT DISTINCT c.course_code, c.course_name, t.name as trimester_name, cs.section_name
                          FROM course_sections cs
                          JOIN courses c ON cs.course_id = c.id
                          JOIN trimesters t ON cs.trimester_id = t.id
                          WHERE cs.teacher_id = :teacher_id
                          ORDER BY t.start_date DESC, c.course_code";
    $stmtCurrentCourses = $pdo->prepare($sqlCurrentCourses);
    $stmtCurrentCourses->execute([':teacher_id' => $teacherId]);
    $currentCourses = $stmtCurrentCourses->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        'success' => true,
        'profile' => [
            'id' => $profile['id'],
            'full_name' => $profile['full_name'],
            'identifier' => $profile['identifier'],
            'email' => $profile['email'],
            'phone' => $profile['phone'] ?: 'N/A',
            'department' => $profile['department'] ?: 'N/A',
            'status' => $profile['status'],
            'joined_date' => $profile['created_at'],
        ],
        'statistics' => [
            'total_courses' => (int)($coursesData['total_courses'] ?? 0),
            'total_students' => (int)($studentsData['total_students'] ?? 0),
            'results_submitted' => (int)($submittedData['submitted_results'] ?? 0),
        ],
        'current_courses' => $currentCourses,
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Unable to load teacher profile.']);
}
