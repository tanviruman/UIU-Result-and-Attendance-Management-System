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

-- ============================================================
-- LARGE DEMO DATA INCLUDED BELOW: 150 STUDENTS + 25 TEACHERS
-- ============================================================
-- 012_large_university_demo_data_150_students_25_teachers.sql
-- Import AFTER database/000_IMPORT_THIS_FULL_FINAL_DEMO.sql
-- Adds a large demo dataset for final presentation:
-- 150 students, 150 parents, 25 teachers, 26 active/historical sections, multiple enrollments, marks, attendance, result history, and audit-log samples.

USE urams_db;
SET FOREIGN_KEY_CHECKS = 0;
SET @pwd = '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e';


-- More trimesters for dashboard/history visuals
INSERT INTO trimesters (name,start_date,end_date,status) VALUES
('Spring 2025', '2025-01-01', '2025-04-30', 'closed'),
('Summer 2025', '2025-06-01', '2025-09-30', 'closed'),
('Fall 2025', '2025-10-01', '2026-01-31', 'closed'),
('Spring 2026', '2026-02-01', '2026-05-31', 'active')
ON DUPLICATE KEY UPDATE start_date=VALUES(start_date), end_date=VALUES(end_date), status=VALUES(status);


-- 25 demo teachers
INSERT INTO users (full_name,email,identifier,role,password_hash,program,department,status) VALUES
('Mr. Sakib Akter', 't001@uiu.ac.bd', 'T001', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'CSE', 'active'),
('Ms. Farhana Kabir', 't002@uiu.ac.bd', 'T002', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'CSE', 'active'),
('Dr. Rakib Tasnim', 't003@uiu.ac.bd', 'T003', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'CSE', 'active'),
('Ms. Mim Molla', 't004@uiu.ac.bd', 'T004', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'CSE', 'active'),
('Mr. Fahim Ahmed', 't005@uiu.ac.bd', 'T005', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'CSE', 'active'),
('Dr. Jannatul Amin', 't006@uiu.ac.bd', 'T006', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'CSE', 'active'),
('Mr. Rafi Uddin', 't007@uiu.ac.bd', 'T007', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'CSE', 'active'),
('Ms. Mahi Khan', 't008@uiu.ac.bd', 'T008', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'CSE', 'active'),
('Dr. Hasan Bari', 't009@uiu.ac.bd', 'T009', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'CSE', 'active'),
('Ms. Ayesha Uddin', 't010@uiu.ac.bd', 'T010', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'CSE', 'active'),
('Mr. Nafis Akter', 't011@uiu.ac.bd', 'T011', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'EEE', 'active'),
('Dr. Sumaiya Ferdous', 't012@uiu.ac.bd', 'T012', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'EEE', 'active'),
('Mr. Sabbir Tasnim', 't013@uiu.ac.bd', 'T013', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'EEE', 'active'),
('Ms. Lamisa Bashar', 't014@uiu.ac.bd', 'T014', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'EEE', 'active'),
('Dr. Minhaz Ahmed', 't015@uiu.ac.bd', 'T015', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'EEE', 'active'),
('Ms. Nafisa Hossain', 't016@uiu.ac.bd', 'T016', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'Business', 'active'),
('Mr. Aminul Uddin', 't017@uiu.ac.bd', 'T017', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'Business', 'active'),
('Dr. Mousumi Chowdhury', 't018@uiu.ac.bd', 'T018', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'Business', 'active'),
('Mr. Mahmud Bari', 't019@uiu.ac.bd', 'T019', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'Business', 'active'),
('Ms. Ritu Tasnim', 't020@uiu.ac.bd', 'T020', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'Business', 'active'),
('Dr. Abrar Akter', 't021@uiu.ac.bd', 'T021', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'Pharmacy', 'active'),
('Ms. Zarin Jahan', 't022@uiu.ac.bd', 'T022', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'Pharmacy', 'active'),
('Mr. Imran Tasnim', 't023@uiu.ac.bd', 'T023', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'Pharmacy', 'active'),
('Dr. Sanjida Rahman', 't024@uiu.ac.bd', 'T024', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'Pharmacy', 'active'),
('Mr. Tahmid Ahmed', 't025@uiu.ac.bd', 'T025', 'teacher', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, 'Pharmacy', 'active')
ON DUPLICATE KEY UPDATE full_name=VALUES(full_name), role='teacher', password_hash=VALUES(password_hash), department=VALUES(department), status='active';


