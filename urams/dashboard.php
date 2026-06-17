<?php
// dashboard.php
// Step: Role-based dashboard loader.
require_once __DIR__ . '/includes/auth.php';
require_login();

$role = $_SESSION['role'];
if (!in_array($role, URAMS_ROLES, true)) {
    http_response_code(403);
    exit('Invalid role.');
}

$pageTitle = ucfirst($role) . ' Dashboard - URAMS';
require __DIR__ . '/includes/header.php';
?>
<script>
// Step: JS initialization er jonno current role browser e pathai.
window.URAMS_CURRENT_ROLE = <?= json_encode($role) ?>;
</script>

<?php
// Step: Server-side role based include. Sudhu logged-in role er module load hobe.
$module = __DIR__ . '/modules/' . $role . '.php';
if (file_exists($module)) {
    require $module;
} else {
    echo '<div class="content"><h2>Dashboard module not found.</h2></div>';
}

require __DIR__ . '/includes/modals.php';
?>
<script>
// Step: Module load howar por correct panel initialize kori.
document.addEventListener('DOMContentLoaded', function(){
  if (window.URAMS_CURRENT_ROLE) {
    currentRole = window.URAMS_CURRENT_ROLE;
    if (typeof initCurrentPanel === 'function') initCurrentPanel();
  }
});
</script>
<?php require __DIR__ . '/includes/footer.php'; ?>