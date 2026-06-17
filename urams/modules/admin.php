<?php
// modules/admin.php
// Step: Fetch actual database values for the admin dashboard.

$profileInitials = e(get_user_initials());
$profileName = e(get_user_full_name());
$profileRoleLabel = e(get_user_role_label());

// 1. Fetch course sections with submission workflow status.
$sqlSections = "SELECT cs.id AS section_id,
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
                JOIN courses c ON cs.course_id = c.id
                JOIN trimesters t ON cs.trimester_id = t.id
                JOIN users u ON cs.teacher_id = u.id
                LEFT JOIN result_submissions rs ON rs.section_id = cs.id
                WHERE COALESCE(rs.status, cs.status) IN ('submitted','approved','rejected')
                ORDER BY rs.submitted_at DESC, t.start_date DESC, c.course_name, cs.section_name";
$stmtSec = $pdo->prepare($sqlSections);
$stmtSec->execute();
$adminSections = $stmtSec->fetchAll(PDO::FETCH_ASSOC);

// Calculate stats for admin dashboard.
$stmtStats = $pdo->prepare("SELECT COUNT(*) AS count FROM users WHERE role = 'teacher' AND status = 'active'");
$stmtStats->execute();
$totalTeachers = (int)$stmtStats->fetch()['count'];

$stmtStats = $pdo->prepare("SELECT COUNT(*) AS count FROM users WHERE role = 'student' AND status = 'active'");
$stmtStats->execute();
$totalStudents = (int)$stmtStats->fetch()['count'];

$stmtStats = $pdo->prepare("SELECT COUNT(*) AS count FROM result_submissions WHERE status = 'submitted'");
$stmtStats->execute();
$pendingApprovals = (int)$stmtStats->fetch()['count'];

$stmtStats = $pdo->prepare("SELECT COUNT(*) AS count FROM trimesters WHERE status = 'active'");
$stmtStats->execute();
$activeTrimesters = (int)$stmtStats->fetch()['count'];

// 2. Fetch recent audit logs.
$sqlAudit = "SELECT a.created_at, u.full_name AS user_name, u.role, a.action, a.old_value, a.new_value, a.ip_address
             FROM audit_logs a
             LEFT JOIN users u ON a.user_id = u.id
             ORDER BY a.created_at DESC
             LIMIT 100";
$stmtAudit = $pdo->prepare($sqlAudit);
$stmtAudit->execute();
$auditLogs = $stmtAudit->fetchAll(PDO::FETCH_ASSOC);