-- 150 demo students
INSERT INTO users (full_name,email,identifier,role,password_hash,program,department,status) VALUES
('Sakib Akter', '0242510001@student.uiu.ac.bd', '0242510001', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Farhana Sultana', '0242510002@student.uiu.ac.bd', '0242510002', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Rakib Tasnim', '0242510003@student.uiu.ac.bd', '0242510003', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mim Alam', '0242510004@student.uiu.ac.bd', '0242510004', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Fahim Ahmed', '0242510005@student.uiu.ac.bd', '0242510005', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Jannatul Talukder', '0242510006@student.uiu.ac.bd', '0242510006', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Rafi Uddin', '0242510007@student.uiu.ac.bd', '0242510007', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mahi Haque', '0242510008@student.uiu.ac.bd', '0242510008', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Hasan Bari', '0242510009@student.uiu.ac.bd', '0242510009', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Ayesha Akter', '0242510010@student.uiu.ac.bd', '0242510010', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Nafis Akter', '0242510011@student.uiu.ac.bd', '0242510011', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Sumaiya Kabir', '0242510012@student.uiu.ac.bd', '0242510012', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Sabbir Tasnim', '0242510013@student.uiu.ac.bd', '0242510013', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Lamisa Molla', '0242510014@student.uiu.ac.bd', '0242510014', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Minhaz Ahmed', '0242510015@student.uiu.ac.bd', '0242510015', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Nafisa Amin', '0242510016@student.uiu.ac.bd', '0242510016', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Aminul Uddin', '0242510017@student.uiu.ac.bd', '0242510017', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mousumi Khan', '0242510018@student.uiu.ac.bd', '0242510018', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mahmud Bari', '0242510019@student.uiu.ac.bd', '0242510019', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Ritu Uddin', '0242510020@student.uiu.ac.bd', '0242510020', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Abrar Akter', '0242510021@student.uiu.ac.bd', '0242510021', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Zarin Ferdous', '0242510022@student.uiu.ac.bd', '0242510022', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Imran Tasnim', '0242510023@student.uiu.ac.bd', '0242510023', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Sanjida Bashar', '0242510024@student.uiu.ac.bd', '0242510024', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Tahmid Ahmed', '0242510025@student.uiu.ac.bd', '0242510025', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Keya Hossain', '0242510026@student.uiu.ac.bd', '0242510026', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Shahadat Uddin', '0242510027@student.uiu.ac.bd', '0242510027', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mehrin Chowdhury', '0242510028@student.uiu.ac.bd', '0242510028', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Nabil Bari', '0242510029@student.uiu.ac.bd', '0242510029', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Nusrat Tasnim', '0242510030@student.uiu.ac.bd', '0242510030', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Sakib Akter', '0242510031@student.uiu.ac.bd', '0242510031', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Farhana Jahan', '0242510032@student.uiu.ac.bd', '0242510032', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Rakib Tasnim', '0242510033@student.uiu.ac.bd', '0242510033', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mim Rahman', '0242510034@student.uiu.ac.bd', '0242510034', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Fahim Ahmed', '0242510035@student.uiu.ac.bd', '0242510035', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Jannatul Hasan', '0242510036@student.uiu.ac.bd', '0242510036', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Rafi Uddin', '0242510037@student.uiu.ac.bd', '0242510037', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mahi Mahmud', '0242510038@student.uiu.ac.bd', '0242510038', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Hasan Bari', '0242510039@student.uiu.ac.bd', '0242510039', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Ayesha Bari', '0242510040@student.uiu.ac.bd', '0242510040', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Nafis Akter', '0242510041@student.uiu.ac.bd', '0242510041', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Sumaiya Islam', '0242510042@student.uiu.ac.bd', '0242510042', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Sabbir Tasnim', '0242510043@student.uiu.ac.bd', '0242510043', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Lamisa Mia', '0242510044@student.uiu.ac.bd', '0242510044', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Minhaz Ahmed', '0242510045@student.uiu.ac.bd', '0242510045', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Nafisa Karim', '0242510046@student.uiu.ac.bd', '0242510046', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Aminul Uddin', '0242510047@student.uiu.ac.bd', '0242510047', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mousumi Sarker', '0242510048@student.uiu.ac.bd', '0242510048', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mahmud Bari', '0242510049@student.uiu.ac.bd', '0242510049', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Ritu Ahmed', '0242510050@student.uiu.ac.bd', '0242510050', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Abrar Akter', '0242510051@student.uiu.ac.bd', '0242510051', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Zarin Sultana', '0242510052@student.uiu.ac.bd', '0242510052', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Imran Tasnim', '0242510053@student.uiu.ac.bd', '0242510053', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Sanjida Alam', '0242510054@student.uiu.ac.bd', '0242510054', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Tahmid Ahmed', '0242510055@student.uiu.ac.bd', '0242510055', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Keya Talukder', '0242510056@student.uiu.ac.bd', '0242510056', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Shahadat Uddin', '0242510057@student.uiu.ac.bd', '0242510057', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mehrin Haque', '0242510058@student.uiu.ac.bd', '0242510058', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Nabil Bari', '0242510059@student.uiu.ac.bd', '0242510059', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Nusrat Akter', '0242510060@student.uiu.ac.bd', '0242510060', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Sakib Akter', '0242510061@student.uiu.ac.bd', '0242510061', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Farhana Kabir', '0242510062@student.uiu.ac.bd', '0242510062', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Rakib Tasnim', '0242510063@student.uiu.ac.bd', '0242510063', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mim Molla', '0242510064@student.uiu.ac.bd', '0242510064', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Fahim Ahmed', '0242510065@student.uiu.ac.bd', '0242510065', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Jannatul Amin', '0242510066@student.uiu.ac.bd', '0242510066', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Rafi Uddin', '0242510067@student.uiu.ac.bd', '0242510067', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mahi Khan', '0242510068@student.uiu.ac.bd', '0242510068', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Hasan Bari', '0242510069@student.uiu.ac.bd', '0242510069', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Ayesha Uddin', '0242510070@student.uiu.ac.bd', '0242510070', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Nafis Akter', '0242510071@student.uiu.ac.bd', '0242510071', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Sumaiya Ferdous', '0242510072@student.uiu.ac.bd', '0242510072', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Sabbir Tasnim', '0242510073@student.uiu.ac.bd', '0242510073', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Lamisa Bashar', '0242510074@student.uiu.ac.bd', '0242510074', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Minhaz Ahmed', '0242510075@student.uiu.ac.bd', '0242510075', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Nafisa Hossain', '0242510076@student.uiu.ac.bd', '0242510076', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Aminul Uddin', '0242510077@student.uiu.ac.bd', '0242510077', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mousumi Chowdhury', '0242510078@student.uiu.ac.bd', '0242510078', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Mahmud Bari', '0242510079@student.uiu.ac.bd', '0242510079', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Ritu Tasnim', '0242510080@student.uiu.ac.bd', '0242510080', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc CSE', 'CSE', 'active'),
('Abrar Akter', '0242520001@student.uiu.ac.bd', '0242520001', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Zarin Jahan', '0242520002@student.uiu.ac.bd', '0242520002', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Imran Tasnim', '0242520003@student.uiu.ac.bd', '0242520003', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Sanjida Rahman', '0242520004@student.uiu.ac.bd', '0242520004', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Tahmid Ahmed', '0242520005@student.uiu.ac.bd', '0242520005', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Keya Hasan', '0242520006@student.uiu.ac.bd', '0242520006', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Shahadat Uddin', '0242520007@student.uiu.ac.bd', '0242520007', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Mehrin Mahmud', '0242520008@student.uiu.ac.bd', '0242520008', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Nabil Bari', '0242520009@student.uiu.ac.bd', '0242520009', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Nusrat Bari', '0242520010@student.uiu.ac.bd', '0242520010', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Sakib Akter', '0242520011@student.uiu.ac.bd', '0242520011', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Farhana Islam', '0242520012@student.uiu.ac.bd', '0242520012', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Rakib Tasnim', '0242520013@student.uiu.ac.bd', '0242520013', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Mim Mia', '0242520014@student.uiu.ac.bd', '0242520014', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Fahim Ahmed', '0242520015@student.uiu.ac.bd', '0242520015', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Jannatul Karim', '0242520016@student.uiu.ac.bd', '0242520016', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Rafi Uddin', '0242520017@student.uiu.ac.bd', '0242520017', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Mahi Sarker', '0242520018@student.uiu.ac.bd', '0242520018', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Hasan Bari', '0242520019@student.uiu.ac.bd', '0242520019', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Ayesha Ahmed', '0242520020@student.uiu.ac.bd', '0242520020', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Nafis Akter', '0242520021@student.uiu.ac.bd', '0242520021', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Sumaiya Sultana', '0242520022@student.uiu.ac.bd', '0242520022', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Sabbir Tasnim', '0242520023@student.uiu.ac.bd', '0242520023', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Lamisa Alam', '0242520024@student.uiu.ac.bd', '0242520024', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Minhaz Ahmed', '0242520025@student.uiu.ac.bd', '0242520025', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Nafisa Talukder', '0242520026@student.uiu.ac.bd', '0242520026', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Aminul Uddin', '0242520027@student.uiu.ac.bd', '0242520027', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Mousumi Haque', '0242520028@student.uiu.ac.bd', '0242520028', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Mahmud Bari', '0242520029@student.uiu.ac.bd', '0242520029', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Ritu Akter', '0242520030@student.uiu.ac.bd', '0242520030', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BSc EEE', 'EEE', 'active'),
('Abrar Akter', '0242530001@student.uiu.ac.bd', '0242530001', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Zarin Kabir', '0242530002@student.uiu.ac.bd', '0242530002', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Imran Tasnim', '0242530003@student.uiu.ac.bd', '0242530003', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Sanjida Molla', '0242530004@student.uiu.ac.bd', '0242530004', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Tahmid Ahmed', '0242530005@student.uiu.ac.bd', '0242530005', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Keya Amin', '0242530006@student.uiu.ac.bd', '0242530006', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Shahadat Uddin', '0242530007@student.uiu.ac.bd', '0242530007', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Mehrin Khan', '0242530008@student.uiu.ac.bd', '0242530008', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Nabil Bari', '0242530009@student.uiu.ac.bd', '0242530009', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Nusrat Uddin', '0242530010@student.uiu.ac.bd', '0242530010', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Sakib Akter', '0242530011@student.uiu.ac.bd', '0242530011', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Farhana Ferdous', '0242530012@student.uiu.ac.bd', '0242530012', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Rakib Tasnim', '0242530013@student.uiu.ac.bd', '0242530013', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Mim Bashar', '0242530014@student.uiu.ac.bd', '0242530014', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Fahim Ahmed', '0242530015@student.uiu.ac.bd', '0242530015', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Jannatul Hossain', '0242530016@student.uiu.ac.bd', '0242530016', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Rafi Uddin', '0242530017@student.uiu.ac.bd', '0242530017', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Mahi Chowdhury', '0242530018@student.uiu.ac.bd', '0242530018', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Hasan Bari', '0242530019@student.uiu.ac.bd', '0242530019', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Ayesha Tasnim', '0242530020@student.uiu.ac.bd', '0242530020', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Nafis Akter', '0242530021@student.uiu.ac.bd', '0242530021', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Sumaiya Jahan', '0242530022@student.uiu.ac.bd', '0242530022', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Sabbir Tasnim', '0242530023@student.uiu.ac.bd', '0242530023', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Lamisa Rahman', '0242530024@student.uiu.ac.bd', '0242530024', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Minhaz Ahmed', '0242530025@student.uiu.ac.bd', '0242530025', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'BBA', 'Business', 'active'),
('Nafisa Hasan', '0242540001@student.uiu.ac.bd', '0242540001', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Aminul Uddin', '0242540002@student.uiu.ac.bd', '0242540002', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Mousumi Mahmud', '0242540003@student.uiu.ac.bd', '0242540003', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Mahmud Bari', '0242540004@student.uiu.ac.bd', '0242540004', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Ritu Bari', '0242540005@student.uiu.ac.bd', '0242540005', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Abrar Akter', '0242540006@student.uiu.ac.bd', '0242540006', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Zarin Islam', '0242540007@student.uiu.ac.bd', '0242540007', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Imran Tasnim', '0242540008@student.uiu.ac.bd', '0242540008', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Sanjida Mia', '0242540009@student.uiu.ac.bd', '0242540009', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Tahmid Ahmed', '0242540010@student.uiu.ac.bd', '0242540010', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Keya Karim', '0242540011@student.uiu.ac.bd', '0242540011', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Shahadat Uddin', '0242540012@student.uiu.ac.bd', '0242540012', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Mehrin Sarker', '0242540013@student.uiu.ac.bd', '0242540013', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Nabil Bari', '0242540014@student.uiu.ac.bd', '0242540014', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active'),
('Nusrat Ahmed', '0242540015@student.uiu.ac.bd', '0242540015', 'student', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', 'B.Pharm', 'Pharmacy', 'active')
ON DUPLICATE KEY UPDATE full_name=VALUES(full_name), role='student', password_hash=VALUES(password_hash), program=VALUES(program), department=VALUES(department), status='active';


-- 150 parent/guardian demo accounts
INSERT INTO users (full_name,email,identifier,role,password_hash,program,department,status) VALUES
('Guardian of Sakib Akter', 'parent.0242510001@guardian.uiu.local', 'PARENT0242510001', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Farhana Sultana', 'parent.0242510002@guardian.uiu.local', 'PARENT0242510002', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Rakib Tasnim', 'parent.0242510003@guardian.uiu.local', 'PARENT0242510003', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mim Alam', 'parent.0242510004@guardian.uiu.local', 'PARENT0242510004', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Fahim Ahmed', 'parent.0242510005@guardian.uiu.local', 'PARENT0242510005', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Jannatul Talukder', 'parent.0242510006@guardian.uiu.local', 'PARENT0242510006', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Rafi Uddin', 'parent.0242510007@guardian.uiu.local', 'PARENT0242510007', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mahi Haque', 'parent.0242510008@guardian.uiu.local', 'PARENT0242510008', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Hasan Bari', 'parent.0242510009@guardian.uiu.local', 'PARENT0242510009', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Ayesha Akter', 'parent.0242510010@guardian.uiu.local', 'PARENT0242510010', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nafis Akter', 'parent.0242510011@guardian.uiu.local', 'PARENT0242510011', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sumaiya Kabir', 'parent.0242510012@guardian.uiu.local', 'PARENT0242510012', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sabbir Tasnim', 'parent.0242510013@guardian.uiu.local', 'PARENT0242510013', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Lamisa Molla', 'parent.0242510014@guardian.uiu.local', 'PARENT0242510014', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Minhaz Ahmed', 'parent.0242510015@guardian.uiu.local', 'PARENT0242510015', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nafisa Amin', 'parent.0242510016@guardian.uiu.local', 'PARENT0242510016', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Aminul Uddin', 'parent.0242510017@guardian.uiu.local', 'PARENT0242510017', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mousumi Khan', 'parent.0242510018@guardian.uiu.local', 'PARENT0242510018', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mahmud Bari', 'parent.0242510019@guardian.uiu.local', 'PARENT0242510019', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Ritu Uddin', 'parent.0242510020@guardian.uiu.local', 'PARENT0242510020', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Abrar Akter', 'parent.0242510021@guardian.uiu.local', 'PARENT0242510021', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Zarin Ferdous', 'parent.0242510022@guardian.uiu.local', 'PARENT0242510022', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Imran Tasnim', 'parent.0242510023@guardian.uiu.local', 'PARENT0242510023', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sanjida Bashar', 'parent.0242510024@guardian.uiu.local', 'PARENT0242510024', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Tahmid Ahmed', 'parent.0242510025@guardian.uiu.local', 'PARENT0242510025', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Keya Hossain', 'parent.0242510026@guardian.uiu.local', 'PARENT0242510026', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Shahadat Uddin', 'parent.0242510027@guardian.uiu.local', 'PARENT0242510027', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mehrin Chowdhury', 'parent.0242510028@guardian.uiu.local', 'PARENT0242510028', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nabil Bari', 'parent.0242510029@guardian.uiu.local', 'PARENT0242510029', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nusrat Tasnim', 'parent.0242510030@guardian.uiu.local', 'PARENT0242510030', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sakib Akter', 'parent.0242510031@guardian.uiu.local', 'PARENT0242510031', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Farhana Jahan', 'parent.0242510032@guardian.uiu.local', 'PARENT0242510032', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Rakib Tasnim', 'parent.0242510033@guardian.uiu.local', 'PARENT0242510033', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mim Rahman', 'parent.0242510034@guardian.uiu.local', 'PARENT0242510034', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Fahim Ahmed', 'parent.0242510035@guardian.uiu.local', 'PARENT0242510035', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Jannatul Hasan', 'parent.0242510036@guardian.uiu.local', 'PARENT0242510036', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Rafi Uddin', 'parent.0242510037@guardian.uiu.local', 'PARENT0242510037', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mahi Mahmud', 'parent.0242510038@guardian.uiu.local', 'PARENT0242510038', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Hasan Bari', 'parent.0242510039@guardian.uiu.local', 'PARENT0242510039', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Ayesha Bari', 'parent.0242510040@guardian.uiu.local', 'PARENT0242510040', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nafis Akter', 'parent.0242510041@guardian.uiu.local', 'PARENT0242510041', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sumaiya Islam', 'parent.0242510042@guardian.uiu.local', 'PARENT0242510042', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sabbir Tasnim', 'parent.0242510043@guardian.uiu.local', 'PARENT0242510043', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Lamisa Mia', 'parent.0242510044@guardian.uiu.local', 'PARENT0242510044', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Minhaz Ahmed', 'parent.0242510045@guardian.uiu.local', 'PARENT0242510045', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nafisa Karim', 'parent.0242510046@guardian.uiu.local', 'PARENT0242510046', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Aminul Uddin', 'parent.0242510047@guardian.uiu.local', 'PARENT0242510047', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mousumi Sarker', 'parent.0242510048@guardian.uiu.local', 'PARENT0242510048', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mahmud Bari', 'parent.0242510049@guardian.uiu.local', 'PARENT0242510049', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Ritu Ahmed', 'parent.0242510050@guardian.uiu.local', 'PARENT0242510050', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Abrar Akter', 'parent.0242510051@guardian.uiu.local', 'PARENT0242510051', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Zarin Sultana', 'parent.0242510052@guardian.uiu.local', 'PARENT0242510052', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Imran Tasnim', 'parent.0242510053@guardian.uiu.local', 'PARENT0242510053', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sanjida Alam', 'parent.0242510054@guardian.uiu.local', 'PARENT0242510054', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Tahmid Ahmed', 'parent.0242510055@guardian.uiu.local', 'PARENT0242510055', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Keya Talukder', 'parent.0242510056@guardian.uiu.local', 'PARENT0242510056', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Shahadat Uddin', 'parent.0242510057@guardian.uiu.local', 'PARENT0242510057', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mehrin Haque', 'parent.0242510058@guardian.uiu.local', 'PARENT0242510058', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nabil Bari', 'parent.0242510059@guardian.uiu.local', 'PARENT0242510059', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nusrat Akter', 'parent.0242510060@guardian.uiu.local', 'PARENT0242510060', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sakib Akter', 'parent.0242510061@guardian.uiu.local', 'PARENT0242510061', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Farhana Kabir', 'parent.0242510062@guardian.uiu.local', 'PARENT0242510062', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Rakib Tasnim', 'parent.0242510063@guardian.uiu.local', 'PARENT0242510063', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mim Molla', 'parent.0242510064@guardian.uiu.local', 'PARENT0242510064', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Fahim Ahmed', 'parent.0242510065@guardian.uiu.local', 'PARENT0242510065', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Jannatul Amin', 'parent.0242510066@guardian.uiu.local', 'PARENT0242510066', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Rafi Uddin', 'parent.0242510067@guardian.uiu.local', 'PARENT0242510067', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mahi Khan', 'parent.0242510068@guardian.uiu.local', 'PARENT0242510068', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Hasan Bari', 'parent.0242510069@guardian.uiu.local', 'PARENT0242510069', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Ayesha Uddin', 'parent.0242510070@guardian.uiu.local', 'PARENT0242510070', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nafis Akter', 'parent.0242510071@guardian.uiu.local', 'PARENT0242510071', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sumaiya Ferdous', 'parent.0242510072@guardian.uiu.local', 'PARENT0242510072', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sabbir Tasnim', 'parent.0242510073@guardian.uiu.local', 'PARENT0242510073', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Lamisa Bashar', 'parent.0242510074@guardian.uiu.local', 'PARENT0242510074', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Minhaz Ahmed', 'parent.0242510075@guardian.uiu.local', 'PARENT0242510075', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nafisa Hossain', 'parent.0242510076@guardian.uiu.local', 'PARENT0242510076', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Aminul Uddin', 'parent.0242510077@guardian.uiu.local', 'PARENT0242510077', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mousumi Chowdhury', 'parent.0242510078@guardian.uiu.local', 'PARENT0242510078', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mahmud Bari', 'parent.0242510079@guardian.uiu.local', 'PARENT0242510079', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Ritu Tasnim', 'parent.0242510080@guardian.uiu.local', 'PARENT0242510080', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Abrar Akter', 'parent.0242520001@guardian.uiu.local', 'PARENT0242520001', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Zarin Jahan', 'parent.0242520002@guardian.uiu.local', 'PARENT0242520002', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Imran Tasnim', 'parent.0242520003@guardian.uiu.local', 'PARENT0242520003', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sanjida Rahman', 'parent.0242520004@guardian.uiu.local', 'PARENT0242520004', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Tahmid Ahmed', 'parent.0242520005@guardian.uiu.local', 'PARENT0242520005', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Keya Hasan', 'parent.0242520006@guardian.uiu.local', 'PARENT0242520006', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Shahadat Uddin', 'parent.0242520007@guardian.uiu.local', 'PARENT0242520007', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mehrin Mahmud', 'parent.0242520008@guardian.uiu.local', 'PARENT0242520008', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nabil Bari', 'parent.0242520009@guardian.uiu.local', 'PARENT0242520009', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nusrat Bari', 'parent.0242520010@guardian.uiu.local', 'PARENT0242520010', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sakib Akter', 'parent.0242520011@guardian.uiu.local', 'PARENT0242520011', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Farhana Islam', 'parent.0242520012@guardian.uiu.local', 'PARENT0242520012', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Rakib Tasnim', 'parent.0242520013@guardian.uiu.local', 'PARENT0242520013', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mim Mia', 'parent.0242520014@guardian.uiu.local', 'PARENT0242520014', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Fahim Ahmed', 'parent.0242520015@guardian.uiu.local', 'PARENT0242520015', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Jannatul Karim', 'parent.0242520016@guardian.uiu.local', 'PARENT0242520016', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Rafi Uddin', 'parent.0242520017@guardian.uiu.local', 'PARENT0242520017', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mahi Sarker', 'parent.0242520018@guardian.uiu.local', 'PARENT0242520018', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Hasan Bari', 'parent.0242520019@guardian.uiu.local', 'PARENT0242520019', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Ayesha Ahmed', 'parent.0242520020@guardian.uiu.local', 'PARENT0242520020', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nafis Akter', 'parent.0242520021@guardian.uiu.local', 'PARENT0242520021', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sumaiya Sultana', 'parent.0242520022@guardian.uiu.local', 'PARENT0242520022', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sabbir Tasnim', 'parent.0242520023@guardian.uiu.local', 'PARENT0242520023', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Lamisa Alam', 'parent.0242520024@guardian.uiu.local', 'PARENT0242520024', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Minhaz Ahmed', 'parent.0242520025@guardian.uiu.local', 'PARENT0242520025', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nafisa Talukder', 'parent.0242520026@guardian.uiu.local', 'PARENT0242520026', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Aminul Uddin', 'parent.0242520027@guardian.uiu.local', 'PARENT0242520027', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mousumi Haque', 'parent.0242520028@guardian.uiu.local', 'PARENT0242520028', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mahmud Bari', 'parent.0242520029@guardian.uiu.local', 'PARENT0242520029', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Ritu Akter', 'parent.0242520030@guardian.uiu.local', 'PARENT0242520030', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Abrar Akter', 'parent.0242530001@guardian.uiu.local', 'PARENT0242530001', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Zarin Kabir', 'parent.0242530002@guardian.uiu.local', 'PARENT0242530002', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Imran Tasnim', 'parent.0242530003@guardian.uiu.local', 'PARENT0242530003', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sanjida Molla', 'parent.0242530004@guardian.uiu.local', 'PARENT0242530004', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Tahmid Ahmed', 'parent.0242530005@guardian.uiu.local', 'PARENT0242530005', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Keya Amin', 'parent.0242530006@guardian.uiu.local', 'PARENT0242530006', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Shahadat Uddin', 'parent.0242530007@guardian.uiu.local', 'PARENT0242530007', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mehrin Khan', 'parent.0242530008@guardian.uiu.local', 'PARENT0242530008', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nabil Bari', 'parent.0242530009@guardian.uiu.local', 'PARENT0242530009', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nusrat Uddin', 'parent.0242530010@guardian.uiu.local', 'PARENT0242530010', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sakib Akter', 'parent.0242530011@guardian.uiu.local', 'PARENT0242530011', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Farhana Ferdous', 'parent.0242530012@guardian.uiu.local', 'PARENT0242530012', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Rakib Tasnim', 'parent.0242530013@guardian.uiu.local', 'PARENT0242530013', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mim Bashar', 'parent.0242530014@guardian.uiu.local', 'PARENT0242530014', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Fahim Ahmed', 'parent.0242530015@guardian.uiu.local', 'PARENT0242530015', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Jannatul Hossain', 'parent.0242530016@guardian.uiu.local', 'PARENT0242530016', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Rafi Uddin', 'parent.0242530017@guardian.uiu.local', 'PARENT0242530017', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mahi Chowdhury', 'parent.0242530018@guardian.uiu.local', 'PARENT0242530018', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Hasan Bari', 'parent.0242530019@guardian.uiu.local', 'PARENT0242530019', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Ayesha Tasnim', 'parent.0242530020@guardian.uiu.local', 'PARENT0242530020', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nafis Akter', 'parent.0242530021@guardian.uiu.local', 'PARENT0242530021', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sumaiya Jahan', 'parent.0242530022@guardian.uiu.local', 'PARENT0242530022', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sabbir Tasnim', 'parent.0242530023@guardian.uiu.local', 'PARENT0242530023', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Lamisa Rahman', 'parent.0242530024@guardian.uiu.local', 'PARENT0242530024', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Minhaz Ahmed', 'parent.0242530025@guardian.uiu.local', 'PARENT0242530025', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nafisa Hasan', 'parent.0242540001@guardian.uiu.local', 'PARENT0242540001', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Aminul Uddin', 'parent.0242540002@guardian.uiu.local', 'PARENT0242540002', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mousumi Mahmud', 'parent.0242540003@guardian.uiu.local', 'PARENT0242540003', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mahmud Bari', 'parent.0242540004@guardian.uiu.local', 'PARENT0242540004', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Ritu Bari', 'parent.0242540005@guardian.uiu.local', 'PARENT0242540005', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Abrar Akter', 'parent.0242540006@guardian.uiu.local', 'PARENT0242540006', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Zarin Islam', 'parent.0242540007@guardian.uiu.local', 'PARENT0242540007', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Imran Tasnim', 'parent.0242540008@guardian.uiu.local', 'PARENT0242540008', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Sanjida Mia', 'parent.0242540009@guardian.uiu.local', 'PARENT0242540009', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Tahmid Ahmed', 'parent.0242540010@guardian.uiu.local', 'PARENT0242540010', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Keya Karim', 'parent.0242540011@guardian.uiu.local', 'PARENT0242540011', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Shahadat Uddin', 'parent.0242540012@guardian.uiu.local', 'PARENT0242540012', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Mehrin Sarker', 'parent.0242540013@guardian.uiu.local', 'PARENT0242540013', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nabil Bari', 'parent.0242540014@guardian.uiu.local', 'PARENT0242540014', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active'),
('Guardian of Nusrat Ahmed', 'parent.0242540015@guardian.uiu.local', 'PARENT0242540015', 'parent', '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e', NULL, NULL, 'active')
ON DUPLICATE KEY UPDATE full_name=VALUES(full_name), role='parent', password_hash=VALUES(password_hash), status='active';


-- Sync demo students with academic setup tables if those tables exist
UPDATE users u JOIN programs p ON p.name = u.program SET u.program_id = p.id WHERE u.role='student' AND u.program_id IS NULL;
UPDATE users u
JOIN programs p ON p.id = u.program_id
JOIN curriculum_versions cv ON cv.program_id = p.id AND cv.status='active'
SET u.curriculum_version_id = cv.id
WHERE u.role='student' AND u.curriculum_version_id IS NULL;


-- Demo courses used by large sections
INSERT INTO courses (course_code,course_name,credit) VALUES
('CSE1111', 'Structured Programming Language', 3.0),
('MATH1151', 'Fundamental Calculus', 3.0),
('ENG1011', 'English I', 3.0),
('CSE2215', 'Data Structure and Algorithms I', 3.0),
('CSE2218', 'Data Structure and Algorithms II Laboratory', 1.0),
('CSE4533', 'Object Oriented Programming', 3.0),
('CSE3521', 'Database Management Systems', 3.0),
('CSE3313', 'Computer Architecture', 3.0),
('CSE4165', 'Web Programming', 3.0),
('CSE4509', 'Operating Systems', 3.0),
('CSE3711', 'Computer Networks', 3.0),
('CSE4889', 'Machine Learning', 3.0),
('EEE1001', 'Electrical Circuits I', 3.0),
('EEE1003', 'Electrical Circuits II', 3.0),
('EEE2101', 'Electronics I', 3.0),
('EEE3307', 'Communication Theory', 3.0),
('EEE4109', 'Control System', 3.0),
('BUS1102', 'Introduction to Business', 3.0),
('ACN1205', 'Financial Accounting I', 3.0),
('MKT2320', 'Introduction to Marketing', 3.0),
('FIN2319', 'Principles of Finance', 3.0),
('MGT3122', 'Human Resource Management', 3.0),
('PHR1001', 'Introduction to Pharmacy', 2.0),
('PHR1005L', 'Pharmacognosy & Natural Product Chemistry-I Laboratory', 1.0),
('PHR2005', 'Basic Pharmaceutics', 3.0),
('PHR3002', 'Pharmacology-I', 3.0)
ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit);


DROP TEMPORARY TABLE IF EXISTS tmp_large_sections;
CREATE TEMPORARY TABLE tmp_large_sections (
  course_code VARCHAR(20) NOT NULL,
  trimester_name VARCHAR(50) NOT NULL,
  section_name VARCHAR(10) NOT NULL,
  teacher_identifier VARCHAR(50) NOT NULL,
  section_status VARCHAR(20) NOT NULL,
  room VARCHAR(80) NULL,
  class_schedule VARCHAR(180) NULL,
  capacity INT UNSIGNED NOT NULL DEFAULT 50
);

INSERT INTO tmp_large_sections VALUES
('CSE1111', 'Spring 2025', 'A', 'T001', 'approved', '501 Permanent Campus', 'Sun 08:30AM-09:50AM; Tue 08:30AM-09:50AM', 60),
('MATH1151', 'Spring 2025', 'B', 'T002', 'approved', '302 Permanent Campus', 'Mon 10:00AM-11:20AM; Wed 10:00AM-11:20AM', 60),
('ENG1011', 'Spring 2025', 'C', 'T003', 'approved', '210 Permanent Campus', 'Sat 11:30AM-12:50PM; Mon 11:30AM-12:50PM', 60),
('CSE2215', 'Summer 2025', 'A', 'MRI', 'approved', '323 Permanent Campus', 'Sun 03:11PM-04:30PM; Wed 03:11PM-04:30PM', 70),
('CSE4533', 'Summer 2025', 'A', 'MRI', 'approved', '404 Permanent Campus', 'Sat 09:51AM-11:10AM; Tue 09:51AM-11:10AM', 70),
('CSE3521', 'Fall 2025', 'A', 'T004', 'approved', '602 Permanent Campus', 'Sun 02:00PM-03:20PM; Tue 02:00PM-03:20PM', 60),
('CSE3313', 'Fall 2025', 'B', 'T005', 'approved', '711 Permanent Campus', 'Mon 01:00PM-02:20PM; Wed 01:00PM-02:20PM', 60),
('CSE4165', 'Fall 2025', 'C', 'MRI', 'approved', '927 Permanent Campus', 'Sat 11:11AM-12:30PM; Mon 11:11AM-12:30PM', 60),
('CSE2218', 'Spring 2026', 'F', 'MRI', 'running', '424 Permanent Campus', 'Sat 02:00PM-04:30PM', 80),
('CSE4509', 'Spring 2026', 'A', 'T006', 'running', '710 Permanent Campus', 'Sun 11:30AM-12:50PM; Tue 11:30AM-12:50PM', 60),
('CSE3711', 'Spring 2026', 'B', 'T007', 'submitted', '815 Permanent Campus', 'Mon 08:30AM-09:50AM; Wed 08:30AM-09:50AM', 60),
('CSE4889', 'Spring 2026', 'C', 'T008', 'running', '903 Permanent Campus', 'Sat 12:31PM-01:50PM; Tue 12:31PM-01:50PM', 60),
('EEE1001', 'Spring 2025', 'A', 'T011', 'approved', '301 Permanent Campus', 'Sun 08:30AM-09:50AM; Tue 08:30AM-09:50AM', 50),
('EEE1003', 'Summer 2025', 'A', 'T012', 'approved', '305 Permanent Campus', 'Mon 10:00AM-11:20AM; Wed 10:00AM-11:20AM', 50),
('EEE2101', 'Fall 2025', 'B', 'T013', 'approved', '407 Permanent Campus', 'Sat 11:30AM-12:50PM; Mon 11:30AM-12:50PM', 50),
('EEE3307', 'Spring 2026', 'A', 'T014', 'running', '512 Permanent Campus', 'Sun 02:00PM-03:20PM; Tue 02:00PM-03:20PM', 50),
('EEE4109', 'Spring 2026', 'A', 'T015', 'submitted', '509 Permanent Campus', 'Wed 11:11AM-01:40PM', 50),
('BUS1102', 'Spring 2025', 'A', 'T016', 'approved', 'BBA-301', 'Sun 09:00AM-10:20AM; Tue 09:00AM-10:20AM', 50),
('ACN1205', 'Summer 2025', 'B', 'T017', 'approved', 'BBA-402', 'Mon 10:30AM-11:50AM; Wed 10:30AM-11:50AM', 50),
('MKT2320', 'Fall 2025', 'C', 'T018', 'approved', 'BBA-503', 'Sat 02:00PM-03:20PM; Mon 02:00PM-03:20PM', 50),
('FIN2319', 'Spring 2026', 'A', 'T019', 'running', 'BBA-207', 'Sun 12:30PM-01:50PM; Tue 12:30PM-01:50PM', 50),
('MGT3122', 'Spring 2026', 'B', 'T020', 'submitted', 'BBA-612', 'Wed 03:00PM-04:20PM', 50),
('PHR1001', 'Spring 2025', 'A', 'T021', 'approved', 'PHR-201', 'Sun 08:30AM-09:50AM; Tue 08:30AM-09:50AM', 40),
('PHR2005', 'Summer 2025', 'A', 'T022', 'approved', 'PHR-304', 'Mon 11:30AM-12:50PM; Wed 11:30AM-12:50PM', 40),
('PHR1005L', 'Spring 2026', 'A', 'T023', 'running', 'PHR-Lab-1', 'Sat 02:00PM-04:30PM', 40),
('PHR3002', 'Spring 2026', 'A', 'T024', 'submitted', 'PHR-406', 'Sun 10:00AM-11:20AM; Tue 10:00AM-11:20AM', 40);


-- Create sections and assign teachers
INSERT INTO course_sections (course_id, trimester_id, teacher_id, section_name, status, capacity, room, class_schedule)
SELECT c.id, tr.id, u.id, s.section_name, s.section_status, s.capacity, s.room, s.class_schedule
FROM tmp_large_sections s
JOIN courses c ON c.course_code=s.course_code
JOIN trimesters tr ON tr.name=s.trimester_name
JOIN users u ON u.identifier=s.teacher_identifier AND u.role='teacher'
ON DUPLICATE KEY UPDATE teacher_id=VALUES(teacher_id), status=VALUES(status), capacity=VALUES(capacity), room=VALUES(room), class_schedule=VALUES(class_schedule);

-- Ensure CT/Assignment/Mid/Final/Attendance components for all large demo sections
INSERT IGNORE INTO assessment_components (section_id,component_key,component_name,component_type,taken_out_of,convert_to,weight,sort_order,is_best_of_group,best_of_group,created_by)
SELECT cs.id,'ct1','CT1','ct',30,15,15,1,1,'ct',cs.teacher_id FROM tmp_large_sections s JOIN courses c ON c.course_code=s.course_code JOIN trimesters tr ON tr.name=s.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=s.section_name;
INSERT IGNORE INTO assessment_components (section_id,component_key,component_name,component_type,taken_out_of,convert_to,weight,sort_order,is_best_of_group,best_of_group,created_by)
SELECT cs.id,'ct2','CT2','ct',30,15,15,2,1,'ct',cs.teacher_id FROM tmp_large_sections s JOIN courses c ON c.course_code=s.course_code JOIN trimesters tr ON tr.name=s.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=s.section_name;
INSERT IGNORE INTO assessment_components (section_id,component_key,component_name,component_type,taken_out_of,convert_to,weight,sort_order,is_best_of_group,best_of_group,created_by)
SELECT cs.id,'assignment','Assignment','assignment',10,10,10,3,0,NULL,cs.teacher_id FROM tmp_large_sections s JOIN courses c ON c.course_code=s.course_code JOIN trimesters tr ON tr.name=s.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=s.section_name;
INSERT IGNORE INTO assessment_components (section_id,component_key,component_name,component_type,taken_out_of,convert_to,weight,sort_order,is_best_of_group,best_of_group,created_by)
SELECT cs.id,'mid','Mid Term','mid',50,25,25,4,0,NULL,cs.teacher_id FROM tmp_large_sections s JOIN courses c ON c.course_code=s.course_code JOIN trimesters tr ON tr.name=s.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=s.section_name;
INSERT IGNORE INTO assessment_components (section_id,component_key,component_name,component_type,taken_out_of,convert_to,weight,sort_order,is_best_of_group,best_of_group,created_by)
SELECT cs.id,'final','Final Exam','final',80,40,40,5,0,NULL,cs.teacher_id FROM tmp_large_sections s JOIN courses c ON c.course_code=s.course_code JOIN trimesters tr ON tr.name=s.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=s.section_name;
INSERT IGNORE INTO assessment_components (section_id,component_key,component_name,component_type,taken_out_of,convert_to,weight,sort_order,is_best_of_group,best_of_group,created_by)
SELECT cs.id,'attendance','Attendance','attendance',10,10,10,6,0,NULL,cs.teacher_id FROM tmp_large_sections s JOIN courses c ON c.course_code=s.course_code JOIN trimesters tr ON tr.name=s.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=s.section_name;


DROP TEMPORARY TABLE IF EXISTS tmp_large_marks;
CREATE TEMPORARY TABLE tmp_large_marks (
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
  result_status VARCHAR(20) NOT NULL
);

INSERT INTO tmp_large_marks VALUES
('0242510001', 'PARENT0242510001', 'CSE1111', 'Spring 2025', 'A', 10.54, 10.32, 6.18, 16.02, 26.35, 8.0, 'approved'),
('0242510001', 'PARENT0242510001', 'CSE2215', 'Summer 2025', 'A', 12.25, 12.09, 9.28, 17.63, 29.93, 10, 'approved'),
('0242510001', 'PARENT0242510001', 'CSE3521', 'Fall 2025', 'A', 11.18, 14.05, 5.46, 17.41, 23.42, 8.0, 'approved'),
('0242510001', 'PARENT0242510001', 'CSE2218', 'Spring 2026', 'F', 6.14, 12.28, 5.33, 11.65, 18, 10, 'draft'),
('0242510002', 'PARENT0242510002', 'CSE1111', 'Spring 2025', 'A', 10.31, 14.23, 7.38, 14.05, 33.21, 8.0, 'approved'),
('0242510002', 'PARENT0242510002', 'CSE4533', 'Summer 2025', 'A', 10.49, 13.84, 5.29, 15.16, 23.39, 10, 'approved'),
('0242510002', 'PARENT0242510002', 'CSE3521', 'Fall 2025', 'A', 10.9, 11.12, 9.84, 21.14, 32.87, 10, 'approved'),
('0242510002', 'PARENT0242510002', 'CSE2218', 'Spring 2026', 'F', 13.19, 9.16, 9.0, 14.54, 34.5, 10, 'draft'),
('0242510003', 'PARENT0242510003', 'CSE1111', 'Spring 2025', 'A', 10.29, 9.65, 8.55, 18.94, 30.88, 9.0, 'approved'),
('0242510003', 'PARENT0242510003', 'CSE2215', 'Summer 2025', 'A', 15, 12.57, 7.78, 20.75, 29.32, 10, 'approved'),
('0242510003', 'PARENT0242510003', 'CSE3313', 'Fall 2025', 'B', 13.35, 15, 8.61, 20.97, 32.95, 7.0, 'approved'),
('0242510003', 'PARENT0242510003', 'CSE2218', 'Spring 2026', 'F', 10.59, 15, 7.99, 24.88, 40, 10, 'draft'),
('0242510004', 'PARENT0242510004', 'CSE1111', 'Spring 2025', 'A', 15, 14.02, 10, 15.72, 31.62, 10, 'approved'),
('0242510004', 'PARENT0242510004', 'CSE4533', 'Summer 2025', 'A', 11.76, 9.19, 7.36, 10.63, 18.96, 10, 'approved'),
('0242510004', 'PARENT0242510004', 'CSE3521', 'Fall 2025', 'A', 6.69, 7.15, 5.7, 15.44, 23.49, 10, 'approved'),
('0242510004', 'PARENT0242510004', 'CSE4165', 'Fall 2025', 'C', 15, 13.42, 8.43, 21.38, 36.09, 7.0, 'approved'),
('0242510004', 'PARENT0242510004', 'CSE2218', 'Spring 2026', 'F', 11.29, 10.13, 8.04, 18.24, 20.87, 10, 'draft'),
('0242510005', 'PARENT0242510005', 'CSE1111', 'Spring 2025', 'A', 13.46, 13.21, 9.46, 13.94, 36.99, 8.0, 'approved'),
('0242510005', 'PARENT0242510005', 'CSE2215', 'Summer 2025', 'A', 6.82, 7.37, 5.58, 15.53, 23.71, 8.0, 'approved'),
('0242510005', 'PARENT0242510005', 'CSE3521', 'Fall 2025', 'A', 8.33, 6.74, 5.5, 17.97, 19.54, 10, 'approved'),
('0242510005', 'PARENT0242510005', 'CSE2218', 'Spring 2026', 'F', 13.74, 13.15, 9.59, 24.24, 28.11, 10, 'draft'),
('0242510005', 'PARENT0242510005', 'CSE3711', 'Spring 2026', 'B', 10.57, 11.32, 8.2, 16.31, 29.55, 8.0, 'submitted'),
('0242510006', 'PARENT0242510006', 'CSE1111', 'Spring 2025', 'A', 12.08, 10.14, 6.55, 21.15, 28.01, 8.0, 'approved'),
('0242510006', 'PARENT0242510006', 'CSE4533', 'Summer 2025', 'A', 13.77, 10.25, 8.79, 18.21, 29.37, 10, 'approved'),
('0242510006', 'PARENT0242510006', 'CSE3313', 'Fall 2025', 'B', 12.69, 14.22, 8.9, 22.42, 28.27, 8.0, 'approved'),
('0242510006', 'PARENT0242510006', 'CSE2218', 'Spring 2026', 'F', 7.76, 13.08, 5.24, 15.46, 26.84, 10, 'draft'),
('0242510007', 'PARENT0242510007', 'CSE1111', 'Spring 2025', 'A', 8.22, 11.96, 7.2, 21.14, 28.21, 9.0, 'approved'),
('0242510007', 'PARENT0242510007', 'CSE2215', 'Summer 2025', 'A', 11.15, 14.94, 5.73, 21.43, 27.44, 8.0, 'approved'),
('0242510007', 'PARENT0242510007', 'CSE3521', 'Fall 2025', 'A', 9.1, 5.79, 6.76, 10.13, 34.59, 10, 'approved'),
('0242510007', 'PARENT0242510007', 'CSE2218', 'Spring 2026', 'F', 8.75, 9.65, 6.88, 22.83, 20.07, 7.0, 'draft'),
('0242510007', 'PARENT0242510007', 'CSE4889', 'Spring 2026', 'C', 11.27, 8.45, 6.63, 16.04, 36.73, 9.0, 'draft'),
('0242510008', 'PARENT0242510008', 'CSE1111', 'Spring 2025', 'A', 14.9, 11.43, 6.21, 11.36, 24.64, 10, 'approved'),
('0242510008', 'PARENT0242510008', 'CSE4533', 'Summer 2025', 'A', 12.89, 8.78, 5.64, 18.64, 33.97, 7.0, 'approved'),
('0242510008', 'PARENT0242510008', 'CSE3521', 'Fall 2025', 'A', 9.73, 7.75, 7.28, 13.87, 25.09, 10, 'approved'),
('0242510008', 'PARENT0242510008', 'CSE4165', 'Fall 2025', 'C', 10.62, 13.61, 5.79, 13.78, 25.97, 9.0, 'approved'),
('0242510008', 'PARENT0242510008', 'CSE2218', 'Spring 2026', 'F', 9.72, 9.22, 5, 14.82, 20.74, 9.0, 'draft'),
('0242510009', 'PARENT0242510009', 'CSE1111', 'Spring 2025', 'A', 8.03, 11.59, 8.75, 18.51, 32.27, 9.0, 'approved'),
('0242510009', 'PARENT0242510009', 'CSE2215', 'Summer 2025', 'A', 7.73, 9.57, 5, 17.42, 23.77, 8.0, 'approved'),
('0242510009', 'PARENT0242510009', 'CSE3313', 'Fall 2025', 'B', 13.8, 9.89, 5, 16.77, 28.1, 10, 'approved'),
('0242510009', 'PARENT0242510009', 'CSE2218', 'Spring 2026', 'F', 10.56, 8.51, 7.69, 16.56, 31.13, 10, 'draft'),
('0242510010', 'PARENT0242510010', 'CSE1111', 'Spring 2025', 'A', 9.7, 10.21, 7.77, 15.74, 27.97, 9.0, 'approved'),
('0242510010', 'PARENT0242510010', 'CSE4533', 'Summer 2025', 'A', 10.58, 15, 8.07, 17.49, 31.47, 10, 'approved'),
('0242510010', 'PARENT0242510010', 'CSE3521', 'Fall 2025', 'A', 12.61, 13.82, 8.38, 18.98, 30.76, 7.0, 'approved'),
('0242510010', 'PARENT0242510010', 'CSE2218', 'Spring 2026', 'F', 10.26, 7.74, 7.43, 16.33, 22.98, 10, 'draft'),
('0242510010', 'PARENT0242510010', 'CSE3711', 'Spring 2026', 'B', 13.47, 11.46, 5.69, 16.44, 34.23, 10, 'submitted'),
('0242510011', 'PARENT0242510011', 'CSE1111', 'Spring 2025', 'A', 11.26, 11.49, 6.19, 15.17, 25.15, 8.0, 'approved'),
('0242510011', 'PARENT0242510011', 'CSE2215', 'Summer 2025', 'A', 10.27, 11.85, 8.41, 19.15, 29.24, 7.0, 'approved'),
('0242510011', 'PARENT0242510011', 'CSE3521', 'Fall 2025', 'A', 11.17, 12.35, 7.3, 17.92, 28.94, 7.0, 'approved'),
('0242510011', 'PARENT0242510011', 'CSE2218', 'Spring 2026', 'F', 14.71, 13.8, 6.35, 16.93, 31.39, 8.0, 'draft'),
('0242510012', 'PARENT0242510012', 'CSE1111', 'Spring 2025', 'A', 9.93, 7.89, 5, 10, 27.95, 10, 'approved'),
('0242510012', 'PARENT0242510012', 'CSE4533', 'Summer 2025', 'A', 10.59, 12.8, 7.18, 23.47, 31.61, 8.0, 'approved'),
('0242510012', 'PARENT0242510012', 'CSE3313', 'Fall 2025', 'B', 7.13, 9.41, 8.21, 17.35, 21.12, 8.0, 'approved'),
('0242510012', 'PARENT0242510012', 'CSE4165', 'Fall 2025', 'C', 9.39, 8.82, 7.87, 15.29, 22.14, 10, 'approved'),
('0242510012', 'PARENT0242510012', 'CSE2218', 'Spring 2026', 'F', 10.65, 7.82, 6.15, 16.18, 18, 8.0, 'draft'),
('0242510013', 'PARENT0242510013', 'CSE1111', 'Spring 2025', 'A', 11.49, 15, 10, 22.12, 36.23, 10, 'approved'),
('0242510013', 'PARENT0242510013', 'CSE2215', 'Summer 2025', 'A', 9.21, 11.4, 5.44, 21.67, 22.01, 10, 'approved'),
('0242510013', 'PARENT0242510013', 'CSE3521', 'Fall 2025', 'A', 12.73, 11.99, 5.88, 17.91, 32.4, 9.0, 'approved'),
('0242510013', 'PARENT0242510013', 'CSE2218', 'Spring 2026', 'F', 11.94, 11.46, 10, 19.8, 34.76, 10, 'draft'),
('0242510014', 'PARENT0242510014', 'CSE1111', 'Spring 2025', 'A', 11.46, 10.86, 6.89, 13.61, 25.63, 9.0, 'approved'),
('0242510014', 'PARENT0242510014', 'CSE4533', 'Summer 2025', 'A', 12.16, 13.49, 7.01, 17.11, 30.41, 10, 'approved'),
('0242510014', 'PARENT0242510014', 'CSE3521', 'Fall 2025', 'A', 12.37, 10.33, 6.42, 11.98, 30.1, 7.0, 'approved'),
('0242510014', 'PARENT0242510014', 'CSE2218', 'Spring 2026', 'F', 8.91, 14.34, 6.8, 16.39, 21.12, 8.0, 'draft'),
('0242510014', 'PARENT0242510014', 'CSE4889', 'Spring 2026', 'C', 13.11, 9.56, 6.12, 12.88, 19.83, 9.0, 'draft'),
('0242510015', 'PARENT0242510015', 'CSE1111', 'Spring 2025', 'A', 15, 8.16, 6.55, 20.62, 35.05, 10, 'approved'),
('0242510015', 'PARENT0242510015', 'CSE2215', 'Summer 2025', 'A', 8.62, 9.53, 6.78, 13.16, 27.83, 10, 'approved'),
('0242510015', 'PARENT0242510015', 'CSE3313', 'Fall 2025', 'B', 12.22, 10.61, 6.6, 20.25, 26.56, 9.0, 'approved'),
('0242510015', 'PARENT0242510015', 'CSE2218', 'Spring 2026', 'F', 11.93, 8.34, 5.76, 14.96, 23.53, 9.0, 'draft'),
('0242510015', 'PARENT0242510015', 'CSE3711', 'Spring 2026', 'B', 8.23, 8.84, 5.38, 13.99, 29.18, 7.0, 'submitted'),
('0242510016', 'PARENT0242510016', 'CSE1111', 'Spring 2025', 'A', 12.09, 15, 9.92, 25, 35.88, 9.0, 'approved'),
('0242510016', 'PARENT0242510016', 'CSE4533', 'Summer 2025', 'A', 10.7, 11.18, 7.1, 15.99, 18, 8.0, 'approved'),
('0242510016', 'PARENT0242510016', 'CSE3521', 'Fall 2025', 'A', 13.99, 12.46, 5.6, 12.76, 36.2, 9.0, 'approved'),
('0242510016', 'PARENT0242510016', 'CSE4165', 'Fall 2025', 'C', 12.48, 10.65, 6.38, 12.38, 29.2, 7.0, 'approved'),
('0242510016', 'PARENT0242510016', 'CSE2218', 'Spring 2026', 'F', 15, 13.98, 8.43, 21.79, 32.65, 9.0, 'draft'),
('0242510017', 'PARENT0242510017', 'CSE1111', 'Spring 2025', 'A', 11.46, 8.46, 7.91, 11.86, 32.91, 10, 'approved'),
('0242510017', 'PARENT0242510017', 'CSE2215', 'Summer 2025', 'A', 11.45, 12.0, 10, 20.01, 31.43, 9.0, 'approved'),
('0242510017', 'PARENT0242510017', 'CSE3521', 'Fall 2025', 'A', 9.41, 11.53, 5, 10, 19.68, 9.0, 'approved'),
('0242510017', 'PARENT0242510017', 'CSE2218', 'Spring 2026', 'F', 11.52, 14.06, 5, 14.67, 19.86, 10, 'draft'),
('0242510018', 'PARENT0242510018', 'CSE1111', 'Spring 2025', 'A', 8.66, 9.24, 7.87, 16.64, 21.3, 10, 'approved'),
('0242510018', 'PARENT0242510018', 'CSE4533', 'Summer 2025', 'A', 10.02, 13.3, 5.55, 18.16, 27.27, 10, 'approved'),
('0242510018', 'PARENT0242510018', 'CSE3313', 'Fall 2025', 'B', 11.33, 14.25, 9.19, 20.16, 24.96, 10, 'approved'),
('0242510018', 'PARENT0242510018', 'CSE2218', 'Spring 2026', 'F', 12.65, 9.83, 6.46, 14.8, 31.31, 7.0, 'draft'),
('0242510019', 'PARENT0242510019', 'CSE1111', 'Spring 2025', 'A', 15, 12.95, 7.35, 20.88, 30.01, 10, 'approved'),
('0242510019', 'PARENT0242510019', 'CSE2215', 'Summer 2025', 'A', 8.65, 10.84, 5.68, 16.13, 31.79, 10, 'approved'),
('0242510019', 'PARENT0242510019', 'CSE3521', 'Fall 2025', 'A', 11.11, 12.18, 6.98, 17.47, 31.05, 10, 'approved'),
('0242510019', 'PARENT0242510019', 'CSE2218', 'Spring 2026', 'F', 9.75, 8.42, 7.51, 18.7, 31.13, 9.0, 'draft'),
('0242510020', 'PARENT0242510020', 'CSE1111', 'Spring 2025', 'A', 12.01, 8.78, 6.92, 10.24, 27.13, 10, 'approved'),
('0242510020', 'PARENT0242510020', 'CSE4533', 'Summer 2025', 'A', 7.26, 10.73, 8.61, 19.74, 31.44, 10, 'approved'),
('0242510020', 'PARENT0242510020', 'CSE3521', 'Fall 2025', 'A', 8.86, 8.53, 7.33, 10.36, 31.64, 9.0, 'approved'),
('0242510020', 'PARENT0242510020', 'CSE4165', 'Fall 2025', 'C', 14.8, 5.27, 9.97, 14.77, 28.77, 9.0, 'approved'),
('0242510020', 'PARENT0242510020', 'CSE2218', 'Spring 2026', 'F', 11.35, 12.21, 7.77, 15.72, 24.14, 9.0, 'draft'),
('0242510020', 'PARENT0242510020', 'CSE3711', 'Spring 2026', 'B', 9.17, 10.11, 9.0, 20.51, 27.16, 9.0, 'submitted'),
('0242510021', 'PARENT0242510021', 'CSE1111', 'Spring 2025', 'A', 13.13, 13.03, 9.75, 18.73, 30.1, 10, 'approved'),
('0242510021', 'PARENT0242510021', 'CSE2215', 'Summer 2025', 'A', 12.18, 10.76, 7.15, 17.22, 24.9, 10, 'approved'),
('0242510021', 'PARENT0242510021', 'CSE3313', 'Fall 2025', 'B', 14.04, 13.39, 8.75, 22.99, 30.58, 10, 'approved'),
('0242510021', 'PARENT0242510021', 'CSE2218', 'Spring 2026', 'F', 12.18, 12.17, 10, 13.16, 21.59, 8.0, 'draft'),
('0242510021', 'PARENT0242510021', 'CSE4889', 'Spring 2026', 'C', 15, 13.78, 9.41, 16.89, 33.45, 9.0, 'draft'),
('0242510022', 'PARENT0242510022', 'CSE1111', 'Spring 2025', 'A', 12.84, 10.5, 8.3, 13.98, 32.31, 10, 'approved'),
('0242510022', 'PARENT0242510022', 'CSE4533', 'Summer 2025', 'A', 9.17, 7.33, 7.71, 16.62, 27.96, 10, 'approved'),
('0242510022', 'PARENT0242510022', 'CSE3521', 'Fall 2025', 'A', 12.31, 10.89, 5.84, 17.52, 32.04, 10, 'approved'),
('0242510022', 'PARENT0242510022', 'CSE2218', 'Spring 2026', 'F', 9.89, 10.06, 6.78, 17.88, 18, 9.0, 'draft'),
('0242510023', 'PARENT0242510023', 'CSE1111', 'Spring 2025', 'A', 10.41, 12.14, 7.01, 14.26, 23.05, 7.0, 'approved'),
('0242510023', 'PARENT0242510023', 'CSE2215', 'Summer 2025', 'A', 15, 10.43, 8.59, 24.59, 31.68, 10, 'approved'),
('0242510023', 'PARENT0242510023', 'CSE3521', 'Fall 2025', 'A', 11.34, 12.83, 7.35, 18.1, 25.45, 9.0, 'approved'),
('0242510023', 'PARENT0242510023', 'CSE2218', 'Spring 2026', 'F', 8.04, 9.39, 7.24, 14.36, 32.6, 8.0, 'draft'),
('0242510024', 'PARENT0242510024', 'CSE1111', 'Spring 2025', 'A', 11.67, 13.93, 7.59, 12.69, 33.22, 10, 'approved'),
('0242510024', 'PARENT0242510024', 'CSE4533', 'Summer 2025', 'A', 11.1, 10.45, 5, 17.12, 36.86, 10, 'approved'),
('0242510024', 'PARENT0242510024', 'CSE3313', 'Fall 2025', 'B', 13.93, 12.64, 7.58, 21.29, 32.39, 10, 'approved'),
('0242510024', 'PARENT0242510024', 'CSE4165', 'Fall 2025', 'C', 12.63, 14.78, 9.7, 18.21, 28.08, 9.0, 'approved'),
('0242510024', 'PARENT0242510024', 'CSE2218', 'Spring 2026', 'F', 12.94, 12.19, 8.21, 15.84, 26.4, 8.0, 'draft'),
('0242510025', 'PARENT0242510025', 'CSE1111', 'Spring 2025', 'A', 11.58, 13.88, 6.33, 14.05, 40, 10, 'approved'),
('0242510025', 'PARENT0242510025', 'CSE2215', 'Summer 2025', 'A', 9.84, 12.34, 7.59, 15.14, 33.56, 7.0, 'approved'),
('0242510025', 'PARENT0242510025', 'CSE3521', 'Fall 2025', 'A', 9.2, 11.84, 6.75, 15.32, 27.56, 9.0, 'approved'),
('0242510025', 'PARENT0242510025', 'CSE2218', 'Spring 2026', 'F', 13.09, 15, 7.03, 21.89, 35.06, 10, 'draft'),
('0242510025', 'PARENT0242510025', 'CSE3711', 'Spring 2026', 'B', 11.65, 11.0, 6.77, 15.45, 31.19, 10, 'submitted'),
('0242510026', 'PARENT0242510026', 'CSE1111', 'Spring 2025', 'A', 9.93, 10.16, 5.49, 15.6, 18, 8.0, 'approved'),
('0242510026', 'PARENT0242510026', 'CSE4533', 'Summer 2025', 'A', 8.13, 9.83, 6.32, 18.18, 23.59, 9.0, 'approved'),
('0242510026', 'PARENT0242510026', 'CSE3521', 'Fall 2025', 'A', 11.8, 10.19, 6.86, 13.42, 34.91, 7.0, 'approved'),
('0242510026', 'PARENT0242510026', 'CSE2218', 'Spring 2026', 'F', 11.7, 10.25, 7.23, 17.3, 25.51, 10, 'draft'),
('0242510027', 'PARENT0242510027', 'CSE1111', 'Spring 2025', 'A', 9.84, 11.98, 5.08, 15.03, 20.54, 10, 'approved'),
('0242510027', 'PARENT0242510027', 'CSE2215', 'Summer 2025', 'A', 12.38, 10.36, 5, 16.82, 24.2, 10, 'approved'),
('0242510027', 'PARENT0242510027', 'CSE3313', 'Fall 2025', 'B', 8.84, 9.33, 8.06, 16.68, 29.69, 9.0, 'approved'),
('0242510027', 'PARENT0242510027', 'CSE2218', 'Spring 2026', 'F', 14.16, 12.86, 8.32, 20.58, 26.03, 9.0, 'draft'),
('0242510028', 'PARENT0242510028', 'CSE1111', 'Spring 2025', 'A', 9.62, 11.67, 6.88, 17.18, 30.69, 10, 'approved'),
('0242510028', 'PARENT0242510028', 'CSE4533', 'Summer 2025', 'A', 15, 10.92, 7.31, 16.59, 27.08, 10, 'approved'),
('0242510028', 'PARENT0242510028', 'CSE3521', 'Fall 2025', 'A', 8.92, 13.55, 6.88, 14.9, 18.75, 8.0, 'approved'),
('0242510028', 'PARENT0242510028', 'CSE4165', 'Fall 2025', 'C', 13.97, 10.67, 9.48, 16.68, 23.15, 9.0, 'approved'),
('0242510028', 'PARENT0242510028', 'CSE2218', 'Spring 2026', 'F', 7.98, 8.46, 7.0, 15.25, 33.64, 8.0, 'draft'),
('0242510028', 'PARENT0242510028', 'CSE4889', 'Spring 2026', 'C', 13.08, 14.95, 6.65, 23.58, 21.57, 9.0, 'draft'),
('0242510029', 'PARENT0242510029', 'CSE1111', 'Spring 2025', 'A', 13.5, 10.31, 9.72, 22.05, 30.17, 8.0, 'approved'),
('0242510029', 'PARENT0242510029', 'CSE2215', 'Summer 2025', 'A', 8.07, 12.71, 5.9, 14.24, 28.57, 8.0, 'approved'),
('0242510029', 'PARENT0242510029', 'CSE3521', 'Fall 2025', 'A', 9.69, 10.99, 5, 10, 25.2, 8.0, 'approved'),
('0242510029', 'PARENT0242510029', 'CSE2218', 'Spring 2026', 'F', 11.84, 9.14, 6.74, 21.81, 23.96, 9.0, 'draft'),
('0242510030', 'PARENT0242510030', 'CSE1111', 'Spring 2025', 'A', 10.29, 12.91, 7.9, 19.41, 32.18, 7.0, 'approved'),
('0242510030', 'PARENT0242510030', 'CSE4533', 'Summer 2025', 'A', 11.74, 10.68, 8.06, 24.52, 38.47, 7.0, 'approved'),
('0242510030', 'PARENT0242510030', 'CSE3313', 'Fall 2025', 'B', 12.23, 13.36, 8.24, 18.98, 35.57, 8.0, 'approved'),
('0242510030', 'PARENT0242510030', 'CSE2218', 'Spring 2026', 'F', 8.23, 11.13, 9.11, 17.01, 18, 7.0, 'draft'),
('0242510030', 'PARENT0242510030', 'CSE3711', 'Spring 2026', 'B', 14.44, 10.39, 8.78, 18.12, 29.98, 9.0, 'submitted'),
('0242510031', 'PARENT0242510031', 'CSE1111', 'Spring 2025', 'A', 9.61, 10.53, 5.78, 19.81, 19.96, 8.0, 'approved'),
('0242510031', 'PARENT0242510031', 'CSE2215', 'Summer 2025', 'A', 12.38, 7.2, 5.84, 14.97, 27.53, 8.0, 'approved'),
('0242510031', 'PARENT0242510031', 'CSE3521', 'Fall 2025', 'A', 13.86, 10.25, 6.72, 22.33, 28.76, 7.0, 'approved'),
('0242510031', 'PARENT0242510031', 'CSE2218', 'Spring 2026', 'F', 14.44, 15, 8.5, 23.54, 40, 10, 'draft'),
('0242510032', 'PARENT0242510032', 'CSE1111', 'Spring 2025', 'A', 10.62, 9.16, 9.45, 18.06, 24.46, 8.0, 'approved'),
('0242510032', 'PARENT0242510032', 'CSE4533', 'Summer 2025', 'A', 12.41, 11.39, 9.8, 20.79, 40, 10, 'approved'),
('0242510032', 'PARENT0242510032', 'CSE3521', 'Fall 2025', 'A', 11.96, 12.89, 7.7, 16.85, 23.31, 10, 'approved'),
('0242510032', 'PARENT0242510032', 'CSE4165', 'Fall 2025', 'C', 15, 9.8, 8.19, 18.2, 34.72, 7.0, 'approved'),
('0242510032', 'PARENT0242510032', 'CSE2218', 'Spring 2026', 'F', 13.04, 12.73, 8.74, 18.86, 31.02, 7.0, 'draft'),
('0242510033', 'PARENT0242510033', 'CSE1111', 'Spring 2025', 'A', 7.63, 12.65, 7.76, 23.09, 25.46, 7.0, 'approved'),
('0242510033', 'PARENT0242510033', 'CSE2215', 'Summer 2025', 'A', 13.55, 8.38, 5.49, 15.77, 25.49, 9.0, 'approved'),
('0242510033', 'PARENT0242510033', 'CSE3313', 'Fall 2025', 'B', 9.94, 12.98, 5.57, 15.05, 32.24, 10, 'approved'),
('0242510033', 'PARENT0242510033', 'CSE2218', 'Spring 2026', 'F', 8.93, 7.29, 5.97, 11.85, 26.06, 7.0, 'draft'),
('0242510034', 'PARENT0242510034', 'CSE1111', 'Spring 2025', 'A', 10.84, 7.78, 6.63, 12.46, 29.81, 8.0, 'approved'),
('0242510034', 'PARENT0242510034', 'CSE4533', 'Summer 2025', 'A', 14.77, 15, 8.57, 15.28, 29.42, 9.0, 'approved'),
('0242510034', 'PARENT0242510034', 'CSE3521', 'Fall 2025', 'A', 15, 15, 8.76, 18.83, 40, 7.0, 'approved'),
('0242510034', 'PARENT0242510034', 'CSE2218', 'Spring 2026', 'F', 12.37, 10.86, 7.78, 18.94, 39.01, 10, 'draft'),
('0242510035', 'PARENT0242510035', 'CSE1111', 'Spring 2025', 'A', 11.52, 8.26, 6.52, 19.64, 28.14, 7.0, 'approved'),
('0242510035', 'PARENT0242510035', 'CSE2215', 'Summer 2025', 'A', 9.99, 9.55, 6.74, 17.56, 25.71, 10, 'approved'),
('0242510035', 'PARENT0242510035', 'CSE3521', 'Fall 2025', 'A', 13.26, 14.27, 9.02, 17.65, 39.17, 9.0, 'approved'),
('0242510035', 'PARENT0242510035', 'CSE2218', 'Spring 2026', 'F', 11.08, 11.82, 9.06, 18.62, 34.38, 9.0, 'draft'),
('0242510035', 'PARENT0242510035', 'CSE3711', 'Spring 2026', 'B', 12.16, 8.73, 7.92, 10, 25.23, 7.0, 'submitted'),
('0242510035', 'PARENT0242510035', 'CSE4889', 'Spring 2026', 'C', 7.88, 10.44, 6.47, 22.67, 22.13, 8.0, 'draft'),
('0242510036', 'PARENT0242510036', 'CSE1111', 'Spring 2025', 'A', 14.56, 11.9, 7.84, 23.0, 35.06, 10, 'approved'),
('0242510036', 'PARENT0242510036', 'CSE4533', 'Summer 2025', 'A', 15, 13.91, 7.1, 17.86, 21.93, 7.0, 'approved'),
('0242510036', 'PARENT0242510036', 'CSE3313', 'Fall 2025', 'B', 11.09, 11.25, 9.9, 18.59, 30.11, 9.0, 'approved'),
('0242510036', 'PARENT0242510036', 'CSE4165', 'Fall 2025', 'C', 11.92, 10.59, 6.89, 14.09, 20.43, 9.0, 'approved'),
('0242510036', 'PARENT0242510036', 'CSE2218', 'Spring 2026', 'F', 13.48, 12.45, 9.87, 19.52, 38.44, 10, 'draft'),
('0242510037', 'PARENT0242510037', 'CSE1111', 'Spring 2025', 'A', 15, 9.71, 9.36, 22.3, 27.27, 9.0, 'approved'),
('0242510037', 'PARENT0242510037', 'CSE2215', 'Summer 2025', 'A', 10.34, 8.82, 7.17, 22.09, 32.35, 10, 'approved'),
('0242510037', 'PARENT0242510037', 'CSE3521', 'Fall 2025', 'A', 12.16, 11.63, 10, 17.57, 34.59, 7.0, 'approved'),
('0242510037', 'PARENT0242510037', 'CSE2218', 'Spring 2026', 'F', 14.49, 10.35, 6.89, 18.07, 36.24, 7.0, 'draft'),
('0242510038', 'PARENT0242510038', 'CSE1111', 'Spring 2025', 'A', 11.03, 12.58, 9.59, 16.24, 23.1, 9.0, 'approved'),
('0242510038', 'PARENT0242510038', 'CSE4533', 'Summer 2025', 'A', 11.31, 8.53, 6.61, 11.93, 18.3, 7.0, 'approved'),
('0242510038', 'PARENT0242510038', 'CSE3521', 'Fall 2025', 'A', 15, 10.63, 9.2, 16.11, 37.58, 8.0, 'approved'),
('0242510038', 'PARENT0242510038', 'CSE2218', 'Spring 2026', 'F', 10.35, 9.72, 8.18, 17.05, 31.09, 10, 'draft'),
('0242510039', 'PARENT0242510039', 'CSE1111', 'Spring 2025', 'A', 11.3, 12.52, 6.72, 18.4, 39.02, 10, 'approved'),
('0242510039', 'PARENT0242510039', 'CSE2215', 'Summer 2025', 'A', 11.74, 12.29, 8.38, 22.4, 29.21, 10, 'approved'),
('0242510039', 'PARENT0242510039', 'CSE3313', 'Fall 2025', 'B', 10.46, 13.68, 7.08, 16.95, 28.54, 10, 'approved'),
('0242510039', 'PARENT0242510039', 'CSE2218', 'Spring 2026', 'F', 12.1, 10.69, 6.69, 15.14, 23.93, 10, 'draft'),
('0242510040', 'PARENT0242510040', 'CSE1111', 'Spring 2025', 'A', 9.46, 9.95, 6.42, 12.61, 22.13, 9.0, 'approved'),
('0242510040', 'PARENT0242510040', 'CSE4533', 'Summer 2025', 'A', 10.44, 12.01, 5.42, 12.98, 25.69, 7.0, 'approved'),
('0242510040', 'PARENT0242510040', 'CSE3521', 'Fall 2025', 'A', 9.64, 12.33, 9.33, 17.63, 31.33, 8.0, 'approved'),
('0242510040', 'PARENT0242510040', 'CSE4165', 'Fall 2025', 'C', 12.07, 8.4, 6.25, 18.76, 29.19, 7.0, 'approved'),
('0242510040', 'PARENT0242510040', 'CSE2218', 'Spring 2026', 'F', 14.19, 13.15, 8.85, 14.36, 27.51, 10, 'draft'),
('0242510040', 'PARENT0242510040', 'CSE3711', 'Spring 2026', 'B', 7.63, 11.06, 7.43, 18.73, 22.61, 9.0, 'submitted'),
('0242510041', 'PARENT0242510041', 'CSE1111', 'Spring 2025', 'A', 11.33, 10.56, 9.04, 16.77, 30.33, 8.0, 'approved'),
('0242510041', 'PARENT0242510041', 'CSE2215', 'Summer 2025', 'A', 10.3, 12.18, 5.69, 19.62, 24.35, 10, 'approved'),
('0242510041', 'PARENT0242510041', 'CSE3521', 'Fall 2025', 'A', 13.72, 14.19, 8.99, 22.91, 33.17, 7.0, 'approved'),
('0242510041', 'PARENT0242510041', 'CSE2218', 'Spring 2026', 'F', 10.34, 12.51, 7.36, 13.57, 27.92, 9.0, 'draft'),
('0242510042', 'PARENT0242510042', 'CSE1111', 'Spring 2025', 'A', 10.98, 8.04, 8.64, 16.51, 32.87, 9.0, 'approved'),
('0242510042', 'PARENT0242510042', 'CSE4533', 'Summer 2025', 'A', 6.6, 6.75, 5.92, 16.38, 27.41, 9.0, 'approved'),
('0242510042', 'PARENT0242510042', 'CSE3313', 'Fall 2025', 'B', 12.98, 10.53, 6.62, 15.01, 28.81, 8.0, 'approved'),
('0242510042', 'PARENT0242510042', 'CSE2218', 'Spring 2026', 'F', 10.24, 10.7, 7.05, 12.18, 22.92, 10, 'draft'),
('0242510042', 'PARENT0242510042', 'CSE4889', 'Spring 2026', 'C', 10.39, 8.38, 5.44, 17.6, 33.89, 10, 'draft'),
('0242510043', 'PARENT0242510043', 'CSE1111', 'Spring 2025', 'A', 13.07, 13.51, 10, 24.0, 30.4, 10, 'approved'),
('0242510043', 'PARENT0242510043', 'CSE2215', 'Summer 2025', 'A', 11.28, 11.16, 9.98, 15.56, 30.11, 10, 'approved'),
('0242510043', 'PARENT0242510043', 'CSE3521', 'Fall 2025', 'A', 13.08, 10.43, 8.02, 22.18, 29.5, 10, 'approved'),
('0242510043', 'PARENT0242510043', 'CSE2218', 'Spring 2026', 'F', 11.15, 12.39, 8.53, 23.46, 32.5, 10, 'draft'),
('0242510044', 'PARENT0242510044', 'CSE1111', 'Spring 2025', 'A', 12.92, 12.21, 5.41, 15.57, 27.39, 9.0, 'approved'),
('0242510044', 'PARENT0242510044', 'CSE4533', 'Summer 2025', 'A', 8.42, 11.26, 7.0, 16.31, 29.3, 10, 'approved'),
('0242510044', 'PARENT0242510044', 'CSE3521', 'Fall 2025', 'A', 12.81, 11.04, 7.08, 17.49, 24.68, 9.0, 'approved'),
('0242510044', 'PARENT0242510044', 'CSE4165', 'Fall 2025', 'C', 12.35, 10.87, 10, 13.73, 34.64, 8.0, 'approved'),
('0242510044', 'PARENT0242510044', 'CSE2218', 'Spring 2026', 'F', 8.99, 11.44, 6.31, 14.64, 23.42, 7.0, 'draft'),
('0242510045', 'PARENT0242510045', 'CSE1111', 'Spring 2025', 'A', 9.42, 10.38, 5.19, 11.95, 18.37, 8.0, 'approved'),
('0242510045', 'PARENT0242510045', 'CSE2215', 'Summer 2025', 'A', 11.64, 14.65, 6.01, 19.98, 29.8, 10, 'approved'),
('0242510045', 'PARENT0242510045', 'CSE3313', 'Fall 2025', 'B', 10.77, 13.79, 7.77, 16.11, 40, 9.0, 'approved'),
('0242510045', 'PARENT0242510045', 'CSE2218', 'Spring 2026', 'F', 7.63, 8.85, 5.19, 13.32, 21.31, 10, 'draft'),
('0242510045', 'PARENT0242510045', 'CSE3711', 'Spring 2026', 'B', 12.21, 12.52, 6.91, 14.5, 34.2, 8.0, 'submitted'),
('0242510046', 'PARENT0242510046', 'CSE1111', 'Spring 2025', 'A', 13.79, 9.8, 7.94, 22.25, 28.92, 8.0, 'approved'),
('0242510046', 'PARENT0242510046', 'CSE4533', 'Summer 2025', 'A', 13.73, 14.06, 10, 22.45, 28.6, 8.0, 'approved'),
('0242510046', 'PARENT0242510046', 'CSE3521', 'Fall 2025', 'A', 10.65, 11.96, 5.6, 16.41, 21.57, 9.0, 'approved'),
('0242510046', 'PARENT0242510046', 'CSE4509', 'Spring 2026', 'A', 12.05, 9.29, 7.95, 11.48, 29.32, 10, 'draft'),
('0242510047', 'PARENT0242510047', 'CSE1111', 'Spring 2025', 'A', 13.72, 9.03, 8.95, 25, 27.01, 10, 'approved'),
('0242510047', 'PARENT0242510047', 'CSE2215', 'Summer 2025', 'A', 12.71, 13.48, 8.54, 19.32, 29.63, 10, 'approved'),
('0242510047', 'PARENT0242510047', 'CSE3521', 'Fall 2025', 'A', 14.27, 14.81, 7.81, 25, 25.5, 10, 'approved'),
('0242510047', 'PARENT0242510047', 'CSE4509', 'Spring 2026', 'A', 14.28, 13.53, 6.7, 17.03, 27.58, 10, 'draft'),
('0242510048', 'PARENT0242510048', 'CSE1111', 'Spring 2025', 'A', 10.03, 7.34, 6.23, 20.51, 21.11, 7.0, 'approved'),
('0242510048', 'PARENT0242510048', 'CSE4533', 'Summer 2025', 'A', 14.36, 13.35, 10, 21.55, 32.92, 7.0, 'approved'),
('0242510048', 'PARENT0242510048', 'CSE3313', 'Fall 2025', 'B', 11.85, 14.47, 8.29, 22.55, 33.98, 8.0, 'approved'),
('0242510048', 'PARENT0242510048', 'CSE4165', 'Fall 2025', 'C', 12.62, 14.3, 9.39, 11.74, 30.18, 10, 'approved'),
('0242510048', 'PARENT0242510048', 'CSE4509', 'Spring 2026', 'A', 11.25, 8.46, 9.11, 20.33, 34.48, 7.0, 'draft'),
('0242510049', 'PARENT0242510049', 'CSE1111', 'Spring 2025', 'A', 13.11, 13.23, 10, 19.87, 28.8, 9.0, 'approved'),
('0242510049', 'PARENT0242510049', 'CSE2215', 'Summer 2025', 'A', 15, 12.9, 9.25, 25, 35.12, 10, 'approved'),
('0242510049', 'PARENT0242510049', 'CSE3521', 'Fall 2025', 'A', 13.84, 9.85, 6.79, 21.24, 18, 8.0, 'approved'),
('0242510049', 'PARENT0242510049', 'CSE4509', 'Spring 2026', 'A', 14.18, 9.66, 6.23, 21.71, 31.7, 10, 'draft'),
('0242510049', 'PARENT0242510049', 'CSE4889', 'Spring 2026', 'C', 13.91, 10.81, 5.19, 19.04, 26.01, 9.0, 'draft'),
('0242510050', 'PARENT0242510050', 'CSE1111', 'Spring 2025', 'A', 15, 13.14, 9.27, 25, 35.07, 9.0, 'approved'),
('0242510050', 'PARENT0242510050', 'CSE4533', 'Summer 2025', 'A', 11.81, 12.19, 8.51, 17.99, 33.67, 7.0, 'approved'),
('0242510050', 'PARENT0242510050', 'CSE3521', 'Fall 2025', 'A', 12.72, 10.66, 7.93, 19.89, 30.43, 10, 'approved'),
('0242510050', 'PARENT0242510050', 'CSE4509', 'Spring 2026', 'A', 11.83, 10.65, 6.05, 21.05, 40, 7.0, 'draft'),
('0242510050', 'PARENT0242510050', 'CSE3711', 'Spring 2026', 'B', 13.94, 13.33, 7.43, 23.71, 32.41, 10, 'submitted'),
('0242510051', 'PARENT0242510051', 'CSE1111', 'Spring 2025', 'A', 13.49, 15, 6.99, 19.12, 34.44, 7.0, 'approved'),
('0242510051', 'PARENT0242510051', 'CSE2215', 'Summer 2025', 'A', 10.97, 10.4, 5.92, 16.18, 33.54, 8.0, 'approved'),
('0242510051', 'PARENT0242510051', 'CSE3313', 'Fall 2025', 'B', 15, 14.27, 9.27, 21.43, 35.72, 7.0, 'approved'),
('0242510051', 'PARENT0242510051', 'CSE4509', 'Spring 2026', 'A', 10.98, 14.35, 6.87, 19.17, 31.82, 10, 'draft'),
('0242510052', 'PARENT0242510052', 'CSE1111', 'Spring 2025', 'A', 11.55, 10.21, 6.18, 14.48, 30.06, 8.0, 'approved'),
('0242510052', 'PARENT0242510052', 'CSE4533', 'Summer 2025', 'A', 12.73, 11.45, 7.19, 22.25, 29.17, 9.0, 'approved'),
('0242510052', 'PARENT0242510052', 'CSE3521', 'Fall 2025', 'A', 12.95, 14.27, 7.98, 25, 36.39, 9.0, 'approved'),
('0242510052', 'PARENT0242510052', 'CSE4165', 'Fall 2025', 'C', 11.82, 9.79, 5.8, 14.01, 24.78, 9.0, 'approved'),
('0242510052', 'PARENT0242510052', 'CSE4509', 'Spring 2026', 'A', 9.42, 15, 8.86, 20.65, 32.04, 10, 'draft'),
('0242510053', 'PARENT0242510053', 'CSE1111', 'Spring 2025', 'A', 9.8, 10.46, 6.52, 15.83, 27.25, 7.0, 'approved'),
('0242510053', 'PARENT0242510053', 'CSE2215', 'Summer 2025', 'A', 5, 7.63, 5.71, 17.28, 22.41, 7.0, 'approved'),
('0242510053', 'PARENT0242510053', 'CSE3521', 'Fall 2025', 'A', 10.92, 11.78, 6.65, 17.26, 23.99, 10, 'approved'),
('0242510053', 'PARENT0242510053', 'CSE4509', 'Spring 2026', 'A', 14.64, 13.69, 9.66, 23.91, 26.45, 10, 'draft'),
('0242510054', 'PARENT0242510054', 'CSE1111', 'Spring 2025', 'A', 12.3, 8.24, 8.17, 15.43, 25.85, 10, 'approved'),
('0242510054', 'PARENT0242510054', 'CSE4533', 'Summer 2025', 'A', 13.39, 15, 9.63, 18.52, 34.76, 9.0, 'approved'),
('0242510054', 'PARENT0242510054', 'CSE3313', 'Fall 2025', 'B', 11.93, 10.1, 7.63, 20.67, 27.63, 8.0, 'approved'),
('0242510054', 'PARENT0242510054', 'CSE4509', 'Spring 2026', 'A', 9.69, 12.4, 9.21, 17.2, 25.66, 10, 'draft'),
('0242510055', 'PARENT0242510055', 'CSE1111', 'Spring 2025', 'A', 15, 11.58, 9.41, 25, 35.08, 10, 'approved'),
('0242510055', 'PARENT0242510055', 'CSE2215', 'Summer 2025', 'A', 6.82, 14.58, 5.2, 13.03, 22.67, 8.0, 'approved'),
('0242510055', 'PARENT0242510055', 'CSE3521', 'Fall 2025', 'A', 12.07, 11.04, 8.44, 22.33, 23.42, 7.0, 'approved'),
('0242510055', 'PARENT0242510055', 'CSE4509', 'Spring 2026', 'A', 7.46, 5.92, 6.12, 16.9, 28.61, 7.0, 'draft'),
('0242510055', 'PARENT0242510055', 'CSE3711', 'Spring 2026', 'B', 10.45, 11.1, 9.51, 10.09, 18, 7.0, 'submitted'),
('0242510056', 'PARENT0242510056', 'CSE1111', 'Spring 2025', 'A', 11.21, 7.8, 7.62, 14.81, 20.43, 10, 'approved'),
('0242510056', 'PARENT0242510056', 'CSE4533', 'Summer 2025', 'A', 13.57, 12.23, 10, 21.15, 36.11, 9.0, 'approved'),
('0242510056', 'PARENT0242510056', 'CSE3521', 'Fall 2025', 'A', 11.96, 13.05, 10, 18.27, 40, 9.0, 'approved'),
('0242510056', 'PARENT0242510056', 'CSE4165', 'Fall 2025', 'C', 13.71, 14.03, 6.67, 20.54, 31.22, 10, 'approved'),
('0242510056', 'PARENT0242510056', 'CSE4509', 'Spring 2026', 'A', 12.14, 14.3, 8.58, 25, 38.02, 8.0, 'draft'),
('0242510056', 'PARENT0242510056', 'CSE4889', 'Spring 2026', 'C', 11.72, 14.3, 8.53, 16.48, 37.05, 9.0, 'draft'),
('0242510057', 'PARENT0242510057', 'CSE1111', 'Spring 2025', 'A', 12.32, 10.69, 8.44, 18.68, 26.34, 9.0, 'approved'),
('0242510057', 'PARENT0242510057', 'CSE2215', 'Summer 2025', 'A', 9.89, 12.34, 6.63, 21.69, 28.34, 10, 'approved'),
('0242510057', 'PARENT0242510057', 'CSE3313', 'Fall 2025', 'B', 10.83, 12.38, 7.39, 15.09, 25.84, 7.0, 'approved'),
('0242510057', 'PARENT0242510057', 'CSE4509', 'Spring 2026', 'A', 7.6, 8.37, 6.19, 15.9, 23.99, 7.0, 'draft'),
('0242510058', 'PARENT0242510058', 'CSE1111', 'Spring 2025', 'A', 9.04, 11.04, 5.19, 20.45, 39.78, 7.0, 'approved'),
('0242510058', 'PARENT0242510058', 'CSE4533', 'Summer 2025', 'A', 13.48, 13.22, 8.45, 19.68, 30.41, 8.0, 'approved'),
('0242510058', 'PARENT0242510058', 'CSE3521', 'Fall 2025', 'A', 6.03, 15, 7.27, 24.24, 31.42, 8.0, 'approved'),
('0242510058', 'PARENT0242510058', 'CSE4509', 'Spring 2026', 'A', 11.56, 11.87, 6.44, 13.93, 33.55, 10, 'draft'),
('0242510059', 'PARENT0242510059', 'CSE1111', 'Spring 2025', 'A', 13.89, 11.24, 8.44, 17.4, 25.27, 9.0, 'approved'),
('0242510059', 'PARENT0242510059', 'CSE2215', 'Summer 2025', 'A', 15, 15, 7.66, 24.99, 33.47, 9.0, 'approved'),
('0242510059', 'PARENT0242510059', 'CSE3521', 'Fall 2025', 'A', 8.1, 11.29, 7.06, 16.17, 18, 10, 'approved'),
('0242510059', 'PARENT0242510059', 'CSE4509', 'Spring 2026', 'A', 14.38, 13.2, 10, 23.22, 35.01, 9.0, 'draft'),
('0242510060', 'PARENT0242510060', 'CSE1111', 'Spring 2025', 'A', 12.85, 9.55, 8.98, 19.18, 38.88, 10, 'approved'),
('0242510060', 'PARENT0242510060', 'CSE4533', 'Summer 2025', 'A', 11.82, 8.23, 7.54, 14.83, 18, 9.0, 'approved'),
('0242510060', 'PARENT0242510060', 'CSE3313', 'Fall 2025', 'B', 15, 12.1, 10, 22.3, 38.13, 9.0, 'approved'),
('0242510060', 'PARENT0242510060', 'CSE4165', 'Fall 2025', 'C', 11.05, 13.99, 9.35, 21.48, 35.79, 9.0, 'approved'),
('0242510060', 'PARENT0242510060', 'CSE4509', 'Spring 2026', 'A', 11.21, 10.39, 7.02, 22.48, 18.83, 7.0, 'draft'),
('0242510060', 'PARENT0242510060', 'CSE3711', 'Spring 2026', 'B', 10.44, 12.41, 6.98, 14.05, 27.36, 10, 'submitted'),
('0242510061', 'PARENT0242510061', 'CSE1111', 'Spring 2025', 'A', 8.03, 13.42, 5.78, 15.28, 22.8, 8.0, 'approved'),
('0242510061', 'PARENT0242510061', 'CSE2215', 'Summer 2025', 'A', 11.81, 9.34, 6.56, 17.67, 32.11, 9.0, 'approved'),
('0242510061', 'PARENT0242510061', 'CSE3521', 'Fall 2025', 'A', 12.17, 10.0, 6.92, 13.69, 24.88, 10, 'approved'),
('0242510061', 'PARENT0242510061', 'CSE4509', 'Spring 2026', 'A', 14.92, 11.3, 8.06, 16.95, 40, 8.0, 'draft'),
('0242510062', 'PARENT0242510062', 'CSE1111', 'Spring 2025', 'A', 10.05, 10.67, 8.21, 13.7, 30.08, 10, 'approved'),
('0242510062', 'PARENT0242510062', 'CSE4533', 'Summer 2025', 'A', 13.01, 14.12, 8.31, 18.9, 40, 10, 'approved'),
('0242510062', 'PARENT0242510062', 'CSE3521', 'Fall 2025', 'A', 10.24, 8.51, 6.01, 11.06, 18.21, 9.0, 'approved'),
('0242510062', 'PARENT0242510062', 'CSE4509', 'Spring 2026', 'A', 14.63, 10.11, 7.52, 18.59, 40, 9.0, 'draft'),
('0242510063', 'PARENT0242510063', 'CSE1111', 'Spring 2025', 'A', 10.41, 6.21, 6.32, 13.52, 23.94, 7.0, 'approved'),
('0242510063', 'PARENT0242510063', 'CSE2215', 'Summer 2025', 'A', 9.82, 10.61, 5.99, 15.1, 26.52, 10, 'approved'),
('0242510063', 'PARENT0242510063', 'CSE3313', 'Fall 2025', 'B', 8.81, 7.86, 6.01, 15.56, 28.22, 7.0, 'approved'),
('0242510063', 'PARENT0242510063', 'CSE4509', 'Spring 2026', 'A', 10.83, 12.22, 5.31, 10, 30.35, 8.0, 'draft'),
('0242510063', 'PARENT0242510063', 'CSE4889', 'Spring 2026', 'C', 12.31, 14.12, 8.45, 16.52, 34.3, 7.0, 'draft'),
('0242510064', 'PARENT0242510064', 'CSE1111', 'Spring 2025', 'A', 13.76, 15, 5.22, 19.02, 28.57, 10, 'approved'),
('0242510064', 'PARENT0242510064', 'CSE4533', 'Summer 2025', 'A', 10.03, 11.14, 5.04, 10, 32.18, 7.0, 'approved'),
('0242510064', 'PARENT0242510064', 'CSE3521', 'Fall 2025', 'A', 10.9, 10.69, 8.89, 19.12, 26.46, 7.0, 'approved'),
('0242510064', 'PARENT0242510064', 'CSE4165', 'Fall 2025', 'C', 7.09, 7.93, 5.19, 12.9, 22.12, 7.0, 'approved'),
('0242510064', 'PARENT0242510064', 'CSE4509', 'Spring 2026', 'A', 13.14, 14.85, 6.5, 20.7, 40, 7.0, 'draft'),
('0242510065', 'PARENT0242510065', 'CSE1111', 'Spring 2025', 'A', 9.27, 8.9, 6.31, 16.39, 19.16, 9.0, 'approved'),
('0242510065', 'PARENT0242510065', 'CSE2215', 'Summer 2025', 'A', 13.26, 9.29, 5.46, 12.54, 26.07, 9.0, 'approved'),
('0242510065', 'PARENT0242510065', 'CSE3521', 'Fall 2025', 'A', 14.3, 15, 10, 22.03, 38.53, 8.0, 'approved'),
('0242510065', 'PARENT0242510065', 'CSE4509', 'Spring 2026', 'A', 10.02, 11.33, 7.94, 21.53, 33.41, 9.0, 'draft'),
('0242510065', 'PARENT0242510065', 'CSE3711', 'Spring 2026', 'B', 10.37, 12.36, 6.96, 25, 23.32, 8.0, 'submitted'),
('0242510066', 'PARENT0242510066', 'CSE1111', 'Spring 2025', 'A', 11.17, 9.64, 7.02, 15.83, 32.72, 10, 'approved'),
('0242510066', 'PARENT0242510066', 'CSE4533', 'Summer 2025', 'A', 11.12, 9.88, 5.24, 18.44, 28.48, 10, 'approved'),
('0242510066', 'PARENT0242510066', 'CSE3313', 'Fall 2025', 'B', 13.64, 14.2, 7.9, 18.04, 39.4, 10, 'approved'),
('0242510066', 'PARENT0242510066', 'CSE4509', 'Spring 2026', 'A', 7.73, 7.36, 6.32, 18.06, 18, 8.0, 'draft'),
('0242510067', 'PARENT0242510067', 'CSE1111', 'Spring 2025', 'A', 12.88, 9.13, 7.51, 16.13, 26.28, 10, 'approved'),
('0242510067', 'PARENT0242510067', 'CSE2215', 'Summer 2025', 'A', 10.64, 10.14, 8.99, 14.38, 31.38, 8.0, 'approved'),
('0242510067', 'PARENT0242510067', 'CSE3521', 'Fall 2025', 'A', 13.61, 12.95, 9.7, 22.42, 32.11, 10, 'approved'),
('0242510067', 'PARENT0242510067', 'CSE4509', 'Spring 2026', 'A', 12.88, 10.34, 8.67, 22.49, 36.15, 10, 'draft'),
('0242510068', 'PARENT0242510068', 'CSE1111', 'Spring 2025', 'A', 11.53, 11.72, 6.37, 16.95, 30.73, 10, 'approved'),
('0242510068', 'PARENT0242510068', 'CSE4533', 'Summer 2025', 'A', 14.09, 12.72, 8.13, 19.32, 25.74, 7.0, 'approved'),
('0242510068', 'PARENT0242510068', 'CSE3521', 'Fall 2025', 'A', 9.12, 12.08, 8.97, 24.12, 25.62, 9.0, 'approved'),
('0242510068', 'PARENT0242510068', 'CSE4165', 'Fall 2025', 'C', 8.51, 7.9, 7.55, 19.91, 24.9, 10, 'approved'),
('0242510068', 'PARENT0242510068', 'CSE4509', 'Spring 2026', 'A', 13.21, 12.2, 9.22, 21.69, 32.46, 10, 'draft'),
('0242510069', 'PARENT0242510069', 'CSE1111', 'Spring 2025', 'A', 12.51, 6.14, 6.34, 14.23, 32.47, 10, 'approved'),
('0242510069', 'PARENT0242510069', 'CSE2215', 'Summer 2025', 'A', 9.43, 8.6, 5, 15.11, 22.36, 7.0, 'approved'),
('0242510069', 'PARENT0242510069', 'CSE3313', 'Fall 2025', 'B', 12.83, 10.51, 7.43, 18.95, 33.66, 9.0, 'approved'),
('0242510069', 'PARENT0242510069', 'CSE4509', 'Spring 2026', 'A', 11.02, 11.34, 6.16, 18.72, 34.79, 8.0, 'draft'),
('0242510070', 'PARENT0242510070', 'CSE1111', 'Spring 2025', 'A', 10.1, 11.01, 9.19, 19.3, 21.93, 10, 'approved'),
('0242510070', 'PARENT0242510070', 'CSE4533', 'Summer 2025', 'A', 9.62, 9.24, 7.56, 12.92, 23.86, 8.0, 'approved'),
('0242510070', 'PARENT0242510070', 'CSE3521', 'Fall 2025', 'A', 11.18, 9.86, 8.89, 20.54, 30.54, 9.0, 'approved'),
('0242510070', 'PARENT0242510070', 'CSE4509', 'Spring 2026', 'A', 9.71, 10.07, 7.39, 14.55, 18.71, 10, 'draft'),
('0242510070', 'PARENT0242510070', 'CSE3711', 'Spring 2026', 'B', 12.14, 13.06, 10, 16.69, 39.56, 10, 'submitted'),
('0242510070', 'PARENT0242510070', 'CSE4889', 'Spring 2026', 'C', 10.41, 10.53, 6.8, 14.28, 30.19, 10, 'draft'),
('0242510071', 'PARENT0242510071', 'CSE1111', 'Spring 2025', 'A', 14.41, 14.05, 7.1, 20.72, 33.1, 7.0, 'approved'),
('0242510071', 'PARENT0242510071', 'CSE2215', 'Summer 2025', 'A', 9.36, 7.48, 5.95, 10, 24.95, 10, 'approved'),
('0242510071', 'PARENT0242510071', 'CSE3521', 'Fall 2025', 'A', 13.02, 15, 9.9, 25, 33.36, 10, 'approved'),
('0242510071', 'PARENT0242510071', 'CSE4509', 'Spring 2026', 'A', 12.85, 12.03, 7.51, 19.96, 28.32, 8.0, 'draft'),
('0242510072', 'PARENT0242510072', 'CSE1111', 'Spring 2025', 'A', 13.11, 13.01, 5.23, 12.18, 24.08, 10, 'approved'),
('0242510072', 'PARENT0242510072', 'CSE4533', 'Summer 2025', 'A', 11.68, 13.86, 7.48, 20.37, 34.15, 7.0, 'approved'),
('0242510072', 'PARENT0242510072', 'CSE3313', 'Fall 2025', 'B', 10.69, 12.32, 7.54, 23.23, 31.63, 10, 'approved'),
('0242510072', 'PARENT0242510072', 'CSE4165', 'Fall 2025', 'C', 9.36, 7.79, 5.6, 19.49, 24.93, 7.0, 'approved'),
('0242510072', 'PARENT0242510072', 'CSE4509', 'Spring 2026', 'A', 14.74, 12.39, 5.98, 19.08, 34.72, 7.0, 'draft'),
('0242510073', 'PARENT0242510073', 'CSE1111', 'Spring 2025', 'A', 10.54, 12.16, 7.48, 15.82, 30.75, 10, 'approved'),
('0242510073', 'PARENT0242510073', 'CSE2215', 'Summer 2025', 'A', 10.13, 12.73, 8.29, 23.26, 37.77, 7.0, 'approved'),
('0242510073', 'PARENT0242510073', 'CSE3521', 'Fall 2025', 'A', 11.83, 12.96, 10, 14.55, 35.83, 10, 'approved'),
('0242510073', 'PARENT0242510073', 'CSE4509', 'Spring 2026', 'A', 14.78, 12.55, 9.82, 22.73, 22.64, 8.0, 'draft'),
('0242510074', 'PARENT0242510074', 'CSE1111', 'Spring 2025', 'A', 11.8, 12.47, 8.95, 19.2, 35.54, 9.0, 'approved'),
('0242510074', 'PARENT0242510074', 'CSE4533', 'Summer 2025', 'A', 14.55, 8.29, 6.79, 21.36, 34.28, 7.0, 'approved'),
('0242510074', 'PARENT0242510074', 'CSE3521', 'Fall 2025', 'A', 14.58, 15, 9.98, 16.25, 28.32, 9.0, 'approved'),
('0242510074', 'PARENT0242510074', 'CSE4509', 'Spring 2026', 'A', 8.7, 8.64, 6.5, 12.99, 19.42, 8.0, 'draft'),
('0242510075', 'PARENT0242510075', 'CSE1111', 'Spring 2025', 'A', 12.18, 8.81, 7.99, 16.02, 29.82, 9.0, 'approved'),
('0242510075', 'PARENT0242510075', 'CSE2215', 'Summer 2025', 'A', 9.07, 10.7, 5.96, 17.81, 18, 9.0, 'approved'),
('0242510075', 'PARENT0242510075', 'CSE3313', 'Fall 2025', 'B', 9.34, 9.18, 6.38, 18.57, 29.78, 9.0, 'approved'),
('0242510075', 'PARENT0242510075', 'CSE4509', 'Spring 2026', 'A', 8.9, 8.1, 6.4, 11.27, 28.02, 9.0, 'draft'),
('0242510075', 'PARENT0242510075', 'CSE3711', 'Spring 2026', 'B', 10.87, 12.82, 6.75, 21.35, 22.26, 9.0, 'submitted'),
('0242510076', 'PARENT0242510076', 'CSE1111', 'Spring 2025', 'A', 14.98, 11.45, 8.43, 22.63, 28.55, 10, 'approved'),
('0242510076', 'PARENT0242510076', 'CSE4533', 'Summer 2025', 'A', 14.68, 8.83, 6.67, 20.08, 19.88, 8.0, 'approved'),
('0242510076', 'PARENT0242510076', 'CSE3521', 'Fall 2025', 'A', 14.95, 11.12, 7.66, 24.19, 30.52, 10, 'approved'),
('0242510076', 'PARENT0242510076', 'CSE4165', 'Fall 2025', 'C', 11.64, 9.88, 7.28, 17.59, 25.99, 9.0, 'approved'),
('0242510076', 'PARENT0242510076', 'CSE4509', 'Spring 2026', 'A', 11.87, 10.69, 7.47, 13.88, 32.68, 10, 'draft'),
('0242510077', 'PARENT0242510077', 'CSE1111', 'Spring 2025', 'A', 13.82, 13.53, 8.98, 19.27, 36.32, 10, 'approved'),
('0242510077', 'PARENT0242510077', 'CSE2215', 'Summer 2025', 'A', 8.53, 12.29, 6.22, 19.82, 23.8, 10, 'approved'),
('0242510077', 'PARENT0242510077', 'CSE3521', 'Fall 2025', 'A', 9.47, 9.36, 5.3, 17.0, 21.61, 10, 'approved'),
('0242510077', 'PARENT0242510077', 'CSE4509', 'Spring 2026', 'A', 15, 11.38, 8.89, 16.31, 36.21, 8.0, 'draft'),
('0242510077', 'PARENT0242510077', 'CSE4889', 'Spring 2026', 'C', 13.67, 13.33, 8.39, 25, 38.59, 9.0, 'draft'),
('0242510078', 'PARENT0242510078', 'CSE1111', 'Spring 2025', 'A', 10.74, 7.74, 6.65, 18.18, 19.8, 10, 'approved'),
('0242510078', 'PARENT0242510078', 'CSE4533', 'Summer 2025', 'A', 13.35, 12.5, 7.24, 17.55, 32.34, 8.0, 'approved'),
('0242510078', 'PARENT0242510078', 'CSE3313', 'Fall 2025', 'B', 6.99, 11.93, 6.28, 12.35, 20.61, 10, 'approved'),
('0242510078', 'PARENT0242510078', 'CSE4509', 'Spring 2026', 'A', 14.57, 14.16, 7.03, 18.43, 30.75, 8.0, 'draft'),
('0242510079', 'PARENT0242510079', 'CSE1111', 'Spring 2025', 'A', 9.45, 9.9, 8.12, 14.62, 22.37, 9.0, 'approved'),
('0242510079', 'PARENT0242510079', 'CSE2215', 'Summer 2025', 'A', 14.16, 14.66, 8.31, 18.57, 40, 10, 'approved'),
('0242510079', 'PARENT0242510079', 'CSE3521', 'Fall 2025', 'A', 9.0, 12.15, 7.03, 15.48, 18, 8.0, 'approved'),
('0242510079', 'PARENT0242510079', 'CSE4509', 'Spring 2026', 'A', 12.45, 14.06, 7.85, 23.12, 38.78, 7.0, 'draft'),
('0242510080', 'PARENT0242510080', 'CSE1111', 'Spring 2025', 'A', 7.97, 8.91, 5.71, 13.75, 26.43, 7.0, 'approved'),
('0242510080', 'PARENT0242510080', 'CSE4533', 'Summer 2025', 'A', 8.91, 7.67, 6.12, 14.66, 25.53, 7.0, 'approved'),
('0242510080', 'PARENT0242510080', 'CSE3521', 'Fall 2025', 'A', 7.17, 8.22, 8.99, 18.29, 27.02, 8.0, 'approved'),
('0242510080', 'PARENT0242510080', 'CSE4165', 'Fall 2025', 'C', 13.57, 9.42, 8.54, 15.44, 32.05, 7.0, 'approved'),
('0242510080', 'PARENT0242510080', 'CSE4509', 'Spring 2026', 'A', 12.13, 12.92, 8.64, 20.81, 25.07, 10, 'draft'),
('0242510080', 'PARENT0242510080', 'CSE3711', 'Spring 2026', 'B', 8.12, 9.01, 6.16, 14.4, 29.2, 10, 'submitted'),
('0242520001', 'PARENT0242520001', 'EEE1001', 'Spring 2025', 'A', 9.13, 7.61, 5, 15.37, 18.76, 7.0, 'approved'),
('0242520001', 'PARENT0242520001', 'EEE1003', 'Summer 2025', 'A', 9.88, 9.61, 8.38, 12.98, 20.75, 8.0, 'approved'),
('0242520001', 'PARENT0242520001', 'EEE2101', 'Fall 2025', 'B', 7.08, 11.0, 5.98, 14.53, 23.43, 7.0, 'approved'),
('0242520001', 'PARENT0242520001', 'EEE3307', 'Spring 2026', 'A', 14.22, 12.16, 9.13, 21.37, 40, 9.0, 'draft'),
('0242520001', 'PARENT0242520001', 'EEE4109', 'Spring 2026', 'A', 11.7, 15, 8.83, 24.06, 30.81, 9.0, 'submitted'),
('0242520002', 'PARENT0242520002', 'EEE1001', 'Spring 2025', 'A', 11.82, 13.05, 5.54, 17.23, 23.06, 10, 'approved'),
('0242520002', 'PARENT0242520002', 'EEE1003', 'Summer 2025', 'A', 14.11, 9.47, 8.44, 16.78, 28.7, 8.0, 'approved'),
('0242520002', 'PARENT0242520002', 'EEE2101', 'Fall 2025', 'B', 10.71, 10.42, 7.81, 18.07, 23.35, 10, 'approved'),
('0242520002', 'PARENT0242520002', 'EEE3307', 'Spring 2026', 'A', 10.26, 8.15, 5.05, 17.06, 30.78, 8.0, 'draft'),
('0242520002', 'PARENT0242520002', 'EEE4109', 'Spring 2026', 'A', 8.6, 8.13, 7.81, 21.02, 34.37, 10, 'submitted'),
('0242520003', 'PARENT0242520003', 'EEE1001', 'Spring 2025', 'A', 12.31, 13.59, 8.42, 25, 35.89, 10, 'approved'),
('0242520003', 'PARENT0242520003', 'EEE1003', 'Summer 2025', 'A', 11.36, 9.06, 7.18, 18.5, 23.68, 8.0, 'approved'),
('0242520003', 'PARENT0242520003', 'EEE2101', 'Fall 2025', 'B', 9.07, 9.27, 5.76, 16.32, 22.26, 7.0, 'approved'),
('0242520003', 'PARENT0242520003', 'EEE3307', 'Spring 2026', 'A', 12.43, 10.09, 7.32, 18.33, 29.88, 8.0, 'draft'),
('0242520003', 'PARENT0242520003', 'EEE4109', 'Spring 2026', 'A', 11.7, 12.16, 7.88, 22.53, 34.4, 9.0, 'submitted'),
('0242520004', 'PARENT0242520004', 'EEE1001', 'Spring 2025', 'A', 10.1, 11.4, 7.49, 19.47, 23.69, 8.0, 'approved'),
('0242520004', 'PARENT0242520004', 'EEE1003', 'Summer 2025', 'A', 9.59, 9.43, 6.75, 13.28, 18, 7.0, 'approved'),
('0242520004', 'PARENT0242520004', 'EEE2101', 'Fall 2025', 'B', 12.63, 14.22, 9.5, 17.56, 28.23, 9.0, 'approved'),
('0242520004', 'PARENT0242520004', 'EEE3307', 'Spring 2026', 'A', 11.28, 9.74, 6.57, 21.46, 18.43, 10, 'draft'),
('0242520004', 'PARENT0242520004', 'EEE4109', 'Spring 2026', 'A', 12.18, 12.42, 8.73, 24.56, 32.9, 7.0, 'submitted'),
('0242520005', 'PARENT0242520005', 'EEE1001', 'Spring 2025', 'A', 10.6, 10.49, 8.89, 15.86, 25.37, 9.0, 'approved'),
('0242520005', 'PARENT0242520005', 'EEE1003', 'Summer 2025', 'A', 10.51, 10.48, 9.75, 18.56, 30.38, 9.0, 'approved'),
('0242520005', 'PARENT0242520005', 'EEE2101', 'Fall 2025', 'B', 7.96, 12.15, 6.04, 20.36, 19.54, 10, 'approved'),
('0242520005', 'PARENT0242520005', 'EEE3307', 'Spring 2026', 'A', 9.71, 13.53, 10, 23.39, 33.28, 10, 'draft'),
('0242520005', 'PARENT0242520005', 'EEE4109', 'Spring 2026', 'A', 11.27, 10.0, 6.52, 19.55, 32.52, 8.0, 'submitted'),
('0242520006', 'PARENT0242520006', 'EEE1001', 'Spring 2025', 'A', 13.56, 9.88, 9.09, 25, 32.06, 8.0, 'approved'),
('0242520006', 'PARENT0242520006', 'EEE1003', 'Summer 2025', 'A', 13.88, 5.85, 6.81, 17.28, 29.51, 7.0, 'approved'),
('0242520006', 'PARENT0242520006', 'EEE2101', 'Fall 2025', 'B', 11.27, 10.45, 5.35, 16.52, 26.32, 10, 'approved'),
('0242520006', 'PARENT0242520006', 'EEE3307', 'Spring 2026', 'A', 14.23, 15, 10, 18.79, 35.85, 7.0, 'draft'),
('0242520006', 'PARENT0242520006', 'EEE4109', 'Spring 2026', 'A', 10.81, 6.15, 6.83, 18.13, 29.07, 10, 'submitted'),
('0242520007', 'PARENT0242520007', 'EEE1001', 'Spring 2025', 'A', 11.81, 12.92, 8.89, 19.57, 28.03, 10, 'approved'),
('0242520007', 'PARENT0242520007', 'EEE1003', 'Summer 2025', 'A', 12.34, 10.36, 7.03, 23.69, 29.54, 7.0, 'approved'),
('0242520007', 'PARENT0242520007', 'EEE2101', 'Fall 2025', 'B', 10.91, 8.77, 6.01, 20.45, 23.76, 10, 'approved'),
('0242520007', 'PARENT0242520007', 'EEE3307', 'Spring 2026', 'A', 15, 12.45, 8.48, 22.07, 23.29, 7.0, 'draft'),
('0242520007', 'PARENT0242520007', 'EEE4109', 'Spring 2026', 'A', 11.12, 8.86, 5.89, 16.76, 25.77, 7.0, 'submitted'),
('0242520008', 'PARENT0242520008', 'EEE1001', 'Spring 2025', 'A', 14.72, 8.09, 5.93, 15.41, 28.39, 9.0, 'approved'),
('0242520008', 'PARENT0242520008', 'EEE1003', 'Summer 2025', 'A', 13.11, 8.77, 7.57, 20.19, 26.34, 9.0, 'approved'),
('0242520008', 'PARENT0242520008', 'EEE2101', 'Fall 2025', 'B', 11.77, 10.26, 5, 14.33, 24.45, 7.0, 'approved'),
('0242520008', 'PARENT0242520008', 'EEE3307', 'Spring 2026', 'A', 13.96, 13.19, 9.3, 21.99, 34.43, 8.0, 'draft'),
('0242520008', 'PARENT0242520008', 'EEE4109', 'Spring 2026', 'A', 11.29, 9.45, 5, 18.06, 18, 8.0, 'submitted'),
('0242520009', 'PARENT0242520009', 'EEE1001', 'Spring 2025', 'A', 12.22, 11.62, 5.66, 15.47, 27.7, 7.0, 'approved'),
('0242520009', 'PARENT0242520009', 'EEE1003', 'Summer 2025', 'A', 11.38, 5.82, 6.41, 13.61, 28.38, 7.0, 'approved'),
('0242520009', 'PARENT0242520009', 'EEE2101', 'Fall 2025', 'B', 15, 10.39, 10, 25, 27.9, 7.0, 'approved'),
('0242520009', 'PARENT0242520009', 'EEE3307', 'Spring 2026', 'A', 10.1, 8.3, 5.65, 10.76, 20.49, 9.0, 'draft'),
('0242520009', 'PARENT0242520009', 'EEE4109', 'Spring 2026', 'A', 11.99, 10.74, 6.26, 16.09, 32.69, 10, 'submitted'),
('0242520010', 'PARENT0242520010', 'EEE1001', 'Spring 2025', 'A', 8.07, 11.98, 8.66, 11.84, 28.93, 7.0, 'approved'),
('0242520010', 'PARENT0242520010', 'EEE1003', 'Summer 2025', 'A', 14.27, 14.64, 9.35, 15.32, 32.08, 7.0, 'approved'),
('0242520010', 'PARENT0242520010', 'EEE2101', 'Fall 2025', 'B', 10.95, 7.07, 5, 14.8, 27.93, 9.0, 'approved'),
('0242520010', 'PARENT0242520010', 'EEE3307', 'Spring 2026', 'A', 14.31, 13.3, 7.03, 16.5, 33.14, 10, 'draft'),
('0242520010', 'PARENT0242520010', 'EEE4109', 'Spring 2026', 'A', 9.44, 8.29, 5.37, 16.2, 25.79, 7.0, 'submitted'),
('0242520011', 'PARENT0242520011', 'EEE1001', 'Spring 2025', 'A', 12.79, 15, 10, 25, 24.26, 9.0, 'approved'),
('0242520011', 'PARENT0242520011', 'EEE1003', 'Summer 2025', 'A', 10.28, 9.9, 6.23, 21.07, 24.29, 8.0, 'approved'),
('0242520011', 'PARENT0242520011', 'EEE2101', 'Fall 2025', 'B', 12.32, 12.79, 7.96, 16.64, 32.17, 10, 'approved'),
('0242520011', 'PARENT0242520011', 'EEE3307', 'Spring 2026', 'A', 9.88, 12.01, 6.53, 12.94, 24.36, 10, 'draft'),
('0242520011', 'PARENT0242520011', 'EEE4109', 'Spring 2026', 'A', 15, 11.96, 7.94, 18.24, 30.69, 10, 'submitted'),
('0242520012', 'PARENT0242520012', 'EEE1001', 'Spring 2025', 'A', 13.55, 9.86, 8.05, 14.98, 34.79, 10, 'approved'),
('0242520012', 'PARENT0242520012', 'EEE1003', 'Summer 2025', 'A', 10.96, 9.1, 6.3, 16.28, 24.57, 10, 'approved'),
('0242520012', 'PARENT0242520012', 'EEE2101', 'Fall 2025', 'B', 9.08, 9.44, 6.58, 21.67, 23.0, 10, 'approved'),
('0242520012', 'PARENT0242520012', 'EEE3307', 'Spring 2026', 'A', 8.41, 10.25, 5.04, 11.09, 20.48, 7.0, 'draft'),
('0242520012', 'PARENT0242520012', 'EEE4109', 'Spring 2026', 'A', 6.64, 10.81, 5.93, 11.66, 22.28, 9.0, 'submitted'),
('0242520013', 'PARENT0242520013', 'EEE1001', 'Spring 2025', 'A', 10.88, 10.64, 7.43, 19.18, 31.58, 9.0, 'approved'),
('0242520013', 'PARENT0242520013', 'EEE1003', 'Summer 2025', 'A', 13.62, 13.6, 8.23, 19.55, 32.42, 7.0, 'approved'),
('0242520013', 'PARENT0242520013', 'EEE2101', 'Fall 2025', 'B', 13.59, 15, 6.58, 17.14, 34.47, 8.0, 'approved'),
('0242520013', 'PARENT0242520013', 'EEE3307', 'Spring 2026', 'A', 6.17, 11.64, 7.25, 16.42, 29.47, 9.0, 'draft'),
('0242520013', 'PARENT0242520013', 'EEE4109', 'Spring 2026', 'A', 13.73, 13.34, 7.31, 22.61, 34.28, 10, 'submitted'),
('0242520014', 'PARENT0242520014', 'EEE1001', 'Spring 2025', 'A', 7.76, 9.47, 8.15, 11.81, 31.23, 9.0, 'approved'),
('0242520014', 'PARENT0242520014', 'EEE1003', 'Summer 2025', 'A', 11.69, 10.09, 5.22, 15.59, 25.63, 8.0, 'approved'),
('0242520014', 'PARENT0242520014', 'EEE2101', 'Fall 2025', 'B', 5.76, 10.76, 6.73, 21.98, 24.26, 10, 'approved'),
('0242520014', 'PARENT0242520014', 'EEE3307', 'Spring 2026', 'A', 8.77, 9.16, 5, 16.8, 18, 8.0, 'draft'),
('0242520014', 'PARENT0242520014', 'EEE4109', 'Spring 2026', 'A', 12.47, 14.5, 9.53, 22.85, 35.57, 8.0, 'submitted'),
('0242520015', 'PARENT0242520015', 'EEE1001', 'Spring 2025', 'A', 11.69, 9.86, 5.87, 15.32, 23.14, 10, 'approved'),
('0242520015', 'PARENT0242520015', 'EEE1003', 'Summer 2025', 'A', 10.99, 9.03, 6.73, 15.21, 18, 10, 'approved'),
('0242520015', 'PARENT0242520015', 'EEE2101', 'Fall 2025', 'B', 12.37, 8.36, 5.96, 14.44, 23.8, 10, 'approved'),
('0242520015', 'PARENT0242520015', 'EEE3307', 'Spring 2026', 'A', 12.11, 11.62, 8.99, 24.45, 33.74, 8.0, 'draft'),
('0242520015', 'PARENT0242520015', 'EEE4109', 'Spring 2026', 'A', 15, 13.78, 7.62, 18.67, 34.57, 9.0, 'submitted'),
('0242520016', 'PARENT0242520016', 'EEE1001', 'Spring 2025', 'A', 10.42, 11.29, 7.45, 14.04, 28.99, 9.0, 'approved'),
('0242520016', 'PARENT0242520016', 'EEE1003', 'Summer 2025', 'A', 12.9, 12.92, 7.88, 19.79, 28.48, 10, 'approved'),
('0242520016', 'PARENT0242520016', 'EEE2101', 'Fall 2025', 'B', 13.68, 10.64, 8.73, 13.61, 35.63, 9.0, 'approved'),
('0242520016', 'PARENT0242520016', 'EEE3307', 'Spring 2026', 'A', 8.58, 9.35, 6.13, 10.95, 18, 8.0, 'draft'),
('0242520016', 'PARENT0242520016', 'EEE4109', 'Spring 2026', 'A', 12.04, 14.01, 7.91, 16.6, 32.45, 10, 'submitted'),
('0242520017', 'PARENT0242520017', 'EEE1001', 'Spring 2025', 'A', 10.03, 6.54, 5.15, 10, 18.83, 10, 'approved'),
('0242520017', 'PARENT0242520017', 'EEE1003', 'Summer 2025', 'A', 10.46, 10.1, 6.99, 15.27, 28.9, 7.0, 'approved'),
('0242520017', 'PARENT0242520017', 'EEE2101', 'Fall 2025', 'B', 10.26, 12.32, 9.14, 17.57, 30.36, 8.0, 'approved'),
('0242520017', 'PARENT0242520017', 'EEE3307', 'Spring 2026', 'A', 10.28, 10.12, 6.86, 13.32, 20.5, 9.0, 'draft'),
('0242520017', 'PARENT0242520017', 'EEE4109', 'Spring 2026', 'A', 10.7, 15, 8.24, 13.96, 29.25, 10, 'submitted'),
('0242520018', 'PARENT0242520018', 'EEE1001', 'Spring 2025', 'A', 14.57, 11.11, 6.18, 18.01, 26.95, 7.0, 'approved'),
('0242520018', 'PARENT0242520018', 'EEE1003', 'Summer 2025', 'A', 15, 14.07, 8.9, 22.02, 33.02, 10, 'approved'),
('0242520018', 'PARENT0242520018', 'EEE2101', 'Fall 2025', 'B', 12.71, 13.31, 7.02, 21.16, 34.93, 10, 'approved'),
('0242520018', 'PARENT0242520018', 'EEE3307', 'Spring 2026', 'A', 5.48, 11.73, 5, 17.79, 24.53, 8.0, 'draft'),
('0242520018', 'PARENT0242520018', 'EEE4109', 'Spring 2026', 'A', 9.32, 12.3, 6.62, 16.08, 29.05, 7.0, 'submitted'),
('0242520019', 'PARENT0242520019', 'EEE1001', 'Spring 2025', 'A', 13.2, 9.48, 6.52, 14.26, 28.17, 10, 'approved'),
('0242520019', 'PARENT0242520019', 'EEE1003', 'Summer 2025', 'A', 10.79, 10.52, 7.18, 12.62, 30.16, 9.0, 'approved'),
('0242520019', 'PARENT0242520019', 'EEE2101', 'Fall 2025', 'B', 13.47, 10.99, 9.16, 17.54, 22.32, 8.0, 'approved'),
('0242520019', 'PARENT0242520019', 'EEE3307', 'Spring 2026', 'A', 13.13, 14.16, 8.75, 20.62, 40, 10, 'draft'),
('0242520019', 'PARENT0242520019', 'EEE4109', 'Spring 2026', 'A', 12.24, 14.09, 8.13, 20.63, 31.18, 10, 'submitted'),
('0242520020', 'PARENT0242520020', 'EEE1001', 'Spring 2025', 'A', 10.2, 11.15, 5.27, 13.6, 20.15, 10, 'approved'),
('0242520020', 'PARENT0242520020', 'EEE1003', 'Summer 2025', 'A', 10.48, 11.88, 6.95, 25, 37.83, 10, 'approved'),
('0242520020', 'PARENT0242520020', 'EEE2101', 'Fall 2025', 'B', 9.32, 13.52, 8.35, 22.47, 33.49, 9.0, 'approved'),
('0242520020', 'PARENT0242520020', 'EEE3307', 'Spring 2026', 'A', 11.94, 10.03, 7.56, 16.53, 24.75, 9.0, 'draft'),
('0242520020', 'PARENT0242520020', 'EEE4109', 'Spring 2026', 'A', 11.78, 8.03, 7.92, 18.72, 25.09, 10, 'submitted'),
('0242520021', 'PARENT0242520021', 'EEE1001', 'Spring 2025', 'A', 11.31, 9.53, 8.19, 20.14, 25.66, 9.0, 'approved'),
('0242520021', 'PARENT0242520021', 'EEE1003', 'Summer 2025', 'A', 12.34, 8.57, 8.32, 18.99, 31.6, 7.0, 'approved'),
('0242520021', 'PARENT0242520021', 'EEE2101', 'Fall 2025', 'B', 12.32, 11.29, 8.51, 17.88, 31.4, 10, 'approved'),
('0242520021', 'PARENT0242520021', 'EEE3307', 'Spring 2026', 'A', 14.61, 11.86, 7.62, 12.21, 32.87, 9.0, 'draft'),
('0242520021', 'PARENT0242520021', 'EEE4109', 'Spring 2026', 'A', 12.51, 15, 6.56, 16.44, 28.62, 8.0, 'submitted'),
('0242520022', 'PARENT0242520022', 'EEE1001', 'Spring 2025', 'A', 11.77, 12.37, 7.13, 17.06, 27.19, 8.0, 'approved'),
('0242520022', 'PARENT0242520022', 'EEE1003', 'Summer 2025', 'A', 14.07, 15, 8.49, 17.57, 38.84, 9.0, 'approved'),
('0242520022', 'PARENT0242520022', 'EEE2101', 'Fall 2025', 'B', 11.98, 6.66, 5, 18.23, 22.98, 9.0, 'approved'),
('0242520022', 'PARENT0242520022', 'EEE3307', 'Spring 2026', 'A', 9.48, 6.98, 7.7, 17.99, 25.46, 10, 'draft'),
('0242520022', 'PARENT0242520022', 'EEE4109', 'Spring 2026', 'A', 11.79, 7.46, 5.7, 17.69, 26.0, 10, 'submitted'),
('0242520023', 'PARENT0242520023', 'EEE1001', 'Spring 2025', 'A', 12.04, 13.3, 8.0, 18.73, 32.8, 10, 'approved'),
('0242520023', 'PARENT0242520023', 'EEE1003', 'Summer 2025', 'A', 11.27, 12.22, 5.06, 15.64, 33.49, 10, 'approved'),
('0242520023', 'PARENT0242520023', 'EEE2101', 'Fall 2025', 'B', 7.39, 5.75, 6.12, 14.67, 23.81, 7.0, 'approved'),
('0242520023', 'PARENT0242520023', 'EEE3307', 'Spring 2026', 'A', 14.22, 12.74, 5.23, 19.68, 22.27, 10, 'draft'),
('0242520023', 'PARENT0242520023', 'EEE4109', 'Spring 2026', 'A', 10.43, 11.44, 8.03, 13.72, 21.87, 10, 'submitted'),
('0242520024', 'PARENT0242520024', 'EEE1001', 'Spring 2025', 'A', 15, 13.38, 7.94, 18.84, 34.31, 9.0, 'approved'),
('0242520024', 'PARENT0242520024', 'EEE1003', 'Summer 2025', 'A', 8.63, 10.31, 6.8, 16.9, 30.65, 7.0, 'approved'),
('0242520024', 'PARENT0242520024', 'EEE2101', 'Fall 2025', 'B', 10.27, 10.03, 7.11, 12.62, 18, 7.0, 'approved'),
('0242520024', 'PARENT0242520024', 'EEE3307', 'Spring 2026', 'A', 11.9, 11.02, 5, 20.73, 19.19, 9.0, 'draft'),
('0242520024', 'PARENT0242520024', 'EEE4109', 'Spring 2026', 'A', 10.37, 6.92, 8.01, 13.04, 29.02, 9.0, 'submitted'),
('0242520025', 'PARENT0242520025', 'EEE1001', 'Spring 2025', 'A', 9.03, 8.97, 7.11, 12.89, 33.17, 9.0, 'approved'),
('0242520025', 'PARENT0242520025', 'EEE1003', 'Summer 2025', 'A', 11.38, 9.38, 5.68, 22.97, 30.19, 9.0, 'approved'),
('0242520025', 'PARENT0242520025', 'EEE2101', 'Fall 2025', 'B', 12.79, 10.73, 6.48, 14.38, 33.84, 10, 'approved'),
('0242520025', 'PARENT0242520025', 'EEE3307', 'Spring 2026', 'A', 7.07, 12.51, 5, 17.19, 18, 7.0, 'draft'),
('0242520025', 'PARENT0242520025', 'EEE4109', 'Spring 2026', 'A', 10.96, 9.91, 6.59, 15.99, 32.75, 10, 'submitted'),
('0242520026', 'PARENT0242520026', 'EEE1001', 'Spring 2025', 'A', 15, 9.32, 7.8, 23.13, 32.16, 9.0, 'approved'),
('0242520026', 'PARENT0242520026', 'EEE1003', 'Summer 2025', 'A', 14.14, 9.5, 9.01, 21.61, 31.82, 9.0, 'approved'),
('0242520026', 'PARENT0242520026', 'EEE2101', 'Fall 2025', 'B', 12.23, 10.58, 5, 16.85, 31.82, 10, 'approved'),
('0242520026', 'PARENT0242520026', 'EEE3307', 'Spring 2026', 'A', 13.55, 9.38, 7.42, 11.45, 35.04, 9.0, 'draft'),
('0242520026', 'PARENT0242520026', 'EEE4109', 'Spring 2026', 'A', 13.91, 14.31, 5, 12.48, 26.45, 9.0, 'submitted'),
('0242520027', 'PARENT0242520027', 'EEE1001', 'Spring 2025', 'A', 8.53, 10.45, 5.62, 18.48, 20.76, 8.0, 'approved'),
('0242520027', 'PARENT0242520027', 'EEE1003', 'Summer 2025', 'A', 13.0, 10.55, 7.38, 21.13, 25.33, 7.0, 'approved'),
('0242520027', 'PARENT0242520027', 'EEE2101', 'Fall 2025', 'B', 10.04, 14.57, 7.45, 21.27, 24.8, 10, 'approved'),
('0242520027', 'PARENT0242520027', 'EEE3307', 'Spring 2026', 'A', 9.6, 9.7, 8.87, 21.81, 29.98, 7.0, 'draft'),
('0242520027', 'PARENT0242520027', 'EEE4109', 'Spring 2026', 'A', 12.32, 9.82, 6.97, 14.78, 25.37, 7.0, 'submitted'),
('0242520028', 'PARENT0242520028', 'EEE1001', 'Spring 2025', 'A', 11.98, 12.87, 7.46, 21.73, 37.99, 10, 'approved'),
('0242520028', 'PARENT0242520028', 'EEE1003', 'Summer 2025', 'A', 5.65, 9.21, 6.74, 13.33, 21.16, 9.0, 'approved'),
('0242520028', 'PARENT0242520028', 'EEE2101', 'Fall 2025', 'B', 12.27, 12.92, 7.83, 20.71, 25.61, 8.0, 'approved'),
('0242520028', 'PARENT0242520028', 'EEE3307', 'Spring 2026', 'A', 15, 9.31, 10, 22.8, 37.74, 10, 'draft'),
('0242520028', 'PARENT0242520028', 'EEE4109', 'Spring 2026', 'A', 14.42, 15, 10, 23.98, 33.87, 7.0, 'submitted'),
('0242520029', 'PARENT0242520029', 'EEE1001', 'Spring 2025', 'A', 13.27, 12.9, 7.65, 25, 40, 10, 'approved'),
('0242520029', 'PARENT0242520029', 'EEE1003', 'Summer 2025', 'A', 7.53, 10.36, 7.85, 11.96, 27.87, 10, 'approved'),
('0242520029', 'PARENT0242520029', 'EEE2101', 'Fall 2025', 'B', 15, 14.61, 7.91, 24.97, 36.39, 10, 'approved'),
('0242520029', 'PARENT0242520029', 'EEE3307', 'Spring 2026', 'A', 13.66, 15, 9.47, 22.02, 24.46, 8.0, 'draft'),
('0242520029', 'PARENT0242520029', 'EEE4109', 'Spring 2026', 'A', 8.19, 9.13, 5, 12.44, 20.72, 10, 'submitted'),
('0242520030', 'PARENT0242520030', 'EEE1001', 'Spring 2025', 'A', 10.78, 11.84, 8.07, 21.39, 34.14, 8.0, 'approved'),
('0242520030', 'PARENT0242520030', 'EEE1003', 'Summer 2025', 'A', 9.33, 7.5, 6.51, 10, 23.91, 7.0, 'approved'),
('0242520030', 'PARENT0242520030', 'EEE2101', 'Fall 2025', 'B', 12.13, 11.14, 7.67, 15.94, 29.82, 10, 'approved'),
('0242520030', 'PARENT0242520030', 'EEE3307', 'Spring 2026', 'A', 12.05, 13.73, 7.81, 15.87, 40, 7.0, 'draft'),
('0242520030', 'PARENT0242520030', 'EEE4109', 'Spring 2026', 'A', 14.19, 13.3, 9.05, 24.58, 39.98, 8.0, 'submitted'),
('0242530001', 'PARENT0242530001', 'BUS1102', 'Spring 2025', 'A', 14.4, 15, 7.83, 17.95, 40, 7.0, 'approved'),
('0242530001', 'PARENT0242530001', 'ACN1205', 'Summer 2025', 'B', 10.98, 13.4, 8.09, 14.85, 18, 7.0, 'approved'),
('0242530001', 'PARENT0242530001', 'MKT2320', 'Fall 2025', 'C', 9.42, 15, 7.42, 25, 24.18, 7.0, 'approved'),
('0242530001', 'PARENT0242530001', 'FIN2319', 'Spring 2026', 'A', 10.46, 12.01, 7.08, 19.5, 29.96, 8.0, 'draft'),
('0242530001', 'PARENT0242530001', 'MGT3122', 'Spring 2026', 'B', 13.97, 12.16, 7.62, 20.87, 29.03, 10, 'submitted'),
('0242530002', 'PARENT0242530002', 'BUS1102', 'Spring 2025', 'A', 15, 12.11, 5.45, 19.87, 28.91, 10, 'approved'),
('0242530002', 'PARENT0242530002', 'ACN1205', 'Summer 2025', 'B', 14.68, 8.98, 5.17, 22.54, 26.62, 10, 'approved'),
('0242530002', 'PARENT0242530002', 'MKT2320', 'Fall 2025', 'C', 10.62, 10.82, 6.93, 18.74, 38.01, 7.0, 'approved'),
('0242530002', 'PARENT0242530002', 'FIN2319', 'Spring 2026', 'A', 12.26, 14.49, 8.39, 20.82, 20.44, 10, 'draft'),
('0242530002', 'PARENT0242530002', 'MGT3122', 'Spring 2026', 'B', 8.43, 9.92, 6.49, 11.05, 26.27, 10, 'submitted'),
('0242530003', 'PARENT0242530003', 'BUS1102', 'Spring 2025', 'A', 10.77, 10.63, 6.1, 21.88, 20.6, 9.0, 'approved'),
('0242530003', 'PARENT0242530003', 'ACN1205', 'Summer 2025', 'B', 13.03, 11.94, 6.52, 22.49, 40, 9.0, 'approved'),
('0242530003', 'PARENT0242530003', 'MKT2320', 'Fall 2025', 'C', 8.83, 11.29, 5.28, 14.81, 23.44, 10, 'approved'),
('0242530003', 'PARENT0242530003', 'FIN2319', 'Spring 2026', 'A', 12.02, 11.4, 6.71, 20.52, 36.69, 8.0, 'draft'),
('0242530003', 'PARENT0242530003', 'MGT3122', 'Spring 2026', 'B', 11.44, 13.23, 6.91, 20.32, 25.85, 8.0, 'submitted'),
('0242530004', 'PARENT0242530004', 'BUS1102', 'Spring 2025', 'A', 11.71, 12.87, 8.8, 20.32, 37.54, 9.0, 'approved'),
('0242530004', 'PARENT0242530004', 'ACN1205', 'Summer 2025', 'B', 9.44, 8.97, 5, 20.99, 24.78, 10, 'approved'),
('0242530004', 'PARENT0242530004', 'MKT2320', 'Fall 2025', 'C', 8.5, 12.06, 7.14, 15.94, 30.33, 9.0, 'approved'),
('0242530004', 'PARENT0242530004', 'FIN2319', 'Spring 2026', 'A', 10.25, 15, 7.41, 17.08, 24.76, 7.0, 'draft'),
('0242530004', 'PARENT0242530004', 'MGT3122', 'Spring 2026', 'B', 9.39, 8.69, 5, 12.87, 26.72, 7.0, 'submitted'),
('0242530005', 'PARENT0242530005', 'BUS1102', 'Spring 2025', 'A', 11.4, 8.79, 5.17, 13.1, 34.39, 9.0, 'approved'),
('0242530005', 'PARENT0242530005', 'ACN1205', 'Summer 2025', 'B', 8.08, 10.22, 5.95, 20.07, 24.74, 10, 'approved'),
('0242530005', 'PARENT0242530005', 'MKT2320', 'Fall 2025', 'C', 15, 14.32, 8.48, 19.66, 39.81, 10, 'approved'),
('0242530005', 'PARENT0242530005', 'FIN2319', 'Spring 2026', 'A', 14.26, 13.77, 7.58, 20.42, 24.47, 10, 'draft'),
('0242530005', 'PARENT0242530005', 'MGT3122', 'Spring 2026', 'B', 14.0, 10.68, 7.85, 16.8, 32.2, 10, 'submitted'),
('0242530006', 'PARENT0242530006', 'BUS1102', 'Spring 2025', 'A', 14.6, 15, 7.54, 20.84, 27.97, 9.0, 'approved'),
('0242530006', 'PARENT0242530006', 'ACN1205', 'Summer 2025', 'B', 15, 14.48, 7.8, 23.14, 25.51, 9.0, 'approved'),
('0242530006', 'PARENT0242530006', 'MKT2320', 'Fall 2025', 'C', 9.2, 8.94, 6.75, 10, 24.91, 8.0, 'approved'),
('0242530006', 'PARENT0242530006', 'FIN2319', 'Spring 2026', 'A', 14.01, 11.1, 7.83, 22.59, 30.34, 10, 'draft'),
('0242530006', 'PARENT0242530006', 'MGT3122', 'Spring 2026', 'B', 10.83, 8.88, 7.15, 10, 31.66, 7.0, 'submitted'),
('0242530007', 'PARENT0242530007', 'BUS1102', 'Spring 2025', 'A', 15, 8.27, 8.27, 21.5, 27.82, 7.0, 'approved'),
('0242530007', 'PARENT0242530007', 'ACN1205', 'Summer 2025', 'B', 7.93, 9.24, 7.09, 13.52, 19.41, 10, 'approved'),
('0242530007', 'PARENT0242530007', 'MKT2320', 'Fall 2025', 'C', 9.22, 10.93, 6.96, 11.08, 23.08, 10, 'approved'),
('0242530007', 'PARENT0242530007', 'FIN2319', 'Spring 2026', 'A', 11.24, 10.43, 9.03, 15.12, 35.19, 8.0, 'draft'),
('0242530007', 'PARENT0242530007', 'MGT3122', 'Spring 2026', 'B', 12.92, 12.51, 8.34, 13.1, 33.6, 10, 'submitted'),
('0242530008', 'PARENT0242530008', 'BUS1102', 'Spring 2025', 'A', 11.18, 14.35, 8.04, 12.88, 40, 7.0, 'approved'),
('0242530008', 'PARENT0242530008', 'ACN1205', 'Summer 2025', 'B', 13.48, 9.24, 7.83, 20.11, 37.95, 10, 'approved'),
('0242530008', 'PARENT0242530008', 'MKT2320', 'Fall 2025', 'C', 12.52, 9.46, 6.07, 14.36, 25.27, 8.0, 'approved'),
('0242530008', 'PARENT0242530008', 'FIN2319', 'Spring 2026', 'A', 7.11, 11.93, 7.03, 13.1, 22.16, 9.0, 'draft'),
('0242530008', 'PARENT0242530008', 'MGT3122', 'Spring 2026', 'B', 7.1, 13.13, 5, 24.49, 40, 8.0, 'submitted'),
('0242530009', 'PARENT0242530009', 'BUS1102', 'Spring 2025', 'A', 9.68, 11.1, 7.26, 24.41, 28.76, 7.0, 'approved'),
('0242530009', 'PARENT0242530009', 'ACN1205', 'Summer 2025', 'B', 13.77, 12.26, 8.16, 14.48, 29.07, 8.0, 'approved'),
('0242530009', 'PARENT0242530009', 'MKT2320', 'Fall 2025', 'C', 7.79, 7.3, 5.22, 13.64, 21.15, 7.0, 'approved'),
('0242530009', 'PARENT0242530009', 'FIN2319', 'Spring 2026', 'A', 12.0, 11.08, 5.96, 15.5, 30.24, 10, 'draft'),
('0242530009', 'PARENT0242530009', 'MGT3122', 'Spring 2026', 'B', 13.19, 9.73, 8.13, 13.64, 19.73, 8.0, 'submitted'),
('0242530010', 'PARENT0242530010', 'BUS1102', 'Spring 2025', 'A', 13.81, 10.62, 5, 17.63, 26.06, 10, 'approved'),
('0242530010', 'PARENT0242530010', 'ACN1205', 'Summer 2025', 'B', 13.13, 11.66, 7.62, 10.32, 36.37, 8.0, 'approved'),
('0242530010', 'PARENT0242530010', 'MKT2320', 'Fall 2025', 'C', 11.58, 11.86, 7.51, 14.56, 30.69, 10, 'approved'),
('0242530010', 'PARENT0242530010', 'FIN2319', 'Spring 2026', 'A', 13.03, 8.65, 7.41, 25, 28.52, 8.0, 'draft'),
('0242530010', 'PARENT0242530010', 'MGT3122', 'Spring 2026', 'B', 7.49, 9.76, 5, 17.33, 23.37, 10, 'submitted'),
('0242530011', 'PARENT0242530011', 'BUS1102', 'Spring 2025', 'A', 13.26, 15, 7.25, 16.07, 34.74, 9.0, 'approved'),
('0242530011', 'PARENT0242530011', 'ACN1205', 'Summer 2025', 'B', 12.25, 15, 8.04, 20.42, 30.9, 8.0, 'approved'),
('0242530011', 'PARENT0242530011', 'MKT2320', 'Fall 2025', 'C', 7.04, 10.85, 6.6, 14.92, 25.63, 10, 'approved'),
('0242530011', 'PARENT0242530011', 'FIN2319', 'Spring 2026', 'A', 14.61, 10.01, 7.94, 16.71, 35.31, 10, 'draft'),
('0242530011', 'PARENT0242530011', 'MGT3122', 'Spring 2026', 'B', 11.14, 10.37, 5.96, 11.81, 24.31, 7.0, 'submitted'),
('0242530012', 'PARENT0242530012', 'BUS1102', 'Spring 2025', 'A', 10.07, 11.16, 9.18, 21.3, 30.3, 9.0, 'approved'),
('0242530012', 'PARENT0242530012', 'ACN1205', 'Summer 2025', 'B', 8.92, 10.42, 5.82, 12.4, 32.21, 9.0, 'approved'),
('0242530012', 'PARENT0242530012', 'MKT2320', 'Fall 2025', 'C', 12.31, 8.02, 5.08, 17.46, 22.11, 10, 'approved'),
('0242530012', 'PARENT0242530012', 'FIN2319', 'Spring 2026', 'A', 13.82, 14.18, 10, 18.16, 34.73, 10, 'draft'),
('0242530012', 'PARENT0242530012', 'MGT3122', 'Spring 2026', 'B', 6.2, 10.93, 5, 11.54, 23.85, 9.0, 'submitted'),
('0242530013', 'PARENT0242530013', 'BUS1102', 'Spring 2025', 'A', 15, 13.45, 6.06, 17.63, 32.69, 10, 'approved'),
('0242530013', 'PARENT0242530013', 'ACN1205', 'Summer 2025', 'B', 10.84, 11.82, 9.13, 17.44, 31.0, 9.0, 'approved'),
('0242530013', 'PARENT0242530013', 'MKT2320', 'Fall 2025', 'C', 11.47, 6.17, 6.27, 16.62, 29.59, 10, 'approved'),
('0242530013', 'PARENT0242530013', 'FIN2319', 'Spring 2026', 'A', 11.39, 13.3, 9.03, 21.23, 34.8, 10, 'draft'),
('0242530013', 'PARENT0242530013', 'MGT3122', 'Spring 2026', 'B', 10.24, 12.32, 8.5, 14.4, 24.41, 9.0, 'submitted'),
('0242530014', 'PARENT0242530014', 'BUS1102', 'Spring 2025', 'A', 8.17, 7.59, 5.55, 11.61, 21.04, 10, 'approved'),
('0242530014', 'PARENT0242530014', 'ACN1205', 'Summer 2025', 'B', 13.9, 8.87, 7.49, 16.83, 28.82, 7.0, 'approved'),
('0242530014', 'PARENT0242530014', 'MKT2320', 'Fall 2025', 'C', 14.37, 12.13, 8.07, 19.5, 38.82, 9.0, 'approved'),
('0242530014', 'PARENT0242530014', 'FIN2319', 'Spring 2026', 'A', 10.2, 10.94, 6.42, 15.85, 25.76, 10, 'draft'),
('0242530014', 'PARENT0242530014', 'MGT3122', 'Spring 2026', 'B', 13.17, 15, 7.99, 20.25, 32.39, 10, 'submitted'),
('0242530015', 'PARENT0242530015', 'BUS1102', 'Spring 2025', 'A', 13.4, 9.62, 6.69, 19.11, 40, 8.0, 'approved'),
('0242530015', 'PARENT0242530015', 'ACN1205', 'Summer 2025', 'B', 13.63, 11.95, 7.45, 21.56, 34.71, 7.0, 'approved'),
('0242530015', 'PARENT0242530015', 'MKT2320', 'Fall 2025', 'C', 8.04, 14.64, 5.05, 15.04, 21.6, 9.0, 'approved'),
('0242530015', 'PARENT0242530015', 'FIN2319', 'Spring 2026', 'A', 12.67, 14.1, 7.03, 20.63, 40, 10, 'draft'),
('0242530015', 'PARENT0242530015', 'MGT3122', 'Spring 2026', 'B', 10.92, 11.02, 7.4, 21.73, 22.27, 10, 'submitted'),
('0242530016', 'PARENT0242530016', 'BUS1102', 'Spring 2025', 'A', 15, 10.83, 8.59, 22.15, 30.56, 8.0, 'approved'),
('0242530016', 'PARENT0242530016', 'ACN1205', 'Summer 2025', 'B', 10.93, 11.03, 6.44, 20.92, 28.24, 9.0, 'approved'),
('0242530016', 'PARENT0242530016', 'MKT2320', 'Fall 2025', 'C', 12.77, 9.92, 8.06, 15.81, 21.5, 10, 'approved'),
('0242530016', 'PARENT0242530016', 'FIN2319', 'Spring 2026', 'A', 11.77, 12.01, 7.58, 20.05, 28.38, 7.0, 'draft'),
('0242530016', 'PARENT0242530016', 'MGT3122', 'Spring 2026', 'B', 14.71, 10.52, 7.53, 22.36, 34.66, 9.0, 'submitted'),
('0242530017', 'PARENT0242530017', 'BUS1102', 'Spring 2025', 'A', 12.54, 13.23, 9.16, 18.65, 28.18, 10, 'approved'),
('0242530017', 'PARENT0242530017', 'ACN1205', 'Summer 2025', 'B', 6.41, 11.04, 5.91, 16.52, 19.66, 8.0, 'approved'),
('0242530017', 'PARENT0242530017', 'MKT2320', 'Fall 2025', 'C', 8.65, 11.35, 5, 11.78, 25.09, 9.0, 'approved'),
('0242530017', 'PARENT0242530017', 'FIN2319', 'Spring 2026', 'A', 9.99, 12.83, 6.81, 18.48, 30.0, 8.0, 'draft'),
('0242530017', 'PARENT0242530017', 'MGT3122', 'Spring 2026', 'B', 9.17, 10.79, 6.95, 19.96, 28.97, 10, 'submitted'),
('0242530018', 'PARENT0242530018', 'BUS1102', 'Spring 2025', 'A', 11.14, 8.88, 6.53, 10, 20.65, 8.0, 'approved'),
('0242530018', 'PARENT0242530018', 'ACN1205', 'Summer 2025', 'B', 11.29, 14.35, 5.94, 18.47, 26.11, 7.0, 'approved'),
('0242530018', 'PARENT0242530018', 'MKT2320', 'Fall 2025', 'C', 13.51, 11.23, 6.34, 14.07, 35.26, 8.0, 'approved'),
('0242530018', 'PARENT0242530018', 'FIN2319', 'Spring 2026', 'A', 15, 10.05, 6.12, 14.84, 30.38, 9.0, 'draft'),
('0242530018', 'PARENT0242530018', 'MGT3122', 'Spring 2026', 'B', 9.76, 7.34, 5, 19.0, 24.73, 10, 'submitted'),
('0242530019', 'PARENT0242530019', 'BUS1102', 'Spring 2025', 'A', 11.73, 10.93, 7.46, 22.37, 39.06, 10, 'approved'),
('0242530019', 'PARENT0242530019', 'ACN1205', 'Summer 2025', 'B', 9.2, 15, 9.09, 21.2, 27.33, 9.0, 'approved'),
('0242530019', 'PARENT0242530019', 'MKT2320', 'Fall 2025', 'C', 8.37, 12.87, 5.22, 13.51, 18, 10, 'approved'),
('0242530019', 'PARENT0242530019', 'FIN2319', 'Spring 2026', 'A', 15, 14.46, 9.57, 19.14, 28.39, 8.0, 'draft'),
('0242530019', 'PARENT0242530019', 'MGT3122', 'Spring 2026', 'B', 7.7, 12.58, 6.55, 18.82, 22.98, 10, 'submitted'),
('0242530020', 'PARENT0242530020', 'BUS1102', 'Spring 2025', 'A', 9.49, 12.62, 5, 14.2, 18, 10, 'approved'),
('0242530020', 'PARENT0242530020', 'ACN1205', 'Summer 2025', 'B', 10.89, 12.94, 6.27, 18.61, 34.67, 8.0, 'approved'),
('0242530020', 'PARENT0242530020', 'MKT2320', 'Fall 2025', 'C', 6.78, 11.37, 6.57, 19.87, 21.44, 9.0, 'approved'),
('0242530020', 'PARENT0242530020', 'FIN2319', 'Spring 2026', 'A', 12.49, 14.45, 10, 19.19, 35.84, 9.0, 'draft'),
('0242530020', 'PARENT0242530020', 'MGT3122', 'Spring 2026', 'B', 7.81, 8.74, 5, 14.06, 20.98, 10, 'submitted'),
('0242530021', 'PARENT0242530021', 'BUS1102', 'Spring 2025', 'A', 11.56, 8.68, 5, 13.36, 25.1, 7.0, 'approved'),
('0242530021', 'PARENT0242530021', 'ACN1205', 'Summer 2025', 'B', 11.19, 11.9, 7.75, 15.01, 30.5, 8.0, 'approved'),
('0242530021', 'PARENT0242530021', 'MKT2320', 'Fall 2025', 'C', 15, 15, 8.81, 23.12, 40, 10, 'approved'),
('0242530021', 'PARENT0242530021', 'FIN2319', 'Spring 2026', 'A', 11.09, 12.31, 7.72, 20.84, 40, 7.0, 'draft'),
('0242530021', 'PARENT0242530021', 'MGT3122', 'Spring 2026', 'B', 7.9, 9.79, 7.84, 14.55, 32.97, 7.0, 'submitted'),
('0242530022', 'PARENT0242530022', 'BUS1102', 'Spring 2025', 'A', 15, 14.26, 8.73, 20.37, 30.89, 7.0, 'approved'),
('0242530022', 'PARENT0242530022', 'ACN1205', 'Summer 2025', 'B', 15, 15, 9.19, 14.21, 39.89, 10, 'approved'),
('0242530022', 'PARENT0242530022', 'MKT2320', 'Fall 2025', 'C', 14.68, 14.65, 8.16, 17.12, 28.25, 9.0, 'approved'),
('0242530022', 'PARENT0242530022', 'FIN2319', 'Spring 2026', 'A', 15, 13.22, 10, 18.94, 35.38, 8.0, 'draft'),
('0242530022', 'PARENT0242530022', 'MGT3122', 'Spring 2026', 'B', 10.22, 11.2, 7.3, 19.8, 18, 8.0, 'submitted'),
('0242530023', 'PARENT0242530023', 'BUS1102', 'Spring 2025', 'A', 13.79, 13.07, 10, 22.97, 33.64, 8.0, 'approved'),
('0242530023', 'PARENT0242530023', 'ACN1205', 'Summer 2025', 'B', 14.57, 13.85, 9.25, 11.13, 31.16, 9.0, 'approved'),
('0242530023', 'PARENT0242530023', 'MKT2320', 'Fall 2025', 'C', 9.5, 12.85, 5, 14.43, 30.14, 8.0, 'approved'),
('0242530023', 'PARENT0242530023', 'FIN2319', 'Spring 2026', 'A', 12.86, 14.05, 9.05, 15.64, 34.98, 8.0, 'draft'),
('0242530023', 'PARENT0242530023', 'MGT3122', 'Spring 2026', 'B', 7.37, 11.52, 6.88, 13.29, 21.95, 10, 'submitted'),
('0242530024', 'PARENT0242530024', 'BUS1102', 'Spring 2025', 'A', 11.75, 10.43, 8.2, 20.93, 36.62, 10, 'approved'),
('0242530024', 'PARENT0242530024', 'ACN1205', 'Summer 2025', 'B', 12.27, 7.18, 7.37, 14.86, 32.3, 10, 'approved'),
('0242530024', 'PARENT0242530024', 'MKT2320', 'Fall 2025', 'C', 8.49, 12.04, 6.33, 15.75, 22.1, 7.0, 'approved'),
('0242530024', 'PARENT0242530024', 'FIN2319', 'Spring 2026', 'A', 11.17, 11.44, 6.32, 16.47, 23.64, 10, 'draft'),
('0242530024', 'PARENT0242530024', 'MGT3122', 'Spring 2026', 'B', 9.53, 11.68, 6.68, 18.34, 27.88, 9.0, 'submitted'),
('0242530025', 'PARENT0242530025', 'BUS1102', 'Spring 2025', 'A', 15, 12.71, 9.07, 20.66, 26.99, 7.0, 'approved'),
('0242530025', 'PARENT0242530025', 'ACN1205', 'Summer 2025', 'B', 11.0, 12.13, 6.75, 17.85, 31.06, 9.0, 'approved'),
('0242530025', 'PARENT0242530025', 'MKT2320', 'Fall 2025', 'C', 7.69, 9.94, 7.35, 11.43, 32.93, 10, 'approved'),
('0242530025', 'PARENT0242530025', 'FIN2319', 'Spring 2026', 'A', 15, 13.98, 8.73, 11.46, 27.32, 10, 'draft'),
('0242530025', 'PARENT0242530025', 'MGT3122', 'Spring 2026', 'B', 13.79, 10.56, 8.58, 21.31, 33.77, 10, 'submitted'),
('0242540001', 'PARENT0242540001', 'PHR1001', 'Spring 2025', 'A', 12.33, 10.56, 7.66, 20.63, 36.53, 8.0, 'approved'),
('0242540001', 'PARENT0242540001', 'PHR2005', 'Summer 2025', 'A', 8.19, 10.44, 7.55, 14.17, 23.75, 8.0, 'approved'),
('0242540001', 'PARENT0242540001', 'PHR1005L', 'Spring 2026', 'A', 11.55, 9.83, 7.5, 10.59, 27.99, 10, 'draft'),
('0242540001', 'PARENT0242540001', 'PHR3002', 'Spring 2026', 'A', 14.19, 11.61, 9.12, 21.18, 37.31, 10, 'submitted'),
('0242540002', 'PARENT0242540002', 'PHR1001', 'Spring 2025', 'A', 10.43, 11.24, 7.04, 15.63, 20.89, 8.0, 'approved'),
('0242540002', 'PARENT0242540002', 'PHR2005', 'Summer 2025', 'A', 14.2, 15, 6.67, 21.23, 31.79, 10, 'approved'),
('0242540002', 'PARENT0242540002', 'PHR1005L', 'Spring 2026', 'A', 9.4, 7.33, 5.19, 15.85, 18, 9.0, 'draft'),
('0242540002', 'PARENT0242540002', 'PHR3002', 'Spring 2026', 'A', 12.76, 11.68, 9.93, 20.62, 33.57, 7.0, 'submitted'),
('0242540003', 'PARENT0242540003', 'PHR1001', 'Spring 2025', 'A', 15, 11.92, 8.91, 23.3, 24.57, 8.0, 'approved'),
('0242540003', 'PARENT0242540003', 'PHR2005', 'Summer 2025', 'A', 9.8, 7.24, 6.61, 10, 19.76, 10, 'approved'),
('0242540003', 'PARENT0242540003', 'PHR1005L', 'Spring 2026', 'A', 9.05, 10.69, 5.85, 16.35, 24.4, 10, 'draft'),
('0242540003', 'PARENT0242540003', 'PHR3002', 'Spring 2026', 'A', 11.87, 8.38, 5.17, 19.46, 25.7, 10, 'submitted'),
('0242540004', 'PARENT0242540004', 'PHR1001', 'Spring 2025', 'A', 14.11, 5.64, 6.6, 14.1, 27.59, 10, 'approved'),
('0242540004', 'PARENT0242540004', 'PHR2005', 'Summer 2025', 'A', 15, 13.57, 8.91, 19.89, 33.06, 8.0, 'approved'),
('0242540004', 'PARENT0242540004', 'PHR1005L', 'Spring 2026', 'A', 9.79, 11.04, 9.76, 12.72, 24.13, 8.0, 'draft'),
('0242540004', 'PARENT0242540004', 'PHR3002', 'Spring 2026', 'A', 11.22, 9.75, 7.94, 20.19, 33.93, 10, 'submitted'),
('0242540005', 'PARENT0242540005', 'PHR1001', 'Spring 2025', 'A', 11.51, 10.14, 6.8, 10.9, 31.01, 9.0, 'approved'),
('0242540005', 'PARENT0242540005', 'PHR2005', 'Summer 2025', 'A', 12.44, 8.68, 6.39, 17.97, 30.83, 9.0, 'approved'),
('0242540005', 'PARENT0242540005', 'PHR1005L', 'Spring 2026', 'A', 8.35, 9.68, 7.15, 16.66, 22.99, 9.0, 'draft'),
('0242540005', 'PARENT0242540005', 'PHR3002', 'Spring 2026', 'A', 11.06, 6.52, 5.11, 18.76, 25.77, 7.0, 'submitted'),
('0242540006', 'PARENT0242540006', 'PHR1001', 'Spring 2025', 'A', 9.65, 10.4, 7.03, 17.24, 23.17, 9.0, 'approved'),
('0242540006', 'PARENT0242540006', 'PHR2005', 'Summer 2025', 'A', 9.73, 8.99, 5, 18.26, 26.94, 10, 'approved'),
('0242540006', 'PARENT0242540006', 'PHR1005L', 'Spring 2026', 'A', 13.2, 11.63, 8.13, 16.66, 36.64, 10, 'draft'),
('0242540006', 'PARENT0242540006', 'PHR3002', 'Spring 2026', 'A', 12.62, 10.37, 5.43, 16.36, 27.62, 10, 'submitted'),
('0242540007', 'PARENT0242540007', 'PHR1001', 'Spring 2025', 'A', 10.27, 9.8, 7.79, 22.65, 40, 8.0, 'approved'),
('0242540007', 'PARENT0242540007', 'PHR2005', 'Summer 2025', 'A', 9.5, 13.74, 6.67, 14.47, 29.79, 10, 'approved'),
('0242540007', 'PARENT0242540007', 'PHR1005L', 'Spring 2026', 'A', 8.79, 12.21, 6.45, 16.88, 32.87, 7.0, 'draft'),
('0242540007', 'PARENT0242540007', 'PHR3002', 'Spring 2026', 'A', 11.14, 14.83, 6.81, 24.3, 36.25, 8.0, 'submitted'),
('0242540008', 'PARENT0242540008', 'PHR1001', 'Spring 2025', 'A', 10.85, 10.16, 5, 15.66, 18, 8.0, 'approved'),
('0242540008', 'PARENT0242540008', 'PHR2005', 'Summer 2025', 'A', 8.71, 9.05, 5, 20.92, 29.95, 8.0, 'approved'),
('0242540008', 'PARENT0242540008', 'PHR1005L', 'Spring 2026', 'A', 11.52, 8.14, 5.45, 16.89, 38.61, 10, 'draft'),
('0242540008', 'PARENT0242540008', 'PHR3002', 'Spring 2026', 'A', 9.59, 14.9, 9.65, 19.85, 27.92, 7.0, 'submitted'),
('0242540009', 'PARENT0242540009', 'PHR1001', 'Spring 2025', 'A', 13.63, 12.82, 9.52, 18.38, 26.89, 10, 'approved'),
('0242540009', 'PARENT0242540009', 'PHR2005', 'Summer 2025', 'A', 10.37, 9.78, 7.96, 10, 19.73, 10, 'approved'),
('0242540009', 'PARENT0242540009', 'PHR1005L', 'Spring 2026', 'A', 8.87, 8.73, 5.93, 14.31, 27.93, 8.0, 'draft'),
('0242540009', 'PARENT0242540009', 'PHR3002', 'Spring 2026', 'A', 12.53, 9.02, 6.59, 16.59, 29.11, 9.0, 'submitted'),
('0242540010', 'PARENT0242540010', 'PHR1001', 'Spring 2025', 'A', 13.45, 12.46, 7.91, 20.8, 33.06, 10, 'approved'),
('0242540010', 'PARENT0242540010', 'PHR2005', 'Summer 2025', 'A', 8.32, 11.47, 8.18, 16.33, 21.84, 8.0, 'approved'),
('0242540010', 'PARENT0242540010', 'PHR1005L', 'Spring 2026', 'A', 14.35, 13.35, 7.52, 18.25, 36.82, 8.0, 'draft'),
('0242540010', 'PARENT0242540010', 'PHR3002', 'Spring 2026', 'A', 12.31, 6.72, 6.27, 10.36, 26.55, 8.0, 'submitted'),
('0242540011', 'PARENT0242540011', 'PHR1001', 'Spring 2025', 'A', 10.74, 9.72, 6.29, 13.45, 20.77, 9.0, 'approved'),
('0242540011', 'PARENT0242540011', 'PHR2005', 'Summer 2025', 'A', 13.36, 12.02, 8.95, 23.81, 31.69, 8.0, 'approved'),
('0242540011', 'PARENT0242540011', 'PHR1005L', 'Spring 2026', 'A', 13.52, 7.52, 7.48, 21.29, 26.77, 8.0, 'draft'),
('0242540011', 'PARENT0242540011', 'PHR3002', 'Spring 2026', 'A', 14.08, 14.37, 5.88, 25, 40, 10, 'submitted'),
('0242540012', 'PARENT0242540012', 'PHR1001', 'Spring 2025', 'A', 11.52, 12.68, 9.73, 20.14, 27.35, 7.0, 'approved'),
('0242540012', 'PARENT0242540012', 'PHR2005', 'Summer 2025', 'A', 9.81, 12.91, 7.79, 14.48, 27.54, 8.0, 'approved'),
('0242540012', 'PARENT0242540012', 'PHR1005L', 'Spring 2026', 'A', 13.18, 14.14, 7.35, 18.41, 40, 10, 'draft'),
('0242540012', 'PARENT0242540012', 'PHR3002', 'Spring 2026', 'A', 13.49, 8.65, 8.64, 22.59, 31.18, 8.0, 'submitted'),
('0242540013', 'PARENT0242540013', 'PHR1001', 'Spring 2025', 'A', 9.46, 7.71, 6.03, 17.1, 18.57, 9.0, 'approved'),
('0242540013', 'PARENT0242540013', 'PHR2005', 'Summer 2025', 'A', 10.03, 7.97, 6.39, 19.62, 32.2, 10, 'approved'),
('0242540013', 'PARENT0242540013', 'PHR1005L', 'Spring 2026', 'A', 9.92, 9.62, 6.22, 14.9, 22.49, 10, 'draft'),
('0242540013', 'PARENT0242540013', 'PHR3002', 'Spring 2026', 'A', 12.89, 11.73, 9.03, 18.08, 29.01, 8.0, 'submitted'),
('0242540014', 'PARENT0242540014', 'PHR1001', 'Spring 2025', 'A', 7.32, 8.15, 6.5, 15.63, 29.54, 7.0, 'approved'),
('0242540014', 'PARENT0242540014', 'PHR2005', 'Summer 2025', 'A', 11.07, 14.76, 5.33, 19.48, 26.9, 10, 'approved'),
('0242540014', 'PARENT0242540014', 'PHR1005L', 'Spring 2026', 'A', 10.88, 14.34, 6.8, 24.13, 31.72, 10, 'draft'),
('0242540014', 'PARENT0242540014', 'PHR3002', 'Spring 2026', 'A', 14.05, 12.53, 8.63, 22.57, 40, 8.0, 'submitted'),
('0242540015', 'PARENT0242540015', 'PHR1001', 'Spring 2025', 'A', 9.76, 6.29, 6.9, 10, 23.34, 9.0, 'approved'),
('0242540015', 'PARENT0242540015', 'PHR2005', 'Summer 2025', 'A', 11.27, 9.46, 6.37, 21.29, 29.21, 8.0, 'approved'),
('0242540015', 'PARENT0242540015', 'PHR1005L', 'Spring 2026', 'A', 10.57, 15, 6.24, 15.46, 31.91, 8.0, 'draft'),
('0242540015', 'PARENT0242540015', 'PHR3002', 'Spring 2026', 'A', 12.49, 14.26, 9.28, 18.94, 28.6, 9.0, 'submitted');


-- Enroll students in multiple sections
INSERT INTO enrollments (student_id, section_id, parent_user_id, status)
SELECT stu.id, cs.id, par.id, 'active'
FROM tmp_large_marks m
JOIN users stu ON stu.identifier=m.student_identifier AND stu.role='student'
LEFT JOIN users par ON par.identifier=m.parent_identifier AND par.role='parent'
JOIN courses c ON c.course_code=m.course_code
JOIN trimesters tr ON tr.name=m.trimester_name
JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=m.section_name
ON DUPLICATE KEY UPDATE parent_user_id=VALUES(parent_user_id), status='active';

-- Legacy result cache used by dashboards
INSERT INTO results (enrollment_id,ct1,ct2,best_ct,assignment,mid,final,attendance_marks,total_marks,grade,grade_point,status,submitted_by,approved_by,submitted_at,approved_at)
SELECT e.id, m.ct1, m.ct2, GREATEST(m.ct1,m.ct2), m.assignment, m.mid, m.final_exam, m.attendance,
       ROUND(GREATEST(m.ct1,m.ct2)+m.assignment+m.mid+m.final_exam+m.attendance,2) AS total_marks,
       gr.grade, gr.grade_point, m.result_status,
       CASE WHEN m.result_status IN ('submitted','approved') THEN cs.teacher_id ELSE NULL END,
       CASE WHEN m.result_status='approved' THEN admin.id ELSE NULL END,
       CASE WHEN m.result_status IN ('submitted','approved') THEN NOW() ELSE NULL END,
       CASE WHEN m.result_status='approved' THEN NOW() ELSE NULL END
FROM tmp_large_marks m
JOIN users stu ON stu.identifier=m.student_identifier AND stu.role='student'
JOIN courses c ON c.course_code=m.course_code
JOIN trimesters tr ON tr.name=m.trimester_name
JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=m.section_name
JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id
JOIN users admin ON admin.identifier='admin001' AND admin.role='admin'
JOIN grade_rules gr ON ROUND(GREATEST(m.ct1,m.ct2)+m.assignment+m.mid+m.final_exam+m.attendance,2) BETWEEN gr.min_mark AND gr.max_mark AND gr.is_active=1
ON DUPLICATE KEY UPDATE ct1=VALUES(ct1),ct2=VALUES(ct2),best_ct=VALUES(best_ct),assignment=VALUES(assignment),mid=VALUES(mid),final=VALUES(final),attendance_marks=VALUES(attendance_marks),total_marks=VALUES(total_marks),grade=VALUES(grade),grade_point=VALUES(grade_point),status=VALUES(status),submitted_by=VALUES(submitted_by),approved_by=VALUES(approved_by),submitted_at=VALUES(submitted_at),approved_at=VALUES(approved_at);

-- Normalized component marks: CT/Mid/Final raw marks + converted marks
INSERT INTO student_component_marks (enrollment_id,component_id,raw_marks,converted_marks,is_absent,updated_by)
SELECT e.id,ac.id,ROUND((m.ct1/ac.convert_to)*ac.taken_out_of,2),m.ct1,0,cs.teacher_id
FROM tmp_large_marks m JOIN users stu ON stu.identifier=m.student_identifier AND stu.role='student' JOIN courses c ON c.course_code=m.course_code JOIN trimesters tr ON tr.name=m.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=m.section_name JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id JOIN assessment_components ac ON ac.section_id=cs.id AND ac.component_key='ct1'
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks),converted_marks=VALUES(converted_marks),is_absent=0,updated_by=VALUES(updated_by);
INSERT INTO student_component_marks (enrollment_id,component_id,raw_marks,converted_marks,is_absent,updated_by)
SELECT e.id,ac.id,ROUND((m.ct2/ac.convert_to)*ac.taken_out_of,2),m.ct2,0,cs.teacher_id
FROM tmp_large_marks m JOIN users stu ON stu.identifier=m.student_identifier AND stu.role='student' JOIN courses c ON c.course_code=m.course_code JOIN trimesters tr ON tr.name=m.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=m.section_name JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id JOIN assessment_components ac ON ac.section_id=cs.id AND ac.component_key='ct2'
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks),converted_marks=VALUES(converted_marks),is_absent=0,updated_by=VALUES(updated_by);
INSERT INTO student_component_marks (enrollment_id,component_id,raw_marks,converted_marks,is_absent,updated_by)
SELECT e.id,ac.id,m.assignment,m.assignment,0,cs.teacher_id
FROM tmp_large_marks m JOIN users stu ON stu.identifier=m.student_identifier AND stu.role='student' JOIN courses c ON c.course_code=m.course_code JOIN trimesters tr ON tr.name=m.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=m.section_name JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id JOIN assessment_components ac ON ac.section_id=cs.id AND ac.component_key='assignment'
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks),converted_marks=VALUES(converted_marks),is_absent=0,updated_by=VALUES(updated_by);
INSERT INTO student_component_marks (enrollment_id,component_id,raw_marks,converted_marks,is_absent,updated_by)
SELECT e.id,ac.id,ROUND((m.mid/ac.convert_to)*ac.taken_out_of,2),m.mid,0,cs.teacher_id
FROM tmp_large_marks m JOIN users stu ON stu.identifier=m.student_identifier AND stu.role='student' JOIN courses c ON c.course_code=m.course_code JOIN trimesters tr ON tr.name=m.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=m.section_name JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id JOIN assessment_components ac ON ac.section_id=cs.id AND ac.component_key='mid'
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks),converted_marks=VALUES(converted_marks),is_absent=0,updated_by=VALUES(updated_by);
INSERT INTO student_component_marks (enrollment_id,component_id,raw_marks,converted_marks,is_absent,updated_by)
SELECT e.id,ac.id,ROUND((m.final_exam/ac.convert_to)*ac.taken_out_of,2),m.final_exam,0,cs.teacher_id
FROM tmp_large_marks m JOIN users stu ON stu.identifier=m.student_identifier AND stu.role='student' JOIN courses c ON c.course_code=m.course_code JOIN trimesters tr ON tr.name=m.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=m.section_name JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id JOIN assessment_components ac ON ac.section_id=cs.id AND ac.component_key='final'
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks),converted_marks=VALUES(converted_marks),is_absent=0,updated_by=VALUES(updated_by);
INSERT INTO student_component_marks (enrollment_id,component_id,raw_marks,converted_marks,is_absent,updated_by,remarks)
SELECT e.id,ac.id,m.attendance,m.attendance,0,cs.teacher_id,'Large demo attendance'
FROM tmp_large_marks m JOIN users stu ON stu.identifier=m.student_identifier AND stu.role='student' JOIN courses c ON c.course_code=m.course_code JOIN trimesters tr ON tr.name=m.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=m.section_name JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id JOIN assessment_components ac ON ac.section_id=cs.id AND ac.component_key='attendance'
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks),converted_marks=VALUES(converted_marks),is_absent=0,updated_by=VALUES(updated_by),remarks=VALUES(remarks);

