<?php
// includes/auth.php
// Step: Login, logout, role checking, registration helper sob ekhane rakha hoyeche.

require_once __DIR__ . '/../config/db.php';

if (session_status() === PHP_SESSION_NONE) {
    // Step: Session cookie ke HTTP only rakha safer.
    session_set_cookie_params([
        'httponly' => true,
        'samesite' => 'Lax'
    ]);
    session_start();
}

const URAMS_ROLES = ['admin', 'teacher', 'student', 'parent'];

function is_logged_in(): bool
{
    // Bangla: user_id and role thakle user logged in.
    return isset($_SESSION['user_id'], $_SESSION['role']);
}

function urams_clear_session_only(): void
{
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000, $params['path'], $params['domain'], $params['secure'], $params['httponly']);
    }
    if (session_status() === PHP_SESSION_ACTIVE) {
        session_destroy();
    }
}

function urams_is_ajax_request(): bool
{
    return (isset($_SERVER['HTTP_X_REQUESTED_WITH']) && strtolower((string)$_SERVER['HTTP_X_REQUESTED_WITH']) === 'xmlhttprequest')
        || (isset($_SERVER['HTTP_ACCEPT']) && strpos((string)$_SERVER['HTTP_ACCEPT'], 'application/json') !== false)
        || (isset($_SERVER['CONTENT_TYPE']) && strpos((string)$_SERVER['CONTENT_TYPE'], 'application/json') !== false);
}

function require_login(): void
{
    // Bangla: Login chara protected page access korte dibo na.
    if (!is_logged_in()) {
        header('Location: login.php');
        exit;
    }

    // After demo database re-import, old browser session user_id may no longer exist.
    // In that case, clear stale session and force a fresh login instead of breaking FK/audit logic.
    global $pdo;
    if (isset($pdo) && $pdo instanceof PDO && isset($_SESSION['user_id'], $_SESSION['role'])) {
        try {
            $stmt = $pdo->prepare("SELECT id, full_name, email, identifier, role, status FROM users WHERE id = :id LIMIT 1");
            $stmt->execute([':id' => (int)$_SESSION['user_id']]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$user || ($user['status'] ?? '') !== 'active' || ($user['role'] ?? '') !== ($_SESSION['role'] ?? '')) {
                urams_clear_session_only();
                if (urams_is_ajax_request()) {
                    http_response_code(401);
                    header('Content-Type: application/json');
                    echo json_encode(['success' => false, 'message' => 'Session expired. Please login again.']);
                    exit;
                }
                header('Location: login.php?session=expired');
                exit;
            }
            $_SESSION['full_name'] = $user['full_name'];
            $_SESSION['email'] = $user['email'];
            $_SESSION['identifier'] = $user['identifier'];
            $_SESSION['role'] = $user['role'];
        } catch (Throwable $e) {
            // If the database is temporarily unavailable, do not expose errors here.
        }
    }
}

function require_role(array $allowedRoles): void
{
    // Step: Specific role check. Example: admin-only page.
    require_login();
    if (!in_array($_SESSION['role'], $allowedRoles, true)) {
        http_response_code(403);
        exit('403 Forbidden: You do not have permission.');
    }
}

function e(string $value): string
{
    // Step: XSS protection. HTML e data print korar age escape kori.
    return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
}


function get_current_user_record()
{
    if (!isset($_SESSION['user_id'])) {
        return false;
    }
    global $pdo;
    if (!isset($pdo) || !$pdo instanceof PDO) {
        return false;
    }

    try {
        $hasProfilePhotoColumn = function_exists('ensure_profile_photo_column') ? ensure_profile_photo_column($pdo) : false;
        $photoSelect = $hasProfilePhotoColumn ? ', profile_photo' : '';
        $stmt = $pdo->prepare("SELECT full_name, identifier, email{$photoSelect} FROM users WHERE id = :id LIMIT 1");
        $stmt->execute([':id' => (int)$_SESSION['user_id']]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (Throwable $e) {
        return false;
    }

    if (!$user) {
        return false;
    }
    if (!empty($user['full_name'])) {
        $_SESSION['full_name'] = $user['full_name'];
    }
    if (!empty($user['identifier'])) {
        $_SESSION['identifier'] = $user['identifier'];
    }
    if (!empty($user['email'])) {
        $_SESSION['email'] = $user['email'];
    }
    if (!empty($user['profile_photo'])) {
        $_SESSION['profile_photo'] = $user['profile_photo'];
    }
    return $user;
}

function get_user_full_name(): string
{
    return trim($_SESSION['full_name'] ?? 'User');
}

function get_user_identifier(): string
{
    return trim($_SESSION['identifier'] ?? '');
}

function ensure_profile_photo_column(PDO $pdo): bool
{
    static $hasColumn = null;
    if ($hasColumn !== null) {
        return $hasColumn;
    }

    try {
        $stmt = $pdo->query("SHOW COLUMNS FROM users LIKE 'profile_photo'");
        if (!$stmt->fetch()) {
            $pdo->exec("ALTER TABLE users ADD COLUMN profile_photo VARCHAR(255) NULL AFTER status");
        }
        $hasColumn = true;
    } catch (Throwable $e) {
        $hasColumn = false;
    }

    return $hasColumn;
}

function get_user_profile_photo(): string
{
    $photo = trim((string)($_SESSION['profile_photo'] ?? ''));
    if ($photo === '') {
        return '';
    }

    // Only allow local upload paths to avoid accidentally rendering unsafe external URLs.
    if (preg_match('/^uploads\/profile_photos\/[A-Za-z0-9._-]+$/', $photo)) {
        return $photo;
    }

    return '';
}

function get_user_initials(): string
{
    $fullName = get_user_full_name();
    if ($fullName !== '') {
        $parts = preg_split('/\s+/', $fullName, -1, PREG_SPLIT_NO_EMPTY);
        $initials = '';
        foreach ($parts as $part) {
            $initials .= strtoupper(substr($part, 0, 1));
            if (strlen($initials) >= 2) {
                break;
            }
        }
        return $initials;
    }

    return strtoupper(substr(get_user_identifier(), 0, 2));
}

function get_user_role_label(): string
{
    $role = $_SESSION['role'] ?? '';
    $identifier = get_user_identifier();

    switch ($role) {
        case 'admin':
            return 'Admin · Super User';
        case 'teacher':
            return 'Teacher' . ($identifier !== '' ? ' · ' . strtoupper($identifier) : '');
        case 'student':
            return 'Student' . ($identifier !== '' ? ' · ' . $identifier : '');
        case 'parent':
            return 'Parent / Guardian';
        default:
            return ucfirst($role ?: 'User');
    }
}

function write_audit_log(PDO $pdo, ?int $userId, string $action, ?string $tableName = null, ?int $recordId = null, ?string $oldValue = null, ?string $newValue = null): void
{
    // Step: System change history audit_logs table e save hoy.
    // If the browser still has an old session after DB re-import, that user_id may not exist anymore.
    // To keep the system accessible, audit user_id is safely changed to NULL in that case.
    try {
        if ($userId !== null) {
            $check = $pdo->prepare("SELECT id FROM users WHERE id = :id LIMIT 1");
            $check->execute([':id' => (int)$userId]);
            if (!$check->fetchColumn()) {
                $userId = null;
            }
        }

        $sql = "INSERT INTO audit_logs (user_id, action, table_name, record_id, old_value, new_value, ip_address, user_agent)
                VALUES (:user_id, :action, :table_name, :record_id, :old_value, :new_value, :ip_address, :user_agent)";
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':user_id' => $userId,
            ':action' => $action,
            ':table_name' => $tableName,
            ':record_id' => $recordId,
            ':old_value' => $oldValue,
            ':new_value' => $newValue,
            ':ip_address' => $_SERVER['REMOTE_ADDR'] ?? null,
            ':user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? null,
        ]);
    } catch (Throwable $e) {
        // Audit logging must never stop login/logout/marks workflow.
    }
}

