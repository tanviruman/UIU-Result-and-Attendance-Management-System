-- 006_teacher_attendance_filter_hotfix.sql
-- No structural change required. This file is intentionally safe to import.
-- It only normalizes existing attendance component metadata if present.
UPDATE assessment_components
SET component_type = 'attendance', best_of_group = 'attendance', is_best_of_group = 1
WHERE component_key IN ('attendance', 'attendance_marks') OR LOWER(component_name) LIKE 'attendance%';