-- Normalized final result summary
INSERT INTO student_section_results (enrollment_id,total_marks,grade,grade_point,calculated_at,locked_at)
SELECT r.enrollment_id,r.total_marks,r.grade,r.grade_point,NOW(),CASE WHEN r.status='approved' THEN NOW() ELSE NULL END FROM results r
ON DUPLICATE KEY UPDATE total_marks=VALUES(total_marks),grade=VALUES(grade),grade_point=VALUES(grade_point),calculated_at=NOW(),locked_at=VALUES(locked_at);

-- Section workflow statuses
INSERT INTO result_submissions (section_id,status,submitted_by,approved_by,submitted_at,approved_at)
SELECT cs.id,
       CASE WHEN s.section_status='running' THEN 'draft' ELSE s.section_status END,
       CASE WHEN s.section_status IN ('submitted','approved') THEN cs.teacher_id ELSE NULL END,
       CASE WHEN s.section_status='approved' THEN admin.id ELSE NULL END,
       CASE WHEN s.section_status IN ('submitted','approved') THEN NOW() ELSE NULL END,
       CASE WHEN s.section_status='approved' THEN NOW() ELSE NULL END
FROM tmp_large_sections s JOIN courses c ON c.course_code=s.course_code JOIN trimesters tr ON tr.name=s.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id AND cs.section_name=s.section_name JOIN users admin ON admin.identifier='admin001' AND admin.role='admin'
ON DUPLICATE KEY UPDATE status=VALUES(status),submitted_by=VALUES(submitted_by),approved_by=VALUES(approved_by),submitted_at=VALUES(submitted_at),approved_at=VALUES(approved_at),updated_at=CURRENT_TIMESTAMP;

