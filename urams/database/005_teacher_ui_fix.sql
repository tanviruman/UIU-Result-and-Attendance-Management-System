-- database/005_teacher_ui_fix.sql
-- Optional cleanup for existing marks components created before the Teacher UI fix.
USE urams_db;

UPDATE assessment_components
SET component_type = 'ct', is_best_of_group = 1, best_of_group = 'ct'
WHERE LOWER(component_name) REGEXP '^ct[[:space:]]*[0-9]*$'
   OR component_key REGEXP '^ct_?[0-9]*$';

UPDATE assessment_components
SET component_type = 'assignment', is_best_of_group = 1, best_of_group = 'assignment'
WHERE LOWER(component_name) REGEXP '^assignment[[:space:]]*[0-9]*$'
   OR component_key REGEXP '^assignment_?[0-9]*$';

UPDATE assessment_components
SET component_type = 'mid'
WHERE LOWER(component_name) LIKE 'mid%'
   OR component_key REGEXP '^mid(_term)?_?[0-9]*$';

UPDATE assessment_components
SET component_type = 'final'
WHERE LOWER(component_name) LIKE 'final%'
   OR component_key REGEXP '^final(_exam)?_?[0-9]*$';

UPDATE assessment_components
SET component_type = 'attendance'
WHERE LOWER(component_name) LIKE 'attendance%'
   OR component_key REGEXP '^attendance(_marks)?_?[0-9]*$';
