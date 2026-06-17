<?php
// modules/teacher.php
// Teacher panel UI. Data is loaded dynamically from JSON endpoints.

if (function_exists('ensure_profile_photo_column')) {
    ensure_profile_photo_column($pdo);
}

$profileInitials = e(get_user_initials());
$profileName = e(get_user_full_name());
$profileRoleLabel = e(get_user_role_label());
$teacherId = (int)($_SESSION['user_id'] ?? 0);

$teacherProfile = [
    'full_name' => get_user_full_name(),
    'email' => (string)($_SESSION['email'] ?? ''),
    'identifier' => (string)($_SESSION['identifier'] ?? ''),
    'phone' => '',
    'department' => 'CSE',
    'status' => 'active',
    'profile_photo' => get_user_profile_photo(),
];

if ($teacherId > 0) {
    try {
        $profileStmt = $pdo->prepare('SELECT full_name, email, identifier, phone, department, status, profile_photo FROM users WHERE id = :id LIMIT 1');
        $profileStmt->execute([':id' => $teacherId]);
        $profileRow = $profileStmt->fetch(PDO::FETCH_ASSOC);
        if ($profileRow) {
            $teacherProfile = array_merge($teacherProfile, array_filter($profileRow, static fn($v) => $v !== null));
            $_SESSION['full_name'] = (string)$teacherProfile['full_name'];
            $_SESSION['email'] = (string)$teacherProfile['email'];
            $_SESSION['identifier'] = (string)$teacherProfile['identifier'];
            $_SESSION['profile_photo'] = (string)($teacherProfile['profile_photo'] ?? '');
            $profileInitials = e(get_user_initials());
            $profileName = e(get_user_full_name());
            $profileRoleLabel = e(get_user_role_label());
        }
    } catch (Throwable $ignored) {
        // Keep session values if optional profile fields are not available.
    }
}

$profilePhotoPath = get_user_profile_photo();
$profilePhotoEsc = e($profilePhotoPath);
$teacherEmail = e((string)($teacherProfile['email'] ?? ''));
$teacherInitial = e(strtoupper((string)($teacherProfile['identifier'] ?? '')));
$teacherDepartment = e((string)($teacherProfile['department'] ?? 'CSE'));
$teacherPhone = e((string)($teacherProfile['phone'] ?? ''));
$teacherStatus = strtolower((string)($teacherProfile['status'] ?? 'active'));
$teacherStatusLabel = e(ucfirst($teacherStatus ?: 'Active'));
$teacherAvatarHtml = $profilePhotoPath !== ''
    ? '<img src="' . $profilePhotoEsc . '" alt="' . $profileName . '" class="urams-avatar-img">'
    : $profileInitials;

$teacherSections = [];
$activeSectionId = null;