-- Clean old large demo audit rows, then add fresh audit samples
DELETE FROM audit_logs WHERE user_agent='Large demo seed';
INSERT INTO audit_logs (user_id,action,table_name,record_id,old_value,new_value,ip_address,user_agent)
SELECT cs.teacher_id,'SAVE_COMPONENT_MARK','student_component_marks',scm.id,
       JSON_OBJECT('raw_marks',ROUND(scm.raw_marks-1,2),'converted_marks',ROUND(scm.converted_marks-0.50,2)),
       JSON_OBJECT('raw_marks',scm.raw_marks,'converted_marks',scm.converted_marks,'student',stu.identifier,'component',ac.component_key),
       '127.0.0.1','Large demo seed'
FROM student_component_marks scm JOIN assessment_components ac ON ac.id=scm.component_id JOIN enrollments e ON e.id=scm.enrollment_id JOIN users stu ON stu.id=e.student_id JOIN course_sections cs ON cs.id=e.section_id
WHERE stu.identifier LIKE '024251%' AND ac.component_key IN ('ct1','mid') LIMIT 50;

SET FOREIGN_KEY_CHECKS = 1;

-- Quick verification queries to run after import:
-- SELECT role, COUNT(*) FROM users GROUP BY role;
-- SELECT COUNT(*) AS sections FROM course_sections;
-- SELECT COUNT(*) AS enrollments FROM enrollments;
-- SELECT COUNT(*) AS component_marks FROM student_component_marks;


