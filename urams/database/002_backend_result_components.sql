USE urams_db;

SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS assessment_components (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  section_id INT UNSIGNED NOT NULL,
  component_key VARCHAR(50) NOT NULL,
  component_name VARCHAR(80) NOT NULL,
  component_type ENUM('ct','assignment','quiz','mid','final','attendance','lab','presentation','custom') NOT NULL DEFAULT 'custom',
  taken_out_of DECIMAL(6,2) NOT NULL,
  convert_to DECIMAL(6,2) NOT NULL,
  weight DECIMAL(6,2) NOT NULL DEFAULT 0,
  sort_order INT UNSIGNED NOT NULL DEFAULT 1,
  is_best_of_group TINYINT(1) NOT NULL DEFAULT 0,
  best_of_group VARCHAR(50) NULL,
  exam_date DATE NULL,
  created_by INT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_component_section_key (section_id, component_key),
  UNIQUE KEY uq_component_section_name (section_id, component_name),
  INDEX idx_component_section (section_id),
  CONSTRAINT fk_ac_section FOREIGN KEY (section_id) REFERENCES course_sections(id) ON DELETE CASCADE,
  CONSTRAINT fk_ac_creator FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS student_component_marks (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  enrollment_id INT UNSIGNED NOT NULL,
  component_id INT UNSIGNED NOT NULL,
  raw_marks DECIMAL(6,2) NOT NULL DEFAULT 0,
  converted_marks DECIMAL(6,2) NOT NULL DEFAULT 0,
  is_absent TINYINT(1) NOT NULL DEFAULT 0,
  remarks VARCHAR(255) NULL,
  updated_by INT UNSIGNED NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_student_component (enrollment_id, component_id),
  INDEX idx_scm_enrollment (enrollment_id),
  INDEX idx_scm_component (component_id),
  CONSTRAINT fk_scm_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(id) ON DELETE CASCADE,
  CONSTRAINT fk_scm_component FOREIGN KEY (component_id) REFERENCES assessment_components(id) ON DELETE CASCADE,
  CONSTRAINT fk_scm_updated_by FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS student_section_results (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  enrollment_id INT UNSIGNED NOT NULL UNIQUE,
  total_marks DECIMAL(6,2) NOT NULL DEFAULT 0,
  grade VARCHAR(5) NULL,
  grade_point DECIMAL(3,2) NULL,
  calculated_at TIMESTAMP NULL,
  locked_at TIMESTAMP NULL,
  CONSTRAINT fk_ssr_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(id) ON DELETE CASCADE
) ENGINE=InnoDB;

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
  CONSTRAINT fk_rs_section FOREIGN KEY (section_id) REFERENCES course_sections(id) ON DELETE CASCADE,
  CONSTRAINT fk_rs_submitter FOREIGN KEY (submitted_by) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_rs_approver FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_rs_rejecter FOREIGN KEY (rejected_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS grade_rules (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  min_mark DECIMAL(6,2) NOT NULL,
  max_mark DECIMAL(6,2) NOT NULL,
  grade VARCHAR(5) NOT NULL,
  grade_point DECIMAL(3,2) NOT NULL,
  remark VARCHAR(80) NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_grade_range (min_mark, max_mark)
) ENGINE=InnoDB;

INSERT IGNORE INTO grade_rules (min_mark, max_mark, grade, grade_point, remark) VALUES
(90,100,'A+',4.00,'Outstanding'),
(85,89.99,'A',3.75,'Excellent'),
(80,84.99,'A-',3.50,'Very Good'),
(75,79.99,'B+',3.25,'Good'),
(70,74.99,'B',3.00,'Above Average'),
(65,69.99,'B-',2.75,'Average'),
(60,64.99,'C+',2.50,'Below Average'),
(55,59.99,'C',2.25,'Pass'),
(50,54.99,'D',2.00,'Marginal Pass'),
(0,49.99,'F',0.00,'Fail');

INSERT IGNORE INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group)
SELECT cs.id, 'ct1', 'CT1', 'ct', 30, 15, 15, 1, 1, 'ct' FROM course_sections cs;

INSERT IGNORE INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group)
SELECT cs.id, 'ct2', 'CT2', 'ct', 30, 15, 15, 2, 1, 'ct' FROM course_sections cs;

INSERT IGNORE INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group)
SELECT cs.id, 'assignment', 'Assignment', 'assignment', 10, 10, 10, 3, 0, NULL FROM course_sections cs;

