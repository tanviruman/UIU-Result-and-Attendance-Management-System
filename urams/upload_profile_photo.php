<?php
// upload_profile_photo.php
// Handles profile photo upload for logged-in users. Teacher profile UI uses this endpoint.

require_once __DIR__ . '/includes/auth.php';
require_login();

header('Content-Type: application/json; charset=utf-8');

function urams_profile_json(array $payload, int $status = 200): void
{
    http_response_code($status);
    echo json_encode($payload);
    exit;
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        urams_profile_json(['success' => false, 'message' => 'Invalid request method.'], 405);
    }

    ensure_profile_photo_column($pdo);

    if (empty($_FILES['profile_photo']) || !is_array($_FILES['profile_photo'])) {
        urams_profile_json(['success' => false, 'message' => 'No photo file received.'], 400);
    }

    $file = $_FILES['profile_photo'];
    if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        urams_profile_json(['success' => false, 'message' => 'Upload failed. Please choose another image.'], 400);
    }

    $maxBytes = 2 * 1024 * 1024; // 2 MB
    if ((int)$file['size'] > $maxBytes) {
        urams_profile_json(['success' => false, 'message' => 'Image size must be 2 MB or less.'], 400);
    }

    $tmpPath = (string)$file['tmp_name'];
    $mime = '';
    if (class_exists('finfo')) {
        $finfo = new finfo(FILEINFO_MIME_TYPE);
        $mime = (string)$finfo->file($tmpPath);
    } elseif (function_exists('mime_content_type')) {
        $mime = (string)mime_content_type($tmpPath);
    }

    $allowed = [
        'image/jpeg' => 'jpg',
        'image/png'  => 'png',
        'image/webp' => 'webp',
        'image/gif'  => 'gif',
    ];

    if (!isset($allowed[$mime])) {
        urams_profile_json(['success' => false, 'message' => 'Only JPG, PNG, WEBP or GIF images are allowed.'], 400);
    }

    $userId = (int)($_SESSION['user_id'] ?? 0);
    if ($userId <= 0) {
        urams_profile_json(['success' => false, 'message' => 'Login session expired. Please login again.'], 401);
    }

    $uploadDir = __DIR__ . '/uploads/profile_photos';
    if (!is_dir($uploadDir) && !mkdir($uploadDir, 0775, true)) {
        urams_profile_json(['success' => false, 'message' => 'Could not create upload folder.'], 500);
    }

    $extension = $allowed[$mime];
    $fileName = 'user_' . $userId . '_' . date('YmdHis') . '_' . bin2hex(random_bytes(4)) . '.' . $extension;
    $targetPath = $uploadDir . '/' . $fileName;
    $relativePath = 'uploads/profile_photos/' . $fileName;

    if (!move_uploaded_file($tmpPath, $targetPath)) {
        urams_profile_json(['success' => false, 'message' => 'Could not save uploaded photo.'], 500);
    }

    // Remove previous local profile photo to avoid unused files.
    $oldPhoto = trim((string)($_SESSION['profile_photo'] ?? ''));
    if ($oldPhoto !== '' && preg_match('/^uploads\/profile_photos\/[A-Za-z0-9._-]+$/', $oldPhoto)) {
        $oldPath = __DIR__ . '/' . $oldPhoto;
        if (is_file($oldPath) && basename($oldPath) !== $fileName) {
            @unlink($oldPath);
        }
    }

    $stmt = $pdo->prepare('UPDATE users SET profile_photo = :profile_photo WHERE id = :id');
    $stmt->execute([':profile_photo' => $relativePath, ':id' => $userId]);

    $_SESSION['profile_photo'] = $relativePath;

    write_audit_log($pdo, $userId, 'PROFILE_PHOTO_UPLOAD', 'users', $userId, null, $relativePath);

    urams_profile_json([
        'success' => true,
        'message' => 'Profile photo updated successfully.',
        'photo_url' => $relativePath,
    ]);
} catch (Throwable $e) {
    urams_profile_json(['success' => false, 'message' => 'Server error while uploading photo.'], 500);
}
?>
