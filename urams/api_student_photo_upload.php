<?php
// api_student_photo_upload.php
// Student profile photo upload handler.
require_once __DIR__ . '/includes/auth.php';
require_role(['student']);
header('Content-Type: application/json');

$userId = (int)($_SESSION['user_id'] ?? 0);
if ($userId <= 0) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Not authenticated.']);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Only POST requests are allowed.']);
    exit;
}

if (!isset($_FILES['photo']) || !is_uploaded_file($_FILES['photo']['tmp_name'])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'No photo uploaded.']);
    exit;
}

$file = $_FILES['photo'];
if ($file['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Upload error.']);
    exit;
}

$allowedTypes = [
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
];
$finfo = new finfo(FILEINFO_MIME_TYPE);
$mimeType = $finfo->file($file['tmp_name']);
if (!isset($allowedTypes[$mimeType])) {
    http_response_code(415);
    echo json_encode(['success' => false, 'message' => 'Only JPG, PNG, and WEBP images are allowed.']);
    exit;
}

$extension = $allowedTypes[$mimeType];
$uploadDir = __DIR__ . '/uploads/profile_photos';
if (!is_dir($uploadDir) && !mkdir($uploadDir, 0755, true) && !is_dir($uploadDir)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Unable to create upload directory.']);
    exit;
}

$filename = sprintf('student_%d_%s.%s', $userId, time(), $extension);
$destination = $uploadDir . '/' . $filename;
if (!move_uploaded_file($file['tmp_name'], $destination)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Failed to save uploaded photo.']);
    exit;
}

$photoPath = 'uploads/profile_photos/' . $filename;

try {
    // Ensure the profile_photo column exists.
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'profile_photo'"
    );
    $stmt->execute();
    if ((int)$stmt->fetchColumn() === 0) {
        $pdo->exec("ALTER TABLE users ADD COLUMN profile_photo VARCHAR(255) NULL");
    }

    $stmt = $pdo->prepare("UPDATE users SET profile_photo = :photo WHERE id = :id");
    $stmt->execute([':photo' => $photoPath, ':id' => $userId]);
    $_SESSION['profile_photo'] = $photoPath;

    echo json_encode(['success' => true, 'photo' => $photoPath]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Unable to save profile photo.']);
}
