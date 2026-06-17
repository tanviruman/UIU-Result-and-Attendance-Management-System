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
