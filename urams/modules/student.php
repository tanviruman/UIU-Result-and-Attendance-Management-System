<?php
// modules/student.php
// Step: Ei file sudhu Student dashboard UI render kore.

get_current_user_record();
$profileInitials = e(get_user_initials());
$profileName = e(get_user_full_name());
$profileRoleLabel = e(get_user_role_label());
$profileIdentifier = e(get_user_identifier());
$profilePhoto = function_exists('get_user_profile_photo') ? e(get_user_profile_photo()) : e($_SESSION['profile_photo'] ?? '');

$studentId = $_SESSION['user_id'] ?? null;
$studentCourses = [];
$studentEnrollments = $_SESSION['student_enrollments'] ?? []; // Session e theke enrollment data.
$enrollmentCount = $_SESSION['student_enrollment_count'] ?? 0;
$studentSummary = [
    'cgpa' => '0.00',
    'last_gpa' => '0.00',
    'trimesters' => 0,
    'credits_done' => '0',
];
$trimesterTitle = 'Summer 2025';
if ($studentId) {
    $sql = "SELECT c.course_code, c.course_name, c.credit,
                   cs.section_name, t.name AS trimester_name,
                   ut.full_name AS teacher_name, ut.identifier AS teacher_identifier,
                   r.grade, r.grade_point, r.total_marks, r.status,
                   r.ct1, r.ct2, r.best_ct, r.assignment, r.mid, r.final, r.attendance_marks
            FROM enrollments e
            JOIN course_sections cs ON e.section_id = cs.id
            JOIN courses c ON cs.course_id = c.id
            JOIN trimesters t ON cs.trimester_id = t.id
            JOIN users ut ON cs.teacher_id = ut.id
            LEFT JOIN results r ON r.enrollment_id = e.id
            WHERE e.student_id = :student_id
            ORDER BY t.start_date DESC, c.course_name";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':student_id' => $studentId]);
    $studentCourses = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (!empty($studentCourses)) {
        $trimesterTitle = $studentCourses[0]['trimester_name'];
        $trimesterNames = [];
        $creditsDone = 0.0;
        $weightedPoints = 0.0;
        $weightedCredits = 0.0;
        $latestTrimester = null;
        $latestTrimesterPoints = 0.0;
        $latestTrimesterCredits = 0.0;
        foreach ($studentCourses as $course) {
            $trimesterNames[$course['trimester_name']] = true;
            $credit = (float)$course['credit'];
            $creditsDone += $credit;
            if ($latestTrimester === null) {
                $latestTrimester = $course['trimester_name'];
            }
            if ($course['grade_point'] !== null) {
                $point = (float)$course['grade_point'];
                $weightedPoints += ($point * $credit);
                $weightedCredits += $credit;
                if ($course['trimester_name'] === $latestTrimester) {
                    $latestTrimesterPoints += ($point * $credit);
                    $latestTrimesterCredits += $credit;
                }
            }
        }
        $studentSummary['trimesters'] = count($trimesterNames);
        $studentSummary['credits_done'] = number_format($creditsDone, 0);
        if ($weightedCredits > 0) {
            $studentSummary['cgpa'] = number_format($weightedPoints / $weightedCredits, 2);
        }
        if ($latestTrimesterCredits > 0) {
            $studentSummary['last_gpa'] = number_format($latestTrimesterPoints / $latestTrimesterCredits, 2);
        }

        // Load the student's full trimester history for charts and result history.
        $studentHistory = [];
        $sqlHistory = "SELECT t.id AS trimester_id, t.name AS trimester_name, t.start_date,
                              c.course_code, c.course_name, c.credit, cs.section_name,
                              r.grade, r.grade_point, r.total_marks, r.status,
                              r.ct1, r.ct2, r.best_ct, r.assignment, r.mid, r.final, r.attendance_marks
                       FROM enrollments e
                       JOIN course_sections cs ON e.section_id = cs.id
                       JOIN trimesters t ON cs.trimester_id = t.id
                       JOIN courses c ON cs.course_id = c.id
                       LEFT JOIN results r ON r.enrollment_id = e.id
                       WHERE e.student_id = :student_id
                       ORDER BY t.start_date ASC, c.course_code";
        $stmtHistory = $pdo->prepare($sqlHistory);
        $stmtHistory->execute([':student_id' => $studentId]);
        $historyRows = $stmtHistory->fetchAll(PDO::FETCH_ASSOC);

        $historyMap = [];
        foreach ($historyRows as $row) {
            $trimId = (int)$row['trimester_id'];
            if (!isset($historyMap[$trimId])) {
                $historyMap[$trimId] = [
                    'trimester_id' => $trimId,
                    'trimester_name' => $row['trimester_name'],
                    'start_date' => $row['start_date'],
                    'courses' => [],
                    'gpa' => 0.0,
                    'cgpa' => 0.0,
                    'status' => 'partial',
                    '_gpa_sum' => 0.0,
                    '_gpa_count' => 0,
                    '_total_count' => 0,
                ];
            }
            $gradePoint = $row['grade_point'] !== null ? (float)$row['grade_point'] : null;
            $historyMap[$trimId]['courses'][] = [
                'course_code' => $row['course_code'],
                'course_name' => $row['course_name'],
                'credit' => (float)$row['credit'],
                'section_name' => $row['section_name'],
                'grade' => $row['grade'] ?: 'N/A',
                'grade_point' => $gradePoint,
                'status' => $row['status'] ?? 'draft',
                'total_marks' => $row['total_marks'] !== null ? (float)$row['total_marks'] : 0.0,
                'ct1' => $row['ct1'] !== null ? (float)$row['ct1'] : null,
                'ct2' => $row['ct2'] !== null ? (float)$row['ct2'] : null,
                'best_ct' => $row['best_ct'] !== null ? (float)$row['best_ct'] : null,
                'assignment' => $row['assignment'] !== null ? (float)$row['assignment'] : null,
                'mid' => $row['mid'] !== null ? (float)$row['mid'] : null,
                'final' => $row['final'] !== null ? (float)$row['final'] : null,
                'attendance_marks' => $row['attendance_marks'] !== null ? (float)$row['attendance_marks'] : null,
            ];
            $historyMap[$trimId]['_total_count']++;
            if ($gradePoint !== null) {
                $historyMap[$trimId]['_gpa_sum'] += $gradePoint;
                $historyMap[$trimId]['_gpa_count']++;
            }
        }

        $cumulativePoints = 0.0;
        $cumulativeCount = 0;
        foreach ($historyMap as &$term) {
            if ($term['_gpa_count'] > 0) {
                $term['gpa'] = number_format($term['_gpa_sum'] / $term['_gpa_count'], 2);
                $cumulativePoints += $term['_gpa_sum'];
                $cumulativeCount += $term['_gpa_count'];
            }
            if ($cumulativeCount > 0) {
                $term['cgpa'] = number_format($cumulativePoints / $cumulativeCount, 2);
            }
            if ($term['_gpa_count'] === $term['_total_count'] && $term['_total_count'] > 0) {
                $term['status'] = 'approved';
            }
            unset($term['_gpa_sum'], $term['_gpa_count'], $term['_total_count']);
        }
        unset($term);
        $studentHistory = array_values($historyMap);
    } else {
        $studentHistory = [];
        $studentCourses = [];
        $trimesterTitle = 'No Enrolled Course';
    }
}
?>
<script>
window.URAMS_STUDENT_HISTORY = <?= json_encode($studentHistory, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>;
window.URAMS_STUDENT_COURSES = <?= json_encode($studentCourses, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>;
window.URAMS_STUDENT_PROFILE = <?= json_encode([
  'name' => html_entity_decode($profileName),
  'identifier' => html_entity_decode($profileIdentifier),
  'department' => 'CSE Department',
  'program' => 'BSc Engineering',
  'cgpa' => $studentSummary['cgpa'],
  'last_gpa' => $studentSummary['last_gpa'],
  'trimesters' => $studentSummary['trimesters'],
  'credits_done' => $studentSummary['credits_done'],
], JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>;
</script>
<!-- ═══════════════════════════════════════════════════════════════
     STUDENT PANEL
     ═══════════════════════════════════════════════════════════════ -->
<div class="page active" id="page-student">
  <div class="app-layout">
    <aside class="sidebar" id="student-sidebar">
      <div class="sidebar-logo">
        <div class="sidebar-logo-icon"><i class="fas fa-graduation-cap"></i></div>
        <div class="sidebar-logo-text">URAMS <span>UIU Student Portal</span></div>
      </div>
      <div class="sidebar-user">
        <div class="sidebar-avatar" style="<?php if ($profilePhoto): ?>background-image:url('<?= $profilePhoto ?>');background-size:cover;background-position:center;color:transparent;<?php endif; ?>"><?php if (!$profilePhoto): ?><?= $profileInitials ?><?php endif; ?></div>
        <div class="sidebar-user-info">
          <div class="sidebar-user-name"><?= $profileName ?></div>
          <div class="sidebar-user-role"><?= $profileRoleLabel ?></div>
        </div>
      </div>
      <nav class="sidebar-nav">
        <div class="nav-section-title">Main</div>
        <div class="nav-item active" onclick="studentNav('dashboard',this)"><span class="nav-icon"><i class="fas fa-th-large"></i></span> Dashboard</div>
        <div class="nav-item" onclick="studentNav('continuous',this)"><span class="nav-icon"><i class="fas fa-chart-line"></i></span> Continuous Eval</div>
        <div class="nav-item" onclick="studentNav('history',this)"><span class="nav-icon"><i class="fas fa-history"></i></span> Result History</div>
        <div class="nav-section-title">Account</div>
        <div class="nav-item" onclick="studentNav('profile',this)"><span class="nav-icon"><i class="fas fa-user-circle"></i></span> My Profile</div>
      </nav>
      <div class="sidebar-footer">
        <button class="sidebar-logout" onclick="logout()"><i class="fas fa-sign-out-alt"></i> Sign Out</button>
      </div>
    </aside>
    <div class="main-area">
      <header class="app-header">
        <div class="header-left">
          <button class="hamburger" onclick="toggleSidebar('student-sidebar')"><i class="fas fa-bars"></i></button>
          <div><div class="header-title" id="student-page-title">My Dashboard</div><div class="header-subtitle">CSE Dept · BSc Program</div></div>
        </div>
        <div class="header-right" style="position:relative">
          <div class="header-btn" onclick="toggleNotifications('student-notifs')">
            <i class="fas fa-bell"></i><div class="notif-badge">1</div>
          </div>
          <div class="notif-dropdown" id="student-notifs">
            <div class="notif-header"><span>Notifications</span></div>
            <div class="notif-item unread" onclick="markNotifRead(this)">
              <div class="notif-dot"></div>
              <div><div class="notif-text">📊 Your OOP result has been approved by Admin</div><div class="notif-time">1 hour ago</div></div>
            </div>
          </div>
          <div class="header-avatar" title="Profile" onclick="studentNav('profile',null)" style="<?php if ($profilePhoto): ?>background-image:url('<?= $profilePhoto ?>');background-size:cover;background-position:center;color:transparent;<?php endif; ?>"><?php if (!$profilePhoto): ?><?= $profileInitials ?><?php endif; ?></div>
        </div>
      </header>
      <div class="content" id="student-content">

        <!-- STUDENT DASHBOARD -->
        <div id="s-view-dashboard">
          <div class="student-info-card">
            <div style="position:relative;z-index:1;flex:1">
              <div style="font-size:12px;opacity:0.6;text-transform:uppercase;letter-spacing:1px;margin-bottom:4px">Student Profile</div>
              <div style="font-size:24px;font-weight:800;margin-bottom:4px"><?= $profileName ?></div>
              <div style="opacity:0.7;font-size:13px;margin-bottom:20px"><?= $profileIdentifier ?> · CSE Department · BSc Engineering</div>
              <div class="student-hero-stats">
                <div class="parent-stat">
                  <div id="student-cgpa" class="parent-stat-val" style="font-size:40px;font-family:'Instrument Serif',serif"><?= e($studentSummary['cgpa']) ?></div>
                  <div class="parent-stat-lbl">CGPA</div>
                </div>
                <div class="parent-stat">
                  <div id="student-last-gpa" class="parent-stat-val" style="font-size:40px;font-family:'Instrument Serif',serif"><?= e($studentSummary['last_gpa']) ?></div>
                  <div class="parent-stat-lbl">Last GPA</div>
                </div>
                <div class="parent-stat">
                  <div id="student-trimesters" class="parent-stat-val" style="font-size:40px;font-family:'Instrument Serif',serif"><?= e($studentSummary['trimesters']) ?></div>
                  <div class="parent-stat-lbl">Trimesters</div>
                </div>
                <div class="parent-stat">
                  <div id="student-credits-done" class="parent-stat-val" style="font-size:40px;font-family:'Instrument Serif',serif"><?= e($studentSummary['credits_done']) ?></div>
                  <div class="parent-stat-lbl">Credits Done</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Dashboard academic summary section: 3 cards side by side -->
          <div class="student-dashboard-stack">
            <div class="card student-routine-card">
              <div class="card-header">
                <div>
                  <span class="card-label">Class Routine</span>
                  <div class="card-title">Current enrolled course schedule</div>
                </div>
              </div>
              <div class="card-body" id="class-routine-body">
                <div style="text-align:center;color:var(--text2);padding:24px">Loading class routine...</div>
              </div>
            </div>

            <div class="card student-result-card">
              <div class="card-header">
                <div>
                  <span class="card-label card-label-green">Result Summary</span>
                  <div class="card-title">GPA / CGPA Progression</div>
                </div>
                <div class="card-actions"><i class="fas fa-ellipsis-v"></i></div>
              </div>
              <div class="card-body">
                <div style="display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:12px;flex-wrap:wrap">
                  <div class="chart-title" style="display:flex;align-items:center;gap:10px"><i class="fas fa-chart-line" style="color:var(--primary)"></i> <span id="student-gpa-chart-title">CGPA / GPA Progression</span></div>
                  <div style="display:flex;gap:8px;flex-wrap:wrap">
                    <button type="button" class="btn btn-secondary gpa-toggle-btn active" data-mode="both" onclick="setStudentGPAChartMode('both')">Both</button>
                    <button type="button" class="btn btn-secondary gpa-toggle-btn" data-mode="gpa" onclick="setStudentGPAChartMode('gpa')">GPA</button>
                    <button type="button" class="btn btn-secondary gpa-toggle-btn" data-mode="cgpa" onclick="setStudentGPAChartMode('cgpa')">CGPA</button>
                  </div>
                </div>
                <canvas id="student-gpa-chart" height="200"></canvas>
              </div>
            </div>

            <div class="card student-attendance-card">
              <div class="card-header">
                <div>
                  <span class="card-label">Attendance Summary</span>
                  <div class="card-title">Course-wise attendance overview</div>
                </div>
              </div>
              <div class="card-body">
                <div class="student-attendance-summary-layout">
                  <div id="student-attendance-list" class="student-attendance-list">
                    <div class="empty-state" style="padding:18px;text-align:center;color:var(--text2)">Loading attendance...</div>
                  </div>
                  <canvas id="att-bar-chart" height="200"></canvas>
                </div>
              </div>
            </div>
          </div>

          <!-- Quick actions -->
          <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin-bottom:20px">
            <div class="quick-action-card" onclick="studentNav('continuous',null)">
              <div class="quick-action-icon" style="background:rgba(26,86,219,0.12);color:var(--primary)"><i class="fas fa-chart-line"></i></div>
              <div><div style="font-weight:700;font-size:13px">Continuous Eval</div><div style="font-size:12px;color:var(--text2)">Ongoing marks</div></div>
            </div>
            <div class="quick-action-card" onclick="studentNav('history',null)">
              <div class="quick-action-icon" style="background:rgba(16,185,129,0.12);color:var(--success)"><i class="fas fa-history"></i></div>
              <div><div style="font-weight:700;font-size:13px">Result History</div><div style="font-size:12px;color:var(--text2)">Past trimesters</div></div>
            </div>
            <div class="quick-action-card" onclick="downloadTranscript()">
              <div class="quick-action-icon" style="background:rgba(239,68,68,0.1);color:var(--danger)"><i class="fas fa-file-pdf"></i></div>
              <div><div style="font-weight:700;font-size:13px">Download Transcript</div><div style="font-size:12px;color:var(--text2)">Official result PDF</div></div>
            </div>
          </div>

          <!-- Current courses -->
          <div class="card">
            <div class="card-header"><div id="student-current-trimester-title" class="card-title">Current Semester Courses — <?= e($trimesterTitle) ?></div></div>
            <div class="table-wrap">
              <table>
                <thead><tr><th>Course Code</th><th>Course Name</th><th>Credit</th><th>Teacher</th><th>Status</th></tr></thead>
                <tbody id="student-courses-body">
                  <?php if (!empty($studentCourses)): ?>
                    <?php foreach ($studentCourses as $course): ?>
                      <tr>
                        <td class="td-id"><?= e($course['course_code']) ?></td>
                        <td class="td-name"><?= e($course['course_name']) ?></td>
                        <td><?= e(number_format((float)$course['credit'], 1)) ?></td>
                        <td><?= e($course['teacher_name']) ?> (<?= e(strtoupper($course['teacher_identifier'])) ?>)</td>
                        <td>
                          <?php if ($course['status'] === 'approved'): ?>
                            <span class="badge badge-success"><i class="fas fa-check"></i> Result Approved</span>
                          <?php elseif ($course['status'] === 'submitted'): ?>
                            <span class="badge badge-primary"><i class="fas fa-paper-plane"></i> Submitted</span>
                          <?php else: ?>
                            <span class="badge badge-warning pending-badge"><i class="fas fa-clock"></i> <?= e(ucfirst($course['status'] ?? 'running')) ?></span>
                          <?php endif; ?>
                        </td>
                      </tr>
                    <?php endforeach; ?>
                  <?php else: ?>
                    <tr><td colspan="5" style="text-align:center">No enrolled courses found for your account.</td></tr>
                  <?php endif; ?>
                </tbody>
              </table>
            </div>
          </div>
        </div><!-- /#s-view-dashboard -->

        <!-- PROFILE VIEW -->
        <div id="s-view-profile" style="display:none">
          <div class="section-header">
            <div>
              <div class="breadcrumb"><span onclick="studentNav('dashboard',null)" style="cursor:pointer;color:var(--primary)">Dashboard</span> <span>›</span> My Profile</div>
              <div class="section-title">My Profile</div>
              <div class="section-subtitle">Your student profile information</div>
            </div>
          </div>

          <div style="display:grid;grid-template-columns:280px 1fr;gap:20px;flex-wrap:wrap">
            <!-- Picture Card -->
            <div class="card" style="text-align:center;padding:24px">
              <div id="student-profile-avatar" style="width:120px;height:120px;border-radius:50%;background:var(--primary-glow);display:flex;align-items:center;justify-content:center;margin:0 auto 16px;font-size:40px;font-weight:700;color:var(--primary)<?php if ($profilePhoto): ?>;background-image:url('<?= $profilePhoto ?>');background-size:cover;background-position:center;<?php endif; ?>">
                <?php if (!$profilePhoto): ?>
                  <?= $profileInitials ?>
                <?php endif; ?>
              </div>
              <button class="btn btn-primary" style="width:100%;margin-bottom:12px;padding:12px 16px;border-radius:12px;justify-content:center;" onclick="document.getElementById('student-photo-input').click()">
                <i class="fas fa-camera" style="font-size:14px"></i>
                <span style="font-size:14px;letter-spacing:.2px">Upload Profile Photo</span>
              </button>
              <input type="file" id="student-photo-input" accept="image/*" style="display:none" onchange="previewStudentPhoto(event)">
              <div style="font-size:13px;color:var(--text2)">Upload your profile photo here</div>
            </div>

            <!-- Details Card -->
            <div class="card">
              <div class="card-header"><div class="card-title">Account Information</div></div>
              <div class="card-body" style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
                <div class="form-group">
                  <label class="form-label">Full Name</label>
                  <input type="text" class="form-control" value="<?= $profileName ?>" readonly style="background:var(--input-bg);cursor:not-allowed">
                </div>
                <div class="form-group">
                  <label class="form-label">Student ID</label>
                  <input type="text" class="form-control" value="<?= $profileIdentifier ?>" readonly style="background:var(--input-bg);cursor:not-allowed">
                </div>
                <div class="form-group" style="grid-column:1/-1">
                  <label class="form-label">Email</label>
                  <input type="email" class="form-control" value="<?= e($_SESSION['email'] ?? ($profileIdentifier . '@uiu.ac.bd')) ?>" readonly style="background:var(--input-bg);cursor:not-allowed">
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- CONTINUOUS EVAL VIEW -->
        <div id="s-view-continuous" style="display:none">
          <div class="section-header">
            <div>
              <div class="breadcrumb"><span onclick="studentNav('dashboard',null)" style="cursor:pointer;color:var(--primary)">Dashboard</span> <span>›</span> Continuous Evaluation</div>
              <div class="section-title">Continuous Evaluation</div>
            </div>
          </div>

          <script>
            // Expose current logged-in student identifier to frontend JS
            window.URAMS_CURRENT_STUDENT_ID = "<?= e($profileIdentifier) ?>";
          </script>
          <div class="filter-bar" style="margin-bottom:20px">
            <div class="filter-group"><label>Trimester</label>
              <select class="form-control" id="student-continuous-trimester-filter"></select>
            </div>
            <div class="filter-group"><label>Course</label>
              <select class="form-control" id="student-continuous-course-filter"></select>
            </div>
            <div style="align-self:flex-end"><button class="btn btn-primary" onclick="loadContinuousEval()"><i class="fas fa-eye"></i> View</button></div>
          </div>
          <div class="card" id="continuous-eval-result">
            <div class="card-body" style="text-align:center;padding:40px;color:var(--text2)">
              <i class="fas fa-chart-line" style="font-size:40px;opacity:0.3;margin-bottom:12px;display:block"></i>
              Select a trimester and course then click View
            </div>
          </div>
        </div>

        <!-- RESULT HISTORY VIEW -->
        <div id="s-view-history" style="display:none">
          <div class="section-header">
            <div>
              <div class="breadcrumb"><span onclick="studentNav('dashboard',null)" style="cursor:pointer;color:var(--primary)">Dashboard</span> <span>›</span> Result History</div>
              <div class="section-title">Result History</div>
            </div>
            <button class="btn btn-secondary btn-sm" onclick="downloadPDF()"><i class="fas fa-file-pdf"></i> Print Transcript</button>
          </div>
          <div id="result-history-accordion"></div>
        </div>

      </div>
    </div>
  </div>
</div><!-- /#page-student -->