// 3. Fetch teachers list.
$stmtT = $pdo->prepare("
    SELECT u.id, u.identifier, u.full_name, u.email, u.phone, u.department, u.status,
           (SELECT COUNT(*) FROM course_sections cs WHERE cs.teacher_id = u.id) AS courses
    FROM users u
    WHERE u.role = 'teacher' AND u.status = 'active'
    ORDER BY u.full_name
");
$stmtT->execute();
$dbTeachers = $stmtT->fetchAll(PDO::FETCH_ASSOC);

// 4. Fetch students list.
$stmtS = $pdo->prepare("
    SELECT u.id, u.identifier, u.full_name, u.email, u.phone, u.program, u.department, u.status
    FROM users u
    WHERE u.role = 'student' AND u.status = 'active'
    ORDER BY u.identifier
");
$stmtS->execute();
$dbStudents = $stmtS->fetchAll(PDO::FETCH_ASSOC);
?>
<script>
window.URAMS_ADMIN_SECTIONS = <?= json_encode($adminSections, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>;
window.URAMS_AUDIT_LOGS = <?= json_encode($auditLogs, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>;
window.URAMS_ADMIN_TEACHERS = <?= json_encode($dbTeachers, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>;
window.URAMS_ADMIN_STUDENTS = <?= json_encode($dbStudents, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>;
</script>
<!-- ═══════════════════════════════════════════════════════════════
     ADMIN PANEL
     ═══════════════════════════════════════════════════════════════ -->
<div class="page active" id="page-admin">
  <div class="app-layout">
    <aside class="sidebar" id="admin-sidebar">
      <div class="sidebar-logo">
        <div class="sidebar-logo-icon"><i class="fas fa-graduation-cap"></i></div>
        <div class="sidebar-logo-text">URAMS <span>Admin Control Panel</span></div>
      </div>
      <div class="sidebar-user">
        <div class="sidebar-avatar" style="background:linear-gradient(135deg,#ef4444,#dc2626)"><?= $profileInitials ?></div>
        <div class="sidebar-user-info">
          <div class="sidebar-user-name"><?= $profileName ?></div>
          <div class="sidebar-user-role"><?= $profileRoleLabel ?></div>
        </div>
      </div>
      <nav class="sidebar-nav">
        <div class="nav-section-title">Overview</div>
        <div class="nav-item active" onclick="adminNav('dashboard',this)"><span class="nav-icon"><i class="fas fa-th-large"></i></span> Dashboard</div>
        <div class="nav-section-title">Management</div>
        <div class="nav-item" onclick="adminNav('teachers',this)"><span class="nav-icon"><i class="fas fa-chalkboard-teacher"></i></span> Manage Teachers</div>
        <div class="nav-item" onclick="adminNav('students',this)"><span class="nav-icon"><i class="fas fa-user-graduate"></i></span> Manage Students</div>
        <div class="nav-item" onclick="adminNav('academic',this)"><span class="nav-icon"><i class="fas fa-layer-group"></i></span> Academic Setup</div>
        <div class="nav-item" onclick="adminNav('approve',this)"><span class="nav-icon"><i class="fas fa-clipboard-check"></i></span> Approve Results <div class="nav-badge"><?= $pendingApprovals ?></div></div>
        <div class="nav-section-title">Settings</div>
        <div class="nav-item" onclick="adminNav('grades',this)"><span class="nav-icon"><i class="fas fa-star"></i></span> Grade Rules</div>
        <div class="nav-item" onclick="adminNav('audit',this)"><span class="nav-icon"><i class="fas fa-shield-alt"></i></span> Audit Log</div>
      </nav>
      <div class="sidebar-footer">
        <button class="sidebar-logout" onclick="logout()"><i class="fas fa-sign-out-alt"></i> Sign Out</button>
      </div>
    </aside>
    <div class="main-area">
      <header class="app-header">
        <div class="header-left">
          <button class="hamburger" onclick="toggleSidebar('admin-sidebar')"><i class="fas fa-bars"></i></button>
          <div><div class="header-title" id="admin-page-title">Admin Dashboard</div><div class="header-subtitle">System Control Center</div></div>
        </div>
        <div class="header-right" style="position:relative">
          <div class="header-btn" onclick="toggleNotifications('admin-notifs')">
            <i class="fas fa-bell"></i><div class="notif-badge"><?= $pendingApprovals ?></div>
          </div>
          <div class="notif-dropdown" id="admin-notifs">
            <div class="notif-header"><span>Pending Actions</span></div>
            <div class="notif-item unread" onclick="markNotifRead(this)"><div class="notif-dot"></div><div><div class="notif-text">📝 Result approvals pending in system</div><div class="notif-time">Now</div></div></div>
          </div>
          <div class="header-avatar" style="background:linear-gradient(135deg,#ef4444,#b91c1c)"><?= $profileInitials ?></div>
        </div>
      </header>
      <div class="content" id="admin-content">

        <!-- ADMIN DASHBOARD -->
        <div id="a-view-dashboard">
          <div class="section-header">
            <div class="section-title">System Dashboard</div>
            <span class="badge badge-success"><i class="fas fa-circle"></i> System Online</span>
          </div>
          <div class="stats-grid">
            <div class="stat-card" style="--accent:var(--primary)"><div class="stat-icon" style="background:var(--primary-glow);color:var(--primary)"><i class="fas fa-chalkboard-teacher"></i></div><div class="stat-info"><div class="stat-value"><?= $totalTeachers ?></div><div class="stat-label">Total Teachers</div></div></div>
            <div class="stat-card" style="--accent:var(--success)"><div class="stat-icon" style="background:rgba(16,185,129,0.12);color:var(--success)"><i class="fas fa-user-graduate"></i></div><div class="stat-info"><div class="stat-value"><?= number_format($totalStudents) ?></div><div class="stat-label">Total Students</div></div></div>
            <div class="stat-card" style="--accent:var(--gold)"><div class="stat-icon" style="background:var(--gold-light);color:var(--gold)"><i class="fas fa-clipboard-check"></i></div><div class="stat-info"><div class="stat-value"><?= $pendingApprovals ?></div><div class="stat-label">Pending Approvals</div></div></div>
            <div class="stat-card" style="--accent:var(--info)"><div class="stat-icon" style="background:rgba(6,182,212,0.12);color:var(--info)"><i class="fas fa-calendar-alt"></i></div><div class="stat-info"><div class="stat-value"><?= $activeTrimesters ?></div><div class="stat-label">Active Trimesters</div></div></div>
          </div>

          <!-- Quick actions -->
          <div class="admin-panel-grid">
            <div class="quick-action-card" onclick="adminNav('approve',null)">
              <div class="quick-action-icon" style="background:rgba(16,185,129,0.12);color:var(--success)"><i class="fas fa-clipboard-check"></i></div>
              <div><div style="font-weight:700;font-size:14px">Approve Results</div><div style="font-size:12px;color:var(--text2)"><?= $pendingApprovals ?> pending</div></div>
            </div>
            <div class="quick-action-card" onclick="adminNav('teachers',null)">
              <div class="quick-action-icon" style="background:var(--primary-glow);color:var(--primary)"><i class="fas fa-chalkboard-teacher"></i></div>
              <div><div style="font-weight:700;font-size:14px">Manage Teachers</div><div style="font-size:12px;color:var(--text2)"><?= $totalTeachers ?> registered</div></div>
            </div>
            <div class="quick-action-card" onclick="adminNav('students',null)">
              <div class="quick-action-icon" style="background:rgba(245,158,11,0.12);color:var(--gold)"><i class="fas fa-user-graduate"></i></div>
              <div><div style="font-weight:700;font-size:14px">Manage Students</div><div style="font-size:12px;color:var(--text2)"><?= number_format($totalStudents) ?> enrolled</div></div>
            </div>
            <div class="quick-action-card" onclick="adminNav('academic',null)">
              <div class="quick-action-icon" style="background:rgba(99,102,241,0.12);color:var(--primary)"><i class="fas fa-layer-group"></i></div>
              <div><div style="font-weight:700;font-size:14px">Academic Setup</div><div style="font-size:12px;color:var(--text2)">Programs, sections, enrollments</div></div>
            </div>
            <div class="quick-action-card" onclick="adminNav('grades',null)">
              <div class="quick-action-icon" style="background:rgba(6,182,212,0.12);color:var(--info)"><i class="fas fa-star"></i></div>
              <div><div style="font-weight:700;font-size:14px">Grade Rules</div><div style="font-size:12px;color:var(--text2)">Configurable scale</div></div>
            </div>
            <div class="quick-action-card" onclick="adminNav('audit',null)">
              <div class="quick-action-icon" style="background:rgba(239,68,68,0.1);color:var(--danger)"><i class="fas fa-shield-alt"></i></div>
              <div><div style="font-weight:700;font-size:14px">Audit Log</div><div style="font-size:12px;color:var(--text2)">All system changes</div></div>
            </div>
          </div>

          <!-- Recent audit -->
          <div class="card">
            <div class="card-header"><div class="card-title">Recent Audit Log</div><button class="btn btn-secondary btn-sm" onclick="adminNav('audit',null)">View All</button></div>
            <div class="table-wrap">
              <table>
                <thead><tr><th>Time</th><th>User</th><th>Role</th><th>Action</th><th>IP</th></tr></thead>
                <tbody id="admin-audit-mini"></tbody>
              </table>
            </div>
          </div>
        </div><!-- /#a-view-dashboard -->

        <!-- APPROVE RESULTS -->
        <div id="a-view-approve" style="display:none">
          <div class="section-header">
            <div><div class="breadcrumb"><span onclick="adminNav('dashboard',null)" style="cursor:pointer;color:var(--primary)">Dashboard</span><span>›</span>Approve Results</div><div class="section-title">Result Approvals</div></div>
          </div>
          <div class="card">
            <div class="table-wrap">
              <table>
                <thead><tr><th>Trimester</th><th>Course</th><th>Section</th><th>Teacher</th><th>Submitted</th><th>Status</th><th>Actions</th></tr></thead>
                <tbody id="approve-tbody"></tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- GRADE RULES -->
        <div id="a-view-grades" style="display:none">
          <div class="section-header">
            <div><div class="section-title">Grade Rules</div><div class="section-subtitle">Configurable grading scale — changes apply instantly to all calculations</div></div>
            <button class="btn btn-primary" onclick="addGradeRule()"><i class="fas fa-plus"></i> Add Rule</button>
          </div>
          <div class="card">
            <div class="card-body" style="padding:12px 0">
              <div class="table-wrap">
                <table>
                  <thead><tr><th>Min %</th><th>Max %</th><th>Grade</th><th>Grade Point</th><th>Remark</th><th>Actions</th></tr></thead>
                  <tbody id="grade-rules-tbody"></tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        <!-- MANAGE TEACHERS -->
        <div id="a-view-teachers" style="display:none">
          <div class="section-header">
            <div><div class="section-title">Manage Teachers</div></div>
            <button class="btn btn-primary" onclick="openTeacherForm()"><i class="fas fa-plus"></i> Add Teacher</button>
          </div>
          <div class="card"><div class="table-wrap"><table>
            <thead><tr><th>Initial</th><th>Name</th><th>Email</th><th>Phone</th><th>Courses</th><th>Actions</th></tr></thead>
            <tbody id="teachers-tbody"></tbody>
          </table></div></div>
        </div>

        <!-- MANAGE STUDENTS -->
        <div id="a-view-students" style="display:none">
          <div class="section-header">
            <div><div class="section-title">Manage Students</div></div>
            <button class="btn btn-primary" onclick="openStudentAdminForm()"><i class="fas fa-plus"></i> Add Student</button>
          </div>
          <div class="card"><div class="table-wrap"><table>
            <thead><tr><th>UIU ID</th><th>Name</th><th>Email</th><th>Program</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody id="students-tbody"></tbody>
          </table></div></div>
        </div>

        <!-- ACADEMIC SETUP -->
        <div id="a-view-academic" style="display:none">
          <div class="section-header">
            <div>
              <div class="breadcrumb"><span onclick="adminNav('dashboard',null)" style="cursor:pointer;color:var(--primary)">Dashboard</span><span>›</span>Academic Setup</div>
              <div class="section-title">Academic Setup</div>
              <div class="section-subtitle">Create sections, assign teachers, enroll students, and enforce prerequisites.</div>
            </div>
            <button class="btn btn-secondary btn-sm" onclick="loadAcademicData(true)"><i class="fas fa-sync"></i> Refresh</button>
          </div>

          <div class="admin-panel-grid">
            <div class="card" style="margin:0">
              <div class="card-header"><div class="card-title"><i class="fas fa-plus-circle"></i> Create Course Section</div></div>
              <div class="card-body">
                <div class="form-group"><label class="form-label">Program</label><select class="form-control" id="academic-section-program" onchange="academicOnProgramChange('section')"></select></div>
                <div class="form-group"><label class="form-label">Curriculum</label><select class="form-control" id="academic-section-curriculum" onchange="academicOnCurriculumChange('section')"></select></div>
                <div class="form-group"><label class="form-label">Trimester</label><select class="form-control" id="academic-section-trimester"></select></div>
                <div class="form-group"><label class="form-label">Course</label><select class="form-control" id="academic-section-course"></select></div>
                <div class="form-group"><label class="form-label">Teacher</label><select class="form-control" id="academic-section-teacher"></select></div>
                <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
                  <div class="form-group"><label class="form-label">Section</label><input class="form-control" id="academic-section-name" value="A" maxlength="10"></div>
                  <div class="form-group"><label class="form-label">Capacity</label><input class="form-control" id="academic-section-capacity" type="number" min="1" value="40"></div>
                </div>
                <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
                  <div class="form-group"><label class="form-label">Room</label><input class="form-control" id="academic-section-room" placeholder="e.g. 323 Permanent Campus" maxlength="100"></div>
                  <div class="form-group"><label class="form-label">Class Schedule</label><input class="form-control" id="academic-section-schedule" placeholder="e.g. Sun 03:11PM-04:30PM; Wed 03:11PM-04:30PM" maxlength="255"></div>
                </div>
                <button class="btn btn-primary" style="width:100%" onclick="createAcademicSection()"><i class="fas fa-save"></i> Create Section</button>
              </div>
            </div>

            <div class="card" style="margin:0">
              <div class="card-header"><div class="card-title"><i class="fas fa-user-plus"></i> Enroll Student</div></div>
              <div class="card-body">
                <div class="form-group"><label class="form-label">Student</label><select class="form-control" id="academic-enroll-student"></select></div>
                <div class="form-group"><label class="form-label">Section</label><select class="form-control" id="academic-enroll-section"></select></div>
                <div class="form-group"><label class="form-label">Parent ID</label><input class="form-control" id="academic-enroll-parent" placeholder="e.g. PARENT0242220005"></div>
                <div class="form-group"><label style="display:flex;gap:8px;align-items:center;font-size:13px"><input type="checkbox" id="academic-enroll-force"> Force enroll even if prerequisite missing</label></div>
                <div class="btn-group" style="width:100%">
                  <button class="btn btn-secondary" style="flex:1" onclick="checkAcademicPrerequisites()"><i class="fas fa-check-circle"></i> Check</button>
                  <button class="btn btn-primary" style="flex:1" onclick="enrollAcademicStudent()"><i class="fas fa-save"></i> Enroll</button>
                </div>
                <div id="academic-prereq-result" style="margin-top:12px;font-size:12px;color:var(--text2)"></div>
              </div>
            </div>
          </div>

          <div class="card">
            <div class="card-header"><div class="card-title">Active Sections</div></div>
            <div class="table-wrap"><table>
              <thead><tr><th>Trimester</th><th>Program</th><th>Course</th><th>Section</th><th>Teacher</th><th>Students</th><th>Room</th><th>Schedule</th><th>Status</th></tr></thead>
              <tbody id="academic-sections-tbody"></tbody>
            </table></div>
          </div>

          <div class="card">
            <div class="card-header"><div class="card-title">Curriculum Courses</div><div class="filter-group" style="margin:0"><select class="form-control" id="academic-course-filter" onchange="renderAcademicTables()"></select></div></div>
            <div class="table-wrap"><table>
              <thead><tr><th>Program</th><th>Code</th><th>Course</th><th>Credit</th><th>Type</th><th>Level</th><th>Prerequisite</th></tr></thead>
              <tbody id="academic-courses-tbody"></tbody>
            </table></div>
          </div>
        </div>

        <!-- AUDIT LOG -->
        <div id="a-view-audit" style="display:none">
          <div class="section-header">
            <div><div class="section-title">Audit Log</div></div>
            <button class="btn btn-secondary btn-sm" onclick="showToast('CSV exported!','success','Export')"><i class="fas fa-file-csv"></i> Export CSV</button>
          </div>
          <div class="filter-bar" style="margin-bottom:16px">
            <div class="filter-group"><label>Date From</label><input type="date" class="form-control"></div>
            <div class="filter-group"><label>Date To</label><input type="date" class="form-control"></div>
            <div class="filter-group"><label>Role</label><select class="form-control"><option>All</option><option>Teacher</option><option>Admin</option></select></div>
            <div style="align-self:flex-end"><button class="btn btn-primary"><i class="fas fa-search"></i> Search</button></div>
          </div>
          <div class="card"><div class="table-wrap"><table>
            <thead><tr><th>Date/Time</th><th>User</th><th>Role</th><th>Action</th><th>Old Value</th><th>New Value</th><th>IP</th></tr></thead>
            <tbody id="audit-tbody"></tbody>
          </table></div></div>
        </div>

      </div>
    </div>
  </div>


<!-- Admin Teacher/Student Form Modal -->
<div class="modal-overlay" id="modal-admin-user">
  <div class="modal">
    <div class="modal-header">
      <div class="modal-title" id="admin-user-modal-title"><i class="fas fa-user-plus" style="color:var(--primary)"></i> Add User</div>
      <button class="modal-close" onclick="closeModal('modal-admin-user')"><i class="fas fa-times"></i></button>
    </div>
    <div class="modal-body">
      <input type="hidden" id="admin-user-mode" value="add">
      <input type="hidden" id="admin-user-role" value="teacher">
      <input type="hidden" id="admin-user-id" value="">
      <div class="form-group">
        <label class="form-label">Name</label>
        <input type="text" class="form-control" id="admin-user-full-name" placeholder="Full name">
      </div>
      <div class="form-group">
        <label class="form-label">Email</label>
        <input type="email" class="form-control" id="admin-user-email" placeholder="email@example.com">
      </div>
      <div class="form-group">
        <label class="form-label" id="admin-user-identifier-label">Initial / ID</label>
        <input type="text" class="form-control" id="admin-user-identifier" placeholder="MRI or 0242220005">
      </div>
      <div class="form-group">
        <label class="form-label">Phone</label>
        <input type="text" class="form-control" id="admin-user-phone" placeholder="Optional phone">
      </div>
      <div class="form-group" id="admin-user-program-wrap">
        <label class="form-label">Program</label>
        <select class="form-control" id="admin-user-program" onchange="academicStudentProgramChanged()">
          <option value="BSc CSE">BSc CSE</option>
          <option value="BSc EEE">BSc EEE</option>
          <option value="BBA">BBA</option>
          <option value="B.Pharm">B.Pharm</option>
        </select>
        <input type="hidden" id="admin-user-program-id" value="">
      </div>
      <div class="form-group" id="admin-user-curriculum-wrap" style="display:none">
        <label class="form-label">Curriculum</label>
        <select class="form-control" id="admin-user-curriculum-id"></select>
      </div>
      <div class="form-group">
        <label class="form-label">Department</label>
        <input type="text" class="form-control" id="admin-user-department" placeholder="e.g. CSE">
      </div>
      <div class="form-group" id="admin-user-parent-wrap" style="display:none">
        <label class="form-label">Parent ID</label>
        <input type="text" class="form-control" id="admin-user-parent-identifier" placeholder="e.g. PARENT0242220099">
      </div>
      <div class="form-group" id="admin-user-section-wrap" style="display:none">
        <label class="form-label">Initial Course/Section Enrollment</label>
        <select class="form-control" id="admin-user-section-id">
          <option value="">No section now</option>
        </select>
        <div style="font-size:11px;color:var(--text2);margin-top:4px">Student will appear in Teacher marks table only after section enrollment.</div>
      </div>
      <div class="form-group">
        <label class="form-label">Password <span style="font-size:11px;color:var(--text2)">(leave blank on edit)</span></label>
        <input type="password" class="form-control" id="admin-user-password" placeholder="Default: password123">
      </div>
    </div>
    <div class="modal-footer">
      <button class="btn btn-secondary" onclick="closeModal('modal-admin-user')">Cancel</button>
      <button class="btn btn-primary" onclick="submitAdminUserForm()"><i class="fas fa-save"></i> Save</button>
    </div>
  </div>
</div>

</div><!-- /#page-admin -->

