-- database/004_student_parent_approved_results.sql
-- Student/Parent visibility sync. Run after previous teacher/admin migrations if your DB already exists.
-- Fresh install: importing database/schema.sql is enough.

USE urams_db;

-- If any section was already approved/rejected through result_submissions,
-- keep course_sections/results cache aligned so Student/Parent approved-only queries are correct.
UPDATE course_sections cs
JOIN result_submissions rs ON rs.section_id = cs.id
SET cs.status = rs.status
WHERE rs.status IN ('submitted','approved','rejected');

UPDATE results r
JOIN enrollments e ON e.id = r.enrollment_id
JOIN result_submissions rs ON rs.section_id = e.section_id
SET r.status = rs.status,
    r.approved_by = CASE WHEN rs.status = 'approved' THEN rs.approved_by ELSE NULL END,
    r.approved_at = CASE WHEN rs.status = 'approved' THEN rs.approved_at ELSE NULL END
WHERE rs.status IN ('submitted','approved','rejected');
