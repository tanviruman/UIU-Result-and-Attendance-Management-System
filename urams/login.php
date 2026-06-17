<?php
// login.php
// Step: User login form + secure login processing.
require_once __DIR__ . '/includes/auth.php';

if (is_logged_in()) {
    header('Location: dashboard.php');
    exit;
}

$pageTitle = 'Login - URAMS';
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Step: Form input collect kori.
    $identifier = trim($_POST['identifier'] ?? '');
    $password = $_POST['password'] ?? '';
    $role = $_POST['role'] ?? 'student';

    // Step: Empty field validation.
    if ($identifier === '' || $password === '') {
        $error = 'Please enter your ID and password.';
    } elseif (login_user($pdo, $identifier, $password, $role)) {
        header('Location: dashboard.php');
        exit;
    } else {
        $error = 'Invalid credentials or inactive account.';
    }
}

require __DIR__ . '/includes/header.php';
?>
<div class="page active" id="page-login">
  <div class="login-orbs"><div class="orb orb1"></div><div class="orb orb2"></div><div class="orb orb3"></div></div>
  <div class="grid-overlay"></div>
  <div class="login-container">
    <div class="login-brand">
      <div class="brand-logo-box"><i class="fas fa-graduation-cap"></i></div>
      <div class="brand-title">UIU <em>URAMS</em></div>
      <div class="brand-sub">University Result &amp; Attendance<br>Management System</div>
      <ul class="brand-features">
        <li><div class="feat-icon"><i class="fas fa-chart-line"></i></div>Real-time result tracking</li>
        <li><div class="feat-icon"><i class="fas fa-users"></i></div>Admin, Teacher, Student, Parent roles</li>
        <li><div class="feat-icon"><i class="fas fa-shield-alt"></i></div>PDO + hashed password authentication</li>
        <li><div class="feat-icon"><i class="fas fa-chart-bar"></i></div>Parent analytics using Canvas API</li>
      </ul>
    </div>

    <div class="login-form-panel">
      <div class="form-panel-header"><h2>Sign in to URAMS</h2><p>Continue with your credentials</p></div>
      <?php if ($error): ?><div class="badge badge-danger" style="margin-bottom:14px;"><?= e($error) ?></div><?php endif; ?>
      <form method="POST" action="login.php">
        <div class="role-tabs">
          <label class="role-tab active"><input type="radio" name="role" value="student" checked hidden>Student</label>
          <label class="role-tab"><input type="radio" name="role" value="teacher" hidden>Teacher</label>
          <label class="role-tab"><input type="radio" name="role" value="admin" hidden>Admin</label>
          <label class="role-tab"><input type="radio" name="role" value="parent" hidden>Parent</label>
        </div>
        <div class="field">
          <label>ID / Initial</label>
          <div class="input-wrap"><i class="fas fa-id-card icon"></i><input type="text" name="identifier" placeholder="e.g. 0242220005" required></div>
        </div>
        <div class="field">
          <label>Password</label>
          <div class="input-wrap"><i class="fas fa-lock icon"></i><input type="password" name="password" placeholder="Enter your password" required></div>
        </div>
        <button class="btn-primary" type="submit"><span>Sign In</span><i class="fas fa-arrow-right"></i></button>
      </form>
      <div class="login-support">New user? <a href="register.php">Create account</a></div>
      <p style="text-align:center;font-size:11px;color:var(--text3);margin-top:16px">Demo password for seed users: <strong>password123</strong></p>
    </div>
  </div>
</div>
<script>
// Step: Login role tab active style.
document.querySelectorAll('.role-tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.role-tab').forEach(t => t.classList.remove('active'));
    tab.classList.add('active');
  });
});
</script>
<?php require __DIR__ . '/includes/footer.php'; ?>