<?php
// includes/academic_helpers.php
// Academic setup helpers for Programs, Curriculum, Sections, Enrollments and Prerequisites.

require_once __DIR__ . '/admin_helpers.php';

function urams_academic_int(array $data, string $key, string $label, bool $required = true): ?int
{
    if (!isset($data[$key]) || $data[$key] === '' || $data[$key] === null) {
        if ($required) {
            urams_json_response(['success' => false, 'message' => $label . ' is required.'], 400);
        }
        return null;
    }
    $value = (int)$data[$key];
    if ($value <= 0 && $required) {
        urams_json_response(['success' => false, 'message' => $label . ' is invalid.'], 400);
    }
    return $value > 0 ? $value : null;
}

function urams_academic_get_program_by_name(PDO $pdo, ?string $programName): ?array
{
    $programName = trim((string)$programName);
    if ($programName === '') {
        return null;
    }
    $stmt = $pdo->prepare('SELECT * FROM programs WHERE name = :name OR code = :code LIMIT 1');
    $stmt->execute([':name' => $programName, ':code' => $programName]);
    $row = $stmt->fetch();
    return $row ?: null;
}

function urams_academic_create_parent(PDO $pdo, ?string $parentIdentifier, ?string $studentName = null): ?int
{
    $parentIdentifier = trim((string)$parentIdentifier);
    if ($parentIdentifier === '') {
        return null;
    }

    $stmt = $pdo->prepare("SELECT id, role FROM users WHERE identifier = :identifier LIMIT 1");
    $stmt->execute([':identifier' => $parentIdentifier]);
    $row = $stmt->fetch();
    if ($row) {
        if ($row['role'] !== 'parent') {
            urams_json_response(['success' => false, 'message' => 'Parent ID already exists as a non-parent user.'], 409);
        }
        return (int)$row['id'];
    }

    $safeEmailKey = strtolower(preg_replace('/[^a-z0-9]+/i', '', $parentIdentifier));
    if ($safeEmailKey === '') {
        $safeEmailKey = 'parent' . time();
    }
    $email = $safeEmailKey . '@parent.urams.local';
    $fullName = $studentName ? ('Parent of ' . $studentName) : $parentIdentifier;

    $stmt = $pdo->prepare(
        "INSERT INTO users (full_name, email, identifier, role, password_hash, status)
         VALUES (:full_name, :email, :identifier, 'parent', :password_hash, 'active')"
    );
    $stmt->execute([
        ':full_name' => $fullName,
        ':email' => $email,
        ':identifier' => $parentIdentifier,
        ':password_hash' => password_hash('password123', PASSWORD_DEFAULT),
    ]);
    return (int)$pdo->lastInsertId();
}

function urams_academic_completed_course_ids(PDO $pdo, int $studentId): array
{
    $stmt = $pdo->prepare(
        "SELECT cs.course_id, MAX(COALESCE(r.grade_point, 0)) AS best_point
         FROM enrollments e
         JOIN course_sections cs ON cs.id = e.section_id
         JOIN results r ON r.enrollment_id = e.id
         WHERE e.student_id = :student_id
           AND r.status = 'approved'
           AND COALESCE(r.grade_point, 0) >= 2.00
         GROUP BY cs.course_id"
    );
    $stmt->execute([':student_id' => $studentId]);
    $completed = [];
    foreach ($stmt->fetchAll() as $row) {
        $completed[(int)$row['course_id']] = (float)$row['best_point'];
    }
    return $completed;
}

