-- database/003_admin_panel.sql
-- Run this once on an existing database before using the fixed Admin Panel.
USE urams_db;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS program VARCHAR(80) NULL AFTER phone,
  ADD COLUMN IF NOT EXISTS department VARCHAR(80) NULL AFTER program;

UPDATE users
SET program = COALESCE(program, 'BSc CSE'),
    department = COALESCE(department, 'CSE')
WHERE role = 'student';

UPDATE users
SET department = COALESCE(department, 'CSE')
WHERE role = 'teacher';

CREATE TABLE IF NOT EXISTS result_submissions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  section_id INT UNSIGNED NOT NULL,
  status ENUM('draft','submitted','approved','rejected') NOT NULL DEFAULT 'draft',
  submitted_by INT UNSIGNED NULL,
  approved_by INT UNSIGNED NULL,
  rejected_by INT UNSIGNED NULL,
  submitted_at DATETIME NULL,
  approved_at DATETIME NULL,
  rejected_at DATETIME NULL,
  rejection_reason TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_submission_section (section_id),
  INDEX idx_submission_status (status),
  CONSTRAINT fk_rs_section_admin FOREIGN KEY (section_id) REFERENCES course_sections(id) ON DELETE CASCADE,
  CONSTRAINT fk_rs_submitter_admin FOREIGN KEY (submitted_by) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_rs_approver_admin FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_rs_rejecter_admin FOREIGN KEY (rejected_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

INSERT INTO result_submissions (section_id, status)
SELECT cs.id, CASE WHEN cs.status IN ('submitted','approved','rejected') THEN cs.status ELSE 'draft' END
FROM course_sections cs
ON DUPLICATE KEY UPDATE status = VALUES(status);