-- ============================================================
-- EXTRA SAFE STUDENT DEMO: shaim / 0112430280
-- This keeps the student dashboard visually populated for the common demo login.
-- ============================================================
USE urams_db;
SET FOREIGN_KEY_CHECKS = 0;
SET @pwd = '$2y$12$UyYMMCAzoxeqCFtR/ri6aOPRE1aF/U7bzjQCwt0.qzF/a7XlPgT8e';

INSERT INTO users (full_name,email,identifier,role,password_hash,program,department,status)
VALUES
('shaim','shaim@gmail.com','0112430280','student',@pwd,'BSc Engineering','CSE','active'),
('Guardian of shaim','parent.0112430280@guardian.uiu.local','PARENT0112430280','parent',@pwd,NULL,NULL,'active')
ON DUPLICATE KEY UPDATE full_name=VALUES(full_name), password_hash=VALUES(password_hash), program=VALUES(program), department=VALUES(department), status='active';

INSERT INTO courses (course_code,course_name,credit,course_type,level_no,is_lab) VALUES
('CSE3711','Computer Networks',3,'core',3,0),
('IPE3401','Industrial Management',3,'other',3,0),
('CSE3811','Artificial Intelligence',3,'core',3,0),
('CSE3812','Artificial Intelligence Laboratory',1,'lab',3,1),
('CSE4165','Web Programming',3,'core',4,0)
ON DUPLICATE KEY UPDATE course_name=VALUES(course_name), credit=VALUES(credit);

