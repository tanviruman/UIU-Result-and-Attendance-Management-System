<?php
// fetch_academic_setup.php
// Admin JSON endpoint: returns academic setup data for programs/curricula/courses/sections/enrollment UI.

require_once __DIR__ . '/includes/academic_helpers.php';
require_role(['admin']);

try {
    $programs = $pdo->query("SELECT id, code, name, department, degree_level, total_credits, status FROM programs WHERE status='active' ORDER BY name")->fetchAll();

    $curricula = $pdo->query(
        "SELECT cv.id, cv.program_id, cv.name, cv.version_code, cv.effective_from, cv.total_credits, cv.status, p.name AS program_name
         FROM curriculum_versions cv
         JOIN programs p ON p.id = cv.program_id
         WHERE cv.status='active'
         ORDER BY p.name, cv.effective_from DESC, cv.name"
    )->fetchAll();

    $coursesStmt = $pdo->prepare(
        "SELECT cc.id AS curriculum_course_id, cc.curriculum_version_id, cv.program_id, p.name AS program_name,
                c.id AS course_id, c.course_code, c.course_name, c.credit,
                COALESCE(cc.course_type, c.course_type, 'core') AS course_type,
                cc.level_no, cc.term_no, cc.sequence_no,
                GROUP_CONCAT(DISTINCT pc.course_code ORDER BY pc.course_code SEPARATOR ', ') AS prerequisites
         FROM curriculum_courses cc
         JOIN curriculum_versions cv ON cv.id = cc.curriculum_version_id
         JOIN programs p ON p.id = cv.program_id
         JOIN courses c ON c.id = cc.course_id
         LEFT JOIN course_prerequisites cp ON cp.course_id = c.id
         LEFT JOIN courses pc ON pc.id = cp.prerequisite_course_id
         GROUP BY cc.id, cc.curriculum_version_id, cv.program_id, p.name, c.id, c.course_code, c.course_name, c.credit, cc.course_type, c.course_type, cc.level_no, cc.term_no, cc.sequence_no
         ORDER BY p.name, cc.level_no, cc.term_no, cc.sequence_no, c.course_code"
    );
    $coursesStmt->execute();
    $courses = $coursesStmt->fetchAll();

    $trimesters = $pdo->query("SELECT id, name, start_date, end_date, status FROM trimesters ORDER BY status='active' DESC, start_date DESC, id DESC")->fetchAll();

    $teachers = $pdo->query("SELECT id, identifier, full_name, email, department FROM users WHERE role='teacher' AND status='active' ORDER BY full_name")->fetchAll();

    $students = $pdo->query("SELECT id, identifier, full_name, email, program, department, program_id, curriculum_version_id FROM users WHERE role='student' AND status='active' ORDER BY identifier")->fetchAll();

    $sectionExtraSelect = '';
    $sectionExtraGroup = '';
    try {
        $sectionColumns = $pdo->query('SHOW COLUMNS FROM course_sections')->fetchAll(PDO::FETCH_COLUMN);
        if (in_array('room', $sectionColumns, true)) {
            $sectionExtraSelect .= ', cs.room';
            $sectionExtraGroup .= ', cs.room';
        }
        if (in_array('class_schedule', $sectionColumns, true)) {
            $sectionExtraSelect .= ', cs.class_schedule';
            $sectionExtraGroup .= ', cs.class_schedule';
        }
    } catch (Throwable $ignored) {
        $sectionExtraSelect = '';
        $sectionExtraGroup = '';
    }

    $sectionsStmt = $pdo->prepare(
        "SELECT cs.id AS section_id, cs.section_name, cs.status, COALESCE(cs.capacity, 40) AS capacity{$sectionExtraSelect},
                c.id AS course_id, c.course_code, c.course_name, c.credit,
                t.id AS trimester_id, t.name AS trimester_name,
                u.id AS teacher_id, u.full_name AS teacher_name, u.identifier AS teacher_initial,
                p.id AS program_id, p.name AS program_name,
                COUNT(e.id) AS enrolled_students
         FROM course_sections cs
         JOIN courses c ON c.id = cs.course_id
         JOIN trimesters t ON t.id = cs.trimester_id
         JOIN users u ON u.id = cs.teacher_id
         LEFT JOIN curriculum_courses cc ON cc.course_id = c.id
         LEFT JOIN curriculum_versions cv ON cv.id = cc.curriculum_version_id
         LEFT JOIN programs p ON p.id = COALESCE(c.program_id, cv.program_id)
         LEFT JOIN enrollments e ON e.section_id = cs.id AND COALESCE(e.status,'active')='active'
         GROUP BY cs.id, cs.section_name, cs.status, cs.capacity{$sectionExtraGroup}, c.id, c.course_code, c.course_name, c.credit, t.id, t.name, u.id, u.full_name, u.identifier, p.id, p.name
         ORDER BY t.start_date DESC, c.course_code, cs.section_name"
    );
    $sectionsStmt->execute();

    urams_json_response([
        'success' => true,
        'programs' => $programs,
        'curricula' => $curricula,
        'courses' => $courses,
        'trimesters' => $trimesters,
        'teachers' => $teachers,
        'students' => $students,
        'sections' => $sectionsStmt->fetchAll(),
    ]);
} catch (Throwable $e) {
    urams_json_response(['success' => false, 'message' => 'Could not load academic setup: ' . $e->getMessage()], 500);
}
