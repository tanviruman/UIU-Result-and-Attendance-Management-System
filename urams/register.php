<?php
// register.php
// Step: New user registration. Password always hashed.
require_once __DIR__ . '/includes/auth.php';

$pageTitle = 'Register - URAMS';
$message = '';
$success = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $fullName = trim($_POST['full_name'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $identifier = trim($_POST['identifier'] ?? '');
    $password = $_POST['password'] ?? '';
    $role = $_POST['role'] ?? 'student';

    if ($fullName === '' || $email === '' || $identifier === '' || $password === '') {
        $message = 'All fields are required.';
    } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $message = 'Please enter a valid email address.';
    } else {
        [$success, $message] = register_user($pdo, $fullName, $email, $identifier, $password, $role);
    }
}

require __DIR__ . '/includes/header.php';
?>
<div class="page active" id="page-login">
  <div class="login-orbs"><div class="orb orb1"></div><div class="orb orb2"></div><div class="orb orb3"></div></div>
  <div class="grid-overlay"></div>
  <div class="login-container" style="max-width:540px">
    <div class="login-form-panel" style="width:100%">
      <div class="form-panel-header"><h2>Create URAMS Account</h2><p>Register as Admin, Teacher, Student, or Parent</p></div>
      <?php if ($message): ?><div class="badge <?= $success ? 'badge-success' : 'badge-danger' ?>" style="margin-bottom:14px;"><?= e($message) ?></div><?php endif; ?>
      <form method="POST" action="register.php">
        <div class="field"><label>Full Name</label><div class="input-wrap"><i class="fas fa-user icon"></i><input type="text" name="full_name" required></div></div>
        <div class="field"><label>Email</label><div class="input-wrap"><i class="fas fa-envelope icon"></i><input type="email" name="email" required></div></div>
        <div class="field"><label>ID / Initial</label><div class="input-wrap"><i class="fas fa-id-card icon"></i><input type="text" name="identifier" required></div></div>
        <div class="field"><label>Password</label><div class="input-wrap"><i class="fas fa-lock icon"></i><input type="password" name="password" minlength="6" required></div></div>
        <div class="field"><label>Role</label><select class="form-control" name="role"><option value="student">Student</option><option value="teacher">Teacher</option><option value="parent">Parent</option><option value="admin">Admin</option></select></div>
        <button class="btn-primary" type="submit"><span>Register</span><i class="fas fa-user-plus"></i></button>
      </form>
      <div class="login-support">Already registered? <a href="login.php">Login</a></div>
    </div>
  </div>
</div>
<?php require __DIR__ . '/includes/footer.php'; ?>