<?php
// add_marks_component.php
// Create a real assessment component/marks column in DB.

require_once __DIR__ . '/includes/auth.php';
require_once __DIR__ . '/includes/result_helpers.php';
require_role(['teacher', 'admin']);

$data = urams_read_json();
$sectionId = isset($data['section_id']) ? (int)$data['section_id'] : 0;
$componentName = trim((string)($data['component_name'] ?? $data['exam_name'] ?? $data['name'] ?? ''));
$takenOutOf = isset($data['taken_out_of']) ? (float)$data['taken_out_of'] : (float)($data['taken'] ?? 0);
$convertTo = isset($data['convert_to']) ? (float)$data['convert_to'] : (float)($data['convert'] ?? 0);
$weight = isset($data['weight']) ? (float)$data['weight'] : $convertTo;
$isBestOfGroup = !empty($data['is_best_of_group']) || !empty($data['best_of']);
$bestOfGroup = isset($data['best_of_group']) ? trim((string)$data['best_of_group']) : null;
$examDate = isset($data['exam_date']) && trim((string)$data['exam_date']) !== '' ? trim((string)$data['exam_date']) : null;

if ($sectionId <= 0 || $componentName === '' || $takenOutOf <= 0 || $convertTo <= 0) {
    urams_json_response([
        'success' => false,
        'message' => 'section_id, component_name, taken_out_of and convert_to are required.'
    ], 400);
}