INSERT IGNORE INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group)
SELECT cs.id, 'mid', 'Mid Term', 'mid', 50, 25, 25, 4, 0, NULL FROM course_sections cs;

INSERT IGNORE INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group)
SELECT cs.id, 'final', 'Final Exam', 'final', 80, 40, 40, 5, 0, NULL FROM course_sections cs;

INSERT IGNORE INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group)
SELECT cs.id, 'attendance', 'Attendance', 'attendance', 10, 10, 10, 6, 0, NULL FROM course_sections cs;

INSERT IGNORE INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, updated_by)
SELECT r.enrollment_id, ac.id,
       CASE WHEN ac.convert_to > 0 THEN ROUND((r.ct1 / ac.convert_to) * ac.taken_out_of, 2) ELSE r.ct1 END,
       r.ct1,
       r.submitted_by
FROM results r
JOIN enrollments e ON e.id = r.enrollment_id
JOIN assessment_components ac ON ac.section_id = e.section_id AND ac.component_key = 'ct1'
WHERE r.ct1 > 0;

INSERT IGNORE INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, updated_by)
SELECT r.enrollment_id, ac.id,
       CASE WHEN ac.convert_to > 0 THEN ROUND((r.ct2 / ac.convert_to) * ac.taken_out_of, 2) ELSE r.ct2 END,
       r.ct2,
       r.submitted_by
FROM results r
JOIN enrollments e ON e.id = r.enrollment_id
JOIN assessment_components ac ON ac.section_id = e.section_id AND ac.component_key = 'ct2'
WHERE r.ct2 > 0;

INSERT IGNORE INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, updated_by)
SELECT r.enrollment_id, ac.id, r.assignment, r.assignment, r.submitted_by
FROM results r
JOIN enrollments e ON e.id = r.enrollment_id
JOIN assessment_components ac ON ac.section_id = e.section_id AND ac.component_key = 'assignment'
WHERE r.assignment > 0;

INSERT IGNORE INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, updated_by)
SELECT r.enrollment_id, ac.id,
       CASE WHEN ac.convert_to > 0 THEN ROUND((r.mid / ac.convert_to) * ac.taken_out_of, 2) ELSE r.mid END,
       r.mid,
       r.submitted_by
FROM results r
JOIN enrollments e ON e.id = r.enrollment_id
JOIN assessment_components ac ON ac.section_id = e.section_id AND ac.component_key = 'mid'
WHERE r.mid > 0;

INSERT IGNORE INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, updated_by)
SELECT r.enrollment_id, ac.id,
       CASE WHEN ac.convert_to > 0 THEN ROUND((r.final / ac.convert_to) * ac.taken_out_of, 2) ELSE r.final END,
       r.final,
       r.submitted_by
FROM results r
JOIN enrollments e ON e.id = r.enrollment_id
JOIN assessment_components ac ON ac.section_id = e.section_id AND ac.component_key = 'final'
WHERE r.final > 0;

INSERT IGNORE INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, updated_by)
SELECT r.enrollment_id, ac.id, r.attendance_marks, r.attendance_marks, r.submitted_by
FROM results r
JOIN enrollments e ON e.id = r.enrollment_id
JOIN assessment_components ac ON ac.section_id = e.section_id AND ac.component_key = 'attendance'
WHERE r.attendance_marks > 0;

INSERT INTO student_section_results (enrollment_id, total_marks, grade, grade_point, calculated_at, locked_at)
SELECT r.enrollment_id, r.total_marks, r.grade, r.grade_point, NOW(), IF(r.status='approved', NOW(), NULL)
FROM results r
ON DUPLICATE KEY UPDATE
  total_marks = VALUES(total_marks),
  grade = VALUES(grade),
  grade_point = VALUES(grade_point),
  calculated_at = NOW();

INSERT IGNORE INTO result_submissions (section_id, status, submitted_by, approved_by, submitted_at, approved_at)
SELECT e.section_id,
       CASE
         WHEN MAX(r.status='approved') = 1 THEN 'approved'
         WHEN MAX(r.status='submitted') = 1 THEN 'submitted'
         WHEN MAX(r.status='rejected') = 1 THEN 'rejected'
         ELSE 'draft'
       END AS status,
       MAX(r.submitted_by),
       MAX(r.approved_by),
       MAX(r.submitted_at),
       MAX(r.approved_at)
FROM results r
JOIN enrollments e ON e.id = r.enrollment_id
GROUP BY e.section_id;

SET FOREIGN_KEY_CHECKS = 1;
