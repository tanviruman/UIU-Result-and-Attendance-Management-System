<?php
// includes/admin_helpers.php
// Shared Admin Panel JSON helper

require_once __DIR__ . '/auth.php';
require_once __DIR__ . '/result_helpers.php';

function urams_admin_payload(): array
{
    return urams_read_json();
}

function urams_admin_required_string(array $data, string $key, string $label, int $max = 150): string
{
    $value = trim((string)($data[$key] ?? ''));
    if ($value === '') {
        urams_json_response(['success' => false, 'message' => $label . ' is required.'], 400);
    }
    if (mb_strlen($value) > $max) {
        urams_json_response(['success' => false, 'message' => $label . ' is too long.'], 400);
    }
    return $value;
}

function urams_admin_optional_string(array $data, string $key, int $max = 150): ?string
{
    $value = trim((string)($data[$key] ?? ''));
    if ($value === '') {
        return null;
    }
    return mb_substr($value, 0, $max);
}

function urams_admin_validate_email(string $email): void
{
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        urams_json_response(['success' => false, 'message' => 'Valid email is required.'], 400);
    }
}

function urams_admin_check_duplicate_user(PDO $pdo, string $email, string $identifier, ?int $excludeId = null): void
{
    $sql = 'SELECT id FROM users WHERE (email = :email OR identifier = :identifier)';
    $params = [':email' => $email, ':identifier' => $identifier];
    if ($excludeId !== null) {
        $sql .= ' AND id <> :id';
        $params[':id'] = $excludeId;
    }
    $sql .= ' LIMIT 1';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    if ($stmt->fetch()) {
        urams_json_response(['success' => false, 'message' => 'Email or identifier already exists.'], 409);
    }
}

function urams_admin_user_row(PDO $pdo, int $id): ?array
{
    $stmt = $pdo->prepare('SELECT id, full_name, email, identifier, role, phone, program, department, status, program_id, curriculum_version_id FROM users WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $id]);
    $row = $stmt->fetch();
    return $row ?: null;
}

function urams_admin_require_user(PDO $pdo, int $id, string $role): array
{
    $stmt = $pdo->prepare('SELECT id, full_name, email, identifier, role, phone, program, department, status, program_id, curriculum_version_id FROM users WHERE id = :id AND role = :role LIMIT 1');
    $stmt->execute([':id' => $id, ':role' => $role]);
    $row = $stmt->fetch();
    if (!$row) {
        urams_json_response(['success' => false, 'message' => ucfirst($role) . ' not found.'], 404);
    }
    return $row;
}

function urams_admin_json_user(array $row): array
{
    return [
        'id' => (int)$row['id'],
        'identifier' => (string)$row['identifier'],
        'full_name' => (string)$row['full_name'],
        'email' => (string)$row['email'],
        'phone' => $row['phone'],
        'program' => $row['program'],
        'department' => $row['department'],
        'status' => (string)$row['status'],
        'program_id' => isset($row['program_id']) ? (int)$row['program_id'] : null,
        'curriculum_version_id' => isset($row['curriculum_version_id']) ? (int)$row['curriculum_version_id'] : null,
    ];
}