INSERT INTO course_sections (course_id, trimester_id, teacher_id, section_name, status, capacity, room, class_schedule)
SELECT c.id, tr.id, u.id, x.section_name, x.section_status, 45, x.room, x.class_schedule
FROM (
  SELECT 'CSE3711' course_code, 'Summer 2025' trimester_name, 'MRI' teacher_identifier, 'E' section_name, 'approved' section_status, '323 Permanent Campus' room, 'Sat 01:51PM-03:10PM; Tue 01:51PM-03:10PM' class_schedule
  UNION ALL SELECT 'IPE3401','Summer 2025','MRI','A','approved','424 Permanent Campus','Sat 08:30AM-09:50AM; Tue 08:30AM-09:50AM'
  UNION ALL SELECT 'CSE3811','Summer 2025','MRI','F','approved','404 Permanent Campus','Sun 03:11PM-04:30PM'
  UNION ALL SELECT 'CSE3812','Summer 2025','MRI','E','approved','529 Permanent Campus','Sun 11:11AM-01:40PM'
  UNION ALL SELECT 'CSE4165','Spring 2025','MRI','U','approved','927 Permanent Campus','Wed 11:11AM-01:40PM'
) x
JOIN courses c ON c.course_code=x.course_code
JOIN trimesters tr ON tr.name=x.trimester_name
JOIN users u ON u.identifier=x.teacher_identifier AND u.role='teacher'
ON DUPLICATE KEY UPDATE teacher_id=VALUES(teacher_id), status=VALUES(status), room=VALUES(room), class_schedule=VALUES(class_schedule);

