<?php
// attendance_details_report.php
// Print-only attendance details report for Teacher/Admin.

require_once __DIR__ . '/includes/auth.php';
require_role(['teacher', 'admin']);

$sectionId = isset($_GET['section_id']) ? (int)$_GET['section_id'] : 0;
$classType = trim((string)($_GET['class_type'] ?? 'Regular'));
$classDate = trim((string)($_GET['class_date'] ?? date('Y-m-d')));
if ($sectionId <= 0) {
    http_response_code(400);
    exit('Section ID is required.');
}

function h_att($value): string
{
    return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
}

function att_status(?array $row): string
{
    if (!$row || $row['mark_id'] === null) {
        return 'Not Set';
    }
    if ((int)($row['is_absent'] ?? 0) === 1) {
        return 'Absent';
    }
    if ((float)($row['raw_marks'] ?? 0) > 0 || (float)($row['converted_marks'] ?? 0) > 0) {
        return 'Present';
    }
    return 'Not Set';
}

try {
    $sectionStmt = $pdo->prepare(
        'SELECT cs.id AS section_id, cs.section_name, cs.status,
                c.course_code, c.course_name,
                tr.name AS trimester_name,
                u.full_name AS teacher_name, u.identifier AS teacher_initial
         FROM course_sections cs
         JOIN courses c ON c.id = cs.course_id
         JOIN trimesters tr ON tr.id = cs.trimester_id
         JOIN users u ON u.id = cs.teacher_id
         WHERE cs.id = :id
         LIMIT 1'
    );
    $sectionStmt->execute([':id' => $sectionId]);
    $section = $sectionStmt->fetch(PDO::FETCH_ASSOC);
    if (!$section) {
        http_response_code(404);
        exit('Section not found.');
    }

    if ($_SESSION['role'] === 'teacher') {
        $check = $pdo->prepare('SELECT id FROM course_sections WHERE id = :id AND teacher_id = :teacher_id LIMIT 1');
        $check->execute([':id' => $sectionId, ':teacher_id' => (int)$_SESSION['user_id']]);
        if (!$check->fetch()) {
            http_response_code(403);
            exit('Unauthorized section access.');
        }
    }

    $compStmt = $pdo->prepare(
        'SELECT id, component_name, taken_out_of, convert_to
         FROM assessment_components
         WHERE section_id = :section_id
           AND (component_type = "attendance" OR component_key = "attendance" OR component_name LIKE "%Attendance%")
         ORDER BY id
         LIMIT 1'
    );
    $compStmt->execute([':section_id' => $sectionId]);
    $component = $compStmt->fetch(PDO::FETCH_ASSOC) ?: null;
    $componentId = $component ? (int)$component['id'] : 0;

    $studentStmt = $pdo->prepare(
        'SELECT e.id AS enrollment_id,
                s.identifier AS student_id,
                s.full_name AS student_name,
                s.email,
                scm.id AS mark_id,
                scm.raw_marks,
                scm.converted_marks,
                scm.is_absent,
                scm.remarks,
                scm.updated_at
         FROM enrollments e
         JOIN users s ON s.id = e.student_id
         LEFT JOIN student_component_marks scm
           ON scm.enrollment_id = e.id AND scm.component_id = :component_id
         WHERE e.section_id = :section_id
         ORDER BY s.identifier'
    );
    $studentStmt->execute([':component_id' => $componentId, ':section_id' => $sectionId]);
    $rows = $studentStmt->fetchAll(PDO::FETCH_ASSOC);

    $present = $absent = $notSet = 0;
    foreach ($rows as $row) {
        $st = att_status($row);
        if ($st === 'Present') $present++;
        elseif ($st === 'Absent') $absent++;
        else $notSet++;
    }
} catch (Throwable $e) {
    http_response_code(500);
    exit('Database error: ' . $e->getMessage());
}
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Attendance Details Report</title>
  <style>
    :root{--primary:#1a56db;--primary-dark:#0f3d9a;--border:#d7dee8;--text:#111827;--muted:#64748b;--success:#16a34a;--danger:#dc2626;--warning:#d97706}
    *{box-sizing:border-box}body{font-family:Arial,Helvetica,sans-serif;margin:0;background:#f5f7fb;color:var(--text)}
    .page{max-width:1100px;margin:24px auto;background:#fff;border:1px solid var(--border);border-radius:14px;box-shadow:0 16px 35px rgba(15,23,42,.08);overflow:hidden}
    .top{background:linear-gradient(135deg,var(--primary),var(--primary-dark));color:#fff;padding:22px 28px;display:flex;justify-content:space-between;gap:18px;align-items:flex-start}
    .brand{font-size:24px;font-weight:900;letter-spacing:.4px}.subtitle{font-size:13px;opacity:.85;margin-top:5px}.meta{text-align:right;font-size:13px;line-height:1.6}
    .body{padding:24px 28px}.info{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:18px}.box{border:1px solid var(--border);border-radius:12px;padding:12px;background:#f8fafc}.lbl{font-size:11px;text-transform:uppercase;color:var(--muted);font-weight:800;letter-spacing:.5px}.val{font-size:15px;font-weight:800;margin-top:5px}
    .summary{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:18px}.pill{border-radius:999px;padding:8px 14px;font-weight:800;font-size:13px;background:#eef2ff;color:var(--primary)}.pill.ok{background:#dcfce7;color:var(--success)}.pill.bad{background:#fee2e2;color:var(--danger)}.pill.warn{background:#fef3c7;color:var(--warning)}
    table{width:100%;border-collapse:collapse;font-size:13px}th{background:#eaf1ff;color:var(--primary-dark);border:1px solid var(--border);padding:10px;text-align:left}td{border:1px solid var(--border);padding:9px;vertical-align:top}.center{text-align:center}.status{font-weight:900}.Present{color:var(--success)}.Absent{color:var(--danger)}.NotSet{color:var(--warning)}
    .actions{max-width:1100px;margin:18px auto;text-align:right}.btn{border:0;border-radius:10px;padding:11px 16px;font-weight:800;cursor:pointer;background:var(--primary);color:#fff}.btn.secondary{background:#334155}.footer{padding:16px 28px;color:var(--muted);font-size:12px;border-top:1px solid var(--border);display:flex;justify-content:space-between;gap:12px}
    @media print{body{background:#fff}.actions{display:none}.page{margin:0;max-width:none;border:0;box-shadow:none;border-radius:0}.top{print-color-adjust:exact;-webkit-print-color-adjust:exact}}
    @media(max-width:850px){.top{display:block}.meta{text-align:left;margin-top:12px}.info{grid-template-columns:1fr 1fr}}
  </style>
</head>
<body>
  <div class="actions">
    <button class="btn" onclick="window.print()">Print / Save as PDF</button>
    <button class="btn secondary" onclick="window.close()">Close</button>
  </div>
  <main class="page">
    <section class="top">
      <div>
        <div class="brand">URAMS Attendance Details Report</div>
        <div class="subtitle">University Result & Academic Management System</div>
      </div>
      <div class="meta">
        <div><strong>Generated:</strong> <?= h_att(date('d M Y, h:i A')) ?></div>
        <div><strong>Prepared By:</strong> <?= h_att($_SESSION['full_name'] ?? 'Teacher') ?></div>
      </div>
    </section>
    <section class="body">
      <div class="info">
        <div class="box"><div class="lbl">Course</div><div class="val"><?= h_att($section['course_code']) ?> - <?= h_att($section['course_name']) ?></div></div>
        <div class="box"><div class="lbl">Section</div><div class="val"><?= h_att($section['section_name']) ?></div></div>
        <div class="box"><div class="lbl">Trimester</div><div class="val"><?= h_att($section['trimester_name']) ?></div></div>
        <div class="box"><div class="lbl">Teacher</div><div class="val"><?= h_att($section['teacher_name']) ?> (<?= h_att($section['teacher_initial']) ?>)</div></div>
        <div class="box"><div class="lbl">Class Type</div><div class="val"><?= h_att($classType ?: 'Regular') ?></div></div>
        <div class="box"><div class="lbl">Class Date</div><div class="val"><?= h_att($classDate ?: date('Y-m-d')) ?></div></div>
        <div class="box"><div class="lbl">Total Students</div><div class="val"><?= count($rows) ?></div></div>
        <div class="box"><div class="lbl">Status</div><div class="val"><?= h_att(ucfirst($section['status'])) ?></div></div>
      </div>
      <div class="summary">
        <span class="pill ok">Present: <?= $present ?></span>
        <span class="pill bad">Absent: <?= $absent ?></span>
        <span class="pill warn">Not Set: <?= $notSet ?></span>
        <span class="pill">Attendance Component: <?= h_att($component['component_name'] ?? 'Attendance') ?></span>
      </div>
      <table>
        <thead>
          <tr>
            <th class="center">SL</th>
            <th>Student ID</th>
            <th>Student Name</th>
            <th>Email</th>
            <th class="center">Status</th>
            <th class="center">Absent Count</th>
            <th class="center">Marks</th>
            <th>Comment / Remarks</th>
          </tr>
        </thead>
        <tbody>
        <?php if (!$rows): ?>
          <tr><td colspan="8" class="center">No enrolled students found for this section.</td></tr>
        <?php else: ?>
          <?php foreach ($rows as $i => $row): $status = att_status($row); $cls = str_replace(' ', '', $status); ?>
          <tr>
            <td class="center"><?= $i + 1 ?></td>
            <td><?= h_att($row['student_id']) ?></td>
            <td><?= h_att($row['student_name']) ?></td>
            <td><?= h_att($row['email']) ?></td>
            <td class="center status <?= h_att($cls) ?>"><?= h_att($status) ?></td>
            <td class="center"><?= $status === 'Absent' ? '1' : '0' ?></td>
            <td class="center"><?= $row['converted_marks'] !== null ? h_att(number_format((float)$row['converted_marks'], 2)) : '-' ?></td>
            <td><?= h_att($row['remarks'] ?? '') ?></td>
          </tr>
          <?php endforeach; ?>
        <?php endif; ?>
        </tbody>
      </table>
    </section>
    <section class="footer">
      <div>This report is generated from URAMS attendance records.</div>
      <div>Signature: ____________________</div>
    </section>
  </main>
</body>
</html>
