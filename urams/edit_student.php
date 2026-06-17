<?php
// edit_student.php
// Admin endpoint: update student account + optional parent/section enrollment.

require_once __DIR__ . '/includes/academic_helpers.php';
require_role(['admin']);

$data = urams_admin_payload();
$id = (int)($data['id'] ?? 0);
if ($id <= 0) {
    urams_json_response(['success' => false, 'message' => 'Student ID is required.'], 400);
}
$old = urams_admin_require_user($pdo, $id, 'student');
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
urams_admin_validate_email($email);

try {
    urams_admin_check_duplicate_user($pdo, $email, $identifier, $id);
    $pdo->beginTransaction();

    if ($programId === null) {
        $p = urams_academic_get_program_by_name($pdo, $program);
        if ($p) {
            $programId = (int)$p['id'];
            $program = (string)$p['name'];
            $department = $department ?: (string)$p['department'];
        }
    }

    if ($password !== '') {
        if (strlen($password) < 6) {
            urams_json_response(['success' => false, 'message' => 'Password must be at least 6 characters.'], 400);
        }
        $stmt = $pdo->prepare(
            "UPDATE users
             SET full_name = :full_name, email = :email, identifier = :identifier, phone = :phone,
                 program = :program, department = :department, program_id = :program_id,
                 curriculum_version_id = :curriculum_version_id, password_hash = :password_hash,
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = :id AND role = 'student'"
        );
        $params = [
            ':full_name' => $fullName,
            ':email' => $email,
            ':identifier' => $identifier,
            ':phone' => $phone,
            ':program' => $program,
            ':department' => $department,
            ':program_id' => $programId,
            ':curriculum_version_id' => $curriculumVersionId,
            ':password_hash' => password_hash($password, PASSWORD_DEFAULT),
            ':id' => $id,
        ];
    } else {
        $stmt = $pdo->prepare(
            "UPDATE users
             SET full_name = :full_name, email = :email, identifier = :identifier, phone = :phone,
                 program = :program, department = :department, program_id = :program_id,
                 curriculum_version_id = :curriculum_version_id, updated_at = CURRENT_TIMESTAMP
             WHERE id = :id AND role = 'student'"
        );
        $params = [
            ':full_name' => $fullName,
            ':email' => $email,
            ':identifier' => $identifier,
            ':phone' => $phone,
            ':program' => $program,
            ':department' => $department,
            ':program_id' => $programId,
            ':curriculum_version_id' => $curriculumVersionId,
            ':id' => $id,
        ];
    }
    $stmt->execute($params);

    $parentId = urams_academic_create_parent($pdo, $parentIdentifier, $fullName);
    $enrolled = [];
    foreach ($sectionIds as $sectionId) {
        $enroll = urams_academic_enroll($pdo, $id, $sectionId, $parentId, $forceEnroll);
        if (!$enroll['success']) {
            $pdo->rollBack();
            urams_json_response(['success' => false, 'message' => 'Student update cancelled because prerequisite is missing for selected section.', 'report' => $enroll['report']], 409);
        }
        $enrolled[] = $enroll['enrollment_id'];
    }

    write_audit_log($pdo, (int)$_SESSION['user_id'], 'EDIT_STUDENT', 'users', $id, json_encode($old, JSON_UNESCAPED_UNICODE), json_encode([
        'identifier' => $identifier,
        'email' => $email,
        'program' => $program,
        'parent_identifier' => $parentIdentifier,
        'enrollments' => $enrolled,
    ], JSON_UNESCAPED_UNICODE));
    $pdo->commit();

    urams_json_response(['success' => true, 'message' => 'Student updated successfully.', 'student' => urams_admin_json_user(urams_admin_user_row($pdo, $id)), 'enrollments' => $enrolled]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    urams_json_response(['success' => false, 'message' => 'Could not update student: ' . $e->getMessage()], 500);
}