-- Ensure standard components exist for shaim demo sections
INSERT INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group)
SELECT cs.id, 'ct1', 'CT1', 'ct', 30, 15, 15, 1, 1, 'ct'
FROM course_sections cs JOIN courses c ON c.id=cs.course_id WHERE c.course_code IN ('CSE3711','IPE3401','CSE3811','CSE3812','CSE4165')
ON DUPLICATE KEY UPDATE taken_out_of=VALUES(taken_out_of), convert_to=VALUES(convert_to), weight=VALUES(weight);
INSERT INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group)
SELECT cs.id, 'ct2', 'CT2', 'ct', 30, 15, 15, 2, 1, 'ct'
FROM course_sections cs JOIN courses c ON c.id=cs.course_id WHERE c.course_code IN ('CSE3711','IPE3401','CSE3811','CSE3812','CSE4165')
ON DUPLICATE KEY UPDATE taken_out_of=VALUES(taken_out_of), convert_to=VALUES(convert_to), weight=VALUES(weight);
INSERT INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order)
SELECT cs.id, 'assignment', 'Assignment', 'assignment', 10, 10, 10, 3
FROM course_sections cs JOIN courses c ON c.id=cs.course_id WHERE c.course_code IN ('CSE3711','IPE3401','CSE3811','CSE3812','CSE4165')
ON DUPLICATE KEY UPDATE taken_out_of=VALUES(taken_out_of), convert_to=VALUES(convert_to), weight=VALUES(weight);
INSERT INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order)
SELECT cs.id, 'mid', 'Mid Term', 'mid', 50, 25, 25, 4
FROM course_sections cs JOIN courses c ON c.id=cs.course_id WHERE c.course_code IN ('CSE3711','IPE3401','CSE3811','CSE3812','CSE4165')
ON DUPLICATE KEY UPDATE taken_out_of=VALUES(taken_out_of), convert_to=VALUES(convert_to), weight=VALUES(weight);
INSERT INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order)
SELECT cs.id, 'final', 'Final Exam', 'final', 80, 40, 40, 5
FROM course_sections cs JOIN courses c ON c.id=cs.course_id WHERE c.course_code IN ('CSE3711','IPE3401','CSE3811','CSE3812','CSE4165')
ON DUPLICATE KEY UPDATE taken_out_of=VALUES(taken_out_of), convert_to=VALUES(convert_to), weight=VALUES(weight);
INSERT INTO assessment_components (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order)
SELECT cs.id, 'attendance', 'Attendance', 'attendance', 10, 10, 10, 6
FROM course_sections cs JOIN courses c ON c.id=cs.course_id WHERE c.course_code IN ('CSE3711','IPE3401','CSE3811','CSE3812','CSE4165')
ON DUPLICATE KEY UPDATE taken_out_of=VALUES(taken_out_of), convert_to=VALUES(convert_to), weight=VALUES(weight);

