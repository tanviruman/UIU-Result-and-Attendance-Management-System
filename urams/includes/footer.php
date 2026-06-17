<?php
// includes/footer.php
// Step: Common JS load. Body close ekhane.
?>
<script src="public/assets/js/script.js"></script>
<script src="public/assets/js/academic_admin.js"></script>
<script>
document.addEventListener('DOMContentLoaded', function() {
  const teacherPage = document.getElementById('page-teacher');
  const studentPage = document.getElementById('page-student');
  const parentPage = document.getElementById('page-parent');
  const adminPage = document.getElementById('page-admin');
  
  if (teacherPage) {
    currentRole = 'teacher';
    initTeacherDashboard();
  } else if (studentPage) {
    currentRole = 'student';
    initStudentDashboard();
  } else if (parentPage) {
    currentRole = 'parent';
    initParentDashboard();
  } else if (adminPage) {
    currentRole = 'admin';
    initAdminDashboard();
  }
  
  console.log('URAMS initialized. Role:', currentRole, 'Students:', STUDENTS.length);
});
</script>
</body>
</html>