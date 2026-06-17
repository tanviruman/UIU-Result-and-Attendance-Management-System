<?php
// fetch_submitted_results.php
// Admin endpoint: fetch submitted/approved/rejected result sections.

require_once __DIR__ . '/includes/admin_helpers.php';
require_role(['admin']);

try {
    $stmt = $pdo->prepare(
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
    $stmt->execute();
    urams_json_response(['success' => true, 'sections' => $stmt->fetchAll()]);
} catch (Throwable $e) {
    urams_json_response(['success' => false, 'message' => 'Could not fetch submitted results: ' . $e->getMessage()], 500);
}
