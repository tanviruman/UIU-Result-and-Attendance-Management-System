-- ============================================================
-- URAMS FULL FINAL DATABASE - IMPORT THIS ONE FILE ONLY
-- This creates urams_db, all tables, academic setup, and demo data.
-- Password for every demo account: password123
-- ============================================================

CREATE DATABASE IF NOT EXISTS urams_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE urams_db;
SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW IF EXISTS v_student_completed_courses;
DROP TABLE IF EXISTS course_prerequisites;
DROP TABLE IF EXISTS curriculum_courses;
DROP TABLE IF EXISTS curriculum_versions;
DROP TABLE IF EXISTS programs;
SET FOREIGN_KEY_CHECKS = 1;



-- >>> BEGIN database/schema.sql
-- database/schema.sql
-- URAMS normalized database schema for login + teacher component marks system.

CREATE DATABASE IF NOT EXISTS urams_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE urams_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS result_submissions;
DROP TABLE IF EXISTS student_section_results;
DROP TABLE IF EXISTS student_component_marks;
DROP TABLE IF EXISTS assessment_components;
DROP TABLE IF EXISTS grade_rules;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS results;
DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS course_sections;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS trimesters;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  identifier VARCHAR(50) NOT NULL UNIQUE,
  role ENUM('admin','teacher','student','parent') NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  phone VARCHAR(30) NULL,
  program VARCHAR(80) NULL,
  department VARCHAR(80) NULL,
  status ENUM('active','inactive','blocked') NOT NULL DEFAULT 'active',
  profile_photo VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_users_role (role),
  INDEX idx_users_identifier_role (identifier, role)
) ENGINE=InnoDB;

CREATE TABLE trimesters (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL UNIQUE,
  start_date DATE NULL,
  end_date DATE NULL,
  status ENUM('active','closed') NOT NULL DEFAULT 'active'
) ENGINE=InnoDB;

CREATE TABLE courses (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  course_code VARCHAR(20) NOT NULL UNIQUE,
  course_name VARCHAR(150) NOT NULL,
  credit DECIMAL(3,1) NOT NULL DEFAULT 3.0
) ENGINE=InnoDB;

CREATE TABLE course_sections (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  course_id INT UNSIGNED NOT NULL,
  trimester_id INT UNSIGNED NOT NULL,
  teacher_id INT UNSIGNED NOT NULL,
  section_name VARCHAR(10) NOT NULL,
  status ENUM('running','submitted','approved','rejected') NOT NULL DEFAULT 'running',
  UNIQUE KEY uq_section (course_id, trimester_id, section_name),
  INDEX idx_cs_teacher (teacher_id),
  CONSTRAINT fk_cs_course FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE,
  CONSTRAINT fk_cs_trimester FOREIGN KEY (trimester_id) REFERENCES trimesters(id) ON DELETE CASCADE,
  CONSTRAINT fk_cs_teacher FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE enrollments (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  student_id INT UNSIGNED NOT NULL,
  section_id INT UNSIGNED NOT NULL,
  parent_user_id INT UNSIGNED NULL,
  enrolled_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_enrollment (student_id, section_id),
  INDEX idx_en_section (section_id),
  CONSTRAINT fk_en_student FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_en_section FOREIGN KEY (section_id) REFERENCES course_sections(id) ON DELETE CASCADE,
  CONSTRAINT fk_en_parent FOREIGN KEY (parent_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Compatibility/cache table used by existing Student/Admin/Parent pages.
CREATE TABLE results (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  enrollment_id INT UNSIGNED NOT NULL UNIQUE,
  ct1 DECIMAL(6,2) NOT NULL DEFAULT 0,
  ct2 DECIMAL(6,2) NOT NULL DEFAULT 0,
  best_ct DECIMAL(6,2) NOT NULL DEFAULT 0,
  assignment DECIMAL(6,2) NOT NULL DEFAULT 0,
  mid DECIMAL(6,2) NOT NULL DEFAULT 0,
  final DECIMAL(6,2) NOT NULL DEFAULT 0,
  attendance_marks DECIMAL(6,2) NOT NULL DEFAULT 0,
  total_marks DECIMAL(6,2) NOT NULL DEFAULT 0,
  grade VARCHAR(5) NULL,
  grade_point DECIMAL(3,2) NULL,
  status ENUM('draft','submitted','approved','rejected') NOT NULL DEFAULT 'draft',
  submitted_by INT UNSIGNED NULL,
  approved_by INT UNSIGNED NULL,
  submitted_at DATETIME NULL,
  approved_at DATETIME NULL,
  CONSTRAINT fk_result_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(id) ON DELETE CASCADE,
  CONSTRAINT fk_result_submitter FOREIGN KEY (submitted_by) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_result_approver FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE assessment_components (
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

CREATE TABLE student_component_marks (
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

CREATE TABLE student_section_results (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  enrollment_id INT UNSIGNED NOT NULL UNIQUE,
  total_marks DECIMAL(6,2) NOT NULL DEFAULT 0,
  grade VARCHAR(5) NULL,
  grade_point DECIMAL(3,2) NULL,
  calculated_at TIMESTAMP NULL,
  locked_at TIMESTAMP NULL,
  CONSTRAINT fk_ssr_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE result_submissions (
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

CREATE TABLE grade_rules (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  min_mark DECIMAL(6,2) NOT NULL,
  max_mark DECIMAL(6,2) NOT NULL,
  grade VARCHAR(5) NOT NULL,
  grade_point DECIMAL(3,2) NOT NULL,
  remark VARCHAR(80) NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_grade_range (min_mark, max_mark)
) ENGINE=InnoDB;

CREATE TABLE audit_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NULL,
  action VARCHAR(100) NOT NULL,
  table_name VARCHAR(80) NULL,
  record_id INT UNSIGNED NULL,
  old_value TEXT NULL,
  new_value TEXT NULL,
  ip_address VARCHAR(45) NULL,
  user_agent VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_user (user_id),
  INDEX idx_audit_action (action),
  CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

INSERT INTO grade_rules (min_mark, max_mark, grade, grade_point, remark) VALUES
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

-- Demo users. Password for all demo accounts: password123
INSERT INTO users (full_name, email, identifier, role, password_hash, program, department) VALUES
('System Administrator', 'admin@uiu.ac.bd', 'admin001', 'admin', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL),
('Md. Rafiqul Islam', 'mri@uiu.ac.bd', 'MRI', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'CSE'),
('Fatema Khatun', 'fatema@uiu.ac.bd', '0242220005', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE'),
('Md. Rahim Uddin', 'rahim@uiu.ac.bd', '0242220012', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE'),
('Nasrin Begum', 'nasrin@uiu.ac.bd', '0242220018', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE'),
('Mr. M. Khatun', 'parent@uiu.ac.bd', 'PARENT0242220005', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL);

INSERT INTO trimesters (name, start_date, end_date) VALUES ('Summer 2025', '2025-06-01', '2025-09-30');
INSERT INTO courses (course_code, course_name, credit) VALUES ('CSE4533', 'Object Oriented Programming', 3.0);
INSERT INTO course_sections (course_id, trimester_id, teacher_id, section_name, status) VALUES (1, 1, 2, 'A', 'running');
INSERT INTO enrollments (student_id, section_id, parent_user_id) VALUES (3, 1, 6), (4, 1, NULL), (5, 1, NULL);
INSERT INTO results (enrollment_id, ct1, ct2, best_ct, assignment, mid, final, attendance_marks, total_marks, grade, grade_point) VALUES
(1, 14.5, 13.0, 14.5, 8.5, 22.5, 36.0, 10.0, 91.5, 'A+', 4.00),
(2, 6.0, 8.5, 8.5, 7.0, 15.0, 24.0, 6.0, 60.5, 'C+', 2.50),
(3, 12.0, 11.5, 12.0, 8.0, 20.0, 32.0, 10.0, 82.0, 'A-', 3.50);

-- Default real components for every section.
INSERT INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group)
SELECT cs.id, 'ct1', 'CT1', 'ct', 30, 15, 15, 1, 1, 'ct' FROM course_sections cs;
INSERT INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group)
SELECT cs.id, 'ct2', 'CT2', 'ct', 30, 15, 15, 2, 1, 'ct' FROM course_sections cs;
INSERT INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order)
SELECT cs.id, 'assignment', 'Assignment', 'assignment', 10, 10, 10, 3 FROM course_sections cs;
INSERT INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order)
SELECT cs.id, 'mid', 'Mid Term', 'mid', 50, 25, 25, 4 FROM course_sections cs;
INSERT INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order)
SELECT cs.id, 'final', 'Final Exam', 'final', 80, 40, 40, 5 FROM course_sections cs;
INSERT INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order)
SELECT cs.id, 'attendance', 'Attendance', 'attendance', 10, 10, 10, 6 FROM course_sections cs;

-- Copy demo cached results into normalized marks.
INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks)
SELECT r.enrollment_id, ac.id, ROUND((r.ct1 / ac.convert_to) * ac.taken_out_of, 2), r.ct1
FROM results r JOIN enrollments e ON e.id = r.enrollment_id JOIN assessment_components ac ON ac.section_id = e.section_id AND ac.component_key = 'ct1';
INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks)
SELECT r.enrollment_id, ac.id, ROUND((r.ct2 / ac.convert_to) * ac.taken_out_of, 2), r.ct2
FROM results r JOIN enrollments e ON e.id = r.enrollment_id JOIN assessment_components ac ON ac.section_id = e.section_id AND ac.component_key = 'ct2';
INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks)
SELECT r.enrollment_id, ac.id, r.assignment, r.assignment
FROM results r JOIN enrollments e ON e.id = r.enrollment_id JOIN assessment_components ac ON ac.section_id = e.section_id AND ac.component_key = 'assignment';
INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks)
SELECT r.enrollment_id, ac.id, ROUND((r.mid / ac.convert_to) * ac.taken_out_of, 2), r.mid
FROM results r JOIN enrollments e ON e.id = r.enrollment_id JOIN assessment_components ac ON ac.section_id = e.section_id AND ac.component_key = 'mid';
INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks)
SELECT r.enrollment_id, ac.id, ROUND((r.final / ac.convert_to) * ac.taken_out_of, 2), r.final
FROM results r JOIN enrollments e ON e.id = r.enrollment_id JOIN assessment_components ac ON ac.section_id = e.section_id AND ac.component_key = 'final';
INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks)
SELECT r.enrollment_id, ac.id, r.attendance_marks, r.attendance_marks
FROM results r JOIN enrollments e ON e.id = r.enrollment_id JOIN assessment_components ac ON ac.section_id = e.section_id AND ac.component_key = 'attendance';

