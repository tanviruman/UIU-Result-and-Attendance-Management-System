<?php
// get_section_students.php
// Fetch students + normalized component marks for a teacher/admin section.

require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/result_helpers.php';
require_role(['teacher', 'admin']);

$sectionId = isset($_GET['section_id']) ? (int)$_GET['section_id'] : 0;
if ($sectionId <= 0) {
    urams_json_response(['success' => false, 'message' => 'Section ID is required.'], 400);
}

try {
    $userId = (int)$_SESSION['user_id'];
    $role = (string)$_SESSION['role'];

    if ($role === 'teacher') {
        $check = $pdo->prepare('SELECT id FROM course_sections WHERE id = :id AND teacher_id = :teacher_id LIMIT 1');
        $check->execute([':id' => $sectionId, ':teacher_id' => $userId]);
        if (!$check->fetch()) {
            urams_json_response(['success' => false, 'message' => 'Unauthorized section access.'], 403);
        }
    }

    $sectionStmt = $pdo->prepare(
        'SELECT cs.id AS section_id, cs.section_name, cs.status, c.course_code, c.course_name, t.name AS trimester_name
         FROM course_sections cs
         JOIN courses c ON c.id = cs.course_id
         JOIN trimesters t ON t.id = cs.trimester_id
         WHERE cs.id = :section_id
         LIMIT 1'
    );
    $sectionStmt->execute([':section_id' => $sectionId]);
    $sectionInfo = $sectionStmt->fetch();

    if (!$sectionInfo) {
        urams_json_response(['success' => false, 'message' => 'Section not found.'], 404);
    }

    $pdo->beginTransaction();

    urams_ensure_default_components($pdo, $sectionId, $userId);

    $enrollStmt = $pdo->prepare('SELECT id FROM enrollments WHERE section_id = :section_id ORDER BY id');
    $enrollStmt->execute([':section_id' => $sectionId]);
    $enrollments = $enrollStmt->fetchAll();
    foreach ($enrollments as $enrollment) {
        urams_ensure_legacy_result($pdo, (int)$enrollment['id']);
    }

    urams_migrate_legacy_marks_for_section($pdo, $sectionId, $userId);

    foreach ($enrollments as $enrollment) {
        urams_recalculate_result($pdo, (int)$enrollment['id']);
    }

    $components = urams_get_components($pdo, $sectionId);

    $studentStmt = $pdo->prepare(
        'SELECT r.id AS result_id,
                e.id AS enrollment_id,
                e.section_id,
                u.identifier AS id,
                u.identifier AS student_id,
                u.full_name AS name,
                u.email AS email,
                r.ct1,
                r.ct2,
                r.best_ct,
                r.assignment,
                r.mid,
                r.final,
                r.attendance_marks AS att,
                r.total_marks,
                r.grade,
                r.grade_point,
                COALESCE(rs.status, r.status, "draft") AS result_status
         FROM enrollments e
         JOIN users u ON u.id = e.student_id
         LEFT JOIN results r ON r.enrollment_id = e.id
         LEFT JOIN result_submissions rs ON rs.section_id = e.section_id
         WHERE e.section_id = :section_id
         ORDER BY u.full_name'
    );
    $studentStmt->execute([':section_id' => $sectionId]);
    $students = $studentStmt->fetchAll();

    $marksStmt = $pdo->prepare(
        'SELECT ac.id AS component_id,
                ac.component_key,
                scm.raw_marks,
                scm.converted_marks,
                scm.is_absent,
                scm.remarks
         FROM assessment_components ac
         LEFT JOIN student_component_marks scm
           ON scm.component_id = ac.id AND scm.enrollment_id = :enrollment_id
         WHERE ac.section_id = :section_id
         ORDER BY
           CASE ac.component_type
             WHEN "ct" THEN 10
             WHEN "quiz" THEN 20
             WHEN "assignment" THEN 30
             WHEN "mid" THEN 40
             WHEN "final" THEN 50
             WHEN "attendance" THEN 60
             WHEN "lab" THEN 70
             WHEN "presentation" THEN 80
             ELSE 90
           END,
           ac.sort_order,
           ac.id'
    );

    foreach ($students as &$student) {
        $student['result_id'] = (int)$student['result_id'];
        $student['enrollment_id'] = (int)$student['enrollment_id'];
        $student['section_id'] = (int)$student['section_id'];
        $student['ct1'] = (float)$student['ct1'];
        $student['ct2'] = (float)$student['ct2'];
        $student['best_ct'] = (float)$student['best_ct'];
        $student['assignment'] = (float)$student['assignment'];
        $student['mid'] = (float)$student['mid'];
        $student['final'] = (float)$student['final'];
        $student['att'] = (float)$student['att'];
        $student['total_marks'] = (float)$student['total_marks'];
        $student['grade_point'] = $student['grade_point'] === null ? 0.0 : (float)$student['grade_point'];

        $marksStmt->execute([
            ':enrollment_id' => $student['enrollment_id'],
            ':section_id' => $sectionId,
        ]);

        $student['component_marks'] = [];
        foreach ($marksStmt->fetchAll() as $mark) {
            $student['component_marks'][$mark['component_key']] = [
                'component_id' => (int)$mark['component_id'],
                'raw_marks' => $mark['raw_marks'] === null ? 0.0 : (float)$mark['raw_marks'],
                'converted_marks' => $mark['converted_marks'] === null ? 0.0 : (float)$mark['converted_marks'],
                'is_absent' => (int)($mark['is_absent'] ?? 0),
                'remarks' => $mark['remarks'],
            ];
        }
    }
    unset($student);

    $pdo->commit();

    urams_json_response([
        'success' => true,
        'section' => [
            'section_id' => (int)$sectionInfo['section_id'],
            'course_title' => sprintf('%s (%s)', $sectionInfo['course_name'], $sectionInfo['course_code']),
            'course_code' => $sectionInfo['course_code'],
            'course_name' => $sectionInfo['course_name'],
            'trimester' => $sectionInfo['trimester_name'],
            'section' => $sectionInfo['section_name'],
            'status' => $sectionInfo['status'],
        ],
        'components' => $components,
        'students' => $students,
    ]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    urams_json_response(['success' => false, 'message' => 'Database error: ' . $e->getMessage()], 500);
}
