USE urams_db;

-- Optional safety cleanup if old audit rows exist after manual imports/partial merges.
UPDATE audit_logs a
LEFT JOIN users u ON u.id = a.user_id
SET a.user_id = NULL
WHERE a.user_id IS NOT NULL AND u.id IS NULL;