function urams_academic_prerequisite_report(PDO $pdo, int $studentId, int $sectionId): array
{
    $stmt = $pdo->prepare(
        "SELECT cs.id AS section_id, cs.course_id, c.course_code, c.course_name
         FROM course_sections cs
         JOIN courses c ON c.id = cs.course_id
         WHERE cs.id = :section_id
         LIMIT 1"
    );
    $stmt->execute([':section_id' => $sectionId]);
    $section = $stmt->fetch();
    if (!$section) {
        urams_json_response(['success' => false, 'message' => 'Section not found.'], 404);
    }

    $prStmt = $pdo->prepare(
        "SELECT cp.prerequisite_course_id, cp.min_grade_point, pc.course_code, pc.course_name
         FROM course_prerequisites cp
         JOIN courses pc ON pc.id = cp.prerequisite_course_id
         WHERE cp.course_id = :course_id
         ORDER BY pc.course_code"
    );
    $prStmt->execute([':course_id' => (int)$section['course_id']]);
    $prereqs = $prStmt->fetchAll();
    $completed = urams_academic_completed_course_ids($pdo, $studentId);

    $missing = [];
    $passed = [];
    foreach ($prereqs as $pr) {
        $pid = (int)$pr['prerequisite_course_id'];
        $needed = (float)$pr['min_grade_point'];
        $got = $completed[$pid] ?? null;
        $item = [
            'course_id' => $pid,
            'course_code' => $pr['course_code'],
            'course_name' => $pr['course_name'],
            'min_grade_point' => $needed,
            'student_grade_point' => $got,
        ];
        if ($got !== null && $got >= $needed) {
            $passed[] = $item;
        } else {
            $missing[] = $item;
        }
    }

    return [
        'eligible' => count($missing) === 0,
        'section' => $section,
        'passed' => $passed,
        'missing' => $missing,
        'message' => count($missing) === 0 ? 'Prerequisite check passed.' : 'Prerequisite missing.',
    ];
}

function urams_academic_create_default_components(PDO $pdo, int $sectionId, int $adminUserId): void
{
    $defaults = [
        ['ct1', 'CT1', 'ct', 30, 15, 15, 1, 1, 'ct'],
        ['ct2', 'CT2', 'ct', 30, 15, 15, 2, 1, 'ct'],
        ['assignment', 'Assignment', 'assignment', 10, 10, 10, 20, 0, null],
        ['mid', 'Mid Term', 'mid', 50, 25, 25, 40, 0, null],
        ['final', 'Final Exam', 'final', 80, 40, 40, 60, 0, null],
        ['attendance', 'Attendance', 'attendance', 10, 10, 10, 80, 0, null],
    ];
    $stmt = $pdo->prepare(
        "INSERT IGNORE INTO assessment_components
         (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group, created_by)
         VALUES (:section_id, :component_key, :component_name, :component_type, :taken_out_of, :convert_to, :weight, :sort_order, :is_best_of_group, :best_of_group, :created_by)"
    );
    foreach ($defaults as $d) {
        $stmt->execute([
            ':section_id' => $sectionId,
            ':component_key' => $d[0],
            ':component_name' => $d[1],
            ':component_type' => $d[2],
            ':taken_out_of' => $d[3],
            ':convert_to' => $d[4],
            ':weight' => $d[5],
            ':sort_order' => $d[6],
            ':is_best_of_group' => $d[7],
            ':best_of_group' => $d[8],
            ':created_by' => $adminUserId,
        ]);
    }
}

function urams_academic_enroll(PDO $pdo, int $studentId, int $sectionId, ?int $parentId, bool $force = false): array
{
    $report = urams_academic_prerequisite_report($pdo, $studentId, $sectionId);
    if (!$report['eligible'] && !$force) {
        return ['success' => false, 'blocked' => true, 'report' => $report];
    }

    $stmt = $pdo->prepare(
        "INSERT INTO enrollments (student_id, section_id, parent_user_id, status)
         VALUES (:student_id, :section_id, :parent_user_id, 'active')
         ON DUPLICATE KEY UPDATE parent_user_id = COALESCE(VALUES(parent_user_id), parent_user_id), status = 'active'"
    );
    $stmt->execute([
        ':student_id' => $studentId,
        ':section_id' => $sectionId,
        ':parent_user_id' => $parentId,
    ]);

    $enrollmentStmt = $pdo->prepare('SELECT id FROM enrollments WHERE student_id = :student_id AND section_id = :section_id LIMIT 1');
    $enrollmentStmt->execute([':student_id' => $studentId, ':section_id' => $sectionId]);
    $enrollmentId = (int)$enrollmentStmt->fetchColumn();

    $pdo->prepare("INSERT IGNORE INTO results (enrollment_id, status) VALUES (:enrollment_id, 'draft')")
        ->execute([':enrollment_id' => $enrollmentId]);
    $pdo->prepare("INSERT IGNORE INTO student_section_results (enrollment_id, total_marks, calculated_at) VALUES (:enrollment_id, 0, NOW())")
        ->execute([':enrollment_id' => $enrollmentId]);

    return ['success' => true, 'blocked' => false, 'enrollment_id' => $enrollmentId, 'report' => $report];
}