if ($teacherId > 0) {
    $sectionExtraSelect = '';
    try {
        $sectionColumns = $pdo->query('SHOW COLUMNS FROM course_sections')->fetchAll(PDO::FETCH_COLUMN);
        if (in_array('class_schedule', $sectionColumns, true)) {
            $sectionExtraSelect .= ', cs.class_schedule';
        }
        if (in_array('room', $sectionColumns, true)) {
            $sectionExtraSelect .= ', cs.room';
        }
        if (in_array('capacity', $sectionColumns, true)) {
            $sectionExtraSelect .= ', cs.capacity';
        }
    } catch (Throwable $ignored) {
        $sectionExtraSelect = '';
    }

    $stmt = $pdo->prepare(
        "SELECT cs.id AS section_id,
                cs.status,
                c.course_code,
                c.course_name,
                cs.section_name,
                t.name AS trimester_name,
                (SELECT COUNT(*) FROM enrollments e WHERE e.section_id = cs.id) AS student_count
                $sectionExtraSelect
         FROM course_sections cs
         JOIN courses c ON c.id = cs.course_id
         JOIN trimesters t ON t.id = cs.trimester_id
         WHERE cs.teacher_id = :teacher_id
         ORDER BY t.start_date DESC, c.course_code, cs.section_name"
    );
    $stmt->execute([':teacher_id' => $teacherId]);
    $teacherSections = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($teacherSections as &$section) {
        $section['section_id'] = (int)$section['section_id'];
        $section['student_count'] = (int)$section['student_count'];
    }
    unset($section);

    $activeSectionId = null; // keep filters blank until teacher manually selects and clicks Apply
}
?>
<script>
window.URAMS_TEACHER_SECTIONS = <?= json_encode($teacherSections, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>;
window.URAMS_ACTIVE_SECTION_ID = <?= json_encode($activeSectionId) ?>;
window.URAMS_TEACHER_STUDENTS = [];
window.URAMS_TEACHER_COMPONENTS = [];
window.URAMS_TEACHER_SECTION = null;
</script>

<style>
.legacy-grade-toolbar{display:grid;grid-template-columns:1.2fr 1fr 1fr;gap:16px;margin-bottom:16px}
.legacy-grade-panel{border:1px solid var(--border);border-radius:14px;background:var(--card);box-shadow:var(--shadow);padding:16px}
.legacy-grade-panel-title{font-weight:800;margin-bottom:10px;color:var(--text)}
.legacy-grade-row{display:flex;gap:14px;align-items:flex-end;flex-wrap:wrap}
.legacy-grade-row .form-group{margin:0;min-width:180px;flex:1}
.legacy-grade-action{min-width:180px}
.legacy-grade-sheet-actions{display:flex;gap:12px;justify-content:center;align-items:center;flex-wrap:wrap;margin:12px 0 16px}
.legacy-grade-table-wrap{overflow:auto;border:1px solid var(--border);border-radius:12px;background:var(--card)}
#legacy-grade-table{min-width:1100px;width:100%;border-collapse:collapse}
#legacy-grade-table th{background:#1f2937;color:#fff;text-align:center;vertical-align:middle;border:1px solid rgba(255,255,255,.18);font-size:12px;white-space:nowrap}
#legacy-grade-table td{text-align:center;vertical-align:middle;border:1px solid var(--border);font-size:12px;white-space:nowrap}
#legacy-grade-table .legacy-student-name{text-align:left;font-weight:700;min-width:180px}
.legacy-mark-input{width:80px;min-width:72px;padding:6px 8px;text-align:center;border:1px solid var(--border);border-radius:8px;background:var(--bg);font-weight:700}
.legacy-mark-input:focus{outline:none;border-color:var(--primary);box-shadow:0 0 0 3px var(--primary-glow)}
.legacy-converted{display:block;margin-top:4px;font-size:11px;color:var(--success);font-weight:800}
.legacy-mini-note{font-size:11px;color:var(--text2);font-weight:600;display:block;margin-top:2px}
.legacy-instruction-btn{background:var(--gold);color:white;border:0;border-radius:8px;padding:10px 14px;font-weight:800;box-shadow:var(--shadow-sm)}
.marks-section-loader{border:1px solid var(--border);border-radius:14px;background:var(--card);box-shadow:var(--shadow);padding:16px;margin-bottom:16px}
.marks-section-loader-grid{display:grid;grid-template-columns:minmax(260px,1.35fr) auto auto minmax(170px,.8fr);gap:14px;align-items:end}
.marks-section-status{font-size:12px;font-weight:800;color:var(--text2);padding:11px 12px;border:1px dashed var(--border);border-radius:10px;background:var(--bg)}
.legacy-grade-toolbar{grid-template-columns:1.2fr 1fr 1fr}
#legacy-grade-table th{background:#1e3a8a!important;color:#fff!important;text-transform:uppercase;letter-spacing:.02em}
#legacy-grade-table th.legacy-group-head{background:#1d4ed8!important}
#legacy-grade-table td{background:#fff}
#legacy-grade-table tbody tr:nth-child(even) td{background:#f8fbff}
#legacy-grade-table .legacy-mark-input{background:#fff}
#component-marks-card{display:none!important}
.legacy-sheet-toolbar-note{display:flex;justify-content:center;gap:12px;flex-wrap:wrap;align-items:center}
@media(max-width:1100px){.legacy-grade-toolbar{grid-template-columns:1fr}.legacy-grade-action{min-width:140px}.marks-section-loader-grid{grid-template-columns:1fr}}

.teacher-notif-dropdown{right:42px;top:46px;width:360px;max-height:420px;overflow:auto;z-index:9999}
.teacher-notif-dropdown .notif-item{align-items:flex-start}
.teacher-notif-dropdown .notif-text{font-size:13px;line-height:1.35;color:var(--text)}
.teacher-notif-dropdown .notif-time{font-size:11px;color:var(--text2);margin-left:auto;white-space:nowrap}
.teacher-routine-filter{display:grid;grid-template-columns:1fr 1fr auto;gap:12px;align-items:end;margin-bottom:14px}
.teacher-routine-title{font-size:18px;font-weight:900;color:var(--text);margin:10px 0 6px}
.teacher-routine-note{font-size:12px;color:var(--text2);margin-bottom:12px}
.teacher-routine-table th,.teacher-routine-table td{text-align:center;vertical-align:middle}
.teacher-routine-table .td-name{text-align:left;font-weight:700;min-width:220px}
@media(max-width:760px){.teacher-routine-filter{grid-template-columns:1fr}.teacher-notif-dropdown{right:0;width:calc(100vw - 32px)}}



/* Legacy attendance entry UI */
.attendance-legacy-filter-card{border:1px solid var(--border);border-radius:14px;background:var(--card);box-shadow:var(--shadow);padding:16px;margin-bottom:16px}
.attendance-legacy-grid{display:grid;grid-template-columns:minmax(260px,1.4fr) minmax(130px,.7fr) minmax(150px,.7fr) repeat(4,max-content);gap:12px;align-items:end}
.attendance-legacy-actions{display:flex;gap:10px;align-items:center;justify-content:center;margin:12px 0 16px;flex-wrap:wrap}
.attendance-find-wrap{display:flex;align-items:center;gap:10px;justify-content:flex-end;margin-bottom:10px}
.attendance-find-wrap .form-control{max-width:320px}
.attendance-legacy-table-wrap{overflow:auto;border:1px solid #9ca3af;background:#fff;border-radius:8px}
#attendance-entry-table{min-width:1050px;width:100%;border-collapse:collapse;font-size:13px;color:var(--text);background:var(--card)}
#attendance-entry-table th{background:linear-gradient(135deg,var(--primary),var(--primary-dark));color:#fff;border:1px solid rgba(255,255,255,.18);text-align:center;padding:10px 8px;vertical-align:middle;font-weight:800}
#attendance-entry-table td{border:1px solid var(--border);text-align:center;padding:8px;vertical-align:middle;background:var(--card)}
#attendance-entry-table tbody tr:nth-child(even) td{background:rgba(26,86,219,0.045)}
#attendance-entry-table .td-name{text-align:left;font-weight:700;min-width:190px}
#attendance-entry-table .td-id{font-weight:700;color:var(--primary-dark);white-space:nowrap}
#attendance-entry-table .att-photo{width:46px;height:46px;border-radius:10px;background:var(--primary-glow);display:inline-flex;align-items:center;justify-content:center;font-weight:900;color:var(--primary);border:1px solid var(--border);overflow:hidden}
#attendance-entry-table .att-photo img{width:100%;height:100%;object-fit:cover}
.att-status-cell{min-width:250px}
.att-radio-group{display:flex;align-items:center;justify-content:center;gap:18px;flex-wrap:wrap}
.att-radio-option{display:inline-flex;flex-direction:column;align-items:center;gap:3px;font-size:12px;color:var(--text);font-weight:700;cursor:pointer}
.att-radio-option input{width:14px;height:14px;accent-color:#2563eb;cursor:pointer}
.att-comment-input{width:100%;min-width:220px;border:1px solid var(--border);border-radius:8px;padding:7px 9px;background:var(--card);color:var(--text);font-size:13px}
.att-empty-state{text-align:center;padding:28px;color:var(--text2);background:var(--card)!important;font-weight:700}
.att-email-box{background:#f8fafc;border:1px solid var(--border);border-radius:10px;padding:12px;margin:10px 0;display:none}
.att-email-box textarea{width:100%;min-height:90px;border:1px solid var(--border);border-radius:8px;padding:10px;background:#fff;font-family:monospace;font-size:12px}
@media(max-width:1100px){.attendance-legacy-grid{grid-template-columns:1fr 1fr}.attendance-find-wrap{justify-content:flex-start}.attendance-find-wrap .form-control{max-width:none}}
@media(max-width:720px){.attendance-legacy-grid{grid-template-columns:1fr}.attendance-legacy-actions{justify-content:flex-start}}



/* Teacher profile photo UI */
.urams-profile-avatar{overflow:hidden;background:linear-gradient(135deg,var(--primary),var(--gold));}
.urams-avatar-img{width:100%;height:100%;object-fit:cover;display:block;border-radius:inherit;}
.teacher-profile-layout{display:grid;grid-template-columns:340px 1fr;gap:24px;align-items:start;}
.teacher-profile-photo-card,.teacher-account-card{background:var(--card);border:1px solid var(--border);border-radius:18px;box-shadow:var(--shadow);overflow:hidden;}
.teacher-profile-photo-card{padding:28px;text-align:center;}
.teacher-profile-photo-preview{width:150px;height:150px;border-radius:50%;margin:0 auto 22px;background:var(--primary-glow);display:flex;align-items:center;justify-content:center;font-size:52px;font-weight:900;color:var(--primary);overflow:hidden;border:5px solid rgba(26,86,219,.12);}
.teacher-profile-upload-btn{width:100%;justify-content:center;font-size:15px;padding:13px 18px;margin-bottom:12px;}
.teacher-profile-help{font-size:12px;color:var(--text2);line-height:1.45;}
.teacher-account-card .card-header{border-bottom:1px solid var(--border);}
.teacher-account-grid{display:grid;grid-template-columns:1fr 1fr;gap:18px;}
.teacher-account-field{display:flex;flex-direction:column;gap:8px;}
.teacher-account-field label{font-size:12px;font-weight:800;color:var(--text2);text-transform:uppercase;letter-spacing:.04em;}
.teacher-account-field .profile-readonly{width:100%;padding:13px 14px;border:1px solid var(--border);border-radius:10px;background:var(--bg);font-weight:700;color:var(--text);min-height:45px;display:flex;align-items:center;}
.teacher-profile-topline{display:flex;align-items:center;gap:14px;margin-bottom:18px;}
.teacher-profile-mini-avatar{width:58px;height:58px;border-radius:50%;background:linear-gradient(135deg,var(--primary),var(--gold));display:flex;align-items:center;justify-content:center;color:#fff;font-size:20px;font-weight:900;overflow:hidden;flex-shrink:0;}
@media(max-width:900px){.teacher-profile-layout{grid-template-columns:1fr}.teacher-account-grid{grid-template-columns:1fr}}

</style>

<div class="page active" id="page-teacher">
  <div class="app-layout">
    <aside class="sidebar" id="teacher-sidebar">
      <div class="sidebar-logo">
        <div class="sidebar-logo-icon"><i class="fas fa-graduation-cap"></i></div>
        <div class="sidebar-logo-text">URAMS <span>UIU Academic System</span></div>
      </div>
      <div class="sidebar-user">
        <div class="sidebar-avatar urams-profile-avatar" data-profile-avatar><?= $teacherAvatarHtml ?></div>
        <div class="sidebar-user-info">
          <div class="sidebar-user-name"><?= $profileName ?></div>
          <div class="sidebar-user-role"><?= $profileRoleLabel ?></div>
        </div>
      </div>
      <nav class="sidebar-nav">
        <div class="nav-section-title">Main</div>
        <div class="nav-item active" onclick="teacherNav('dashboard',this)">
          <span class="nav-icon"><i class="fas fa-th-large"></i></span> Dashboard
        </div>
        <div class="nav-item" onclick="teacherNav('marks',this)">
          <span class="nav-icon"><i class="fas fa-edit"></i></span> Add / Edit Marks
        </div>
        <div class="nav-item" onclick="teacherNav('attendance',this)">
          <span class="nav-icon"><i class="fas fa-calendar-check"></i></span> Attendance
        </div>
        <div class="nav-item" onclick="teacherNav('submit',this)">
          <span class="nav-icon"><i class="fas fa-paper-plane"></i></span> Submit Result
        </div>
        <div class="nav-section-title">Account</div>
        <div class="nav-item" onclick="teacherNav('profile',this)">
          <span class="nav-icon"><i class="fas fa-user-circle"></i></span> My Profile
        </div>
      </nav>
      <div class="sidebar-footer">
        <button class="sidebar-logout" onclick="logout()"><i class="fas fa-sign-out-alt"></i> Sign Out</button>
      </div>
    </aside>

    <div class="main-area">
      <header class="app-header">
        <div class="header-left">
          <button class="hamburger" onclick="toggleSidebar('teacher-sidebar')"><i class="fas fa-bars"></i></button>
          <div>
            <div class="header-title" id="teacher-page-title">Dashboard</div>
            <div class="header-subtitle" id="teacher-header-subtitle">Teacher Panel</div>
          </div>
        </div>
        <div class="header-right" style="position:relative">
          <div class="header-btn" onclick="loadCurrentTeacherSection(true)" title="Refresh"><i class="fas fa-sync-alt"></i></div>
          <div class="header-btn" id="teacher-notif-button" onclick="event.stopPropagation();toggleTeacherNotifications(event)" title="Notifications">
            <i class="fas fa-bell"></i>
            <span class="notif-badge" id="teacher-notif-badge">3</span>
          </div>
          <div class="notif-dropdown teacher-notif-dropdown" id="teacher-notif-dropdown" onclick="event.stopPropagation()">
            <div class="notif-header"><span>Teacher Notifications</span><button onclick="markAllTeacherNotifications()" class="btn btn-ghost btn-sm">Mark all read</button></div>
            <div id="teacher-notif-list">
              <div class="notif-item unread" onclick="markNotifRead(this)"><span class="notif-dot"></span><div class="notif-text">Loading teacher notifications...</div><div class="notif-time">Now</div></div>
            </div>
          </div>
          <div class="header-avatar urams-profile-avatar" title="Profile" data-profile-avatar><?= $teacherAvatarHtml ?></div>
        </div>
      </header>

      <div class="content" id="teacher-content">
        <div id="view-dashboard">
          <div class="section-header">
            <div>
              <div class="section-title">Teacher Dashboard</div>
              <div class="section-subtitle">Overview of your assigned sections and result progress</div>
            </div>
            <div class="btn-group">
              <button class="btn btn-secondary btn-sm" onclick="loadCurrentTeacherSection(true)"><i class="fas fa-sync-alt"></i> Refresh</button>
            </div>
          </div>

          <div class="stats-grid">
            <div class="stat-card" onclick="teacherStatNavigate('sections')" style="cursor:pointer;--accent:var(--primary);--icon-bg:var(--primary-glow);--icon-color:var(--primary)">
              <div class="stat-icon"><i class="fas fa-book-open"></i></div>
              <div class="stat-info"><div class="stat-value" id="teacher-stat-courses">0</div><div class="stat-label">Active Sections</div><div class="stat-change up">Click to view sections</div></div>
            </div>
            <div class="stat-card" onclick="teacherStatNavigate('students')" style="cursor:pointer;--accent:var(--success);--icon-bg:rgba(16,185,129,0.12);--icon-color:var(--success)">
              <div class="stat-icon"><i class="fas fa-users"></i></div>
              <div class="stat-info"><div class="stat-value" id="teacher-stat-students">0</div><div class="stat-label">Total Students</div><div class="stat-change up">Across assigned sections</div></div>
            </div>
            <div class="stat-card" onclick="teacherStatNavigate('routine')" style="cursor:pointer;--accent:var(--gold);--icon-bg:var(--gold-light);--icon-color:var(--gold)">
              <div class="stat-icon"><i class="fas fa-calendar-day"></i></div>
              <div class="stat-info"><div class="stat-value" id="teacher-stat-routine">0</div><div class="stat-label">Class Routine</div><div class="stat-change up">Today / weekly schedule</div></div>
            </div>
            <div class="stat-card" onclick="teacherStatNavigate('status')" style="cursor:pointer;--accent:var(--danger);--icon-bg:rgba(239,68,68,0.1);--icon-color:var(--danger)">
              <div class="stat-icon"><i class="fas fa-clipboard-check"></i></div>
              <div class="stat-info"><div class="stat-value" id="teacher-stat-status">0</div><div class="stat-label">Pending Results</div><div class="stat-change down">Need marks / submit</div></div>
            </div>
          </div>

          <div class="filter-bar">
            <div class="filter-group">
              <label><i class="fas fa-calendar"></i> Trimester</label>
              <select class="form-control" id="filter-trimester" onchange="filterChanged()"></select>
            </div>
            <div class="filter-group">
              <label><i class="fas fa-book"></i> Course</label>
              <select class="form-control" id="filter-course" onchange="filterChanged()"></select>
            </div>
            <div class="filter-group">
              <label><i class="fas fa-layer-group"></i> Section</label>
              <select class="form-control" id="filter-section" onchange="filterChanged()"></select>
            </div>
            <div style="display:flex;gap:8px;align-items:flex-end">
              <button class="btn btn-primary" onclick="applyFilter()"><i class="fas fa-search"></i> Apply</button>
            </div>
          </div>

          <div class="btn-group" style="margin-bottom:16px">
            <button class="btn btn-secondary btn-sm" onclick="teacherNav('marks', null)"><i class="fas fa-edit"></i> Add / Edit Marks</button>
            <button class="btn btn-success btn-sm" onclick="confirmSubmitResult()"><i class="fas fa-paper-plane"></i> Submit Result</button>
          </div>

          <div class="card">
            <div class="card-header">
              <div>
                <div class="card-title" id="teacher-section-title">Loading section...</div>
                <div class="card-subtitle" id="teacher-section-subtitle">Students and marks are loaded from database.</div>
              </div>
              <div class="btn-group">
                <input type="text" class="form-control" placeholder="🔍 Search student..." id="student-search" oninput="filterStudents()" style="width:200px">
              </div>
            </div>
            <div class="table-wrap">
              <table id="result-table">
                <thead id="result-thead"></thead>
                <tbody id="result-tbody">
                  <tr><td style="text-align:center;padding:20px">Loading...</td></tr>
                </tbody>
              </table>
            </div>
            <div class="card-footer">
              <span style="font-size:12px;color:var(--text2)">Showing <strong id="student-count">0</strong> students · Last updated: <span id="teacher-last-updated">---</span></span>
            </div>
          </div>
        </div>

        <div id="view-marks" style="display:none">
          <div class="section-header">
            <div>
              <div class="breadcrumb"><span onclick="teacherNav('dashboard',null)" style="cursor:pointer;color:var(--primary)">Dashboard</span> <span>›</span> Marks Entry</div>
              <div class="section-title">Add / Edit Marks</div>
              <div class="section-subtitle" id="marks-section-subtitle">Select a component and enter actual marks.</div>
            </div>
            <div class="btn-group">
              <button class="btn btn-secondary btn-sm" onclick="loadCurrentTeacherSection(true)"><i class="fas fa-sync-alt"></i> Reload</button>
            </div>
          </div>


          <div class="marks-section-loader">
            <div class="marks-section-loader-grid">
              <div class="form-group" style="margin:0">
                <label class="form-label">Course With Section</label>
                <select class="form-control" id="marks-section-select">
                  <option value="">Select Course & Section</option>
                </select>
              </div>
              <button class="btn btn-primary" onclick="loadMarksStudentsLegacy()"><i class="fas fa-users"></i> Load Students</button>
              <button class="btn btn-secondary" onclick="downloadTeacherSelectedResultPdf()" title="Print/save only the selected section result sheet, not the full screen"><i class="fas fa-file-pdf"></i> Result PDF</button>
              <div class="marks-section-status" id="marks-loader-status">No section loaded.</div>
            </div>
          </div>

          <div class="legacy-grade-toolbar">
            <div class="legacy-grade-panel">
              <div class="legacy-grade-panel-title">Assessment :</div>
              <div class="legacy-grade-row">
                <div class="form-group">
                  <select class="form-control" id="legacy-assessment-filter" onchange="renderLegacyGradeSheet()">
                    <option value="">All Assessment</option>
                  </select>
                </div>
                <button class="btn btn-info legacy-grade-action" onclick="recalculateAttendanceLegacy()"><i class="fas fa-sync-alt"></i> Re-Calculate Attendance</button>
              </div>
            </div>
            <div class="legacy-grade-panel">
              <div class="legacy-grade-panel-title">Excel Tools</div>
              <div class="legacy-grade-row" style="justify-content:center">
                <button class="btn btn-info legacy-grade-action" onclick="downloadMarksExcel()"><i class="fas fa-file-excel"></i> Download CSV (Excel)</button>
                <button class="btn btn-danger legacy-grade-action" onclick="document.getElementById('legacy-excel-file').click()"><i class="fas fa-upload"></i> Upload CSV</button>
                <input type="file" id="legacy-excel-file" accept=".csv,text/csv" style="display:none" onchange="uploadMarksExcel(this)">
              </div>
            </div>
            <div class="legacy-grade-panel">
              <div class="legacy-grade-panel-title">Apply Grace Marks</div>
              <div class="legacy-grade-row">
                <div class="form-group">
                  <select class="form-control" id="legacy-grace-value">
                    <option value="0">0</option>
                    <option value="1">1</option>
                    <option value="2">2</option>
                    <option value="3">3</option>
                    <option value="4">4</option>
                    <option value="5">5</option>
                  </select>
                </div>
                <button class="btn btn-success legacy-grade-action" onclick="gradeProcessLegacy()"><i class="fas fa-check-circle"></i> Grade Process</button>
              </div>
            </div>
          </div>

          <div class="card" id="legacy-grade-sheet-card" style="margin-bottom:16px">
            <div class="card-header legacy-sheet-toolbar-note" style="justify-content:center;flex-wrap:wrap;gap:12px">
              <button class="legacy-instruction-btn" onclick="showLegacyMarksInstruction()"><i class="fas fa-info-circle"></i> Marks Entry Instruction</button>
              <button class="btn btn-info" onclick="calculateCtAverageLegacy()"><i class="fas fa-calculator"></i> Calculate CT Average</button>
              <button class="btn btn-primary" onclick="showGradeDetailsLegacy()"><i class="fas fa-list"></i> Grade Details</button>
              <button class="btn btn-success" onclick="saveLegacyGradeSheet()"><i class="fas fa-save"></i> Save Full Sheet</button>
            </div>
            <div class="legacy-grade-table-wrap">
              <table id="legacy-grade-table">
                <thead id="legacy-grade-thead">
                  <tr><th>SL</th><th>Student ID</th><th>Student Name</th><th>Status</th><th>Total</th><th>Grade</th></tr>
                </thead>
                <tbody id="legacy-grade-tbody">
                  <tr><td colspan="6" style="padding:24px;text-align:center;color:var(--text2)">Select trimester, course and section, then click Apply.</td></tr>
                </tbody>
              </table>
            </div>
            <div class="card-footer">
              <span style="font-size:12px;color:var(--text2)">Excel-like full result sheet. Edit marks directly, then click Save Full Sheet / Grade Process.</span>
            </div>
          </div>

          <!-- Exam Configuration removed as requested. Component totals are managed from the sheet/actions. -->

          <div class="chart-wrapper" id="marks-chart-wrapper" style="display:none;margin-bottom:16px">
            <div class="chart-title" id="marks-chart-title"><i class="fas fa-chart-bar" style="color:var(--primary)"></i> Marks Distribution</div>
            <canvas id="marks-bar-chart" height="220"></canvas>
          </div>

          <div class="card" id="component-marks-card">
            <div class="card-header">
              <div class="card-title" id="marks-table-title">Student Marks Entry</div>
              <input type="text" class="form-control" placeholder="🔍 Search student..." style="width:200px" oninput="filterMarksTable(this.value)">
            </div>
            <div class="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>#</th><th>Photo</th><th>UIU ID</th><th>Name</th>
                    <th id="marks-actual-head">Actual Marks</th>
                    <th id="marks-converted-head">Converted</th>
                    <th>Absent?</th><th>Actions</th>
                  </tr>
                </thead>
                <tbody id="marks-tbody"></tbody>
              </table>
            </div>
            <div class="card-footer">
              <div class="btn-group">
                <button class="btn btn-success" onclick="saveAllMarks()"><i class="fas fa-save"></i> Save All Marks</button>
                <button class="btn btn-secondary btn-sm" onclick="teacherNav('dashboard',null)"><i class="fas fa-arrow-left"></i> Back</button>
              </div>
            </div>
          </div>
        </div>

        <div id="view-attendance" style="display:none">
          <div class="section-header">
            <div>
              <div class="breadcrumb"><span onclick="teacherNav('dashboard',null)" style="cursor:pointer;color:var(--primary)">Dashboard</span> <span>›</span> Attendance Entry</div>
              <div class="section-title">Attendance Entry</div>
              <div class="section-subtitle" id="attendance-page-subtitle">Select a course with section, load students, then save attendance.</div>
            </div>
            <div class="btn-group">
              <button class="btn btn-secondary btn-sm" onclick="loadCurrentTeacherSection(true).then(()=>initAttendanceTable())"><i class="fas fa-sync-alt"></i> Reload</button>
            </div>
          </div>

          <div class="attendance-legacy-filter-card">
            <div class="attendance-legacy-grid">
              <div class="form-group" style="margin:0">
                <label class="form-label">Course With Section</label>
                <select class="form-control" id="attendance-section-select">
                  <option value="">Select course with section</option>
                </select>
              </div>
              <div class="form-group" style="margin:0">
                <label class="form-label">Class Type</label>
                <select class="form-control" id="attendance-class-type">
                  <option value="Regular">Regular</option>
                  <option value="Make Up">Make Up</option>
                  <option value="Extra">Extra</option>
                </select>
              </div>
              <div class="form-group" style="margin:0">
                <label class="form-label">Class Date</label>
                <input type="date" class="form-control" id="attendance-class-date">
              </div>
              <button class="btn btn-primary" onclick="loadAttendanceStudentsLegacy()"><i class="fas fa-users"></i> Load Students</button>
              <button class="btn btn-info" onclick="getAttendanceEmails()"><i class="fas fa-envelope"></i> Get Emails</button>
              <button class="btn btn-secondary" onclick="downloadAttendanceExcel()"><i class="fas fa-file-excel"></i> Excel</button>
              <button class="btn btn-secondary" onclick="openAttendanceDetailsReport()"><i class="fas fa-file-alt"></i> Details Report</button>
            </div>
            <div class="att-email-box" id="attendance-email-box">
              <div style="display:flex;justify-content:space-between;gap:10px;align-items:center;margin-bottom:8px;flex-wrap:wrap">
                <strong>Student Email Addresses</strong>
                <button class="btn btn-secondary btn-sm" onclick="copyAttendanceEmails()"><i class="fas fa-copy"></i> Copy Emails</button>
              </div>
              <textarea id="attendance-email-list" readonly></textarea>
            </div>
          </div>

          <div class="card">
            <div class="card-header" style="align-items:flex-end;gap:12px;flex-wrap:wrap">
              <div>
                <div class="card-title" id="attendance-table-title">Student Attendance List</div>
                <div class="card-subtitle" id="attendance-table-subtitle">No section loaded.</div>
              </div>
              <div class="attendance-find-wrap">
                <label class="form-label" style="margin:0;font-weight:800">Find in Page</label>
                <input type="text" class="form-control" id="attendance-search" placeholder="Search StudentID / Name / Course..." oninput="filterAttendanceRows()">
              </div>
            </div>

            <div class="attendance-legacy-actions">
              <button class="btn btn-success" onclick="saveAttendance()"><i class="fas fa-save"></i> Save</button>
              <button class="btn btn-secondary btn-sm" onclick="setAttendanceAll('present')"><i class="fas fa-check"></i> Present All</button>
              <button class="btn btn-secondary btn-sm" onclick="setAttendanceAll('absent')"><i class="fas fa-times"></i> Absent All</button>
              <button class="btn btn-secondary btn-sm" onclick="setAttendanceAll('notset')"><i class="fas fa-minus-circle"></i> Not Set All</button>
            </div>

            <div class="attendance-legacy-table-wrap">
              <table id="attendance-entry-table">
                <thead>
                  <tr>
                    <th>Sl. No</th>
                    <th>Photo</th>
                    <th>StudentID</th>
                    <th>Student Name</th>
                    <th>Course</th>
                    <th>Absent Count</th>
                    <th class="att-status-cell">
                      <div>Attendance</div>
                      <div class="att-radio-group" style="margin-top:6px">
                        <label class="att-radio-option"><input type="radio" name="att-head-bulk" onclick="setAttendanceAll('present')"> Present All</label>
                        <label class="att-radio-option"><input type="radio" name="att-head-bulk" onclick="setAttendanceAll('absent')"> Absent All</label>
                        <label class="att-radio-option"><input type="radio" name="att-head-bulk" onclick="setAttendanceAll('notset')"> Not Set All</label>
                      </div>
                    </th>
                    <th>Comment</th>
                  </tr>
                </thead>
                <tbody id="att-tbody">
                  <tr><td colspan="8" class="att-empty-state">Select Course With Section and click Load Students.</td></tr>
                </tbody>
              </table>
            </div>
            <div class="card-footer">
              <span style="font-size:12px;color:var(--text2)">Attendance saves into the Attendance component. Not Set rows are skipped. Submitted/approved results stay locked.</span>
            </div>
          </div>
        </div>

        <div id="view-submit" style="display:none">
          <div class="section-header">
            <div class="section-title">Submit Results</div>
            <div class="section-subtitle">Review and submit results to Admin for approval</div>
          </div>
          <div class="card">
            <div class="card-body">
              <div style="text-align:center;padding:40px">
                <div style="width:80px;height:80px;background:var(--primary-glow);border-radius:50%;display:flex;align-items:center;justify-content:center;margin:0 auto 20px;font-size:32px;color:var(--primary)">
                  <i class="fas fa-paper-plane"></i>
                </div>
                <h2 style="margin-bottom:8px">Ready to Submit?</h2>
                <p style="color:var(--text2);margin-bottom:24px;max-width:460px;margin-left:auto;margin-right:auto">
                  Review all marks before submitting. Current section: <strong id="submit-current-section">---</strong>
                </p>
                <div class="stats-grid" style="max-width:600px;margin:0 auto 24px">
                  <div class="stat-card"><div class="stat-icon" style="background:var(--primary-glow);color:var(--primary)"><i class="fas fa-users"></i></div><div class="stat-info"><div class="stat-value" id="submit-students-count">0</div><div class="stat-label">Students</div></div></div>
                  <div class="stat-card"><div class="stat-icon" style="background:rgba(16,185,129,0.12);color:var(--success)"><i class="fas fa-check-circle"></i></div><div class="stat-info"><div class="stat-value" id="submit-components-count">0</div><div class="stat-label">Components</div></div></div>
                  <div class="stat-card"><div class="stat-icon" style="background:rgba(245,158,11,0.12);color:var(--gold)"><i class="fas fa-info-circle"></i></div><div class="stat-info"><div class="stat-value" id="submit-status-label">Draft</div><div class="stat-label">Status</div></div></div>
                </div>
                <button class="btn btn-success" onclick="confirmSubmitResult()" style="font-size:15px;padding:12px 32px"><i class="fas fa-paper-plane"></i> Submit to Admin</button>
              </div>
            </div>
          </div>
        </div>

        <div id="view-pdf" style="display:none">
          <div class="section-header"><div class="section-title">Download PDF Report</div></div>
          <div class="card">
            <div class="card-body" style="text-align:center;padding:40px">
              <div style="font-size:48px;margin-bottom:20px">📄</div>
              <h3 style="margin-bottom:8px">Generate Result Sheet PDF</h3>
              <p style="color:var(--text2);margin-bottom:24px">Click download to print the current result sheet.</p>
              <button class="btn btn-danger" onclick="downloadPDF()" style="font-size:15px;padding:12px 28px"><i class="fas fa-file-pdf"></i> Download PDF</button>
            </div>
          </div>
        </div>

        <div id="view-profile" style="display:none">
          <div class="section-header">
            <div>
              <div class="breadcrumb"><span onclick="teacherNav('dashboard',null)" style="cursor:pointer;color:var(--primary)">Dashboard</span> <span>›</span> My Profile</div>
              <div class="section-title">My Profile</div>
              <div class="section-subtitle">Teacher account details from current login session.</div>
            </div>
          </div>
          <div class="teacher-profile-layout">
            <div class="teacher-profile-photo-card">
              <div class="teacher-profile-photo-preview" id="teacher-profile-photo-preview" data-profile-avatar><?= $teacherAvatarHtml ?></div>
              <input type="file" id="teacher-profile-photo-input" accept="image/jpeg,image/png,image/webp,image/gif" style="display:none" onchange="uploadTeacherProfilePhoto(this)">
              <button type="button" class="btn btn-primary teacher-profile-upload-btn" onclick="document.getElementById('teacher-profile-photo-input').click()">
                <i class="fas fa-camera"></i> Upload Profile Photo
              </button>
              <div class="teacher-profile-help">Upload JPG, PNG, WEBP or GIF. Maximum size: 2 MB. The photo will show in the sidebar, header, and teacher profile.</div>
            </div>

            <div class="teacher-account-card">
              <div class="card-header"><div class="card-title">Account Information</div></div>
              <div class="card-body" style="padding:24px">
                <div class="teacher-profile-topline">
                  <div class="teacher-profile-mini-avatar" data-profile-avatar><?= $teacherAvatarHtml ?></div>
                  <div>
                    <h3 style="margin:0;font-size:20px;font-weight:900;color:var(--text)"><?= $profileName ?></h3>
                    <p style="margin:3px 0 8px;color:var(--text2);font-size:13px"><?= $profileRoleLabel ?></p>
                    <span class="badge badge-success"><i class="fas fa-check"></i> <?= $teacherStatusLabel ?></span>
                  </div>
                </div>

                <div class="teacher-account-grid">
                  <div class="teacher-account-field">
                    <label>Full Name</label>
                    <div class="profile-readonly"><?= $profileName ?></div>
                  </div>
                  <div class="teacher-account-field">
                    <label>Teacher Initial</label>
                    <div class="profile-readonly"><?= $teacherInitial ?></div>
                  </div>
                  <div class="teacher-account-field" style="grid-column:1 / -1">
                    <label>Email</label>
                    <div class="profile-readonly"><?= $teacherEmail !== '' ? $teacherEmail : 'Not set' ?></div>
                  </div>
                  <div class="teacher-account-field">
                    <label>Department</label>
                    <div class="profile-readonly"><?= $teacherDepartment !== '' ? $teacherDepartment : 'Not set' ?></div>
                  </div>
                  <div class="teacher-account-field">
                    <label>Phone</label>
                    <div class="profile-readonly"><?= $teacherPhone !== '' ? $teacherPhone : 'Not set' ?></div>
                  </div>
                  <div class="teacher-account-field">
                    <label>Role</label>
                    <div class="profile-readonly">Teacher</div>
                  </div>
                  <div class="teacher-account-field">
                    <label>Status</label>
                    <div class="profile-readonly"><?= $teacherStatusLabel ?></div>
                  </div>
                </div>

                <div class="btn-group" style="margin-top:22px">
                  <button class="btn btn-secondary" onclick="showToast('Change password can be added later if required.','info','Info')"><i class="fas fa-key"></i> Change Password</button>
                  <button class="btn btn-danger" onclick="logout()"><i class="fas fa-sign-out-alt"></i> Logout</button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>


<!-- Teacher dashboard detail modal -->
<div class="modal-overlay" id="modal-teacher-dashboard-detail">
  <div class="modal modal-xl">
    <div class="modal-header">
      <div class="modal-title" id="teacher-dashboard-detail-title">Details</div>
      <button class="modal-close" onclick="closeModal('modal-teacher-dashboard-detail')"><i class="fas fa-times"></i></button>
    </div>
    <div class="modal-body" id="teacher-dashboard-detail-body">
      <div style="text-align:center;color:var(--text2);padding:24px">Loading...</div>
    </div>
    <div class="modal-footer">
      <button class="btn btn-secondary" onclick="closeModal('modal-teacher-dashboard-detail')">Close</button>
    </div>
  </div>
</div>
