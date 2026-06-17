<?php
// approve_reject_section.php
// Admin endpoint: approve/reject submitted result section and sync visibility.

require_once __DIR__ . '/includes/admin_helpers.php';
require_role(['admin']);

$data = urams_admin_payload();
$sectionId = (int)($data['section_id'] ?? 0);
$action = strtolower(trim((string)($data['action'] ?? '')));
$reason = trim((string)($data['reason'] ?? ''));

if ($sectionId <= 0 || !in_array($action, ['approve', 'reject'], true)) {
    urams_json_response(['success' => false, 'message' => 'Valid section_id and action are required.'], 400);
}
if ($action === 'reject' && $reason === '') {
    urams_json_response(['success' => false, 'message' => 'Rejection reason is required.'], 400);
}

try {
    $adminId = (int)$_SESSION['user_id'];

    $sectionStmt = $pdo->prepare(
        "SELECT cs.id, cs.status, COALESCE(rs.status, cs.status, 'running') AS workflow_status
         FROM course_sections cs
         LEFT JOIN result_submissions rs ON rs.section_id = cs.id
         WHERE cs.id = :section_id
         LIMIT 1"
    );
    $sectionStmt->execute([':section_id' => $sectionId]);
    $section = $sectionStmt->fetch();
    if (!$section) {
        urams_json_response(['success' => false, 'message' => 'Section not found.'], 404);
    }
    if ($section['workflow_status'] !== 'submitted') {
        urams_json_response(['success' => false, 'message' => 'Only submitted results can be approved/rejected.'], 409);
    }

    $newStatus = $action === 'approve' ? 'approved' : 'rejected';

    $pdo->beginTransaction();

    if ($action === 'approve') {
        $submission = $pdo->prepare(
            "INSERT INTO result_submissions
             (section_id, status, approved_by, approved_at, rejected_by, rejected_at, rejection_reason)
             VALUES (:section_id, 'approved', :admin_id, NOW(), NULL, NULL, NULL)
             ON DUPLICATE KEY UPDATE
               status = 'approved',
               approved_by = VALUES(approved_by),
               approved_at = NOW(),
               rejected_by = NULL,
               rejected_at = NULL,
               rejection_reason = NULL,
               updated_at = CURRENT_TIMESTAMP"
        );
        $submission->execute([':section_id' => $sectionId, ':admin_id' => $adminId]);

        $lockResults = $pdo->prepare(
            "UPDATE student_section_results ssr
             JOIN enrollments e ON e.id = ssr.enrollment_id
             SET ssr.locked_at = NOW()
             WHERE e.section_id = :section_id"
        );
        $lockResults->execute([':section_id' => $sectionId]);

        $legacy = $pdo->prepare(
            "UPDATE results
             SET status = 'approved', approved_by = :admin_id, approved_at = NOW()
             WHERE enrollment_id IN (SELECT id FROM enrollments WHERE section_id = :section_id)"
        );
        $legacy->execute([':admin_id' => $adminId, ':section_id' => $sectionId]);
    } else {
        $submission = $pdo->prepare(
            "INSERT INTO result_submissions
             (section_id, status, rejected_by, rejected_at, rejection_reason, approved_by, approved_at)
             VALUES (:section_id, 'rejected', :admin_id, NOW(), :reason, NULL, NULL)
             ON DUPLICATE KEY UPDATE
               status = 'rejected',
               rejected_by = VALUES(rejected_by),
               rejected_at = NOW(),
               rejection_reason = VALUES(rejection_reason),
               approved_by = NULL,
               approved_at = NULL,
               updated_at = CURRENT_TIMESTAMP"
        );
        $submission->execute([':section_id' => $sectionId, ':admin_id' => $adminId, ':reason' => $reason]);

        $unlockResults = $pdo->prepare(
            "UPDATE student_section_results ssr
             JOIN enrollments e ON e.id = ssr.enrollment_id
             SET ssr.locked_at = NULL
             WHERE e.section_id = :section_id"
        );
        $unlockResults->execute([':section_id' => $sectionId]);

        $legacy = $pdo->prepare(
            "UPDATE results
             SET status = 'rejected', approved_by = NULL, approved_at = NULL
             WHERE enrollment_id IN (SELECT id FROM enrollments WHERE section_id = :section_id)"
        );
        $legacy->execute([':section_id' => $sectionId]);
    }

    $sectionUpdate = $pdo->prepare('UPDATE course_sections SET status = :status WHERE id = :section_id');
    $sectionUpdate->execute([':status' => $newStatus, ':section_id' => $sectionId]);

    write_audit_log(
        $pdo,
        $adminId,
        $action === 'approve' ? 'APPROVE_RESULT' : 'REJECT_RESULT',
        'result_submissions',
        $sectionId,
        json_encode(['status' => 'submitted'], JSON_UNESCAPED_UNICODE),
        json_encode(['status' => $newStatus, 'reason' => $reason], JSON_UNESCAPED_UNICODE)
    );

    $pdo->commit();

    urams_json_response([
        'success' => true,
        'message' => $action === 'approve'
            ? 'Result approved. Student/parent can now see it.'
            : 'Result rejected and returned to teacher.',
        'section_id' => $sectionId,
        'status' => $newStatus,
    ]);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    urams_json_response(['success' => false, 'message' => 'Could not update result status: ' . $e->getMessage()], 500);
}
