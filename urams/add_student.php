<?php
// add_student.php
// Admin endpoint: create student account + optional parent + optional initial section enrollment.

require_once __DIR__ . '/includes/academic_helpers.php';
require_role(['admin']);

$data = urams_admin_payload();
$fullName = urams_admin_required_string($data, 'full_name', 'Student name');
$email = strtolower(urams_admin_required_string($data, 'email', 'Email'));
$identifier = urams_admin_required_string($data, 'identifier', 'Student ID', 50);
$phone = urams_admin_optional_string($data, 'phone', 30);
$program = urams_admin_optional_string($data, 'program', 80) ?? 'BSc CSE';
$department = urams_admin_optional_string($data, 'department', 80) ?? 'CSE';
$programId = isset($data['program_id']) && (int)$data['program_id'] > 0 ? (int)$data['program_id'] : null;
$curriculumVersionId = isset($data['curriculum_version_id']) && (int)$data['curriculum_version_id'] > 0 ? (int)$data['curriculum_version_id'] : null;
$parentIdentifier = urams_admin_optional_string($data, 'parent_identifier', 50);
$forceEnroll = !empty($data['force_enroll']);
$sectionIds = [];
if (!empty($data['section_ids']) && is_array($data['section_ids'])) {
    foreach ($data['section_ids'] as $sid) {
        $sid = (int)$sid;
        if ($sid > 0) {
            $sectionIds[] = $sid;
        }
    }
} elseif (!empty($data['section_id'])) {
    $sectionIds[] = (int)$data['section_id'];
}
$sectionIds = array_values(array_unique($sectionIds));

$password = (string)($data['password'] ?? '');
if ($password === '') {
    $password = 'password123';
}
if (strlen($password) < 6) {
    urams_json_response(['success' => false, 'message' => 'Password must be at least 6 characters.'], 400);
}
urams_admin_validate_email($email);

try {
    urams_admin_check_duplicate_user($pdo, $email, $identifier);
    $pdo->beginTransaction();

    if ($programId === null) {
        $p = urams_academic_get_program_by_name($pdo, $program);
        if ($p) {
            $programId = (int)$p['id'];
            $program = (string)$p['name'];
            $department = $department ?: (string)$p['department'];
        }
    }

    $stmt = $pdo->prepare(
        "INSERT INTO users (full_name, email, identifier, role, password_hash, phone, program, department, program_id, curriculum_version_id, status)
         VALUES (:full_name, :email, :identifier, 'student', :password_hash, :phone, :program, :department, :program_id, :curriculum_version_id, 'active')"
    );
    $stmt->execute([
        ':full_name' => $fullName,
        ':email' => $email,
        ':identifier' => $identifier,
        ':password_hash' => password_hash($password, PASSWORD_DEFAULT),
        ':phone' => $phone,
        ':program' => $program,
        ':department' => $department,
        ':program_id' => $programId,
        ':curriculum_version_id' => $curriculumVersionId,
    ]);
    $id = (int)$pdo->lastInsertId();

    $parentId = urams_academic_create_parent($pdo, $parentIdentifier, $fullName);
    $enrolled = [];
    foreach ($sectionIds as $sectionId) {
        $enroll = urams_academic_enroll($pdo, $id, $sectionId, $parentId, $forceEnroll);
        if (!$enroll['success']) {
            $pdo->rollBack();
            urams_json_response(['success' => false, 'message' => 'Student created was cancelled because prerequisite is missing for selected section.', 'report' => $enroll['report']], 409);
        }
        $enrolled[] = $enroll['enrollment_id'];
    }

    write_audit_log($pdo, (int)$_SESSION['user_id'], 'ADD_STUDENT', 'users', $id, null, json_encode([
        'id' => $id,
        'identifier' => $identifier,
        'program' => $program,
        'parent_identifier' => $parentIdentifier,
        'enrollments' => $enrolled,
    ], JSON_UNESCAPED_UNICODE));
    $pdo->commit();

    urams_json_response(['success' => true, 'message' => 'Student added successfully.', 'student' => urams_admin_json_user(urams_admin_user_row($pdo, $id)), 'enrollments' => $enrolled]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    urams_json_response(['success' => false, 'message' => 'Could not add student: ' . $e->getMessage()], 500);
}