INSERT INTO student_section_results (enrollment_id, total_marks, grade, grade_point, calculated_at)
SELECT enrollment_id, total_marks, grade, grade_point, NOW() FROM results;

INSERT INTO result_submissions (section_id, status)
SELECT id, 'draft' FROM course_sections;

-- <<< END database/schema.sql


-- >>> BEGIN database/007_academic_setup.sql
-- database/007_academic_setup.sql
-- Academic setup patch: programs, curriculum versions, prerequisite rules, section creation, enrollment.
USE urams_db;

SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS programs (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(30) NOT NULL UNIQUE,
  name VARCHAR(120) NOT NULL UNIQUE,
  department VARCHAR(120) NULL,
  degree_level VARCHAR(50) NULL,
  total_credits DECIMAL(6,1) NULL,
  source_note VARCHAR(255) NULL,
  status ENUM('active','inactive') NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS curriculum_versions (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  program_id INT UNSIGNED NOT NULL,
  version_code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL,
  effective_from DATE NULL,
  total_credits DECIMAL(6,1) NULL,
  status ENUM('active','inactive') NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_cv_program FOREIGN KEY (program_id) REFERENCES programs(id) ON DELETE CASCADE
) ENGINE=InnoDB;

ALTER TABLE users ADD COLUMN IF NOT EXISTS program_id INT UNSIGNED NULL AFTER program;
ALTER TABLE users ADD COLUMN IF NOT EXISTS curriculum_version_id INT UNSIGNED NULL AFTER program_id;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS program_id INT UNSIGNED NULL AFTER id;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS course_type VARCHAR(50) NULL AFTER credit;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS level_no INT UNSIGNED NULL AFTER course_type;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS is_lab TINYINT(1) NOT NULL DEFAULT 0 AFTER level_no;
ALTER TABLE course_sections ADD COLUMN IF NOT EXISTS capacity INT UNSIGNED NOT NULL DEFAULT 40 AFTER section_name;
ALTER TABLE course_sections ADD COLUMN IF NOT EXISTS room VARCHAR(50) NULL AFTER capacity;
ALTER TABLE course_sections ADD COLUMN IF NOT EXISTS class_schedule VARCHAR(150) NULL AFTER room;
ALTER TABLE enrollments ADD COLUMN IF NOT EXISTS status ENUM('active','dropped','completed') NOT NULL DEFAULT 'active' AFTER parent_user_id;

CREATE TABLE IF NOT EXISTS curriculum_courses (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  curriculum_version_id INT UNSIGNED NOT NULL,
  course_id INT UNSIGNED NOT NULL,
  course_type VARCHAR(50) NOT NULL DEFAULT 'core',
  level_no INT UNSIGNED NULL,
  term_no INT UNSIGNED NULL,
  sequence_no INT UNSIGNED NOT NULL DEFAULT 1,
  is_required TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_curriculum_course (curriculum_version_id, course_id),
  INDEX idx_curriculum_course_order (curriculum_version_id, level_no, term_no, sequence_no),
  CONSTRAINT fk_cc_curriculum FOREIGN KEY (curriculum_version_id) REFERENCES curriculum_versions(id) ON DELETE CASCADE,
  CONSTRAINT fk_cc_course FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS course_prerequisites (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  course_id INT UNSIGNED NOT NULL,
  prerequisite_course_id INT UNSIGNED NOT NULL,
  min_grade_point DECIMAL(3,2) NOT NULL DEFAULT 2.00,
  rule_group INT UNSIGNED NOT NULL DEFAULT 1,
  UNIQUE KEY uq_prereq (course_id, prerequisite_course_id),
  CONSTRAINT fk_cp_course FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE,
  CONSTRAINT fk_cp_prereq FOREIGN KEY (prerequisite_course_id) REFERENCES courses(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE OR REPLACE VIEW v_student_completed_courses AS
SELECT e.student_id,
       cs.course_id,
       MAX(COALESCE(r.grade_point, 0)) AS best_grade_point,
       MAX(r.approved_at) AS completed_at
FROM enrollments e
JOIN course_sections cs ON cs.id = e.section_id
JOIN results r ON r.enrollment_id = e.id
WHERE r.status = 'approved' AND COALESCE(r.grade_point, 0) >= 2.00
GROUP BY e.student_id, cs.course_id;

SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO programs (code,name,department,degree_level,total_credits,source_note,status) VALUES ('BSCSE','BSc CSE','CSE','undergraduate',141.0,'2026 Curriculum PDF','active') ON DUPLICATE KEY UPDATE name=VALUES(name), department=VALUES(department), degree_level=VALUES(degree_level), total_credits=VALUES(total_credits), source_note=VALUES(source_note), status='active';
INSERT INTO programs (code,name,department,degree_level,total_credits,source_note,status) VALUES ('BSEEE','BSc EEE','EEE','undergraduate',140.0,'Spring 2023 onward PDF','active') ON DUPLICATE KEY UPDATE name=VALUES(name), department=VALUES(department), degree_level=VALUES(degree_level), total_credits=VALUES(total_credits), source_note=VALUES(source_note), status='active';
INSERT INTO programs (code,name,department,degree_level,total_credits,source_note,status) VALUES ('BBA','BBA','Business','undergraduate',125.0,'Summer 2025 course offering','active') ON DUPLICATE KEY UPDATE name=VALUES(name), department=VALUES(department), degree_level=VALUES(degree_level), total_credits=VALUES(total_credits), source_note=VALUES(source_note), status='active';
INSERT INTO programs (code,name,department,degree_level,total_credits,source_note,status) VALUES ('BPHARM','B.Pharm','Pharmacy','undergraduate',NULL,'Official course curriculum page','active') ON DUPLICATE KEY UPDATE name=VALUES(name), department=VALUES(department), degree_level=VALUES(degree_level), total_credits=VALUES(total_credits), source_note=VALUES(source_note), status='active';
INSERT INTO curriculum_versions (program_id,version_code,name,effective_from,total_credits,status) SELECT id,'BSCSE-2026','BSc CSE Curriculum 2026','2026-06-01',141.0,'active' FROM programs WHERE code='BSCSE' ON DUPLICATE KEY UPDATE name=VALUES(name), effective_from=VALUES(effective_from), total_credits=VALUES(total_credits), status='active';
INSERT INTO curriculum_versions (program_id,version_code,name,effective_from,total_credits,status) SELECT id,'BSEEE-231','BSc EEE 231 Onwards','2023-01-01',140.0,'active' FROM programs WHERE code='BSEEE' ON DUPLICATE KEY UPDATE name=VALUES(name), effective_from=VALUES(effective_from), total_credits=VALUES(total_credits), status='active';
INSERT INTO curriculum_versions (program_id,version_code,name,effective_from,total_credits,status) SELECT id,'BBA-SUMMER-2025','BBA Course Offering Summer 2025','2025-06-01',125.0,'active' FROM programs WHERE code='BBA' ON DUPLICATE KEY UPDATE name=VALUES(name), effective_from=VALUES(effective_from), total_credits=VALUES(total_credits), status='active';
INSERT INTO curriculum_versions (program_id,version_code,name,effective_from,total_credits,status) SELECT id,'BPHARM-CURRENT','B.Pharm Current Curriculum','2025-01-01',NULL,'active' FROM programs WHERE code='BPHARM' ON DUPLICATE KEY UPDATE name=VALUES(name), effective_from=VALUES(effective_from), total_credits=VALUES(total_credits), status='active';

-- Upsert all course catalog rows
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ENG1011','English I',3,'ged',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('BDS1201','History of the Emergence of Bangladesh',2,'ged',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE1110','Introduction to Computer Systems',1,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MATH1151','Fundamental Calculus',3,'math',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ENG1013','English II',3,'ged',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE1111','Structured Programming Language',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE1112','Structured Programming Language Laboratory',1,'lab',1,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE2213','Discrete Mathematics',3,'math',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MATH2183','Calculus and Linear Algebra',3,'math',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHY2105','Physics',3,'science',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHY2106','Physics Laboratory',1,'lab',1,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE2215','Data Structure and Algorithms I',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE2216','Data Structure and Algorithms I Laboratory',1,'lab',1,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MATH2201','Coordinate Geometry and Vector Analysis',3,'math',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE1325','Digital Logic Design',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE1326','Digital Logic Design Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE1115','Object Oriented Programming',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE1116','Object Oriented Programming Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MATH2205','Probability and Statistics',3,'math',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('SOC2101','Society, Environment and Engineering Ethics',3,'ged',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE2217','Data Structure and Algorithms II',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE2218','Data Structure and Algorithms II Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2113','Electrical Circuits',3,'other',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE3521','Database Management Systems',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE3522','Database Management Systems Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE4165','Web Programming',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2123','Electronics',3,'other',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2124','Electronics Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE3313','Computer Architecture',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE2118','Advanced Object Oriented Programming Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('BIO3105','Biology for Engineers',3,'science',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE3411','System Analysis and Design',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE3412','System Analysis and Design Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE4325','Microprocessors and Microcontrollers',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE4326','Microprocessors and Microcontrollers Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE3421','Software Engineering',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE3422','Software Engineering Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE3811','Artificial Intelligence',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE3812','Artificial Intelligence Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE2233','Theory of Computation',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PMG4101','Project Management',3,'ged',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE3711','Computer Networks',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE3712','Computer Networks Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE4889','Machine Learning',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE4000A','Final Year Design Project - I',2,'project',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE4509','Operating Systems',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE4510','Operating Systems Laboratory',1,'lab',4,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE4000B','Final Year Design Project - II',2,'project',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE4531','Computer Security',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CSE4000C','Final Year Design Project - III',2,'project',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE4261','Green Computing',3,'other',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MAT1101','Calculus I',3,'science',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE1001','Electrical Circuits I',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MAT1103','Calculus II',3,'science',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE1003','Electrical Circuits II',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE1004','Electrical Circuits Laboratory',1,'lab',1,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHY1101','Physics I',3,'science',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2000','Simulation Laboratory',1,'lab',1,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2101','Electronics I',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHY1103','Physics II',3,'science',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHY1104','Physics Laboratory',1,'lab',1,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MAT2105','Linear Algebra and Differential Equations',3,'science',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2103','Electronics II',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2104','Electronics Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CHE2101','Chemistry',3,'science',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CHE2102','Chemistry Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MAT2107','Complex Variables, Fourier and Laplace Transforms',3,'science',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MAT2109','Coordinate Geometry and Vector Analysis',3,'science',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2401','Structured Programming Language',3,'other',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2402','Structured Programming Language Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2301','Signals and Linear Systems',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2200','Electrical Wiring and Drafting',1,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2201','Energy Conversion I',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2105','Digital Electronics',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2106','Digital Electronics Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3303','Probability, Statistics and Random Variables',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3107','Electrical Properties of Materials',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ACT3101','Financial and Managerial Accounting',3,'ged',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2203','Energy Conversion II',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE2204','Energy Conversion Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3309','Digital Signal Processing',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3310','Digital Signal Processing Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('SOC3101','Society, Environment and Engineering Ethics',3,'ged',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3305','Engineering Electromagnetics',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3307','Communication Theory',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3308','Communication Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3400','Numerical Techniques Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3205','Power System',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3206','Power System Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3403','Microprocessor and Interfacing',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3404','Microprocessor and Interfacing Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3207','Power Electronics',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE3208','Power Electronics Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('IPE4101','Industrial Production Engineering',3,'other',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE4109','Control System',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE4110','Control System Laboratory',1,'lab',4,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE4901','Capstone Project I',1,'project',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE4902','Capstone Project II',2,'project',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('EEE4903','Capstone Project III',3,'project',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('BUS1102','Introduction to Business',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('BMT1103','Business Mathematics I',3,'ged',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ACN1205','Financial Accounting I',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CST1206','Computer Applications',3,'ged',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MGT1307','Principles of Management',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('BST1308','Business Statistics I',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ACN1309','Financial Accounting II',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('SOC1105','Sociology and Psychology',3,'ged',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ECN2111','Microeconomics',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('BUS2112','Business Communication',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('BMT2113','Business Mathematics II',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ECN2214','Macroeconomics',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ACN2215','Management Accounting',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('BST2216','Business Statistics II',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MIS2218','Advanced Computer Applications in Business',3,'ged',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MGT2318','Organizational Behavior',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('FIN2319','Principles of Finance',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MKT2320','Introduction to Marketing',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('IBS3121','International Business',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MGT3122','Human Resource Management',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('FIN3123','Managerial Finance',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MGT3224','Production & Operations Management',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MGT3225','E-Business',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MKT3336','Marketing Management',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('LAW4151','Business Law',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MGT4356','Strategic Management',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('CST2321','Business Analytics',3,'ged',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MGT3341','Project Management',3,'elective',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MGT3229','Entrepreneurship and Business Plan Development',3,'ged',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MKT4204','Strategic Marketing',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MKT4101','Consumer Behavior',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MKT4311','Brand Management',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MKT4306','Marketing Research',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('MKT4313','Digital Marketing',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('FIN4116','Management of Financial Institutions',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('FIN4219','Securities Analysis and Portfolio Management',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('FIN4332','Financial Technology (FinTech)',3,'elective',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('FIN4333','Financial Analytics',3,'elective',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('HRM4153','Human Resource Planning',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('HRM4270','Industrial Law and Employee Relations',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('HRM4366','Strategic Human Resource Management',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('HRM4365','Change Management',3,'elective',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ACN4237','Cost Accounting',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ACN4136','Advanced Financial Accounting I',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ACN4238','Advanced Financial Accounting II',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ACN4342','Accounting Information Systems',3,'elective',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('ACN4340','Auditing',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('SCM4202','Enterprise Resource Planning (ERP)',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('SCM4203','Inventory Management',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('SCM4313','Service Operation Management',3,'elective',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('SCM4311','Supply Chain Risk and Disruption Management',3,'elective',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('BSA4201','Applied Decision Modeling',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('BSA4202','Advanced Analytics',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('BSA4316','Big Data Analytics and Data Visualization',3,'major',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR1001','Introduction to Pharmacy',2,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR1002','Inorganic Pharmacy',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR1002L','Inorganic Pharmacy Laboratory',1,'lab',1,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR1003','Organic Pharmacy',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR1003L','Organic Pharmacy Laboratory',1,'lab',1,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('GED1101','English',3,'ged',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('GED1102','Fundamentals of Mathematics',3,'ged',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('GED1103','Introduction to Computer Science',2,'ged',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR1004','Physical Pharmacy-I',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR1005','Pharmacognosy & Natural Product Chemistry-I',3,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR1005L','Pharmacognosy & Natural Product Chemistry-I Laboratory',1,'lab',1,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR1006','Physiology-I',1,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR1007','Basic Anatomy',2,'core',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('GED1104','Bangla Language and Literature',3,'ged',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('GED1105','Bangladesh Studies',3,'ged',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('GED1106','History of the Emergence of Bangladesh',3,'ged',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR1008','Oral Assessment-1',1,'assessment',1,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2001','Physical Pharmacy-II',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2001L','Physical Pharmacy-II Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2002','Pharmacognosy & Natural Product Chemistry-II',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2002L','Pharmacognosy & Natural Product Chemistry-II Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2003','Physiology-II',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2003L','Physiology-II Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2004','Pharmaceutical Microbiology-I',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2004L','Pharmaceutical Microbiology-I Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2005','Basic Pharmaceutics',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('GED2101','Biostatistics',3,'ged',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2006','Pharmaceutical Analysis-I',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2006L','Pharmaceutical Analysis-I Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2007','Pharmaceutical Microbiology-II',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2007L','Pharmaceutical Microbiology-II Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2008','Pharmacology-I',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2009','Pharmaceutical Technology-I',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2009L','Pharmaceutical Technology-I Laboratory',1,'lab',2,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2010','Biochemistry & Molecular Biology',3,'core',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('GED2102','Financial and Managerial Accounting',3,'ged',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR2011','Oral Assessment-2',1,'assessment',2,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3001','Pharmaceutical Analysis-II',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3001L','Pharmaceutical Analysis-II Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3002','Pharmacology-II',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3002L','Pharmacology-II Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3003','Medicinal Chemistry-I',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3003L','Medicinal Chemistry-I Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3004','Pharmaceutical Technology-II',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3004L','Pharmaceutical Technology-II Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3005','Pathology and Clinical Biochemistry',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3006','Medicinal Chemistry-II',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3006L','Medicinal Chemistry-II Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3007','Pharmaceutical Technology-III',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3007L','Pharmaceutical Technology-III Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3008','Pharmaceutical Biotechnology',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3008L','Pharmaceutical Biotechnology-Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3009','Biopharmaceutics & Pharmacokinetics-I',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3009L','Biopharmaceutics & Pharmacokinetics-I Laboratory',1,'lab',3,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3010','Pharmaceutical Packaging Technology',2,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3011','Hospital, Clinical & Community Pharmacy',3,'core',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR3012','Oral Assessment-3',1,'assessment',3,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4001','Medicinal Chemistry-III',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4001L','Medicinal Chemistry-III Laboratory',1,'lab',4,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4002','Pharmacology-III',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4003','Biopharmaceutics & Pharmacokinetics-II',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4003L','Biopharmaceutics & Pharmacokinetics-II Laboratory',1,'lab',4,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4004','Pharmaceutical Quality Control and Validation',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4004L','Pharmaceutical Quality Control and Validation Laboratory',1,'lab',4,1) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4005','Pharmaceutical Engineering',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4006','Pharmacy Practice',2,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4007','Pharmacology-IV',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4008','Cosmetology',2,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4009','Pharmaceutical Regulatory Affairs',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4010','Food Technology, Nutraceuticals and Alternative Medicines',3,'core',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4011','Oral Assessment-4',1,'assessment',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4012','In-plant Training',1,'training',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4013','Project',1,'project',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);
INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES ('PHR4014','Hospital Training',0,'training',4,0) ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit), course_type=COALESCE(courses.course_type, VALUES(course_type)), level_no=COALESCE(courses.level_no, VALUES(level_no)), is_lab=VALUES(is_lab);

-- Curriculum mapping for BSCSE-2026
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'language',1,1,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ENG1011' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,1,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BDS1201' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,1,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE1110' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'math',1,1,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MATH1151' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'language',1,2,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ENG1013' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,2,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE1111' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',1,2,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE1112' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'math',1,2,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE2213' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'math',1,3,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MATH2183' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'science',1,3,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHY2105' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',1,3,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHY2106' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,3,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE2215' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',1,3,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE2216' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'math',2,4,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MATH2201' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,4,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE1325' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,4,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE1326' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,4,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE1115' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,4,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE1116' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'math',2,5,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MATH2205' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',2,5,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='SOC2101' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,5,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE2217' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,5,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE2218' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'other',2,5,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2113' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,6,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE3521' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,6,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE3522' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,6,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE4165' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'other',2,6,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2123' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,6,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2124' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,7,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE3313' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,7,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE2118' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'science',3,7,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BIO3105' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,7,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE3411' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,7,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE3412' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,8,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE4325' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,8,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE4326' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,8,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE3421' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,8,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE3422' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,8,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE3811' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,8,6,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE3812' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,9,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE2233' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',3,9,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PMG4101' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,9,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE3711' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,9,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE3712' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,9,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE4889' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'project',4,10,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE4000A' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,10,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE4509' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',4,10,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE4510' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'project',4,11,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE4000B' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,11,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE4531' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'project',4,12,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CSE4000C' WHERE cv.version_code='BSCSE-2026';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'other',4,12,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE4261' WHERE cv.version_code='BSCSE-2026';

-- Curriculum mapping for BSEEE-231
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,1,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ENG1011' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'science',1,1,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MAT1101' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,1,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE1001' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,1,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BDS1201' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,2,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ENG1013' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'science',1,2,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MAT1103' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,2,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE1003' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',1,2,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE1004' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'science',1,2,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHY1101' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',1,3,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2000' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,3,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2101' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'science',1,3,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHY1103' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',1,3,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHY1104' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'science',1,3,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MAT2105' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,4,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2103' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,4,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2104' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'science',2,4,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CHE2101' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,4,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CHE2102' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'science',2,4,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MAT2107' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'science',2,5,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MAT2109' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'other',2,5,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2401' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,5,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2402' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,5,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2301' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,6,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2200' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,6,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2201' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,6,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2105' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,6,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2106' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,6,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3303' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,6,6,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3107' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',3,7,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ACT3101' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,7,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2203' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,7,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE2204' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,7,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3309' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,7,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3310' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',3,8,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='SOC3101' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,8,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3305' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,8,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3307' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,8,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3308' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,8,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3400' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,9,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3205' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,9,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3206' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,9,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3403' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,9,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3404' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,9,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3207' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,9,6,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE3208' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'other',4,10,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='IPE4101' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,10,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE4109' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',4,10,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE4110' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'project',4,10,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE4901' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'project',4,11,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE4902' WHERE cv.version_code='BSEEE-231';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'project',4,12,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='EEE4903' WHERE cv.version_code='BSEEE-231';

-- Curriculum mapping for BBA-SUMMER-2025
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,1,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ENG1011' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,1,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ENG1013' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,1,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BDS1201' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,1,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BUS1102' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,1,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BMT1103' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,1,6,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ACN1205' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,1,7,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CST1206' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,1,8,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MGT1307' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,1,9,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BST1308' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,1,10,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ACN1309' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,1,11,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='SOC1105' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,12,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ECN2111' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,13,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BUS2112' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,14,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BMT2113' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,15,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ECN2214' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,16,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ACN2215' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,17,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BST2216' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',2,1,18,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MIS2218' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,19,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MGT2318' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,20,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='FIN2319' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,21,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MKT2320' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,1,22,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='IBS3121' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,1,23,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MGT3122' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,1,24,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='FIN3123' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,1,25,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MGT3224' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,1,26,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MGT3225' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,1,27,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MKT3336' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,1,28,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='LAW4151' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,1,29,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MGT4356' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',2,1,30,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='CST2321' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'elective',3,1,31,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MGT3341' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',3,1,32,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MGT3229' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,33,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MKT4204' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,34,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MKT4101' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,35,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MKT4311' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,36,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MKT4306' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,37,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='MKT4313' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,38,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='FIN4116' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,39,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='FIN4219' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'elective',4,1,40,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='FIN4332' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'elective',4,1,41,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='FIN4333' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,42,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='HRM4153' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,43,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='HRM4270' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,44,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='HRM4366' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'elective',4,1,45,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='HRM4365' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,46,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ACN4237' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,47,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ACN4136' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,48,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ACN4238' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'elective',4,1,49,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ACN4342' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,50,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='ACN4340' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,51,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='SCM4202' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,52,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='SCM4203' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'elective',4,1,53,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='SCM4313' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'elective',4,1,54,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='SCM4311' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,55,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BSA4201' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,56,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BSA4202' WHERE cv.version_code='BBA-SUMMER-2025';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'major',4,1,57,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='BSA4316' WHERE cv.version_code='BBA-SUMMER-2025';

-- Curriculum mapping for BPHARM-CURRENT
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,1,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR1001' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,1,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR1002' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',1,1,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR1002L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,1,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR1003' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',1,1,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR1003L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,1,6,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='GED1101' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,1,7,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='GED1102' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,1,8,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='GED1103' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,2,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR1004' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,2,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR1005' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',1,2,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR1005L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,2,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR1006' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',1,2,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR1007' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,2,6,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='GED1104' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,2,7,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='GED1105' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',1,2,8,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='GED1106' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'assessment',1,2,9,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR1008' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2001' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,1,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2001L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2002' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,1,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2002L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2003' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,1,6,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2003L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,7,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2004' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,1,8,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2004L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,1,9,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2005' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',2,1,10,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='GED2101' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,2,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2006' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,2,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2006L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,2,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2007' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,2,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2007L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,2,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2008' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,2,6,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2009' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',2,2,7,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2009L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',2,2,8,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2010' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'ged',2,2,9,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='GED2102' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'assessment',2,2,10,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR2011' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,1,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3001' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,1,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3001L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,1,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3002' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,1,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3002L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,1,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3003' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,1,6,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3003L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,1,7,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3004' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,1,8,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3004L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,1,9,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3005' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,2,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3006' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,2,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3006L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,2,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3007' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,2,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3007L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,2,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3008' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,2,6,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3008L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,2,7,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3009' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',3,2,8,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3009L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,2,9,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3010' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',3,2,10,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3011' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'assessment',3,2,11,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR3012' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,1,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4001' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',4,1,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4001L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,1,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4002' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,1,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4003' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',4,1,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4003L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,1,6,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4004' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'lab',4,1,7,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4004L' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,1,8,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4005' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,2,1,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4006' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,2,2,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4007' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,2,3,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4008' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,2,4,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4009' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'core',4,2,5,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4010' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'assessment',4,2,6,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4011' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'training',4,2,7,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4012' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'project',4,2,8,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4013' WHERE cv.version_code='BPHARM-CURRENT';
INSERT IGNORE INTO curriculum_courses (curriculum_version_id,course_id,course_type,level_no,term_no,sequence_no,is_required) SELECT cv.id,c.id,'training',4,2,9,1 FROM curriculum_versions cv JOIN courses c ON c.course_code='PHR4014' WHERE cv.version_code='BPHARM-CURRENT';

-- Prerequisite rules
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='ENG1011' WHERE c.course_code='ENG1013';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE1110' WHERE c.course_code='CSE1111';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE1110' WHERE c.course_code='CSE1112';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MATH1151' WHERE c.course_code='MATH2183';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE1111' WHERE c.course_code='CSE2215';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE1112' WHERE c.course_code='CSE2216';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MATH1151' WHERE c.course_code='MATH2201';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE2215' WHERE c.course_code='CSE1115';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE2216' WHERE c.course_code='CSE1116';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MATH1151' WHERE c.course_code='MATH2205';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE2215' WHERE c.course_code='CSE2217';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE2216' WHERE c.course_code='CSE2218';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE2215' WHERE c.course_code='CSE3521';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE2216' WHERE c.course_code='CSE3522';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE1115' WHERE c.course_code='CSE4165';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE1116' WHERE c.course_code='CSE4165';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2113' WHERE c.course_code='EEE2123';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE1325' WHERE c.course_code='CSE3313';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE1116' WHERE c.course_code='CSE2118';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE3521' WHERE c.course_code='CSE3411';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE3522' WHERE c.course_code='CSE3412';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE3313' WHERE c.course_code='CSE4325';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2124' WHERE c.course_code='CSE4326';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE3411' WHERE c.course_code='CSE3421';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE3412' WHERE c.course_code='CSE3422';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MATH2205' WHERE c.course_code='CSE3811';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE2217' WHERE c.course_code='CSE3811';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MATH2205' WHERE c.course_code='CSE3812';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE2218' WHERE c.course_code='CSE3812';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE3411' WHERE c.course_code='PMG4101';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE2217' WHERE c.course_code='CSE3711';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE3811' WHERE c.course_code='CSE4889';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE3812' WHERE c.course_code='CSE4889';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MATH2183' WHERE c.course_code='CSE4889';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE2217' WHERE c.course_code='CSE4509';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE3313' WHERE c.course_code='CSE4509';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE2218' WHERE c.course_code='CSE4510';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE4000A' WHERE c.course_code='CSE4000B';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE3711' WHERE c.course_code='CSE4531';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE4509' WHERE c.course_code='CSE4531';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE4000A' WHERE c.course_code='CSE4000C';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='CSE4000B' WHERE c.course_code='CSE4000C';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MAT1101' WHERE c.course_code='MAT1103';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE1001' WHERE c.course_code='EEE1003';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE1001' WHERE c.course_code='EEE1004';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE1003' WHERE c.course_code='EEE2000';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE1003' WHERE c.course_code='EEE2101';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='PHY1101' WHERE c.course_code='PHY1103';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='PHY1101' WHERE c.course_code='PHY1104';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MAT1103' WHERE c.course_code='MAT2105';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2101' WHERE c.course_code='EEE2103';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2101' WHERE c.course_code='EEE2104';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MAT1103' WHERE c.course_code='MAT2107';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MAT1103' WHERE c.course_code='MAT2109';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE1003' WHERE c.course_code='EEE2301';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MAT2107' WHERE c.course_code='EEE2301';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE1003' WHERE c.course_code='EEE2200';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE1003' WHERE c.course_code='EEE2201';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2101' WHERE c.course_code='EEE2105';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2101' WHERE c.course_code='EEE2106';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2301' WHERE c.course_code='EEE3303';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MAT2107' WHERE c.course_code='EEE3107';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='PHY1103' WHERE c.course_code='EEE3107';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2201' WHERE c.course_code='EEE2203';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2201' WHERE c.course_code='EEE2204';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2301' WHERE c.course_code='EEE3309';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2301' WHERE c.course_code='EEE3310';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='PHY1103' WHERE c.course_code='EEE3305';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MAT2109' WHERE c.course_code='EEE3305';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2301' WHERE c.course_code='EEE3307';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE3303' WHERE c.course_code='EEE3307';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2301' WHERE c.course_code='EEE3308';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE3303' WHERE c.course_code='EEE3308';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='MAT2105' WHERE c.course_code='EEE3400';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2000' WHERE c.course_code='EEE3400';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2203' WHERE c.course_code='EEE3205';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2203' WHERE c.course_code='EEE3206';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2401' WHERE c.course_code='EEE3403';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2105' WHERE c.course_code='EEE3403';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2401' WHERE c.course_code='EEE3404';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2105' WHERE c.course_code='EEE3404';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2103' WHERE c.course_code='EEE3207';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2203' WHERE c.course_code='EEE3207';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2103' WHERE c.course_code='EEE3208';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2203' WHERE c.course_code='EEE3208';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2103' WHERE c.course_code='EEE4109';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2301' WHERE c.course_code='EEE4109';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2103' WHERE c.course_code='EEE4110';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE2301' WHERE c.course_code='EEE4110';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE4901' WHERE c.course_code='EEE4902';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='EEE4902' WHERE c.course_code='EEE4903';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='PHR3006' WHERE c.course_code='PHR4001';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='PHR3002' WHERE c.course_code='PHR4002';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='PHR3009' WHERE c.course_code='PHR4003';
INSERT IGNORE INTO course_prerequisites (course_id, prerequisite_course_id, min_grade_point) SELECT c.id,p.id,2.00 FROM courses c JOIN courses p ON p.course_code='PHR4002' WHERE c.course_code='PHR4007';

-- Sync existing demo users to academic programs where possible.
UPDATE users u JOIN programs p ON p.name = u.program SET u.program_id = p.id WHERE u.role='student' AND u.program_id IS NULL;
UPDATE users u JOIN curriculum_versions cv JOIN programs p ON p.id = cv.program_id AND p.id = u.program_id SET u.curriculum_version_id = cv.id WHERE u.role='student' AND u.curriculum_version_id IS NULL AND cv.status='active';

-- Ensure common trimesters exist for testing new sections.
INSERT IGNORE INTO trimesters (name,start_date,end_date,status) VALUES
('Summer 2025','2025-06-01','2025-09-30','active'),
('Fall 2025','2025-10-01','2026-01-31','active'),
('Spring 2026','2026-02-01','2026-05-31','active');

-- <<< END database/007_academic_setup.sql


-- >>> BEGIN database/009_attendance_component_hotfix.sql
-- 009_attendance_component_hotfix.sql
-- Optional safety migration: add missing Attendance component to existing course sections.
-- Useful for old sections that already had CT/Mid/Final components but missed Attendance.

INSERT IGNORE INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group, created_by)
SELECT cs.id, 'attendance', 'Attendance', 'attendance', 10, 10, 10, 6, 0, NULL, cs.teacher_id
FROM course_sections cs;

-- <<< END database/009_attendance_component_hotfix.sql


-- >>> BEGIN database/010_profile_photo.sql
-- database/010_profile_photo.sql
-- Optional safety migration for teacher/student profile photo upload.
USE urams_db;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS profile_photo VARCHAR(255) NULL AFTER status;

-- <<< END database/010_profile_photo.sql

-- ============================================================
-- FINAL DEMO DATASET FOR VIVA / FINAL UPDATE
-- Password for every demo account: password123
-- Purpose:
-- 1) Teacher can edit a RUNNING section.
-- 2) Teacher/Admin can submit and approve a SUBMITTED section.
-- 3) Student and Parent can view APPROVED results/history/charts.
-- 4) Audit Log already has sample mark-change entries and live changes create more.
-- ============================================================
USE urams_db;
SET FOREIGN_KEY_CHECKS = 0;

SET @pwd = '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e';

-- Core accounts
INSERT INTO users (full_name, email, identifier, role, password_hash, program, department, status)
VALUES
('System Administrator', 'admin@uiu.ac.bd', 'admin001', 'admin', @pwd, NULL, NULL, 'active'),
('Md. Rafiqul Islam', 'mri@uiu.ac.bd', 'MRI', 'teacher', @pwd, NULL, 'CSE', 'active'),
('Sayem Shahad', 'sayem.cse@uiu.ac.bd', 'SASH', 'teacher', @pwd, NULL, 'CSE', 'active'),
('Nahid', 'nahid@uiu.ac.bd', '0112320269', 'student', @pwd, 'BSc CSE', 'CSE', 'active'),
('Fatema Khatun', 'fatema@uiu.ac.bd', '0242220005', 'student', @pwd, 'BSc CSE', 'CSE', 'active'),
('Md. Rahim Uddin', 'rahim@uiu.ac.bd', '0242220012', 'student', @pwd, 'BSc CSE', 'CSE', 'active'),
('Nasrin Begum', 'nasrin@uiu.ac.bd', '0242220018', 'student', @pwd, 'BSc CSE', 'CSE', 'active'),
('Mr. Nahid Guardian', 'parent.nahid@uiu.ac.bd', 'PARENT0112320269', 'parent', @pwd, NULL, NULL, 'active'),
('Mr. M. Khatun', 'parent@uiu.ac.bd', 'PARENT0242220005', 'parent', @pwd, NULL, NULL, 'active')
ON DUPLICATE KEY UPDATE
  full_name = VALUES(full_name),
  role = VALUES(role),
  password_hash = VALUES(password_hash),
  program = VALUES(program),
  department = VALUES(department),
  status = 'active';

-- Demo trimesters
INSERT INTO trimesters (name, start_date, end_date, status) VALUES
('Spring 2025', '2025-01-01', '2025-04-30', 'closed'),
('Summer 2025', '2025-06-01', '2025-09-30', 'closed'),
('Spring 2026', '2026-01-01', '2026-04-30', 'active')
ON DUPLICATE KEY UPDATE start_date=VALUES(start_date), end_date=VALUES(end_date), status=VALUES(status);

-- Demo courses
INSERT INTO courses (course_code, course_name, credit) VALUES
('CSE2217', 'Data Structure and Algorithms II', 3.0),
('CSE2218', 'Data Structure and Algorithms II Laboratory', 1.0),
('CSE4533', 'Object Oriented Programming', 3.0),
('CSE4165', 'Web Programming', 3.0),
('PHY2105', 'Physics', 3.0)
ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit);

-- Demo section map
DROP TEMPORARY TABLE IF EXISTS tmp_demo_sections;
CREATE TEMPORARY TABLE tmp_demo_sections (
  course_code VARCHAR(20) NOT NULL,
  trimester_name VARCHAR(50) NOT NULL,
  section_name VARCHAR(10) NOT NULL,
  teacher_identifier VARCHAR(50) NOT NULL,
  section_status ENUM('running','submitted','approved','rejected') NOT NULL,
  room VARCHAR(50) NULL,
  class_schedule VARCHAR(150) NULL,
  capacity INT UNSIGNED NOT NULL DEFAULT 45
);

INSERT INTO tmp_demo_sections VALUES
-- Approved sections for Student/Parent history and charts
('CSE2217','Spring 2025','T','MRI','approved','323 Permanent Campus','Sun 03:11PM-04:30PM; Wed 03:11PM-04:30PM',45),
('CSE4533','Summer 2025','A','MRI','approved','404 Permanent Campus','Sat 09:51AM-11:10AM; Tue 09:51AM-11:10AM',45),
-- Running section for Teacher live marks/attendance demo
('CSE2218','Spring 2026','F','MRI','running','424 Permanent Campus','Sat 02:00PM-04:30PM',45),
-- Submitted section for Admin approval demo
('CSE4165','Spring 2026','U','MRI','submitted','927 Permanent Campus','Wed 11:11AM-01:40PM',45),
-- Extra section for admin/academic setup demonstration
('PHY2105','Spring 2026','B','SASH','running','302 Permanent Campus','Mon 10:00AM-11:20AM',45);

INSERT INTO course_sections (course_id, trimester_id, teacher_id, section_name, status, capacity, room, class_schedule)
SELECT c.id, tr.id, u.id, ds.section_name, ds.section_status, ds.capacity, ds.room, ds.class_schedule
FROM tmp_demo_sections ds
JOIN courses c ON c.course_code = ds.course_code
JOIN trimesters tr ON tr.name = ds.trimester_name
JOIN users u ON u.identifier = ds.teacher_identifier AND u.role = 'teacher'
ON DUPLICATE KEY UPDATE
  teacher_id=VALUES(teacher_id),
  status=VALUES(status),
  capacity=VALUES(capacity),
  room=VALUES(room),
  class_schedule=VALUES(class_schedule);

-- Ensure default assessment components for every demo section
INSERT IGNORE INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group, created_by)
SELECT cs.id, 'ct1', 'CT1', 'ct', 30, 15, 15, 1, 1, 'ct', t.id
FROM tmp_demo_sections ds JOIN courses c ON c.course_code=ds.course_code JOIN trimesters tr ON tr.name=ds.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=ds.section_name JOIN users t ON t.identifier=ds.teacher_identifier;
INSERT IGNORE INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group, created_by)
SELECT cs.id, 'ct2', 'CT2', 'ct', 30, 15, 15, 2, 1, 'ct', t.id
FROM tmp_demo_sections ds JOIN courses c ON c.course_code=ds.course_code JOIN trimesters tr ON tr.name=ds.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=ds.section_name JOIN users t ON t.identifier=ds.teacher_identifier;
INSERT IGNORE INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group, created_by)
SELECT cs.id, 'assignment', 'Assignment', 'assignment', 10, 10, 10, 3, 0, NULL, t.id
FROM tmp_demo_sections ds JOIN courses c ON c.course_code=ds.course_code JOIN trimesters tr ON tr.name=ds.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=ds.section_name JOIN users t ON t.identifier=ds.teacher_identifier;
INSERT IGNORE INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group, created_by)
SELECT cs.id, 'mid', 'Mid Term', 'mid', 50, 25, 25, 4, 0, NULL, t.id
FROM tmp_demo_sections ds JOIN courses c ON c.course_code=ds.course_code JOIN trimesters tr ON tr.name=ds.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=ds.section_name JOIN users t ON t.identifier=ds.teacher_identifier;
INSERT IGNORE INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group, created_by)
SELECT cs.id, 'final', 'Final Exam', 'final', 80, 40, 40, 5, 0, NULL, t.id
FROM tmp_demo_sections ds JOIN courses c ON c.course_code=ds.course_code JOIN trimesters tr ON tr.name=ds.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=ds.section_name JOIN users t ON t.identifier=ds.teacher_identifier;
INSERT IGNORE INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group, created_by)
SELECT cs.id, 'attendance', 'Attendance', 'attendance', 10, 10, 10, 6, 0, NULL, t.id
FROM tmp_demo_sections ds JOIN courses c ON c.course_code=ds.course_code JOIN trimesters tr ON tr.name=ds.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=ds.section_name JOIN users t ON t.identifier=ds.teacher_identifier;

-- Demo result rows
DROP TEMPORARY TABLE IF EXISTS tmp_demo_marks;
CREATE TEMPORARY TABLE tmp_demo_marks (
  student_identifier VARCHAR(50) NOT NULL,
  parent_identifier VARCHAR(50) NULL,
  course_code VARCHAR(20) NOT NULL,
  trimester_name VARCHAR(50) NOT NULL,
  section_name VARCHAR(10) NOT NULL,
  ct1 DECIMAL(6,2) NOT NULL,
  ct2 DECIMAL(6,2) NOT NULL,
  assignment DECIMAL(6,2) NOT NULL,
  mid DECIMAL(6,2) NOT NULL,
  final_exam DECIMAL(6,2) NOT NULL,
  attendance DECIMAL(6,2) NOT NULL,
  result_status ENUM('draft','submitted','approved','rejected') NOT NULL
);

INSERT INTO tmp_demo_marks VALUES
-- Nahid approved history for Student + Parent analytics
('0112320269','PARENT0112320269','CSE2217','Spring 2025','T', 13.00, 14.00, 8.00, 21.00, 34.00, 9.00, 'approved'),
('0112320269','PARENT0112320269','CSE4533','Summer 2025','A', 14.50, 13.00, 8.50, 22.50, 36.00, 10.00, 'approved'),
-- Running section for Teacher live edit demo
('0112320269','PARENT0112320269','CSE2218','Spring 2026','F', 12.00, 11.50, 8.00, 20.00, 32.00, 10.00, 'draft'),
('0242220005','PARENT0242220005','CSE2218','Spring 2026','F', 14.50, 13.00, 8.50, 22.50, 36.00, 10.00, 'draft'),
('0242220012',NULL,'CSE2218','Spring 2026','F', 6.00, 8.50, 7.00, 15.00, 24.00, 6.00, 'draft'),
('0242220018',NULL,'CSE2218','Spring 2026','F', 12.00, 11.50, 8.00, 20.00, 32.00, 10.00, 'draft'),
-- Submitted section for Admin approval demonstration
('0242220005','PARENT0242220005','CSE4165','Spring 2026','U', 12.00, 13.00, 9.00, 20.00, 34.00, 9.00, 'submitted'),
('0242220012',NULL,'CSE4165','Spring 2026','U', 10.00, 11.00, 7.50, 18.00, 30.00, 8.00, 'submitted');

-- Enroll students
INSERT INTO enrollments (student_id, section_id, parent_user_id, status)
SELECT stu.id, cs.id, par.id, 'active'
FROM tmp_demo_marks dm
JOIN users stu ON stu.identifier = dm.student_identifier AND stu.role = 'student'
LEFT JOIN users par ON par.identifier = dm.parent_identifier AND par.role = 'parent'
JOIN courses c ON c.course_code = dm.course_code
JOIN trimesters tr ON tr.name = dm.trimester_name
JOIN course_sections cs ON cs.course_id = c.id AND cs.trimester_id = tr.id AND cs.section_name = dm.section_name
ON DUPLICATE KEY UPDATE parent_user_id = VALUES(parent_user_id), status = 'active';

-- Legacy result cache + result status
INSERT INTO results (enrollment_id, ct1, ct2, best_ct, assignment, mid, final, attendance_marks, total_marks, grade, grade_point, status, submitted_by, approved_by, submitted_at, approved_at)
SELECT e.id,
       dm.ct1,
       dm.ct2,
       GREATEST(dm.ct1, dm.ct2) AS best_ct,
       dm.assignment,
       dm.mid,
       dm.final_exam,
       dm.attendance,
       ROUND(GREATEST(dm.ct1, dm.ct2) + dm.assignment + dm.mid + dm.final_exam + dm.attendance, 2) AS total_marks,
       gr.grade,
       gr.grade_point,
       dm.result_status,
       CASE WHEN dm.result_status IN ('submitted','approved') THEN teacher.id ELSE NULL END,
       CASE WHEN dm.result_status = 'approved' THEN admin.id ELSE NULL END,
       CASE WHEN dm.result_status IN ('submitted','approved') THEN NOW() ELSE NULL END,
       CASE WHEN dm.result_status = 'approved' THEN NOW() ELSE NULL END
FROM tmp_demo_marks dm
JOIN users stu ON stu.identifier = dm.student_identifier AND stu.role = 'student'
JOIN courses c ON c.course_code = dm.course_code
JOIN trimesters tr ON tr.name = dm.trimester_name
JOIN course_sections cs ON cs.course_id = c.id AND cs.trimester_id = tr.id AND cs.section_name = dm.section_name
JOIN enrollments e ON e.student_id = stu.id AND e.section_id = cs.id
JOIN users teacher ON teacher.id = cs.teacher_id
JOIN users admin ON admin.identifier = 'admin001' AND admin.role = 'admin'
JOIN grade_rules gr ON ROUND(GREATEST(dm.ct1, dm.ct2) + dm.assignment + dm.mid + dm.final_exam + dm.attendance, 2) BETWEEN gr.min_mark AND gr.max_mark AND gr.is_active = 1
ON DUPLICATE KEY UPDATE
  ct1=VALUES(ct1), ct2=VALUES(ct2), best_ct=VALUES(best_ct), assignment=VALUES(assignment), mid=VALUES(mid), final=VALUES(final), attendance_marks=VALUES(attendance_marks),
  total_marks=VALUES(total_marks), grade=VALUES(grade), grade_point=VALUES(grade_point), status=VALUES(status), submitted_by=VALUES(submitted_by), approved_by=VALUES(approved_by), submitted_at=VALUES(submitted_at), approved_at=VALUES(approved_at);

-- Normalized component marks
INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, is_absent, updated_by)
SELECT e.id, ac.id, ROUND((dm.ct1 / ac.convert_to) * ac.taken_out_of, 2), dm.ct1, 0, cs.teacher_id
FROM tmp_demo_marks dm
JOIN users stu ON stu.identifier=dm.student_identifier AND stu.role='student'
JOIN courses c ON c.course_code=dm.course_code JOIN trimesters tr ON tr.name=dm.trimester_name
JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=dm.section_name
JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id
JOIN assessment_components ac ON ac.section_id=cs.id AND ac.component_key='ct1'
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks), converted_marks=VALUES(converted_marks), is_absent=0, updated_by=VALUES(updated_by);
INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, is_absent, updated_by)
SELECT e.id, ac.id, ROUND((dm.ct2 / ac.convert_to) * ac.taken_out_of, 2), dm.ct2, 0, cs.teacher_id
FROM tmp_demo_marks dm
JOIN users stu ON stu.identifier=dm.student_identifier AND stu.role='student'
JOIN courses c ON c.course_code=dm.course_code JOIN trimesters tr ON tr.name=dm.trimester_name
JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=dm.section_name
JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id
JOIN assessment_components ac ON ac.section_id=cs.id AND ac.component_key='ct2'
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks), converted_marks=VALUES(converted_marks), is_absent=0, updated_by=VALUES(updated_by);
INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, is_absent, updated_by)
SELECT e.id, ac.id, dm.assignment, dm.assignment, 0, cs.teacher_id
FROM tmp_demo_marks dm
JOIN users stu ON stu.identifier=dm.student_identifier AND stu.role='student'
JOIN courses c ON c.course_code=dm.course_code JOIN trimesters tr ON tr.name=dm.trimester_name
JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=dm.section_name
JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id
JOIN assessment_components ac ON ac.section_id=cs.id AND ac.component_key='assignment'
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks), converted_marks=VALUES(converted_marks), is_absent=0, updated_by=VALUES(updated_by);
INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, is_absent, updated_by)
SELECT e.id, ac.id, ROUND((dm.mid / ac.convert_to) * ac.taken_out_of, 2), dm.mid, 0, cs.teacher_id
FROM tmp_demo_marks dm
JOIN users stu ON stu.identifier=dm.student_identifier AND stu.role='student'
JOIN courses c ON c.course_code=dm.course_code JOIN trimesters tr ON tr.name=dm.trimester_name
JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=dm.section_name
JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id
JOIN assessment_components ac ON ac.section_id=cs.id AND ac.component_key='mid'
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks), converted_marks=VALUES(converted_marks), is_absent=0, updated_by=VALUES(updated_by);
INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, is_absent, updated_by)
SELECT e.id, ac.id, ROUND((dm.final_exam / ac.convert_to) * ac.taken_out_of, 2), dm.final_exam, 0, cs.teacher_id
FROM tmp_demo_marks dm
JOIN users stu ON stu.identifier=dm.student_identifier AND stu.role='student'
JOIN courses c ON c.course_code=dm.course_code JOIN trimesters tr ON tr.name=dm.trimester_name
JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=dm.section_name
JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id
JOIN assessment_components ac ON ac.section_id=cs.id AND ac.component_key='final'
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks), converted_marks=VALUES(converted_marks), is_absent=0, updated_by=VALUES(updated_by);
INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, is_absent, updated_by)
SELECT e.id, ac.id, dm.attendance, dm.attendance, 0, cs.teacher_id
FROM tmp_demo_marks dm
JOIN users stu ON stu.identifier=dm.student_identifier AND stu.role='student'
JOIN courses c ON c.course_code=dm.course_code JOIN trimesters tr ON tr.name=dm.trimester_name
JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=dm.section_name
JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id
JOIN assessment_components ac ON ac.section_id=cs.id AND ac.component_key='attendance'
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks), converted_marks=VALUES(converted_marks), is_absent=0, updated_by=VALUES(updated_by);

-- Normalized result summary synced from result cache
INSERT INTO student_section_results (enrollment_id, total_marks, grade, grade_point, calculated_at, locked_at)
SELECT r.enrollment_id, r.total_marks, r.grade, r.grade_point, NOW(), CASE WHEN r.status='approved' THEN NOW() ELSE NULL END
FROM results r
ON DUPLICATE KEY UPDATE total_marks=VALUES(total_marks), grade=VALUES(grade), grade_point=VALUES(grade_point), calculated_at=NOW(), locked_at=VALUES(locked_at);

-- Workflow status: draft/running, submitted, approved
INSERT INTO result_submissions (section_id, status, submitted_by, approved_by, submitted_at, approved_at)
SELECT cs.id,
       CASE WHEN ds.section_status = 'running' THEN 'draft' ELSE ds.section_status END,
       CASE WHEN ds.section_status IN ('submitted','approved') THEN teacher.id ELSE NULL END,
       CASE WHEN ds.section_status = 'approved' THEN admin.id ELSE NULL END,
       CASE WHEN ds.section_status IN ('submitted','approved') THEN NOW() ELSE NULL END,
       CASE WHEN ds.section_status = 'approved' THEN NOW() ELSE NULL END
FROM tmp_demo_sections ds
JOIN courses c ON c.course_code=ds.course_code
JOIN trimesters tr ON tr.name=ds.trimester_name
JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=ds.section_name
JOIN users teacher ON teacher.id=cs.teacher_id
JOIN users admin ON admin.identifier='admin001' AND admin.role='admin'
ON DUPLICATE KEY UPDATE status=VALUES(status), submitted_by=VALUES(submitted_by), approved_by=VALUES(approved_by), submitted_at=VALUES(submitted_at), approved_at=VALUES(approved_at), updated_at=CURRENT_TIMESTAMP;

-- Result cache statuses must match section workflow
UPDATE results r
JOIN enrollments e ON e.id = r.enrollment_id
JOIN result_submissions rs ON rs.section_id = e.section_id
SET r.status = CASE WHEN rs.status IN ('submitted','approved','rejected') THEN rs.status ELSE 'draft' END,
    r.submitted_by = rs.submitted_by,
    r.approved_by = rs.approved_by,
    r.submitted_at = rs.submitted_at,
    r.approved_at = rs.approved_at;

-- Audit log seed for demonstration
INSERT INTO audit_logs (user_id, action, table_name, record_id, old_value, new_value, ip_address, user_agent)
SELECT t.id, 'SAVE_COMPONENT_MARK', 'student_component_marks', scm.id,
       JSON_OBJECT('raw_marks', 26.00, 'converted_marks', 13.00),
       JSON_OBJECT('raw_marks', 29.00, 'converted_marks', 14.50, 'component_key', ac.component_key, 'student', stu.identifier),
       '127.0.0.1', 'Final demo seed'
FROM student_component_marks scm
JOIN assessment_components ac ON ac.id = scm.component_id AND ac.component_key = 'ct1'
JOIN enrollments e ON e.id = scm.enrollment_id
JOIN users stu ON stu.id = e.student_id AND stu.identifier = '0242220005'
JOIN course_sections cs ON cs.id = e.section_id
JOIN courses c ON c.id = cs.course_id AND c.course_code = 'CSE2218'
JOIN users t ON t.id = cs.teacher_id
LIMIT 1;

INSERT INTO audit_logs (user_id, action, table_name, record_id, old_value, new_value, ip_address, user_agent)
SELECT a.id, 'APPROVE_RESULT', 'result_submissions', rs.section_id,
       JSON_OBJECT('status','submitted'),
       JSON_OBJECT('status','approved'),
       '127.0.0.1', 'Final demo seed'
FROM result_submissions rs
JOIN course_sections cs ON cs.id = rs.section_id
JOIN courses c ON c.id = cs.course_id AND c.course_code = 'CSE4533'
JOIN users a ON a.identifier = 'admin001'
LIMIT 1;

SET FOREIGN_KEY_CHECKS = 1;


-- Demo profile photo so Sir can immediately see the upload/photo feature.
UPDATE users
SET profile_photo = 'uploads/profile_photos/demo_teacher_mri.png'
WHERE identifier = 'MRI';
