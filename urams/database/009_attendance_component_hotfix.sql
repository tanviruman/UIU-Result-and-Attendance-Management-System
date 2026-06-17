-- 009_attendance_component_hotfix.sql
-- Optional safety migration: add missing Attendance component to existing course sections.
-- Useful for old sections that already had CT/Mid/Final components but missed Attendance.

INSERT IGNORE INTO assessment_components
(section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight, sort_order, is_best_of_group, best_of_group, created_by)
SELECT cs.id, 'attendance', 'Attendance', 'attendance', 10, 10, 10, 6, 0, NULL, cs.teacher_id
FROM course_sections cs;
