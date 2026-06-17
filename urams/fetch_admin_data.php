<?php
// fetch_admin_data.php
// Admin endpoint: refresh teachers, students, submitted results, audit and stats.

require_once __DIR__ . '/includes/admin_helpers.php';
require_role(['admin']);

try {
    $sectionsStmt = $pdo->prepare(
        "SELECT cs.id AS section_id,
                c.course_code,
                c.course_name,
                cs.section_name,
                t.name AS trimester_name,
                u.full_name AS teacher_name,
                u.identifier AS teacher_initial,
                COALESCE(rs.status, cs.status, 'running') AS status,
                rs.submitted_at,
                rs.approved_at,
                rs.rejected_at,
                rs.rejection_reason
         FROM course_sections cs
         JOIN courses c ON c.id = cs.course_id
         JOIN trimesters t ON t.id = cs.trimester_id
         JOIN users u ON u.id = cs.teacher_id
         LEFT JOIN result_submissions rs ON rs.section_id = cs.id
         WHERE COALESCE(rs.status, cs.status) IN ('submitted','approved','rejected')
         ORDER BY rs.submitted_at DESC, t.start_date DESC, c.course_name, cs.section_name"
    );
    $sectionsStmt->execute();

    $teachersStmt = $pdo->prepare(
        "SELECT u.id, u.identifier, u.full_name, u.email, u.phone, u.department, u.status,
                (SELECT COUNT(*) FROM course_sections cs WHERE cs.teacher_id = u.id) AS courses
         FROM users u
         WHERE u.role = 'teacher' AND u.status = 'active'
         ORDER BY u.full_name"
    );
    $teachersStmt->execute();

    $studentsStmt = $pdo->prepare(
        "SELECT u.id, u.identifier, u.full_name, u.email, u.phone, u.program, u.department, u.status,
                u.program_id, p.name AS program_name, u.curriculum_version_id, cv.name AS curriculum_name,
                GROUP_CONCAT(DISTINCT CONCAT(c.course_code, '-', cs.section_name) ORDER BY c.course_code SEPARATOR ', ') AS sections
         FROM users u
         LEFT JOIN programs p ON p.id = u.program_id
         LEFT JOIN curriculum_versions cv ON cv.id = u.curriculum_version_id
         LEFT JOIN enrollments e ON e.student_id = u.id AND COALESCE(e.status,'active')='active'
         LEFT JOIN course_sections cs ON cs.id = e.section_id
         LEFT JOIN courses c ON c.id = cs.course_id
         WHERE u.role = 'student' AND u.status = 'active'
         GROUP BY u.id, u.identifier, u.full_name, u.email, u.phone, u.program, u.department, u.status, u.program_id, p.name, u.curriculum_version_id, cv.name
         ORDER BY u.identifier"
    );
    $studentsStmt->execute();

    $auditStmt = $pdo->prepare(
        "SELECT a.created_at, u.full_name AS user_name, u.role, a.action, a.old_value, a.new_value, a.ip_address
         FROM audit_logs a
         LEFT JOIN users u ON u.id = a.user_id
         ORDER BY a.created_at DESC
         LIMIT 100"
    );
    $auditStmt->execute();

    $stats = [];
    foreach ([
        'teachers' => "SELECT COUNT(*) FROM users WHERE role='teacher' AND status='active'",
        'students' => "SELECT COUNT(*) FROM users WHERE role='student' AND status='active'",
        'pending' => "SELECT COUNT(*) FROM result_submissions WHERE status='submitted'",
        'trimesters' => "SELECT COUNT(*) FROM trimesters WHERE status='active'",
        'programs' => "SELECT COUNT(*) FROM programs WHERE status='active'",
        'sections' => "SELECT COUNT(*) FROM course_sections WHERE status IN ('running','submitted')",
    ] as $key => $sql) {
        $stmt = $pdo->prepare($sql);
        $stmt->execute();
        $stats[$key] = (int)$stmt->fetchColumn();
    }

    urams_json_response([
        'success' => true,
        'sections' => $sectionsStmt->fetchAll(),
        'teachers' => $teachersStmt->fetchAll(),
        'students' => $studentsStmt->fetchAll(),
        'audit_logs' => $auditStmt->fetchAll(),
        'stats' => $stats,
    ]);
} catch (Throwable $e) {
    urams_json_response(['success' => false, 'message' => 'Could not refresh admin data: ' . $e->getMessage()], 500);
}