function login_user(PDO $pdo, string $identifier, string $password, string $role): bool
{
    // Step 1: Role validate kori.
    if (!in_array($role, URAMS_ROLES, true)) {
        return false;
    }

    // Step 2: Prepared statement diye user search. SQL Injection safe.
    $hasProfilePhotoColumn = ensure_profile_photo_column($pdo);
    $photoSelect = $hasProfilePhotoColumn ? ', profile_photo' : '';
    $stmt = $pdo->prepare("SELECT id, full_name, email, identifier, role, password_hash, status{$photoSelect}
                           FROM users
                           WHERE identifier = :identifier AND role = :role
                           LIMIT 1");
    $stmt->execute([':identifier' => $identifier, ':role' => $role]);
    $user = $stmt->fetch();

    // Step 3: User active kina check.
    if (!$user || $user['status'] !== 'active') {
        return false;
    }

    // Step 4: Hashed password verify kori.
    if (!password_verify($password, $user['password_hash'])) {
        return false;
    }

    // Step 5: Login successful hole session regenerate kori.
    session_regenerate_id(true);
    $_SESSION['user_id'] = (int)$user['id'];
    $_SESSION['full_name'] = $user['full_name'];
    $_SESSION['email'] = $user['email'];
    $_SESSION['identifier'] = $user['identifier'];
    $_SESSION['role'] = $user['role'];
    $_SESSION['profile_photo'] = $hasProfilePhotoColumn ? (string)($user['profile_photo'] ?? '') : '';

    write_audit_log($pdo, (int)$user['id'], 'USER_LOGIN', 'users', (int)$user['id']);
    return true;
}

function register_user(PDO $pdo, string $fullName, string $email, string $identifier, string $password, string $role): array
{
    // Step 1: Input validation.
    if (!in_array($role, URAMS_ROLES, true)) {
        return [false, 'Invalid role selected.'];
    }
    if (strlen($password) < 6) {
        return [false, 'Password must be at least 6 characters.'];
    }

    // Step 2: Duplicate user check using prepared statement.
    $check = $pdo->prepare("SELECT id FROM users WHERE email = :email OR identifier = :identifier LIMIT 1");
    $check->execute([':email' => $email, ':identifier' => $identifier]);
    if ($check->fetch()) {
        return [false, 'Email or ID already exists.'];
    }

    // Step 3: password_hash() diye password secure kori.
    $hash = password_hash($password, PASSWORD_DEFAULT);
    $stmt = $pdo->prepare("INSERT INTO users (full_name, email, identifier, role, password_hash, status)
                           VALUES (:full_name, :email, :identifier, :role, :password_hash, 'active')");
    $stmt->execute([
        ':full_name' => $fullName,
        ':email' => $email,
        ':identifier' => $identifier,
        ':role' => $role,
        ':password_hash' => $hash,
    ]);

    $newId = (int)$pdo->lastInsertId();
    write_audit_log($pdo, $newId, 'USER_REGISTER', 'users', $newId);
    return [true, 'Registration successful. Please login.'];
}

function logout_user(PDO $pdo = null): void
{
    try {
        if ($pdo && isset($_SESSION['user_id'])) {
            write_audit_log($pdo, (int)$_SESSION['user_id'], 'USER_LOGOUT', 'users', (int)$_SESSION['user_id']);
        }
    } catch (Throwable $e) {
        // Logout must work even if audit logging fails after a database re-import.
    }

    // Step: Session data clear kori.
    urams_clear_session_only();
}
?>