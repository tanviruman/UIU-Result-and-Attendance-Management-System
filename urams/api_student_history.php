<?php
// api_student_history.php
// Returns the logged-in student's current course and trimester history.
require_once __DIR__ . '/includes/auth.php';
require_role(['student']);

header('Content-Type: application/json');

$studentId = (int)($_SESSION['user_id'] ?? 0);
if (!$studentId) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Student not authenticated.']);
    exit;
}

try {
    $sqlCourses = "SELECT c.course_code, c.course_name, c.credit,
                           cs.section_name, t.name AS trimester_name,
                           ut.full_name AS teacher_name, ut.identifier AS teacher_identifier,
                           r.grade, r.grade_point, r.total_marks, r.status
                    FROM enrollments e
                    JOIN course_sections cs ON e.section_id = cs.id
                    JOIN courses c ON cs.course_id = c.id
                    JOIN trimesters t ON cs.trimester_id = t.id
                    JOIN users ut ON cs.teacher_id = ut.id
                    LEFT JOIN results r ON r.enrollment_id = e.id
                    WHERE e.student_id = :student_id
                    ORDER BY t.start_date DESC, c.course_name";
    $stmtCourses = $pdo->prepare($sqlCourses);
    $stmtCourses->execute([':student_id' => $studentId]);
    $studentCourses = $stmtCourses->fetchAll(PDO::FETCH_ASSOC);

    $trimesterTitle = 'Current Trimester';
    $studentSummary = [
        'cgpa' => '0.00',
        'last_gpa' => '0.00',
        'trimesters' => 0,
        'credits_done' => '0',
        'sections_enrolled' => count($studentCourses),
    ];

    if (!empty($studentCourses)) {
        $trimesterTitle = $studentCourses[0]['trimester_name'];
        $trimesterNames = [];
        $creditsDone = 0.0;
        $weightedPoints = 0.0;
        $weightedCredits = 0.0;
        $latestTrimester = $studentCourses[0]['trimester_name'] ?? null;
        $latestWeightedPoints = 0.0;
        $latestWeightedCredits = 0.0;
        foreach ($studentCourses as $course) {
            $trimesterNames[$course['trimester_name']] = true;
            $credit = (float)$course['credit'];
            $creditsDone += $credit;
            if ($course['grade_point'] !== null) {
                $point = (float)$course['grade_point'];
                $weightedPoints += ($point * $credit);
                $weightedCredits += $credit;
                if ($course['trimester_name'] === $latestTrimester) {
                    $latestWeightedPoints += ($point * $credit);
                    $latestWeightedCredits += $credit;
                }
            }
        }
        $studentSummary['trimesters'] = count($trimesterNames);
        $studentSummary['credits_done'] = number_format($creditsDone, 0);
        if ($weightedCredits > 0) {
            $studentSummary['cgpa'] = number_format($weightedPoints / $weightedCredits, 2);
        }
        if ($latestWeightedCredits > 0) {
            $studentSummary['last_gpa'] = number_format($latestWeightedPoints / $latestWeightedCredits, 2);
        }
    }

    $sqlHistory = "SELECT t.id AS trimester_id, t.name AS trimester_name, t.start_date,
                          c.course_code, c.course_name, c.credit, cs.section_name,
                          r.grade, r.grade_point, r.total_marks, r.status
                   FROM enrollments e
                   JOIN course_sections cs ON e.section_id = cs.id
                   JOIN trimesters t ON cs.trimester_id = t.id
                   JOIN courses c ON cs.course_id = c.id
                   LEFT JOIN results r ON r.enrollment_id = e.id
                   WHERE e.student_id = :student_id
                   ORDER BY t.start_date ASC, c.course_code";
    $stmtHistory = $pdo->prepare($sqlHistory);
    $stmtHistory->execute([':student_id' => $studentId]);
    $historyRows = $stmtHistory->fetchAll(PDO::FETCH_ASSOC);

    $historyMap = [];
    foreach ($historyRows as $row) {
        $trimId = (int)$row['trimester_id'];
        if (!isset($historyMap[$trimId])) {
            $historyMap[$trimId] = [
                'trimester_id' => $trimId,
                'trimester_name' => $row['trimester_name'],
                'start_date' => $row['start_date'],
                'courses' => [],
                'gpa' => null,
                'cgpa' => null,
                'status' => 'partial',
                '_weighted_points' => 0.0,
                '_weighted_credits' => 0.0,
                '_total_count' => 0,
                '_graded_count' => 0,
            ];
        }
        $gradePoint = $row['grade_point'] !== null ? (float)$row['grade_point'] : null;
        $historyMap[$trimId]['courses'][] = [
            'course_code' => $row['course_code'],
            'course_name' => $row['course_name'],
            'credit' => (float)$row['credit'],
            'section_name' => $row['section_name'],
            'grade' => $row['grade'] ?: 'N/A',
            'grade_point' => $gradePoint,
            'status' => $row['status'] ?? 'draft',
            'total_marks' => $row['total_marks'] !== null ? (float)$row['total_marks'] : 0.0,
        ];
        $historyMap[$trimId]['_total_count']++;
        if ($gradePoint !== null) {
            $credit = (float)$row['credit'];
            $historyMap[$trimId]['_weighted_points'] += ($gradePoint * $credit);
            $historyMap[$trimId]['_weighted_credits'] += $credit;
            $historyMap[$trimId]['_graded_count']++;
        }
    }

    $cumulativePoints = 0.0;
    $cumulativeCredits = 0.0;
    foreach ($historyMap as &$term) {
        if ($term['_weighted_credits'] > 0) {
            $term['gpa'] = number_format($term['_weighted_points'] / $term['_weighted_credits'], 2);
            $cumulativePoints += $term['_weighted_points'];
            $cumulativeCredits += $term['_weighted_credits'];
        }
        if ($cumulativeCredits > 0) {
            $term['cgpa'] = number_format($cumulativePoints / $cumulativeCredits, 2);
        }
        if ($term['_graded_count'] === $term['_total_count'] && $term['_total_count'] > 0) {
            $term['status'] = 'approved';
        }
        unset($term['_weighted_points'], $term['_weighted_credits'], $term['_graded_count'], $term['_total_count']);
    }
    unset($term);

    echo json_encode([
        'success' => true,
        'studentSummary' => $studentSummary,
        'studentCourses' => $studentCourses,
        'studentHistory' => array_values($historyMap),
        'trimesterTitle' => $trimesterTitle,
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Unable to load student history.']);
}
