USE urams_db;
SELECT role, COUNT(*) AS total FROM users GROUP BY role;
SELECT COUNT(*) AS total_sections FROM course_sections;
SELECT COUNT(*) AS total_enrollments FROM enrollments;
SELECT COUNT(*) AS total_results FROM results;
SELECT COUNT(*) AS completed_courses_in_prereq_view FROM v_student_completed_courses;
SELECT COUNT(*) AS component_marks FROM student_component_marks;
SELECT COUNT(*) AS audit_logs FROM audit_logs;