try {
    $userId = (int)$_SESSION['user_id'];
    $role = (string)$_SESSION['role'];

    if ($role === 'teacher') {
        $check = $pdo->prepare('SELECT id, status FROM course_sections WHERE id = :id AND teacher_id = :teacher_id LIMIT 1');
        $check->execute([':id' => $sectionId, ':teacher_id' => $userId]);
        $section = $check->fetch();
        if (!$section) {
            urams_json_response(['success' => false, 'message' => 'Unauthorized section access.'], 403);
        }
    } else {
        $check = $pdo->prepare('SELECT id, status FROM course_sections WHERE id = :id LIMIT 1');
        $check->execute([':id' => $sectionId]);
        $section = $check->fetch();
        if (!$section) {
            urams_json_response(['success' => false, 'message' => 'Section not found.'], 404);
        }
    }

    if (in_array($section['status'], ['submitted', 'approved'], true)) {
        urams_json_response(['success' => false, 'message' => 'Submitted/approved result cannot be edited.'], 409);
    }

    $pdo->beginTransaction();

    urams_ensure_default_components($pdo, $sectionId, $userId);

    $rawKeySource = (string)($data['component_key'] ?? $componentName);
    $baseKey = urams_component_key($rawKeySource);
    $componentType = urams_component_type((string)($data['component_type'] ?? $componentName));

    // CT and Assignment are group-based in URAMS, so extra CT/Assignment columns do not push total above 100.
    if ($componentType === 'ct') {
        $isBestOfGroup = true;
        $bestOfGroup = 'ct';
    } elseif ($componentType === 'assignment') {
        $isBestOfGroup = true;
        $bestOfGroup = 'assignment';
    }

    // If user selects generic CT/Quiz/Assignment repeatedly, create CT3/Quiz2/etc. instead of failing.
    $nameCheck = $pdo->prepare(
        'SELECT id FROM assessment_components WHERE section_id = :section_id AND LOWER(component_name) = LOWER(:component_name) LIMIT 1'
    );
    $nameCheck->execute([':section_id' => $sectionId, ':component_name' => $componentName]);
    if ($nameCheck->fetch()) {
        $componentName .= ' ' . date('His');
        $baseKey = urams_component_key($componentName);
    }

    if (in_array($baseKey, ['ct', 'quiz', 'assignment', 'lab', 'presentation', 'report'], true)) {
        $prefix = $baseKey;
        $countStmt = $pdo->prepare(
            'SELECT COUNT(*) AS total FROM assessment_components WHERE section_id = :section_id AND component_key LIKE :prefix'
        );
        $countStmt->execute([':section_id' => $sectionId, ':prefix' => $prefix . '%']);
        $nextNumber = max(1, (int)$countStmt->fetch()['total'] + 1);
        $baseKey = $prefix . $nextNumber;
        $componentName = strtoupper($prefix) . $nextNumber;
    }

    // Names such as "CT 3" or "Assignment 2" should also get clean keys and correct type.
    if ($componentType === 'ct' && !preg_match('/^ct\d+$/', $baseKey)) {
        $countStmt = $pdo->prepare('SELECT COUNT(*) AS total FROM assessment_components WHERE section_id = :section_id AND component_type = "ct"');
        $countStmt->execute([':section_id' => $sectionId]);
        $nextNumber = max(1, (int)$countStmt->fetch()['total'] + 1);
        $baseKey = 'ct' . $nextNumber;
        if (!preg_match('/^ct\s*\d+/i', $componentName)) {
            $componentName = 'CT' . $nextNumber;
        }
    } elseif ($componentType === 'assignment' && !preg_match('/^assignment\d+$/', $baseKey) && $baseKey !== 'assignment') {
        $countStmt = $pdo->prepare('SELECT COUNT(*) AS total FROM assessment_components WHERE section_id = :section_id AND component_type = "assignment"');
        $countStmt->execute([':section_id' => $sectionId]);
        $nextNumber = max(1, (int)$countStmt->fetch()['total'] + 1);
        $baseKey = $nextNumber === 1 ? 'assignment' : 'assignment' . $nextNumber;
    }

    $keyExists = $pdo->prepare('SELECT id FROM assessment_components WHERE section_id = :section_id AND component_key = :component_key LIMIT 1');
    $candidateKey = $baseKey;
    $suffix = 2;
    while (true) {
        $keyExists->execute([':section_id' => $sectionId, ':component_key' => $candidateKey]);
        if (!$keyExists->fetch()) {
            break;
        }
        $candidateKey = $baseKey . '_' . $suffix;
        $suffix++;
    }
    $baseKey = $candidateKey;

    $sortStmt = $pdo->prepare('SELECT COALESCE(MAX(sort_order), 0) + 1 AS next_order FROM assessment_components WHERE section_id = :section_id AND component_type = :component_type');
    $sortStmt->execute([':section_id' => $sectionId, ':component_type' => $componentType]);
    $typeBaseOrder = urams_component_group_rank($componentType) * 100;
    $sortOrder = isset($data['sort_order'])
        ? (int)$data['sort_order']
        : $typeBaseOrder + (int)$sortStmt->fetch()['next_order'];

    if ($isBestOfGroup && ($bestOfGroup === null || $bestOfGroup === '')) {
        $bestOfGroup = $componentType === 'ct' ? 'ct' : $baseKey;
    }

    $insert = $pdo->prepare(
        'INSERT INTO assessment_components
         (section_id, component_key, component_name, component_type, taken_out_of, convert_to, weight,
          sort_order, is_best_of_group, best_of_group, exam_date, created_by)
         VALUES
         (:section_id, :component_key, :component_name, :component_type, :taken_out_of, :convert_to, :weight,
          :sort_order, :is_best_of_group, :best_of_group, :exam_date, :created_by)'
    );
    $insert->execute([
        ':section_id' => $sectionId,
        ':component_key' => $baseKey,
        ':component_name' => $componentName,
        ':component_type' => $componentType,
        ':taken_out_of' => $takenOutOf,
        ':convert_to' => $convertTo,
        ':weight' => $weight,
        ':sort_order' => $sortOrder,
        ':is_best_of_group' => $isBestOfGroup ? 1 : 0,
        ':best_of_group' => $isBestOfGroup ? $bestOfGroup : null,
        ':exam_date' => $examDate,
        ':created_by' => $userId,
    ]);

    $componentId = (int)$pdo->lastInsertId();
    $componentStmt = $pdo->prepare('SELECT * FROM assessment_components WHERE id = :id LIMIT 1');
    $componentStmt->execute([':id' => $componentId]);
    $component = $componentStmt->fetch();

    write_audit_log(
        $pdo,
        $userId,
        'ADD_ASSESSMENT_COMPONENT',
        'assessment_components',
        $componentId,
        null,
        json_encode($component, JSON_UNESCAPED_UNICODE)
    );

    $pdo->commit();

    $component['id'] = (int)$component['id'];
    $component['section_id'] = (int)$component['section_id'];
    $component['taken_out_of'] = (float)$component['taken_out_of'];
    $component['convert_to'] = (float)$component['convert_to'];
    $component['weight'] = (float)$component['weight'];
    $component['sort_order'] = (int)$component['sort_order'];
    $component['is_best_of_group'] = (int)$component['is_best_of_group'];

    urams_json_response([
        'success' => true,
        'message' => 'Assessment component added successfully.',
        'component' => $component,
    ], 201);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    urams_json_response(['success' => false, 'message' => 'Could not add component: ' . $e->getMessage()], 500);
}
