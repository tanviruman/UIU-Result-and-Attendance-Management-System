<?php
// modules/parent.php
// Parent dashboard: read-only linked child result overview with native JavaScript analytics.

require_once __DIR__ . '/../includes/approved_results_helpers.php';

$profileInitials = e(get_user_initials());
$profileName = e(get_user_full_name());
$profileRoleLabel = e(get_user_role_label());
$profileIdentifier = e(get_user_identifier());

$parentId = (int)($_SESSION['user_id'] ?? 0);
$resultPayload = urams_fetch_approved_result_payload($pdo, $parentId, 'parent');
$childCourses = $resultPayload['courses'];
$childSummary = $resultPayload['summary'];
$trimesterResultsDesc = $resultPayload['trimester_results'];
$childProfile = $resultPayload['student_profile'];

$activeTrimester = $childCourses[0]['trimester_name'] ?? 'No Approved Result';
$childInitials = $childProfile['initials'] ?? 'ST';
$childName = $childProfile['full_name'] ?? 'Student';
$childIdentifier = $childProfile['identifier'] ?? '---';
$childDepartment = $childProfile['department'] ?? 'CSE';
$childProgram = $childProfile['program'] ?? 'BSc Program';
$approvedCourseCount = count($childCourses);
$creditsDone = $childSummary['credits_done'] ?? '0.0';
?>
<script>
window.URAMS_PARENT_COURSES = <?= json_encode($childCourses, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>;
window.URAMS_STUDENT_COURSES = window.URAMS_PARENT_COURSES;
window.URAMS_TRIMESTER_RESULTS = <?= json_encode($trimesterResultsDesc, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>;
window.URAMS_APPROVED_RESULTS_API = 'fetch_parent_results.php';
</script>

<div class="page active" id="page-parent">
  <div class="app-layout">
    <aside class="sidebar" id="parent-sidebar">
      <div class="sidebar-logo">
        <div class="sidebar-logo-icon"><i class="fas fa-graduation-cap"></i></div>
        <div class="sidebar-logo-text">URAMS <span>Parent Portal</span></div>
      </div>
      <div class="sidebar-user">
        <div class="sidebar-avatar" style="background:linear-gradient(135deg,#059669,#10b981)"><?= $profileInitials ?></div>
        <div class="sidebar-user-info">
          <div class="sidebar-user-name"><?= $profileName ?></div>
          <div class="sidebar-user-role"><?= $profileRoleLabel ?></div>
        </div>
      </div>
      <nav class="sidebar-nav">
        <div class="nav-section-title">Main</div>
        <div class="nav-item active" onclick="parentNav('dashboard',this)"><span class="nav-icon"><i class="fas fa-th-large"></i></span> Dashboard</div>
        <div class="nav-item" onclick="parentNav('results',this)"><span class="nav-icon"><i class="fas fa-chart-bar"></i></span> Result Viewer</div>
      </nav>
      <div class="sidebar-footer">
        <button class="sidebar-logout" onclick="logout()"><i class="fas fa-sign-out-alt"></i> Sign Out</button>
      </div>
    </aside>

    <div class="main-area">
      <header class="app-header">
        <div class="header-left">
          <button class="hamburger" onclick="toggleSidebar('parent-sidebar')"><i class="fas fa-bars"></i></button>
          <div>
            <div class="header-title" id="parent-page-title">Parent Dashboard</div>
            <div class="header-subtitle">Read-only child performance overview</div>
          </div>
        </div>
        <div class="header-right">
          <div class="header-btn" onclick="toggleNotifications('parent-notifs')">
            <i class="fas fa-bell"></i><?php if ($approvedCourseCount): ?><div class="notif-badge">1</div><?php endif; ?>
          </div>
          <div class="notif-dropdown" id="parent-notifs">
            <div class="notif-header"><span>Notifications</span></div>
            <div class="notif-item unread" onclick="markNotifRead(this)">
              <div class="notif-dot"></div>
              <div>
                <div class="notif-text">Approved result data is available for <?= e($childName) ?>.</div>
                <div class="notif-time">Parent analytics ready</div>
              </div>
            </div>
          </div>
          <div class="header-avatar" style="background:linear-gradient(135deg,#059669,#10b981)"><?= $profileInitials ?></div>
        </div>
      </header>

      <div class="content">
        <div id="p-view-dashboard">
          <div class="parent-hero-card">
            <div class="parent-child-avatar"><?= e($childInitials) ?></div>
            <div class="parent-child-info">
              <div class="parent-overline">Monitoring Student</div>
              <div class="parent-child-name"><?= e($childName) ?></div>
              <div class="parent-child-meta"><?= e($childIdentifier) ?> · <?= e($childDepartment) ?> Department · <?= e($childProgram) ?></div>
            </div>
            <div class="parent-kpi-strip">
              <div class="parent-kpi"><div><?= e($childSummary['cgpa']) ?></div><span>CGPA</span></div>
              <div class="parent-kpi"><div><?= e($childSummary['last_gpa']) ?></div><span>Last GPA</span></div>
              <div class="parent-kpi"><div><?= e($childSummary['trimesters']) ?></div><span>Trimesters</span></div>
              <div class="parent-kpi"><div><?= e($creditsDone) ?></div><span>Credits Done</span></div>
            </div>
          </div>

          <div class="parent-dashboard-grid">
            <div class="card parent-analytics-card">
              <div class="card-header parent-clean-header">
                <div>
                  <div class="card-title"><i class="fas fa-chart-line" style="color:var(--success)"></i> Academic Progress</div>
                  <div class="section-subtitle">GPA / CGPA progression from approved results</div>
                </div>
                <span class="badge badge-success"><i class="fas fa-lock"></i> Read Only</span>
              </div>
              <div class="card-body parent-chart-body">
                <canvas id="parent-gpa-chart" height="260"></canvas>
              </div>
            </div>

            <div class="card parent-latest-card">
              <div class="card-header parent-clean-header">
                <div>
                  <div class="card-title"><i class="fas fa-award" style="color:var(--primary)"></i> Latest Approved Result</div>
                  <div class="section-subtitle"><?= e($activeTrimester) ?></div>
                </div>
                <button class="btn btn-secondary btn-sm" onclick="parentNav('results',null)"><i class="fas fa-list"></i> View All</button>
              </div>
              <div class="table-wrap parent-table-wrap">
                <table class="parent-result-table">
                  <thead><tr><th>Code</th><th>Course</th><th>Credit</th><th>GP</th><th>Grade</th><th>Total</th></tr></thead>
                  <tbody>
                    <?php if (!empty($childCourses)): ?>
                      <?php foreach (array_slice($childCourses, 0, 8) as $course): ?>
                        <tr>
                          <td class="td-id"><?= e($course['course_code']) ?></td>
                          <td class="td-name"><?= e($course['course_name']) ?></td>
                          <td><?= e(number_format((float)$course['credit'], 1)) ?></td>
                          <td style="font-weight:800;color:var(--success)"><?= e(number_format((float)$course['grade_point'], 2)) ?></td>
                          <td><span class="grade-A-plus"><?= e($course['grade'] ?? '---') ?></span></td>
                          <td style="font-weight:800"><?= e(number_format((float)$course['total_marks'], 2)) ?></td>
                        </tr>
                      <?php endforeach; ?>
                    <?php else: ?>
                      <tr><td colspan="6" style="text-align:center;color:var(--text2);padding:24px">No approved result is available for the linked student yet.</td></tr>
                    <?php endif; ?>
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          <div class="parent-insight-grid">
            <div class="quick-action-card" onclick="parentNav('results',null)">
              <div class="quick-action-icon" style="background:rgba(26,86,219,0.12);color:var(--primary)"><i class="fas fa-chart-bar"></i></div>
              <div><div style="font-weight:800">Full Result History</div><div style="font-size:12px;color:var(--text2)">Trimester-wise approved results</div></div>
            </div>
            <div class="quick-action-card">
              <div class="quick-action-icon" style="background:rgba(16,185,129,0.12);color:var(--success)"><i class="fas fa-check-circle"></i></div>
              <div><div style="font-weight:800">Approved Courses</div><div style="font-size:12px;color:var(--text2)"><?= e($approvedCourseCount) ?> course records visible</div></div>
            </div>
            <div class="quick-action-card">
              <div class="quick-action-icon" style="background:rgba(245,158,11,0.14);color:var(--warning)"><i class="fas fa-shield-alt"></i></div>
              <div><div style="font-weight:800">Read-only Parent View</div><div style="font-size:12px;color:var(--text2)">No edit access for parents</div></div>
            </div>
          </div>
        </div>

        <div id="p-view-results" style="display:none">
          <div class="section-header">
            <div>
              <div class="breadcrumb"><span onclick="parentNav('dashboard',null)" style="cursor:pointer;color:var(--primary)">Dashboard</span> <span>›</span> Result Viewer</div>
              <div class="section-title">Full Result History</div>
              <div class="section-subtitle">Approved trimester-wise results for <?= e($childName) ?></div>
            </div>
            <button class="btn btn-secondary btn-sm" onclick="window.print()"><i class="fas fa-print"></i> Print</button>
          </div>
          <div class="card" style="margin-bottom:20px">
            <div class="card-header parent-clean-header">
              <div class="card-title"><i class="fas fa-chart-line" style="color:var(--success)"></i> GPA / CGPA Analytics</div>
              <span class="badge badge-success"><i class="fas fa-check"></i> Approved Data</span>
            </div>
            <div class="card-body parent-chart-body">
              <canvas id="parent-result-gpa-chart" height="260"></canvas>
            </div>
          </div>
          <div id="parent-history-accordion"></div>
        </div>
      </div>
    </div>
  </div>
</div>