DROP TEMPORARY TABLE IF EXISTS tmp_shaim_marks;
CREATE TEMPORARY TABLE tmp_shaim_marks (
  course_code VARCHAR(20), trimester_name VARCHAR(50), grade VARCHAR(5), grade_point DECIMAL(3,2),
  ct1 DECIMAL(6,2), ct2 DECIMAL(6,2), assignment DECIMAL(6,2), mid DECIMAL(6,2), final_exam DECIMAL(6,2), attendance DECIMAL(6,2)
);
INSERT INTO tmp_shaim_marks VALUES
('CSE4165','Spring 2025','A-',3.50,12.0,13.0,8.5,20.0,32.0,9.0),
('CSE3711','Summer 2025','A',3.75,13.5,14.0,9.0,22.0,34.0,9.0),
('IPE3401','Summer 2025','A',3.75,14.0,13.0,8.5,23.0,35.0,10.0),
('CSE3811','Summer 2025','A-',3.50,12.0,12.5,8.0,21.0,33.0,8.0),
('CSE3812','Summer 2025','A',3.75,14.0,13.5,9.5,22.0,34.0,10.0);

INSERT INTO enrollments (student_id, section_id, parent_user_id, status)
SELECT stu.id, cs.id, par.id, 'completed'
FROM tmp_shaim_marks m
JOIN users stu ON stu.identifier='0112430280' AND stu.role='student'
JOIN users par ON par.identifier='PARENT0112430280' AND par.role='parent'
JOIN courses c ON c.course_code=m.course_code
JOIN trimesters tr ON tr.name=m.trimester_name
JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id
ON DUPLICATE KEY UPDATE parent_user_id=VALUES(parent_user_id), status=VALUES(status);

INSERT INTO results (enrollment_id, ct1, ct2, best_ct, assignment, mid, final, attendance_marks, total_marks, grade, grade_point, status, submitted_at, approved_at)
SELECT e.id, m.ct1, m.ct2, GREATEST(m.ct1,m.ct2), m.assignment, m.mid, m.final_exam, m.attendance,
       LEAST(100, GREATEST(m.ct1,m.ct2)+m.assignment+m.mid+m.final_exam+m.attendance),
       m.grade, m.grade_point, 'approved', NOW(), NOW()
FROM tmp_shaim_marks m
JOIN users stu ON stu.identifier='0112430280' AND stu.role='student'
JOIN courses c ON c.course_code=m.course_code
JOIN trimesters tr ON tr.name=m.trimester_name
JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id
JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id
ON DUPLICATE KEY UPDATE ct1=VALUES(ct1), ct2=VALUES(ct2), best_ct=VALUES(best_ct), assignment=VALUES(assignment), mid=VALUES(mid), final=VALUES(final), attendance_marks=VALUES(attendance_marks), total_marks=VALUES(total_marks), grade=VALUES(grade), grade_point=VALUES(grade_point), status='approved', approved_at=NOW();

INSERT INTO result_submissions (section_id, status, approved_at)
SELECT DISTINCT cs.id, 'approved', NOW()
FROM tmp_shaim_marks m JOIN courses c ON c.course_code=m.course_code JOIN trimesters tr ON tr.name=m.trimester_name JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id
ON DUPLICATE KEY UPDATE status='approved', approved_at=NOW();

INSERT INTO student_component_marks (enrollment_id, component_id, raw_marks, converted_marks, is_absent)
SELECT e.id, ac.id,
CASE ac.component_key
  WHEN 'ct1' THEN ROUND((m.ct1/ac.convert_to)*ac.taken_out_of,2)
  WHEN 'ct2' THEN ROUND((m.ct2/ac.convert_to)*ac.taken_out_of,2)
  WHEN 'assignment' THEN m.assignment
  WHEN 'mid' THEN ROUND((m.mid/ac.convert_to)*ac.taken_out_of,2)
  WHEN 'final' THEN ROUND((m.final_exam/ac.convert_to)*ac.taken_out_of,2)
  WHEN 'attendance' THEN m.attendance
  ELSE 0 END,
CASE ac.component_key
  WHEN 'ct1' THEN m.ct1 WHEN 'ct2' THEN m.ct2 WHEN 'assignment' THEN m.assignment WHEN 'mid' THEN m.mid WHEN 'final' THEN m.final_exam WHEN 'attendance' THEN m.attendance ELSE 0 END,
0
FROM tmp_shaim_marks m
JOIN users stu ON stu.identifier='0112430280' AND stu.role='student'
JOIN courses c ON c.course_code=m.course_code
JOIN trimesters tr ON tr.name=m.trimester_name
JOIN course_sections cs ON cs.course_id=c.id AND cs.trimester_id=tr.id
JOIN enrollments e ON e.student_id=stu.id AND e.section_id=cs.id
JOIN assessment_components ac ON ac.section_id=cs.id
ON DUPLICATE KEY UPDATE raw_marks=VALUES(raw_marks), converted_marks=VALUES(converted_marks), is_absent=0;

INSERT INTO student_section_results (enrollment_id, total_marks, grade, grade_point, calculated_at)
SELECT r.enrollment_id, r.total_marks, r.grade, r.grade_point, NOW()
FROM results r JOIN enrollments e ON e.id=r.enrollment_id JOIN users u ON u.id=e.student_id AND u.identifier='0112430280'
ON DUPLICATE KEY UPDATE total_marks=VALUES(total_marks), grade=VALUES(grade), grade_point=VALUES(grade_point), calculated_at=NOW();

SET FOREIGN_KEY_CHECKS = 1;
-- ============================================================
-- END shaim demo data
-- ============================================================
