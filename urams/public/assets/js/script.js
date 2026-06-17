/*
URAMS frontend JavaScript.
Simple English/Bangla note: UI navigation, tables, toast messages and HTML5 Canvas charts are kept here.
*/

/* ── Global State ──────────────────────────────────────────────── */
let currentRole = 'student';
let confirmCallback = null;
let isDark = localStorage.getItem('urams-dark') === 'true';
let marksChartVisible = false;
let attChartVisible = false;
window.currentEditComponent = window.currentEditComponent || 'ct1';
let currentEditComponent = window.currentEditComponent;

/* ── DB-backed initial state ────────────────────────────────────── */
let STUDENTS = Array.isArray(window.URAMS_TEACHER_STUDENTS) ? window.URAMS_TEACHER_STUDENTS : [];
let TEACHER_COMPONENTS = Array.isArray(window.URAMS_TEACHER_COMPONENTS) ? window.URAMS_TEACHER_COMPONENTS : [];

function syncTeacherGlobals(students, components, section){
  STUDENTS = Array.isArray(students) ? students : [];
  TEACHER_COMPONENTS = Array.isArray(components) ? components : [];
  window.URAMS_TEACHER_STUDENTS = STUDENTS;
  window.URAMS_TEACHER_COMPONENTS = TEACHER_COMPONENTS;
  if(section) window.URAMS_TEACHER_SECTION = section;
}

const GRADE_RULES = [
  {min:90,max:100,grade:'A+',point:4.00,remark:'Outstanding'},
  {min:85,max:89,grade:'A',point:3.75,remark:'Excellent'},
  {min:80,max:84,grade:'A-',point:3.50,remark:'Very Good'},
  {min:75,max:79,grade:'B+',point:3.25,remark:'Good'},
  {min:70,max:74,grade:'B',point:3.00,remark:'Above Average'},
  {min:65,max:69,grade:'B-',point:2.75,remark:'Average'},
  {min:60,max:64,grade:'C+',point:2.50,remark:'Below Average'},
  {min:55,max:59,grade:'C',point:2.25,remark:'Pass'},
  {min:50,max:54,grade:'D',point:2.00,remark:'Marginal Pass'},
  {min:0,max:49,grade:'F',point:0.00,remark:'Fail'},
];

const TRIMESTER_RESULTS = [];

// Deprecated fallback arrays kept empty so final panels do not depend on fake/static sample data.
const AUDIT_ENTRIES = [];
const APPROVE_DATA = [];
const TEACHERS_DATA = [];
const STUDENTS_LIST = [];

/* ══════════════════════════════════════════════════════════════════
   DARK MODE
   ══════════════════════════════════════════════════════════════════ */
function toggleDarkMode(){
  isDark = !isDark;
  document.body.classList.toggle('dark-mode', isDark);
  document.getElementById('dm-icon').className = isDark ? 'fas fa-sun' : 'fas fa-moon';
  localStorage.setItem('urams-dark', isDark);
}
if(isDark){
  document.body.classList.add('dark-mode');
  document.getElementById('dm-icon').className = 'fas fa-sun';
}

/* ══════════════════════════════════════════════════════════════════
   TOAST SYSTEM
   ══════════════════════════════════════════════════════════════════ */
function showToast(msg, type='success', title=''){
  const icons = {success:'fa-check-circle',error:'fa-exclamation-circle',info:'fa-info-circle',warning:'fa-exclamation-triangle'};
  const titles = {success:'Success',error:'Error',info:'Info',warning:'Warning'};
  const t = document.createElement('div');
  t.className = `toast toast-${type}`;
  t.style.position='relative';
  t.innerHTML = `
    <div class="toast-icon"><i class="fas ${icons[type]||icons.success}"></i></div>
    <div class="toast-content">
      <div class="toast-title">${title||titles[type]}</div>
      <div class="toast-msg">${msg}</div>
    </div>
    <div class="toast-progress"></div>
  `;
  document.getElementById('toast-container').appendChild(t);
  setTimeout(()=>{
    t.classList.add('removing');
    setTimeout(()=>t.remove(),300);
  },3000);
}

/* ══════════════════════════════════════════════════════════════════
   MODAL SYSTEM
   ══════════════════════════════════════════════════════════════════ */
function openModal(id){ document.getElementById(id).classList.add('open'); }
function closeModal(id){ document.getElementById(id).classList.remove('open'); }
document.querySelectorAll('.modal-overlay').forEach(o=>{
  o.addEventListener('click', e=>{ if(e.target===o) o.classList.remove('open'); });
});

/* ══════════════════════════════════════════════════════════════════
   SIDEBAR
   ══════════════════════════════════════════════════════════════════ */
function toggleSidebar(id){
  const sb = document.getElementById(id);
  const ov = document.getElementById('sidebar-overlay');
  sb.classList.toggle('mobile-open');
  ov.classList.toggle('show');
}
function closeSidebar(){
  document.querySelectorAll('.sidebar').forEach(s=>s.classList.remove('mobile-open'));
  document.getElementById('sidebar-overlay').classList.remove('show');
}

/* ══════════════════════════════════════════════════════════════════
   NOTIFICATIONS
   ══════════════════════════════════════════════════════════════════ */
function toggleNotifications(id){
  const dd = document.getElementById(id);
  dd.classList.toggle('open');
  document.addEventListener('click', function handler(e){
    if(!dd.contains(e.target)){
      dd.classList.remove('open');
      document.removeEventListener('click',handler);
    }
  });
}
function markNotifRead(el){
  el.classList.remove('unread');
  const dot = el.querySelector('.notif-dot');
  if(dot) dot.style.opacity='0';
  updateBadge(el);
}
function markAllRead(ddId){
  document.querySelectorAll(`#${ddId} .notif-item`).forEach(el=>el.classList.remove('unread'));
  document.querySelectorAll(`#${ddId} .notif-dot`).forEach(d=>d.style.opacity='0');
  showToast('All notifications marked as read','info');
}
function updateBadge(el){ /* simplified */ }

/* ══════════════════════════════════════════════════════════════════
   LOGIN
   ══════════════════════════════════════════════════════════════════ */
function selectRole(role, el){
  currentRole = role;
  document.querySelectorAll('.role-tab').forEach(t=>t.classList.remove('active'));
  if(el) el.classList.add('active');
  const placeholders = {
    student:'e.g. 0242220005',
    teacher:'e.g. MRI (Teacher Initial)',
    admin:'e.g. admin001',
    parent:'e.g. Parent Student ID'
  };
  document.getElementById('login-uid').placeholder = placeholders[role];
}
function togglePwd(){
  const inp = document.getElementById('login-pass');
  const icon = document.getElementById('eye-icon');
  if(inp.type==='password'){inp.type='text';icon.className='fas fa-eye-slash';}
  else{inp.type='password';icon.className='fas fa-eye';}
}
function handleLogin(){
  const uid = document.getElementById('login-uid').value.trim();
  const pwd = document.getElementById('login-pass').value.trim();
  let valid = true;
  document.getElementById('err-uid').classList.remove('show');
  document.getElementById('err-pass').classList.remove('show');
  if(!uid){document.getElementById('err-uid').classList.add('show');valid=false;}
  if(!pwd){document.getElementById('err-pass').classList.add('show');valid=false;}
  if(!valid) return;
  // Show spinner
  document.getElementById('login-btn-text').textContent='Signing in...';
  document.getElementById('login-btn-icon').style.display='none';
  document.getElementById('login-spinner').classList.add('show');
  setTimeout(()=>{
    document.getElementById('login-btn-text').textContent='Sign In';
    document.getElementById('login-btn-icon').style.display='';
    document.getElementById('login-spinner').classList.remove('show');
    navigateTo('page-'+currentRole);
    showToast(`Welcome back! Logged in as ${currentRole}`,'success','Login Successful');
    setTimeout(initCurrentPanel,300);
  },1200);
}
function handleRemember(){
  if(document.getElementById('remember-me').checked){
    localStorage.setItem('urams-uid', document.getElementById('login-uid').value);
  } else {
    localStorage.removeItem('urams-uid');
  }
}
function showForgotModal(){ openModal('modal-forgot'); }
// Restore saved UID
const savedUid = localStorage.getItem('urams-uid');
if(savedUid && document.getElementById('login-uid')){ document.getElementById('login-uid').value=savedUid; const rememberEl=document.getElementById('remember-me'); if(rememberEl) rememberEl.checked=true; }

/* ══════════════════════════════════════════════════════════════════
   PAGE NAVIGATION
   ══════════════════════════════════════════════════════════════════ */
function navigateTo(pageId){
  document.querySelectorAll('.page').forEach(p=>p.classList.remove('active'));
  const p = document.getElementById(pageId);
  if(p) p.classList.add('active');
  closeSidebar();
}
function logout(){
  // PHP app logout: session destroy hobe logout.php file e.
  showToast('Logged out successfully','info','Bye!');
  setTimeout(()=>{ window.location.href = 'logout.php'; },500);
}
function initCurrentPanel(){
  if(currentRole==='teacher'){ initTeacherDashboard(); }
  else if(currentRole==='student'){ initStudentDashboard(); }
  else if(currentRole==='admin'){ initAdminDashboard(); }
  else if(currentRole==='parent'){ initParentDashboard(); }
}

/* ══════════════════════════════════════════════════════════════════
   TEACHER NAVIGATION
   ══════════════════════════════════════════════════════════════════ */
const teacherViews = ['dashboard','marks','attendance','submit','pdf','profile'];
function teacherNav(view, navEl){
  teacherViews.forEach(v=>{
    const el = document.getElementById('view-'+v);
    if(el) el.style.display = v===view ? '' : 'none';
  });
  if(navEl){
    document.querySelectorAll('#teacher-sidebar .nav-item').forEach(n=>n.classList.remove('active'));
    navEl.classList.add('active');
  }
  const titles = {dashboard:'Dashboard',marks:'Add / Edit Marks',attendance:'Attendance',submit:'Submit Results',pdf:'Download PDF'};
  document.getElementById('teacher-page-title').textContent = titles[view]||view;
  if(view==='marks') initMarksTable();
  if(view==='attendance') initAttendanceTable();
  if(view==='marks' && marksChartVisible) drawMarksChart();
  if(view==='attendance' && attChartVisible) drawAttChart();
}

/* ══════════════════════════════════════════════════════════════════
   TEACHER DASHBOARD INIT
   ══════════════════════════════════════════════════════════════════ */
/* ══════════════════════════════════════════════════════════════════
   TEACHER DASHBOARD INIT
   ══════════════════════════════════════════════════════════════════ */
function initTeacherDashboard(){
  populateTeacherFilters();
  updateTeacherDashboardUI();
  renderResultTable();
  document.getElementById('view-dashboard').style.display='';
  teacherViews.filter(v=>v!=='dashboard').forEach(v=>{
    const el=document.getElementById('view-'+v);
    if(el) el.style.display='none';
  });
}

function populateTeacherFilters() {
  const sections = window.URAMS_TEACHER_SECTIONS;
  if (!sections || !sections.length) return;

  const triSelect = document.getElementById('filter-trimester');
  const courseSelect = document.getElementById('filter-course');
  const secSelect = document.getElementById('filter-section');

  if (!triSelect || !courseSelect || !secSelect) return;

  const trimesters = [...new Set(sections.map(s => s.trimester_name))];
  const courses = [...new Set(sections.map(s => `${s.course_name} (${s.course_code})`))];
  const secNames = [...new Set(sections.map(s => s.section_name))];

  triSelect.innerHTML = trimesters.map(t => `<option>${t}</option>`).join('');
  courseSelect.innerHTML = courses.map(c => `<option>${c}</option>`).join('');
  secSelect.innerHTML = secNames.map(s => `<option>${s}</option>`).join('');
}

function updateTeacherDashboardUI() {
  const sections = window.URAMS_TEACHER_SECTIONS || [];
  const activeCoursesCount = [...new Set(sections.map(s => s.course_code))].length;
  
  let totalStudents = 0;
  let submittedCount = 0;
  let pendingCount = 0;
  sections.forEach(s => {
    totalStudents += parseInt(s.student_count) || 0;
    if (s.status === 'submitted' || s.status === 'approved') {
      submittedCount++;
    } else {
      pendingCount++;
    }
  });

  const statsElements = document.querySelectorAll('#view-dashboard .stats-grid .stat-value');
  if (statsElements.length >= 4) {
    statsElements[0].textContent = activeCoursesCount;
    statsElements[1].textContent = totalStudents;
    statsElements[2].textContent = submittedCount;
    statsElements[3].textContent = pendingCount;
  }
  
  const cardTitle = document.querySelector('#view-dashboard .card .card-title');
  const cardSubtitle = document.querySelector('#view-dashboard .card .card-subtitle');
  if (window.URAMS_TEACHER_SECTION) {
    const sec = window.URAMS_TEACHER_SECTION;
    if (cardTitle) {
      cardTitle.textContent = `${sec.course_title} — Section ${sec.section} | ${sec.trimester}`;
    }
    if (cardSubtitle) {
      cardSubtitle.textContent = `${STUDENTS.length} students enrolled · Results: ${sec.status || 'Draft'}`;
    }
  }
}

function loadSectionData(sectionId) {
  fetch(`get_section_students.php?section_id=${sectionId}`)
    .then(res => res.json())
    .then(data => {
      if (!data.success) {
        showToast(data.message || 'Failed to load section data.', 'error', 'Error');
        return;
      }
      STUDENTS = data.students;
      window.URAMS_TEACHER_SECTION = data.section;
      
      updateTeacherDashboardUI();
      renderResultTable();
      showToast('Section loaded successfully.', 'success', 'Loaded');
    })
    .catch(err => {
      showToast('Error fetching section data.', 'error', 'Error');
    });
}

function renderResultTable(){
  const tbody = document.getElementById('result-tbody');
  if(!tbody) return;
  tbody.innerHTML = STUDENTS.map((s,i)=>{
    const best = Math.max(s.ct1,s.ct2);
    const total = best + (s.assignment || 0) + s.mid + s.final + s.att;
    const pct = (total/100)*100;
    const grade = getGrade(pct);
    const grClass = grade==='A+'?'grade-A-plus':grade.startsWith('A')?'grade-A':grade.startsWith('B')?'grade-B':grade.startsWith('C')?'grade-C':grade==='D'?'grade-D':'grade-F';
    return `<tr>
      <td><div class="td-avatar">${s.name.split(' ').map(w=>w[0]).join('').slice(0,2)}</div></td>
      <td><span class="td-id">${s.id}</span> <button class="btn btn-sm btn-ghost" style="font-size:10px;padding:2px 5px" onclick="openStudentModal('${s.name}','${s.id}')"><i class="fas fa-eye"></i></button></td>
      <td class="td-name">${s.name}</td>
      <td class="${s.ct1>s.ct2?'best-mark':''}">${s.ct1}</td>
      <td class="${s.ct2>s.ct1?'best-mark':''}">${s.ct2}</td>
      <td style="color:var(--success);font-weight:700">${best}</td>
      <td>${s.assignment || 0}</td>
      <td>${s.mid}</td>
      <td>${s.final}</td>
      <td>${s.att}</td>
      <td style="font-weight:800">${total.toFixed(1)}</td>
      <td><span class="${grClass}">${grade}</span></td>
    </tr>`;
  }).join('');
  document.getElementById('student-count').textContent = STUDENTS.length;
}
function getGrade(pct){
  for(const r of GRADE_RULES){ if(pct>=r.min && pct<=r.max) return r.grade; }
  return 'F';
}
function getGradePoint(total){
  for(const r of GRADE_RULES){ if(total>=r.min && total<=r.max) return r.point; }
  return 0.00;
}
function filterStudents(){
  const q = document.getElementById('student-search').value.toLowerCase();
  document.querySelectorAll('#result-tbody tr').forEach(tr=>{
    tr.style.display = tr.textContent.toLowerCase().includes(q)?'':'none';
  });
}
function filterChanged(){
  const sections = window.URAMS_TEACHER_SECTIONS;
  if (!sections) return;
  
  const selectedTri = document.getElementById('filter-trimester').value;
  const selectedCourseText = document.getElementById('filter-course').value;
  
  const filtered = sections.filter(s => 
    s.trimester_name === selectedTri && 
    `${s.course_name} (${s.course_code})` === selectedCourseText
  );
  
  const secSelect = document.getElementById('filter-section');
  if (secSelect) {
    secSelect.innerHTML = filtered.map(s => `<option>${s.section_name}</option>`).join('');
  }
}
function applyFilter(){
  const sections = window.URAMS_TEACHER_SECTIONS;
  if (!sections) return;

  const selectedTri = document.getElementById('filter-trimester').value;
  const selectedCourseText = document.getElementById('filter-course').value;
  const selectedSec = document.getElementById('filter-section').value;

  const section = sections.find(s => 
    s.trimester_name === selectedTri && 
    `${s.course_name} (${s.course_code})` === selectedCourseText &&
    s.section_name === selectedSec
  );

  if (!section) {
    showToast('No matching course section found.','warning','Not Found');
    return;
  }

  showToast('Loading section data...','info','Filter');
  loadSectionData(section.section_id);
}

/* ══════════════════════════════════════════════════════════════════
   MARKS TABLE
   ══════════════════════════════════════════════════════════════════ */
function changeEditComponent(comp) {
  currentEditComponent = comp;
  const selectEl = document.getElementById('edit-component-select');
  if (selectEl) selectEl.value = comp;

  const defaults = {
    ct1: { taken: 30, convert: 15 },
    ct2: { taken: 30, convert: 15 },
    assignment: { taken: 10, convert: 10 },
    mid: { taken: 50, convert: 25 },
    final: { taken: 80, convert: 40 },
    attendance_marks: { taken: 10, convert: 10 }
  };
  
  const conf = defaults[comp] || { taken: 100, convert: 100 };
  document.getElementById('conf-taken').value = conf.taken;
  document.getElementById('conf-convert').value = conf.convert;
  document.getElementById('conf-grace').value = 0;

  const labels = {
    ct1: 'CT1',
    ct2: 'CT2',
    assignment: 'Assignment',
    mid: 'Mid Term',
    final: 'Final Exam',
    attendance_marks: 'Attendance'
  };
  const titleEl = document.querySelector('#view-marks .section-title');
  if (titleEl) {
    titleEl.textContent = `${labels[comp] || comp} Marks Entry`;
  }
  
  initMarksTable();
}

function initMarksTable(){
  const tbody = document.getElementById('marks-tbody');
  if(!tbody) return;
  
  const comp = window.currentEditComponent || 'ct1';
  const taken = parseFloat(document.getElementById('conf-taken').value) || 30;
  const convertTo = parseFloat(document.getElementById('conf-convert').value) || 15;

  tbody.innerHTML = STUDENTS.map((s,i)=>{
    const convertedVal = parseFloat(comp === 'attendance_marks' ? (s.att || 0) : (s[comp] || 0));
    const actualVal = convertTo > 0 ? (convertedVal / convertTo * taken) : 0;
    
    return `<tr id="marks-row-${i}">
      <td>${i+1}</td>
      <td><div class="td-avatar">${s.name.split(' ').map(w=>w[0]).join('').slice(0,2)}</div></td>
      <td class="td-id">${s.id}</td>
      <td class="td-name">${s.name}</td>
      <td>
        <input class="marks-input" type="number" min="0" max="${taken}" value="${actualVal.toFixed(1)}" 
          oninput="calcConverted(this,${i})" id="actual-${i}" readonly>
      </td>
      <td><span class="marks-converted" id="conv-${i}">${convertedVal.toFixed(1)}</span></td>
      <td><input type="checkbox" id="abs-${i}" onchange="markAbsent(${i})"></td>
      <td>
        <button class="btn btn-sm btn-ghost" id="edit-btn-${i}" onclick="enableEdit(${i})"><i class="fas fa-edit"></i> Edit</button>
        <button class="btn btn-sm btn-success" id="save-btn-${i}" style="display:none" onclick="saveRow(${i})"><i class="fas fa-save"></i> Save</button>
      </td>
    </tr>`;
  }).join('');
}
function enableEdit(i){
  document.getElementById(`actual-${i}`).removeAttribute('readonly');
  document.getElementById(`actual-${i}`).style.border='1.5px solid var(--primary)';
  document.getElementById(`edit-btn-${i}`).style.display='none';
  document.getElementById(`save-btn-${i}`).style.display='';
  document.getElementById(`actual-${i}`).focus();
}
function calcConverted(inp,i){
  const taken = parseFloat(document.getElementById('conf-taken').value)||30;
  const convertTo = parseFloat(document.getElementById('conf-convert').value)||15;
  const grace = parseFloat(document.getElementById('conf-grace').value)||0;
  const actual = parseFloat(inp.value)||0;
  const conv = ((actual/taken)*convertTo)+grace;
  document.getElementById(`conv-${i}`).textContent = Math.min(conv,convertTo).toFixed(1);
}
function markAbsent(i){
  const absent = document.getElementById(`abs-${i}`).checked;
  const inp = document.getElementById(`actual-${i}`);
  if(absent){ inp.value=0; inp.disabled=true; document.getElementById(`conv-${i}`).textContent='0'; }
  else { inp.disabled=false; }
}
function saveRow(i){
  const student = STUDENTS[i];
  const resultId = student.result_id;
  const comp = window.currentEditComponent || 'ct1';
  const convertedVal = parseFloat(document.getElementById(`conv-${i}`).textContent) || 0;
  if (!resultId) {
    showToast('Unable to save marks: missing result link.','error','Save Failed');
    return;
  }
  fetch('save_marks.php', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({result_id: resultId, component: comp, marks: convertedVal}),
  })
  .then(response => response.json())
  .then(data => {
    if (!data.success) {
      showToast(data.message || 'Failed to save marks.','error','Save Failed');
      return;
    }
    
    // Sync local student values
    if (comp === 'attendance_marks') student.att = convertedVal;
    else student[comp] = convertedVal;
    
    if (data.updated && data.updated[0]) {
      const updated = data.updated[0];
      student.ct1 = updated.ct1;
      student.ct2 = updated.ct2;
      student.assignment = updated.assignment;
      student.mid = updated.mid;
      student.final = updated.final;
      student.att = updated.attendance_marks;
      student.best_ct = updated.best_ct;
      student.total_marks = updated.total_marks;
      student.grade = updated.grade;
      student.grade_point = updated.grade_point;
    }
    document.getElementById(`actual-${i}`).setAttribute('readonly','');
    document.getElementById(`actual-${i}`).style.border='';
    document.getElementById(`edit-btn-${i}`).style.display='';
    document.getElementById(`save-btn-${i}`).style.display='none';
    showToast(`Marks saved for ${student.name}`,'success','Saved');
    if (document.getElementById('result-tbody')) renderResultTable();
  })
  .catch(() => {
    showToast('Unable to save marks. Check your connection.','error','Save Failed');
  });
}
function saveAllMarks(){
  const comp = window.currentEditComponent || 'ct1';
  const updates = STUDENTS.map((student,i) => {
    return {
      result_id: student.result_id,
      marks: parseFloat(document.getElementById(`conv-${i}`).textContent) || 0,
    };
  }).filter(item => item.result_id);

  if (!updates.length) {
    showToast('No student records available to save.','warning','Nothing to Save');
    return;
  }

  fetch('save_marks.php', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({component: comp, updates: updates}),
  })
  .then(response => response.json())
  .then(data => {
    if (!data.success) {
      showToast(data.message || 'Failed to save marks.','error','Save Failed');
      return;
    }
    data.updated.forEach(updated => {
      const student = STUDENTS.find(s => s.result_id === updated.result_id);
      if (student) {
        student.ct1 = updated.ct1;
        student.ct2 = updated.ct2;
        student.assignment = updated.assignment;
        student.mid = updated.mid;
        student.final = updated.final;
        student.att = updated.attendance_marks;
        student.best_ct = updated.best_ct;
        student.total_marks = updated.total_marks;
        student.grade = updated.grade;
        student.grade_point = updated.grade_point;
      }
    });
    showToast('All marks saved successfully!','success','Saved');
    if (document.getElementById('result-tbody')) renderResultTable();
  })
  .catch(() => {
    showToast('Unable to save marks. Check your connection.','error','Save Failed');
  });
}
function filterMarksTable(q){
  q = q.toLowerCase();
  document.querySelectorAll('#marks-tbody tr').forEach(tr=>{ tr.style.display=tr.textContent.toLowerCase().includes(q)?'':'none'; });
}
function saveConfig(){ showToast('Exam configuration updated!','success','Config Saved'); }
function toggleMarksChart(){
  marksChartVisible = !marksChartVisible;
  const wrap = document.getElementById('marks-chart-wrapper');
  wrap.style.display = marksChartVisible ? '' : 'none';
  if(marksChartVisible) setTimeout(drawMarksChart,50);
}
function drawMarksChart(){
  const canvas = document.getElementById('marks-bar-chart');
  if(!canvas) return;
  const labels = STUDENTS.map(s=>s.name.split(' ')[0]);
  const data = STUDENTS.map(s=>s.ct1);
  drawBarChart(canvas, labels, data, 'CT1 Marks');
}

/* ══════════════════════════════════════════════════════════════════
   ATTENDANCE TABLE
   ══════════════════════════════════════════════════════════════════ */
function getAttendanceMetrics(dates){
  const total = dates.length;
  const present = dates.filter(d=>d==='P').length;
  const absent = dates.filter(d=>d==='A').length;
  const pct = total ? Math.round((present/total)*100) : 0;
  const attMarks = pct >= 75 ? 10 : 0;
  return {total, present, absent, pct, attMarks};
}

function initAttendanceTable(){
  // Initialize ATTENDANCE_DATA dynamically from current STUDENTS list if it differs
  if (STUDENTS.length > 0) {
    ATTENDANCE_DATA = STUDENTS.map(s => {
      const existing = ATTENDANCE_DATA.find(a => a.id === s.id);
      let initialDates = ['P','P','P','P','P'];
      if (s.att < 10) {
        initialDates = ['P','P','A','A','P'];
      }
      return {
        id: s.id,
        name: s.name,
        dates: existing ? existing.dates : initialDates
      };
    });
  }

  const tbody = document.getElementById('att-tbody');
  if(!tbody) return;
  tbody.innerHTML = ATTENDANCE_DATA.map((s,i)=>{
    const metrics = getAttendanceMetrics(s.dates);
    const dateCells = s.dates.map((d,di)=>`
      <td>
        <div class="att-toggle att-${d}" id="att-${i}-${di}">${d}</div>
      </td>
    `).join('');
    return `<tr>
      <td><div class="td-avatar">${s.name.split(' ').map(w=>w[0]).join('').slice(0,2)}</div></td>
      <td class="td-id">${s.id}</td>
      <td class="td-name">${s.name}</td>
      ${dateCells}
      <td style="font-weight:700">${metrics.total}</td>
      <td id="att-present-${i}" style="color:var(--success);font-weight:700">${metrics.present}</td>
      <td id="att-absent-${i}" style="color:var(--danger);font-weight:700">${metrics.absent}</td>
      <td>
        <div style="display:flex;align-items:center;gap:8px">
          <div class="progress-bar-wrap" style="width:50px">
            <div class="progress-bar-fill" id="att-bar-${i}" style="width:${metrics.pct}%;background:${metrics.pct>=75?'var(--success)':'var(--danger)'}"></div>
          </div>
          <span id="att-pct-${i}" style="font-weight:700;color:${metrics.pct>=75?'var(--success)':'var(--danger)'}">${metrics.pct}%</span>
        </div>
      </td>
      <td id="att-marks-${i}" style="font-weight:700;color:${metrics.attMarks>0?'var(--success)':'var(--danger)'}">${metrics.attMarks}</td>
    </tr>`;
  }).join('');
  bindAttendanceEvents();
}
function bindAttendanceEvents(){
  const tbody = document.getElementById('att-tbody');
  if(!tbody) return;
  tbody.removeEventListener('click', attendanceTableClickHandler);
  tbody.addEventListener('click', attendanceTableClickHandler);
}
function attendanceTableClickHandler(e){
  const target = e.target.closest('.att-toggle');
  if(!target) return;
  const parts = target.id.split('-');
  if(parts.length !== 3) return;
  const row = parseInt(parts[1], 10);
  const col = parseInt(parts[2], 10);
  if(Number.isNaN(row) || Number.isNaN(col)) return;
  toggleAtt(row, col);
}
function updateAttendanceRow(i){
  const student = ATTENDANCE_DATA[i];
  if(!student) return;
  const metrics = getAttendanceMetrics(student.dates);
  const presentEl = document.getElementById(`att-present-${i}`);
  const absentEl = document.getElementById(`att-absent-${i}`);
  const pctEl = document.getElementById(`att-pct-${i}`);
  const barEl = document.getElementById(`att-bar-${i}`);
  const marksEl = document.getElementById(`att-marks-${i}`);
  if(presentEl) presentEl.textContent = metrics.present;
  if(absentEl) absentEl.textContent = metrics.absent;
  if(pctEl){
    pctEl.textContent = `${metrics.pct}%`;
    pctEl.style.color = metrics.pct >= 75 ? 'var(--success)' : 'var(--danger)';
  }
  if(barEl){
    barEl.style.width = `${metrics.pct}%`;
    barEl.style.background = metrics.pct >= 75 ? 'var(--success)' : 'var(--danger)';
  }
  if(marksEl){
    marksEl.textContent = metrics.attMarks;
    marksEl.style.color = metrics.attMarks > 0 ? 'var(--success)' : 'var(--danger)';
  }
}
function toggleAtt(i,di){
  const states = ['P','A','L'];
  const el = document.getElementById(`att-${i}-${di}`);
  if(!el) return;
  const cur = el.textContent.trim();
  const next = states[(states.indexOf(cur)+1)%3];
  el.textContent = next;
  el.className = `att-toggle att-${next}`;
  if(ATTENDANCE_DATA[i]){
    ATTENDANCE_DATA[i].dates[di] = next;
  }
  updateAttendanceRow(i);
}
function saveAttendance(){
  const updates = ATTENDANCE_DATA.map((student, i) => {
    const sObj = STUDENTS.find(s => s.id === student.id);
    if (!sObj || !sObj.result_id) return null;
    
    const metrics = getAttendanceMetrics(student.dates);
    return {
      result_id: sObj.result_id,
      marks: metrics.attMarks
    };
  }).filter(item => item !== null);

  if (!updates.length) {
    showToast('No attendance records to save.','warning','Nothing to Save');
    return;
  }

  fetch('save_marks.php', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({component: 'attendance_marks', updates: updates})
  })
  .then(response => response.json())
  .then(data => {
    if (!data.success) {
      showToast(data.message || 'Failed to save attendance.','error','Failed');
      return;
    }
    data.updated.forEach(updated => {
      const student = STUDENTS.find(s => s.result_id === updated.result_id);
      if (student) {
        student.ct1 = updated.ct1;
        student.ct2 = updated.ct2;
        student.assignment = updated.assignment;
        student.mid = updated.mid;
        student.final = updated.final;
        student.att = updated.attendance_marks;
        student.best_ct = updated.best_ct;
        student.total_marks = updated.total_marks;
        student.grade = updated.grade;
        student.grade_point = updated.grade_point;
      }
    });
    showToast('Attendance marks saved successfully!','success','Saved');
    if (document.getElementById('result-tbody')) renderResultTable();
  })
  .catch(() => {
    showToast('Unable to save attendance. Check your connection.','error','Save Failed');
  });
}
function editAll(){ showToast('All rows are now editable — click cells to toggle','info','Edit Mode'); }
function addClassDate(){ showToast('New class date column added!','success','Date Added'); }
function toggleAttChart(){
  attChartVisible = !attChartVisible;
  document.getElementById('att-chart-wrapper').style.display = attChartVisible?'':'none';
  if(attChartVisible) setTimeout(drawAttChart,50);
}
function drawAttChart(){
  const canvas = document.getElementById('att-bar-chart');
  if(!canvas) return;
  const labels = ATTENDANCE_DATA.map(s=>s.name.split(' ')[0]);
  const data = ATTENDANCE_DATA.map(s=>{
    const p = s.dates.filter(d=>d==='P').length;
    return Math.round((p/s.dates.length)*100);
  });
  drawBarChart(canvas, labels, data, 'Attendance %', true);
}

/* ══════════════════════════════════════════════════════════════════
   ADD MARKS MODAL
   ══════════════════════════════════════════════════════════════════ */
function openAddMarksModal(){
  const modal = document.getElementById('modal-add-marks');
  if (!modal) {
    showToast('Marks editor is available in the Marks view tab.', 'info', 'Info');
    teacherNav('marks', null);
    return;
  }
  openModal('modal-add-marks');
}
function examTypeChanged(){}
function toggleBestOf(){ document.getElementById('bestof-count-wrap').style.display=document.getElementById('am-bestof').checked?'':'none'; }
function submitAddMarks(){
  closeModal('modal-add-marks');
  showToast('New exam column added to result table!','success','Column Added');
}

/* ══════════════════════════════════════════════════════════════════
   GRACE MODAL
   ══════════════════════════════════════════════════════════════════ */
function openGraceModal(){ 
  document.getElementById('grace-amount').value = '1';
  openModal('modal-grace'); 
}
function applyGrace(){
  const graceValue = parseFloat(document.getElementById('grace-amount').value) || 0;
  if (graceValue < 0 || graceValue > 5) {
    showToast('Grace must be between 0 and 5 points','warning','Invalid Value');
    return;
  }
  if (!STUDENTS || STUDENTS.length === 0) {
    showToast('No student records found','warning','No Data');
    return;
  }
  closeModal('modal-grace');
  showToast('Applying grace marks...','info','Processing');
  
  const sectionId = STUDENTS[0]?.section_id;
  fetch('apply_grace.php', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({grace_value: graceValue, section_id: sectionId})
  })
  .then(response => {
    if (!response.ok) throw new Error('HTTP ' + response.status);
    return response.json();
  })
  .then(data => {
    if (!data.success) {
      showToast(data.message || 'Failed to apply grace marks','error','Failed');
      return;
    }
    STUDENTS.forEach(s => {
      s.att = Math.min(10, (s.att || 0) + graceValue);
      s.total_marks = (s.best_ct || s.ct1 || 0) + (s.assignment || 0) + (s.mid || 0) + (s.final || 0) + s.att;
      s.grade = getGrade(s.total_marks);
      s.grade_point = getGradePoint(s.total_marks);
    });
    setTimeout(() => {
      if (document.getElementById('result-tbody')) renderResultTable();
      if (document.getElementById('marks-tbody')) initMarksTable();
    }, 100);
    showToast('Grace ' + graceValue + ' added to all students!','success','Grace Applied');
  })
  .catch(err => {
    console.error('Grace error:', err);
    showToast('Could not apply grace marks: ' + err.message,'error','Error');
  });
}

/* ══════════════════════════════════════════════════════════════════
   CONFIRM DIALOG
   ══════════════════════════════════════════════════════════════════ */
function showConfirm(title,msg,type,cb){
  confirmCallback = cb;
  document.getElementById('confirm-title').textContent = title;
  document.getElementById('confirm-msg').textContent = msg;
  const icon = document.getElementById('confirm-icon');
  const okBtn = document.getElementById('confirm-ok-btn');
  if(type==='danger'){
    icon.style.background='rgba(239,68,68,0.12)';icon.style.color='var(--danger)';
    icon.innerHTML='<i class="fas fa-exclamation-circle"></i>';
    okBtn.className='btn btn-danger';
  } else {
    icon.style.background='rgba(16,185,129,0.12)';icon.style.color='var(--success)';
    icon.innerHTML='<i class="fas fa-check-circle"></i>';
    okBtn.className='btn btn-success';
  }
  openModal('modal-confirm');
}
function confirmAction(){
  closeModal('modal-confirm');
  if(confirmCallback) confirmCallback();
  confirmCallback=null;
}
function confirmSubmitResult(){
  const sectionTitle = window.URAMS_TEACHER_SECTION?.course_title || 'this section';
  showConfirm('Submit Results',`Are you sure you want to submit ${sectionTitle} results to Admin? You cannot edit after submission.`,'success',()=>{
    submitResultsToAdmin();
  });
}
function submitResultsToAdmin(){
  const sectionId = STUDENTS[0]?.section_id;
  fetch('submit_results.php', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({section_id: sectionId})
  })
  .then(response => response.json())
  .then(data => {
    if (!data.success) {
      showToast(data.message || 'Failed to submit results','error','Failed');
      return;
    }
    showToast('Results submitted to Admin for approval!','success','Submitted');
    setTimeout(() => location.reload(), 1500);
  })
  .catch(() => {
    showToast('Unable to submit results','error','Error');
  });
}
function applyBestCT(){
  if (!STUDENTS || STUDENTS.length === 0) {
    showToast('No student records found','warning','No Data');
    return;
  }
  const rows = document.querySelectorAll('#result-tbody tr');
  if (rows.length === 0) {
    showToast('Please load the result table first','warning','No Data');
    return;
  }
  let maxBestCT = -1;
  STUDENTS.forEach(s => {
    const best = Math.max(s.ct1 || 0, s.ct2 || 0);
    maxBestCT = Math.max(maxBestCT, best);
  });
  rows.forEach((row, idx) => {
    row.cells[3].classList.remove('best-mark');
    row.cells[4].classList.remove('best-mark');
    row.cells[5].classList.remove('best-mark');
    if (idx < STUDENTS.length) {
      const best = Math.max(STUDENTS[idx].ct1 || 0, STUDENTS[idx].ct2 || 0);
      STUDENTS[idx].best_ct = best;
      if (best === maxBestCT) {
        row.cells[5].classList.add('best-mark');
      }
    }
  });
  showToast('Best CT = ' + maxBestCT + ' — highlighted!','success','Best CT Applied');
}
function applyBestAssign(){
  if (!STUDENTS || STUDENTS.length === 0) {
    showToast('No student records found','warning','No Data');
    return;
  }
  const rows = document.querySelectorAll('#result-tbody tr');
  if (rows.length === 0) {
    showToast('Please load the result table first','warning','No Data');
    return;
  }
  let maxBestAssign = -1;
  STUDENTS.forEach(s => {
    maxBestAssign = Math.max(maxBestAssign, s.assignment || 0);
  });
  rows.forEach((row, idx) => {
    row.cells[6].classList.remove('best-mark');
    if (idx < STUDENTS.length) {
      if ((STUDENTS[idx].assignment || 0) === maxBestAssign) {
        row.cells[6].classList.add('best-mark');
      }
    }
  });
  showToast('Best Assignment = ' + maxBestAssign + ' — highlighted!','success','Best Assign Applied');
}

/* ══════════════════════════════════════════════════════════════════
   STUDENT DETAIL MODAL
   ══════════════════════════════════════════════════════════════════ */
function openStudentModal(name,id){
  const initials = name.split(' ').map(w=>w[0]).join('').slice(0,2);
  document.getElementById('modal-student-body').innerHTML = `
    <div class="student-profile-header">
      <div class="student-profile-avatar">${initials}</div>
      <div class="student-profile-info">
        <h3>${name}</h3>
        <p>${id} · CSE Department</p>
        <span class="badge badge-success" style="margin-top:4px"><i class="fas fa-check"></i> Active Student</span>
      </div>
    </div>
    <div class="info-grid">
      <div class="info-item"><div class="info-item-label">Email</div><div class="info-item-value">${id.toLowerCase()}@uiu.ac.bd</div></div>
      <div class="info-item"><div class="info-item-label">Phone</div><div class="info-item-value">+880 1711-XXXXXX</div></div>
      <div class="info-item"><div class="info-item-label">Program</div><div class="info-item-value">BSc in CSE</div></div>
      <div class="info-item"><div class="info-item-label">Semester</div><div class="info-item-value">8th</div></div>
    </div>
    <div style="font-weight:700;font-size:13px;margin-bottom:12px">Historical Results</div>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Trimester</th><th>Course</th><th>Grade</th><th>GP</th><th>Remarks</th></tr></thead>
        <tbody>
          <tr><td>Summer 2025</td><td>OOP (CSE4533)</td><td><span class="grade-A-plus">A+</span></td><td>4.00</td><td><span class="badge badge-success">Pass</span></td></tr>
          <tr><td>Spring 2025</td><td>DSA (CSE3533)</td><td><span class="grade-A">A</span></td><td>3.75</td><td><span class="badge badge-success">Pass</span></td></tr>
          <tr><td>Fall 2024</td><td>OS (CSE4833)</td><td><span class="grade-B">B+</span></td><td>3.25</td><td><span class="badge badge-success">Pass</span></td></tr>
        </tbody>
      </table>
    </div>
  `;
  openModal('modal-student');
}
function showPercentModal(exam){
  document.getElementById('percent-modal-title').textContent = `${exam} — % Distribution`;
  openModal('modal-percent');
  setTimeout(()=>{
    const canvas = document.getElementById('percent-chart');
    const labels = STUDENTS.map(s=>s.name.split(' ')[0]);
    const data = STUDENTS.map(s=>((exam==='CT1'?s.ct1:exam==='CT2'?s.ct2:s.mid)/15*100).toFixed(0));
    drawBarChart(canvas,labels,data,`${exam} Percentage`,true);
  },50);
}
function downloadPDF(){ showToast('PDF generated — opening print dialog','info','Download'); setTimeout(()=>window.print(),500); }
function openChartView(){
  marksChartVisible = !marksChartVisible;
  toggleMarksChart();
}

/* ══════════════════════════════════════════════════════════════════
   STUDENT PANEL + APPROVED RESULT VIEWER
   ══════════════════════════════════════════════════════════════════ */
const studentViews=['dashboard','continuous','history'];

function escapeHtml(value){
  return String(value ?? '').replace(/[&<>'"]/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#039;','"':'&quot;'}[ch]));
}
function formatNumber(value, decimals=1){
  const n = parseFloat(value);
  return Number.isFinite(n) ? n.toFixed(decimals) : (0).toFixed(decimals);
}
function getApprovedCourses(){
  if(Array.isArray(window.URAMS_STUDENT_COURSES)) return window.URAMS_STUDENT_COURSES;
  if(Array.isArray(window.URAMS_PARENT_COURSES)) return window.URAMS_PARENT_COURSES;
  return [];
}
function getApprovedTrimesters(){
  return Array.isArray(window.URAMS_TRIMESTER_RESULTS) ? window.URAMS_TRIMESTER_RESULTS : [];
}
function setApprovedPayload(payload){
  if(!payload || typeof payload !== 'object') return;
  const courses = Array.isArray(payload.courses) ? payload.courses : [];
  window.URAMS_STUDENT_COURSES = courses;
  if(document.getElementById('page-parent')) window.URAMS_PARENT_COURSES = courses;
  window.URAMS_TRIMESTER_RESULTS = Array.isArray(payload.trimester_results) ? payload.trimester_results : [];
}
function refreshApprovedResultsFromApi(callback){
  if(!window.URAMS_APPROVED_RESULTS_API || !window.fetch) {
    if(typeof callback === 'function') callback();
    return;
  }
  fetch(window.URAMS_APPROVED_RESULTS_API, {headers:{'Accept':'application/json'}})
    .then(res => res.ok ? res.json() : null)
    .then(json => {
      if(json && json.success && json.data) setApprovedPayload(json.data);
      if(typeof callback === 'function') callback();
    })
    .catch(() => { if(typeof callback === 'function') callback(); });
}

function studentNav(view,navEl){
  studentViews.forEach(v=>{
    const el=document.getElementById('s-view-'+v);
    if(el) el.style.display=v===view?'':'none';
  });
  if(navEl){
    document.querySelectorAll('#student-sidebar .nav-item').forEach(n=>n.classList.remove('active'));
    navEl.classList.add('active');
  }
  const titleEl = document.getElementById('student-page-title');
  const titles={dashboard:'My Dashboard',continuous:'Continuous Evaluation',history:'Result History'};
  if(titleEl) titleEl.textContent=titles[view]||view;
  if(view==='continuous') initStudentContinuousEvalFilters();
  if(view==='history') initResultHistory('result-history-accordion');
}
function initStudentDashboard(){
  initStudentContinuousEvalFilters();
  initResultHistory('result-history-accordion');
  setTimeout(()=>drawGPAChart('student-gpa-chart'),100);
  refreshApprovedResultsFromApi(()=>{
    initStudentContinuousEvalFilters();
    initResultHistory('result-history-accordion', true);
    setTimeout(()=>drawGPAChart('student-gpa-chart'),50);
  });
}
function initStudentContinuousEvalFilters(){
  const courses = getApprovedCourses();
  const container = document.getElementById('s-view-continuous');
  if(!container) return;

  const triSelect = document.getElementById('student-trimester-filter') || container.querySelector('select');
  const courseSelect = document.getElementById('student-course-filter') || container.querySelectorAll('select')[1];
  if(!triSelect || !courseSelect) return;

  if(!courses.length){
    triSelect.innerHTML = '<option>No approved trimester</option>';
    courseSelect.innerHTML = '<option>No approved course</option>';
    triSelect.disabled = true;
    courseSelect.disabled = true;
    return;
  }

  triSelect.disabled = false;
  courseSelect.disabled = false;
  const previousTri = triSelect.value;
  const trimesters = [...new Set(courses.map(c => c.trimester_name).filter(Boolean))];
  triSelect.innerHTML = trimesters.map(t => `<option value="${escapeHtml(t)}">${escapeHtml(t)}</option>`).join('');
  if(previousTri && trimesters.includes(previousTri)) triSelect.value = previousTri;

  triSelect.onchange = function(){
    const selectedTri = triSelect.value;
    const triCourses = courses.filter(c => c.trimester_name === selectedTri);
    courseSelect.innerHTML = triCourses.map(c => `<option value="${escapeHtml(c.course_code)}">${escapeHtml(c.course_name)} (${escapeHtml(c.course_code)})</option>`).join('');
  };
  triSelect.dispatchEvent(new Event('change'));
}
function initResultHistory(targetId='result-history-accordion', force=false){
  const el = document.getElementById(targetId);
  if(!el || (el.innerHTML && !force)) return;
  renderApprovedResultHistory(targetId);
}
function renderApprovedResultHistory(targetId){
  const el = document.getElementById(targetId);
  if(!el) return;

  const courses = getApprovedCourses();
  const trimesters = getApprovedTrimesters();
  if(!courses.length || !trimesters.length){
    el.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text2)">No approved result history found.</div>';
    return;
  }

  el.innerHTML = trimesters.map((t,i)=>{
    const triCourses = courses.filter(c => c.trimester_name === t.tri);
    const courseRows = triCourses.map(c => {
      const gp = c.grade_point !== null && c.grade_point !== undefined ? formatNumber(c.grade_point,2) : '---';
      const grade = c.grade || '---';
      const isPass = grade !== 'F' && grade !== '---';
      const remarkBadge = isPass ? '<span class="badge badge-success">Pass</span>' : '<span class="badge badge-danger">Fail</span>';
      return `
        <tr>
          <td class="td-id">${escapeHtml(c.course_code)}</td>
          <td class="td-name">${escapeHtml(c.course_name)}</td>
          <td>${formatNumber(c.credit,1)}</td>
          <td style="font-weight:700;color:var(--primary)">${gp}</td>
          <td><span class="grade-A">${escapeHtml(grade)}</span></td>
          <td style="font-weight:700">${formatNumber(c.total_marks,2)}</td>
          <td>${remarkBadge}</td>
        </tr>`;
    }).join('') || '<tr><td colspan="7" style="text-align:center">No approved courses in this trimester.</td></tr>';

    return `
      <div class="accordion-item">
        <div class="accordion-header ${i===0?'open':''}" onclick="toggleAccordion(this)">
          <div>
            <span style="font-weight:700">${escapeHtml(t.tri)}</span>
            <span style="margin-left:12px;color:var(--text2);font-size:12px">GPA: <strong>${formatNumber(t.gpa,2)}</strong> · CGPA: <strong>${formatNumber(t.cgpa,2)}</strong></span>
            <span class="badge badge-success" style="margin-left:8px"><i class="fas fa-check"></i> Approved</span>
          </div>
          <i class="fas fa-chevron-down accordion-arrow" style="${i===0?'transform:rotate(180deg)':''}"></i>
        </div>
        <div class="accordion-body ${i===0?'open':''}">
          <div class="table-wrap" style="padding:0">
            <table>
              <thead><tr><th>Code</th><th>Course</th><th>Credit</th><th>GPA</th><th>Grade</th><th>Total</th><th>Remarks</th></tr></thead>
              <tbody>${courseRows}</tbody>
            </table>
          </div>
          <div style="padding:12px 16px;border-top:1px solid var(--border);display:flex;justify-content:flex-end">
            <button class="btn btn-secondary btn-sm" onclick="showToast('Result card printed','info','Print')"><i class="fas fa-print"></i> Print Card</button>
          </div>
        </div>
      </div>`;
  }).join('');
}
function toggleAccordion(header){
  const body = header.nextElementSibling;
  const arrow = header.querySelector('.accordion-arrow');
  header.classList.toggle('open');
  body.classList.toggle('open');
  if(arrow) arrow.style.transform = body.classList.contains('open')?'rotate(180deg)':'rotate(0deg)';
}
function componentValue(component){
  if(component.converted_marks !== null && component.converted_marks !== undefined) return parseFloat(component.converted_marks) || 0;
  if(component.raw_marks !== null && component.raw_marks !== undefined) return parseFloat(component.raw_marks) || 0;
  return 0;
}
function loadContinuousEval(){
  const courses = getApprovedCourses();
  const container = document.getElementById('s-view-continuous');
  if(!container) return;

  const triSelect = document.getElementById('student-trimester-filter') || container.querySelector('select');
  const courseSelect = document.getElementById('student-course-filter') || container.querySelectorAll('select')[1];
  const resultDiv = document.getElementById('continuous-eval-result');
  if(!triSelect || !courseSelect || !resultDiv) return;

  const course = courses.find(c => c.trimester_name === triSelect.value && c.course_code === courseSelect.value);
  if(!course){
    resultDiv.innerHTML = `
      <div class="card-body" style="text-align:center;padding:40px;color:var(--text2)">
        <i class="fas fa-lock" style="font-size:40px;opacity:0.3;margin-bottom:12px;display:block"></i>
        No approved marks details found for this course.
      </div>`;
    return;
  }

  const components = Array.isArray(course.components) ? course.components : [];
  const bestGroups = {};
  components.forEach(c => {
    if(c.best_of_group){
      const value = componentValue(c);
      bestGroups[c.best_of_group] = Math.max(bestGroups[c.best_of_group] ?? -Infinity, value);
    }
  });

  const headerCells = components.map(c => `<th>${escapeHtml(c.component_name)} (${formatNumber(c.convert_to,0)})</th>`).join('');
  const valueCells = components.map(c => {
    const value = componentValue(c);
    const isBest = c.best_of_group && value === bestGroups[c.best_of_group];
    return `<td class="${isBest ? 'best-mark' : ''}">${formatNumber(value,1)}</td>`;
  }).join('');

  resultDiv.innerHTML = `
    <div class="table-wrap">
      <table>
        <thead><tr>${headerCells}<th>Total</th><th>Grade</th><th>Status</th></tr></thead>
        <tbody>
          <tr>
            ${valueCells}
            <td style="font-weight:800">${formatNumber(course.total_marks,2)}</td>
            <td><span class="grade-A-plus">${escapeHtml(course.grade || '---')}</span></td>
            <td><span class="badge badge-success">Approved</span></td>
          </tr>
        </tbody>
      </table>
    </div>
    <div style="padding:12px 20px;font-size:12px;color:var(--text2);border-top:1px solid var(--border)">
      <i class="fas fa-lock" style="margin-right:4px"></i> Read-only approved result. Draft/submitted/rejected results are hidden.
    </div>`;
}


/* ══════════════════════════════════════════════════════════════════
   ADMIN PANEL
   ══════════════════════════════════════════════════════════════════ */
const adminViews=['dashboard','approve','grades','teachers','students','audit'];
let currentRejectIndex = null;
let currentAdminView = 'dashboard';

function adminNav(view,navEl){
  currentAdminView = view;
  adminViews.forEach(v=>{
    const el=document.getElementById('a-view-'+v);
    if(el) el.style.display=v===view?'':'none';
  });
  if(navEl){
    document.querySelectorAll('#admin-sidebar .nav-item').forEach(n=>n.classList.remove('active'));
    navEl.classList.add('active');
  }
  const titles={dashboard:'Admin Dashboard',approve:'Approve Results',grades:'Grade Rules',teachers:'Manage Teachers',students:'Manage Students',audit:'Audit Log'};
  const title=document.getElementById('admin-page-title');
  if(title) title.textContent=titles[view]||view;
  renderCurrentAdminView();
}

function initAdminDashboard(){
  adminViews.filter(v=>v!=='dashboard').forEach(v=>{const el=document.getElementById('a-view-'+v);if(el) el.style.display='none';});
  const dash=document.getElementById('a-view-dashboard');
  if(dash) dash.style.display='';
  renderAuditMini();
}

function renderCurrentAdminView(){
  if(currentAdminView==='approve') renderApprove();
  if(currentAdminView==='grades') renderGradeRules();
  if(currentAdminView==='teachers') renderTeachers();
  if(currentAdminView==='students') renderStudentsList();
  if(currentAdminView==='audit') renderAuditLog();
  if(currentAdminView==='dashboard') renderAuditMini();
}

function adminFetchJson(url, payload=null){
  const opt = payload === null ? {headers:{'Accept':'application/json'}} : {
    method:'POST',
    headers:{'Content-Type':'application/json','Accept':'application/json'},
    body:JSON.stringify(payload)
  };
  return fetch(url,opt).then(async res=>{
    let data={};
    try{ data=await res.json(); }catch(e){ data={success:false,message:'Invalid JSON response.'}; }
    if(!res.ok || data.success===false){ throw new Error(data.message || 'Request failed.'); }
    return data;
  });
}

function loadAdminData(viewToRender=currentAdminView){
  return adminFetchJson('fetch_admin_data.php')
    .then(data=>{
      window.URAMS_ADMIN_SECTIONS = data.sections || [];
      window.URAMS_ADMIN_TEACHERS = data.teachers || [];
      window.URAMS_ADMIN_STUDENTS = data.students || [];
      window.URAMS_AUDIT_LOGS = data.audit_logs || [];
      currentAdminView = viewToRender;
      renderCurrentAdminView();
    })
    .catch(err=>showToast(err.message || 'Could not refresh admin data.','error','Error'));
}

function renderAuditMini(){
  const tbody=document.getElementById('admin-audit-mini');
  if(!tbody) return;
  const logs = window.URAMS_AUDIT_LOGS || [];
  if(!logs.length){ tbody.innerHTML='<tr><td colspan="5" style="text-align:center">No audit logs.</td></tr>'; return; }
  tbody.innerHTML=logs.slice(0,5).map(a=>`<tr>
    <td style="font-size:12px;color:var(--text2)">${escHtml(a.created_at || '')}</td>
    <td class="td-name" style="font-size:13px">${escHtml(a.user_name || 'System')}</td>
    <td><span class="badge badge-${a.role==='admin'?'danger':a.role==='teacher'?'primary':'neutral'}">${escHtml(a.role || 'system')}</span></td>
    <td style="font-size:12px">${escHtml(a.action || '')}</td>
    <td class="td-id">${escHtml(a.ip_address || '---')}</td>
  </tr>`).join('');
}

function renderApprove(){
  const tbody=document.getElementById('approve-tbody');
  if(!tbody) return;
  const list = window.URAMS_ADMIN_SECTIONS || [];
  if(!list.length){ tbody.innerHTML='<tr><td colspan="7" style="text-align:center">No submitted results found.</td></tr>'; return; }
  tbody.innerHTML=list.map((r,i)=>{
    const status = String(r.status || '').toLowerCase();
    const submitted = r.submitted_at || r.approved_at || r.rejected_at || '---';
    const badge = status==='submitted'
      ? '<span class="badge badge-warning pending-badge"><i class="fas fa-clock"></i> Pending</span>'
      : status==='approved'
        ? '<span class="badge badge-success"><i class="fas fa-check"></i> Approved</span>'
        : '<span class="badge badge-danger"><i class="fas fa-times"></i> Rejected</span>';
    const actions = status==='submitted' ? `<div class="btn-group">
          <button class="btn btn-sm btn-success" onclick="approveResult(${i})"><i class="fas fa-check"></i> Approve</button>
          <button class="btn btn-sm btn-danger" onclick="rejectResult(${i})"><i class="fas fa-times"></i> Reject</button>
        </div>` : `<span class="badge badge-neutral" style="text-transform:capitalize">${escHtml(status || '---')}</span>`;
    return `<tr>
      <td>${escHtml(r.trimester_name || '')}</td>
      <td class="td-name">${escHtml(r.course_name || '')} (${escHtml(r.course_code || '')})</td>
      <td>${escHtml(r.section_name || '')}</td>
      <td>${escHtml(r.teacher_initial || r.teacher_name || '')}</td>
      <td style="font-size:12px;color:var(--text2)">${escHtml(submitted)}</td>
      <td>${badge}</td>
      <td>${actions}</td>
    </tr>`;
  }).join('');
}

function approveResult(i){
  const section = (window.URAMS_ADMIN_SECTIONS || [])[i];
  if(!section) return;
  showConfirm('Approve Result',`Approve ${section.course_name} Section ${section.section_name}? Approved result becomes visible to student/parent.`,'success',()=>{
    adminFetchJson('approve_reject_section.php',{section_id:section.section_id, action:'approve'})
      .then(data=>{ showToast(data.message || 'Result approved.','success','Approved'); return loadAdminData('approve'); })
      .catch(err=>showToast(err.message || 'Error approving result.','error','Error'));
  });
}

function rejectResult(i){
  currentRejectIndex = i;
  const reason = document.getElementById('reject-reason');
  if(reason) reason.value='';
  openModal('modal-reject');
}

function submitReject(){
  const section = (window.URAMS_ADMIN_SECTIONS || [])[currentRejectIndex];
  if(!section) return;
  const reason = (document.getElementById('reject-reason')?.value || '').trim();
  if(!reason){ showToast('Please enter a rejection reason.','warning','Required'); return; }
  adminFetchJson('approve_reject_section.php',{section_id:section.section_id, action:'reject', reason})
    .then(data=>{ closeModal('modal-reject'); showToast(data.message || 'Result rejected.','error','Rejected'); return loadAdminData('approve'); })
    .catch(err=>showToast(err.message || 'Error rejecting result.','error','Error'));
}

function renderGradeRules(){
  const tbody=document.getElementById('grade-rules-tbody');
  if(!tbody) return;
  tbody.innerHTML=GRADE_RULES.map((r,i)=>`<tr id="gr-row-${i}">
    <td><input class="marks-input" value="${r.min}" id="gr-min-${i}" readonly style="width:60px"></td>
    <td><input class="marks-input" value="${r.max}" id="gr-max-${i}" readonly style="width:60px"></td>
    <td><input class="marks-input" value="${r.grade}" id="gr-grade-${i}" readonly style="width:48px;font-weight:800;color:var(--primary)"></td>
    <td><input class="marks-input" value="${r.point}" id="gr-point-${i}" readonly style="width:52px"></td>
    <td><input class="marks-input" value="${r.remark}" id="gr-rem-${i}" readonly style="width:120px"></td>
    <td><div class="btn-group"><button class="btn btn-sm btn-ghost" id="gr-edit-${i}" onclick="editGradeRule(${i})"><i class="fas fa-edit"></i></button><button class="btn btn-sm btn-success" id="gr-save-${i}" style="display:none" onclick="saveGradeRule(${i})"><i class="fas fa-save"></i></button><button class="btn btn-sm btn-danger" onclick="deleteGradeRule(${i})"><i class="fas fa-trash"></i></button></div></td>
  </tr>`).join('');
}
function editGradeRule(i){['min','max','grade','point','rem'].forEach(f=>{const el=document.getElementById(`gr-${f}-${i}`); if(el){el.removeAttribute('readonly'); el.style.border='1.5px solid var(--primary)';}}); document.getElementById(`gr-edit-${i}`).style.display='none'; document.getElementById(`gr-save-${i}`).style.display='';}
function saveGradeRule(i){['min','max','grade','point','rem'].forEach(f=>{const el=document.getElementById(`gr-${f}-${i}`); if(el){el.setAttribute('readonly',''); el.style.border='';}}); document.getElementById(`gr-edit-${i}`).style.display=''; document.getElementById(`gr-save-${i}`).style.display='none'; showToast('Grade rule updated locally. Backend for grade rules is separate.','success','Saved');}
function deleteGradeRule(i){showConfirm('Delete Grade Rule','This only removes the row from current UI.','danger',()=>{document.getElementById(`gr-row-${i}`)?.remove(); showToast('Grade rule removed locally.','error','Deleted');});}
function addGradeRule(){showToast('Grade rule backend is not part of this admin-user patch.','info','Info');}

function renderTeachers(){
  const tbody=document.getElementById('teachers-tbody');
  if(!tbody) return;
  const list = window.URAMS_ADMIN_TEACHERS || [];
  if(!list.length){ tbody.innerHTML='<tr><td colspan="6" style="text-align:center">No teachers found.</td></tr>'; return; }
  tbody.innerHTML=list.map((t,i)=>`<tr>
    <td><span class="badge badge-primary">${escHtml(t.identifier || '')}</span></td>
    <td class="td-name">${escHtml(t.full_name || '')}</td>
    <td style="font-size:12px;color:var(--text2)">${escHtml(t.email || '')}</td>
    <td style="font-size:12px">${escHtml(t.phone || '---')}</td>
    <td><span class="badge badge-neutral">${Number(t.courses || 0)} courses</span></td>
    <td><div class="btn-group">
      <button class="btn btn-sm btn-ghost" onclick="openTeacherForm(${i})"><i class="fas fa-edit"></i></button>
      <button class="btn btn-sm btn-danger" onclick="deleteTeacher(${i})"><i class="fas fa-trash"></i></button>
    </div></td>
  </tr>`).join('');
}

function renderStudentsList(){
  const tbody=document.getElementById('students-tbody');
  if(!tbody) return;
  const list = window.URAMS_ADMIN_STUDENTS || [];
  if(!list.length){ tbody.innerHTML='<tr><td colspan="6" style="text-align:center">No students found.</td></tr>'; return; }
  tbody.innerHTML=list.map((s,i)=>`<tr>
    <td class="td-id">${escHtml(s.identifier || '')}</td>
    <td class="td-name">${escHtml(s.full_name || '')}</td>
    <td style="font-size:12px;color:var(--text2)">${escHtml(s.email || '')}</td>
    <td>${escHtml(s.program || '---')}</td>
    <td>${s.status==='active'?'<span class="badge badge-success">Active</span>':'<span class="badge badge-danger">Inactive</span>'}</td>
    <td><div class="btn-group">
      <button class="btn btn-sm btn-ghost" onclick="openStudentAdminForm(${i})"><i class="fas fa-edit"></i></button>
      <button class="btn btn-sm btn-danger" onclick="deleteStudent(${i})"><i class="fas fa-trash"></i></button>
    </div></td>
  </tr>`).join('');
}

function renderAuditLog(){
  const tbody=document.getElementById('audit-tbody');
  if(!tbody) return;
  const logs = window.URAMS_AUDIT_LOGS || [];
  if(!logs.length){ tbody.innerHTML='<tr><td colspan="7" style="text-align:center">No audit logs.</td></tr>'; return; }
  tbody.innerHTML=logs.map(a=>`<tr>
    <td style="font-size:12px;color:var(--text2)">${escHtml(a.created_at || '')}</td>
    <td class="td-name" style="font-size:13px">${escHtml(a.user_name || 'System')}</td>
    <td><span class="badge badge-${a.role==='admin'?'danger':a.role==='teacher'?'primary':'neutral'}">${escHtml(a.role || 'system')}</span></td>
    <td style="font-size:12px">${escHtml(a.action || '')}</td>
    <td style="font-size:12px;color:var(--danger)">${escHtml(a.old_value || '---')}</td>
    <td style="font-size:12px;color:var(--success)">${escHtml(a.new_value || '---')}</td>
    <td class="td-id">${escHtml(a.ip_address || '---')}</td>
  </tr>`).join('');
}

function openTeacherForm(index=null){
  const t = index === null ? null : (window.URAMS_ADMIN_TEACHERS || [])[index];
  setAdminUserForm('teacher', t);
}
function openStudentAdminForm(index=null){
  const s = index === null ? null : (window.URAMS_ADMIN_STUDENTS || [])[index];
  setAdminUserForm('student', s);
}
function setAdminUserForm(role, user=null){
  const isEdit = !!user;
  document.getElementById('admin-user-mode').value = isEdit ? 'edit' : 'add';
  document.getElementById('admin-user-role').value = role;
  document.getElementById('admin-user-id').value = user?.id || '';
  document.getElementById('admin-user-full-name').value = user?.full_name || '';
  document.getElementById('admin-user-email').value = user?.email || '';
  document.getElementById('admin-user-identifier').value = user?.identifier || '';
  document.getElementById('admin-user-phone').value = user?.phone || '';
  document.getElementById('admin-user-program').value = user?.program || (role==='student' ? 'BSc CSE' : '');
  document.getElementById('admin-user-department').value = user?.department || (role==='student' ? 'CSE' : '');
  document.getElementById('admin-user-password').value = '';
  document.getElementById('admin-user-program-wrap').style.display = role==='student' ? '' : 'none';
  document.getElementById('admin-user-identifier-label').textContent = role==='teacher' ? 'Teacher Initial' : 'Student ID';
  document.getElementById('admin-user-modal-title').innerHTML = `<i class="fas fa-user-plus" style="color:var(--primary)"></i> ${isEdit?'Edit':'Add'} ${role==='teacher'?'Teacher':'Student'}`;
  openModal('modal-admin-user');
}
function getAdminUserFormPayload(){
  return {
    id: Number(document.getElementById('admin-user-id')?.value || 0),
    full_name: document.getElementById('admin-user-full-name')?.value.trim() || '',
    email: document.getElementById('admin-user-email')?.value.trim() || '',
    identifier: document.getElementById('admin-user-identifier')?.value.trim() || '',
    phone: document.getElementById('admin-user-phone')?.value.trim() || '',
    program: document.getElementById('admin-user-program')?.value.trim() || '',
    department: document.getElementById('admin-user-department')?.value.trim() || '',
    password: document.getElementById('admin-user-password')?.value || ''
  };
}
function submitAdminUserForm(){
  const role=document.getElementById('admin-user-role')?.value;
  const mode=document.getElementById('admin-user-mode')?.value;
  const payload=getAdminUserFormPayload();
  if(!payload.full_name || !payload.email || !payload.identifier){ showToast('Name, email and ID/initial are required.','warning','Missing Data'); return; }
  const endpoint = role==='teacher'
    ? (mode==='edit' ? 'edit_teacher.php' : 'add_teacher.php')
    : (mode==='edit' ? 'edit_student.php' : 'add_student.php');
  adminFetchJson(endpoint,payload)
    .then(data=>{ closeModal('modal-admin-user'); showToast(data.message || 'Saved.','success','Saved'); return loadAdminData(role==='teacher'?'teachers':'students'); })
    .catch(err=>showToast(err.message || 'Save failed.','error','Error'));
}
function deleteTeacher(index){
  const t=(window.URAMS_ADMIN_TEACHERS || [])[index];
  if(!t) return;
  showConfirm('Delete Teacher',`Remove ${t.full_name}? Assigned courses will be preserved; account will be deactivated.`,'danger',()=>{
    adminFetchJson('delete_teacher.php',{id:t.id})
      .then(data=>{ showToast(data.message || 'Teacher deleted.','success','Deleted'); return loadAdminData('teachers'); })
      .catch(err=>showToast(err.message || 'Delete failed.','error','Error'));
  });
}
function deleteStudent(index){
  const s=(window.URAMS_ADMIN_STUDENTS || [])[index];
  if(!s) return;
  showConfirm('Delete Student',`Remove ${s.full_name}? Existing academic records will be preserved; account will be deactivated.`,'danger',()=>{
    adminFetchJson('delete_student.php',{id:s.id})
      .then(data=>{ showToast(data.message || 'Student deleted.','success','Deleted'); return loadAdminData('students'); })
      .catch(err=>showToast(err.message || 'Delete failed.','error','Error'));
  });
}

/* ══════════════════════════════════════════════════════════════════
   PARENT PANEL
   ══════════════════════════════════════════════════════════════════ */
const parentViews=['dashboard','results'];
function parentNav(view,navEl){
  parentViews.forEach(v=>{const el=document.getElementById('p-view-'+v);if(el) el.style.display=v===view?'':'none';});
  if(navEl){ document.querySelectorAll('#parent-sidebar .nav-item').forEach(n=>n.classList.remove('active')); navEl.classList.add('active'); }
  if(view==='results') initParentResults(true);
}
function initParentDashboard(){
  initParentResults(true);
  setTimeout(()=>drawGPAChart('parent-gpa-chart'),100);
  refreshApprovedResultsFromApi(()=>{
    initParentResults(true);
    setTimeout(()=>drawGPAChart('parent-gpa-chart'),50);
  });
}
function initParentResults(force=false){
  initResultHistory('parent-history-accordion', force);
}

/* ══════════════════════════════════════════════════════════════════
   CANVAS CHARTS (Pure JavaScript Canvas API)
   ══════════════════════════════════════════════════════════════════ */
function getCSS(v){ return getComputedStyle(document.documentElement).getPropertyValue(v).trim(); }

function drawBarChart(canvas, labels, data, title='', isPercent=false){
  if(!canvas) return;
  const ctx = canvas.getContext('2d');
  const W = canvas.offsetWidth || 700;
  const H = canvas.height || 220;
  canvas.width = W;
  const isDarkMode = document.body.classList.contains('dark-mode');
  const pad = {top:20, right:20, bottom:60, left:50};
  const chartW = W - pad.left - pad.right;
  const chartH = H - pad.top - pad.bottom;
  const maxVal = isPercent ? 100 : Math.max(...data.map(Number)) * 1.15;
  const textColor = isDarkMode ? '#94a3b8' : '#475569';
  const gridColor = isDarkMode ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)';

  ctx.clearRect(0,0,W,H);

  // Grid lines
  const gridCount = 5;
  for(let i=0;i<=gridCount;i++){
    const y = pad.top + chartH - (i/gridCount)*chartH;
    ctx.strokeStyle = gridColor;
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(pad.left,y); ctx.lineTo(pad.left+chartW,y); ctx.stroke();
    ctx.fillStyle = textColor;
    ctx.font = '11px Outfit,sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText(((i/gridCount)*maxVal).toFixed(isPercent?0:1), pad.left-6, y+4);
  }

  // Bars
  const barW = Math.min(40, (chartW/data.length)*0.6);
  const gap = chartW/data.length;
  const colors = ['#1a56db','#10b981','#f59e0b','#ef4444','#06b6d4','#8b5cf6','#ec4899','#14b8a6','#f97316','#84cc16'];
  data.forEach((v,i)=>{
    const val = parseFloat(v)||0;
    const barH = (val/maxVal)*chartH;
    const x = pad.left + i*gap + gap/2 - barW/2;
    const y = pad.top + chartH - barH;
    // Gradient
    const grad = ctx.createLinearGradient(x,y,x,y+barH);
    grad.addColorStop(0, colors[i%colors.length]);
    grad.addColorStop(1, colors[i%colors.length]+'88');
    ctx.fillStyle = grad;
    // Rounded top
    const r = 4;
    ctx.beginPath();
    ctx.moveTo(x+r,y); ctx.lineTo(x+barW-r,y);
    ctx.quadraticCurveTo(x+barW,y,x+barW,y+r);
    ctx.lineTo(x+barW,y+barH); ctx.lineTo(x,y+barH);
    ctx.lineTo(x,y+r); ctx.quadraticCurveTo(x,y,x+r,y);
    ctx.closePath(); ctx.fill();
    // Value
    ctx.fillStyle = isDarkMode?'#f1f5f9':'#1e293b';
    ctx.font = 'bold 11px Outfit,sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(isPercent?val+'%':val, x+barW/2, y-5);
    // Label
    ctx.fillStyle = textColor;
    ctx.font = '11px Outfit,sans-serif';
    ctx.save(); ctx.translate(x+barW/2, pad.top+chartH+12);
    ctx.rotate(-0.4); ctx.textAlign='right';
    ctx.fillText(labels[i]||'', 0, 0); ctx.restore();
  });

  // Y-axis line
  ctx.strokeStyle = isDarkMode?'rgba(255,255,255,0.1)':'rgba(0,0,0,0.1)';
  ctx.lineWidth=1;
  ctx.beginPath(); ctx.moveTo(pad.left,pad.top); ctx.lineTo(pad.left,pad.top+chartH); ctx.stroke();
}

function drawLineChart(canvas, labels, datasets, title=''){
  if(!canvas) return;
  const ctx = canvas.getContext('2d');
  const W = canvas.offsetWidth || 700;
  const H = canvas.height || 200;
  canvas.width = W;
  const isDarkMode = document.body.classList.contains('dark-mode');
  const pad = {top:24, right:24, bottom:50, left:48};
  const chartW = W - pad.left - pad.right;
  const chartH = H - pad.top - pad.bottom;
  const maxVal = 4.0;
  const textColor = isDarkMode ? '#94a3b8' : '#475569';
  const gridColor = isDarkMode ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)';

  ctx.clearRect(0,0,W,H);

  // Grid
  for(let i=0;i<=4;i++){
    const y = pad.top + chartH - (i/4)*chartH;
    ctx.strokeStyle=gridColor; ctx.lineWidth=1;
    ctx.beginPath(); ctx.moveTo(pad.left,y); ctx.lineTo(pad.left+chartW,y); ctx.stroke();
    ctx.fillStyle=textColor; ctx.font='11px Outfit,sans-serif'; ctx.textAlign='right';
    ctx.fillText((i*1.0).toFixed(2), pad.left-6, y+4);
  }

  // Draw each dataset
  const dColors = ['#1a56db','#f59e0b'];
  datasets.forEach((ds,di)=>{
    const pts = ds.data.map((v,i)=>({
      x: labels.length > 1 ? pad.left + (i/(labels.length-1))*chartW : pad.left + chartW/2,
      y: pad.top + chartH - (v/maxVal)*chartH
    }));
    // Area fill
    const grad = ctx.createLinearGradient(0,pad.top,0,pad.top+chartH);
    grad.addColorStop(0, dColors[di]+'33');
    grad.addColorStop(1, dColors[di]+'00');
    ctx.beginPath();
    ctx.moveTo(pts[0].x, pad.top+chartH);
    pts.forEach(p=>ctx.lineTo(p.x,p.y));
    ctx.lineTo(pts[pts.length-1].x, pad.top+chartH);
    ctx.closePath(); ctx.fillStyle=grad; ctx.fill();
    // Line
    ctx.beginPath();
    ctx.strokeStyle=dColors[di]; ctx.lineWidth=2.5;
    ctx.lineJoin='round'; ctx.lineCap='round';
    pts.forEach((p,i)=>{if(i===0) ctx.moveTo(p.x,p.y); else ctx.lineTo(p.x,p.y);});
    ctx.stroke();
    // Dots
    pts.forEach((p,i)=>{
      ctx.beginPath();
      ctx.arc(p.x,p.y,4,0,Math.PI*2);
      ctx.fillStyle=dColors[di]; ctx.fill();
      ctx.strokeStyle='#fff'; ctx.lineWidth=2; ctx.stroke();
      // Value
      ctx.fillStyle=isDarkMode?'#f1f5f9':'#1e293b';
      ctx.font='bold 10px Outfit,sans-serif'; ctx.textAlign='center';
      ctx.fillText(ds.data[i].toFixed(2), p.x, p.y-10);
    });
  });

  // X labels
  labels.forEach((l,i)=>{
    const x = labels.length > 1 ? pad.left + (i/(labels.length-1))*chartW : pad.left + chartW/2;
    ctx.fillStyle=textColor; ctx.font='10px Outfit,sans-serif'; ctx.textAlign='center';
    ctx.fillText(l, x, pad.top+chartH+18);
  });

  // Legend
  datasets.forEach((ds,di)=>{
    const lx = pad.left+di*120;
    ctx.fillStyle=dColors[di];
    ctx.fillRect(lx, H-14, 20, 3);
    ctx.fillStyle=textColor; ctx.font='11px Outfit,sans-serif'; ctx.textAlign='left';
    ctx.fillText(ds.label, lx+24, H-11);
  });
}

function drawGPAChart(canvasId){
  const canvas = document.getElementById(canvasId);
  if(!canvas) return;
  const resultsList = getApprovedTrimesters();
  if(!resultsList.length){
    const ctx = canvas.getContext('2d');
    const W = canvas.offsetWidth || 700;
    const H = canvas.height || 200;
    canvas.width = W;
    ctx.clearRect(0,0,W,H);
    ctx.fillStyle = document.body.classList.contains('dark-mode') ? '#94a3b8' : '#475569';
    ctx.font = '14px Outfit,sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('No approved GPA data yet', W/2, H/2);
    return;
  }
  const chronological = [...resultsList].reverse();
  const labels = chronological.map(t => {
    const parts = String(t.tri || '').split(' ');
    return `${parts[0] || ''} ${parts[1] ? parts[1].slice(2) : ''}`.trim();
  });
  const datasets = [
    {label:'GPA', data: chronological.map(t=>parseFloat(t.gpa)||0)},
    {label:'CGPA', data: chronological.map(t=>parseFloat(t.cgpa)||0)},
  ];
  drawLineChart(canvas, labels, datasets, 'GPA Progression');
}

/* ══════════════════════════════════════════════════════════════════
   WINDOW RESIZE — Redraw charts
   ══════════════════════════════════════════════════════════════════ */
window.addEventListener('resize', ()=>{
  if(marksChartVisible) drawMarksChart();
  if(attChartVisible) drawAttChart();
  const studentPage = document.getElementById('page-student');
  const parentPage = document.getElementById('page-parent');
  if(studentPage && studentPage.classList.contains('active')) setTimeout(()=>drawGPAChart('student-gpa-chart'),50);
  if(parentPage && parentPage.classList.contains('active')) setTimeout(()=>drawGPAChart('parent-gpa-chart'),50);
});

/* ══════════════════════════════════════════════════════════════════
   PRINT CSS
   ══════════════════════════════════════════════════════════════════ */
const printStyle = document.createElement('style');
printStyle.textContent = `
@media print {
  .sidebar, #dm-toggle, #toast-container, .btn-group, .modal-overlay, .app-header { display:none!important; }
  .content { margin:0!important; padding:10px!important; }
  .card { box-shadow:none!important; border:1px solid #ddd!important; }
  body { background:#fff!important; color:#000!important; }
  * { color:#000!important; }
}`;
document.head.appendChild(printStyle);

console.log('%cURAMS Frontend Loaded ✓', 'color:#1a56db;font-weight:bold;font-size:14px');


/* ══════════════════════════════════════════════════════════════════
   TEACHER MARKS SYSTEM OVERRIDE — DB DRIVEN
   ══════════════════════════════════════════════════════════════════ */
function escHtml(value){
  return String(value ?? '').replace(/[&<>'"]/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#039;','"':'&quot;'}[ch]));
}
function num(value, fallback=0){
  const n = parseFloat(value);
  return Number.isFinite(n) ? n : fallback;
}
function getCurrentSectionId(){
  if (window.URAMS_ACTIVE_SECTION_ID) return parseInt(window.URAMS_ACTIVE_SECTION_ID, 10);
  if (window.URAMS_TEACHER_SECTION?.section_id) return parseInt(window.URAMS_TEACHER_SECTION.section_id, 10);
  if (STUDENTS[0]?.section_id) return parseInt(STUDENTS[0].section_id, 10);
  const sections = Array.isArray(window.URAMS_TEACHER_SECTIONS) ? window.URAMS_TEACHER_SECTIONS : [];
  return sections.length ? parseInt(sections[0].section_id, 10) : 0;
}
function getComponentByKey(key){
  return TEACHER_COMPONENTS.find(c => String(c.component_key) === String(key)) || TEACHER_COMPONENTS[0] || null;
}
function getComponentMark(student, component){
  const key = component?.component_key;
  const marks = student?.component_marks || {};
  return marks[key] || {raw_marks:0, converted_marks:0, is_absent:0};
}
function statusBadge(status){
  const s = String(status || 'draft').toLowerCase();
  if (s === 'approved') return '<span class="badge badge-success"><i class="fas fa-check"></i> Approved</span>';
  if (s === 'submitted') return '<span class="badge badge-warning"><i class="fas fa-clock"></i> Submitted</span>';
  if (s === 'rejected') return '<span class="badge badge-danger"><i class="fas fa-times"></i> Rejected</span>';
  return '<span class="badge badge-neutral">Draft</span>';
}
function formatMark(value){ return num(value).toFixed(1); }

function initTeacherDashboard(){
  populateTeacherFilters();
  const sectionId = getCurrentSectionId();
  if(sectionId){
    loadSectionData(sectionId);
  } else {
    renderNoTeacherSection();
  }
  const dash = document.getElementById('view-dashboard');
  if(dash) dash.style.display = '';
  teacherViews.filter(v=>v!=='dashboard').forEach(v=>{
    const el = document.getElementById('view-'+v);
    if(el) el.style.display = 'none';
  });
}
function renderNoTeacherSection(){
  const tbody = document.getElementById('result-tbody');
  if(tbody) tbody.innerHTML = '<tr><td style="text-align:center;padding:24px">No assigned section found.</td></tr>';
  const title = document.getElementById('teacher-section-title');
  if(title) title.textContent = 'No assigned section';
}
function populateTeacherFilters(){
  const sections = Array.isArray(window.URAMS_TEACHER_SECTIONS) ? window.URAMS_TEACHER_SECTIONS : [];
  const triSelect = document.getElementById('filter-trimester');
  const courseSelect = document.getElementById('filter-course');
  const secSelect = document.getElementById('filter-section');
  if(!triSelect || !courseSelect || !secSelect) return;
  const makeOptions = rows => rows.map(r => `<option value="${escHtml(r.section_id)}">${escHtml(r.label)}</option>`).join('');
  triSelect.innerHTML = makeOptions(sections.map(s => ({section_id:s.section_id, label:s.trimester_name})));
  courseSelect.innerHTML = makeOptions(sections.map(s => ({section_id:s.section_id, label:`${s.course_name} (${s.course_code})`})));
  secSelect.innerHTML = makeOptions(sections.map(s => ({section_id:s.section_id, label:s.section_name})));
  const active = getCurrentSectionId();
  [triSelect, courseSelect, secSelect].forEach(sel => { if(active) sel.value = String(active); });
  const statCourses = document.getElementById('teacher-stat-courses');
  if(statCourses) statCourses.textContent = sections.length;
}
function filterChanged(){
  const id = parseInt((document.getElementById('filter-section')?.value || document.getElementById('filter-course')?.value || document.getElementById('filter-trimester')?.value || '0'), 10);
  if(id){
    ['filter-trimester','filter-course','filter-section'].forEach(elId => {
      const el = document.getElementById(elId);
      if(el) el.value = String(id);
    });
    window.URAMS_ACTIVE_SECTION_ID = id;
  }
}
function applyFilter(){
  filterChanged();
  loadCurrentTeacherSection(true);
}
function loadCurrentTeacherSection(showMessage=false){
  const sectionId = getCurrentSectionId();
  if(!sectionId){
    renderNoTeacherSection();
    return Promise.resolve(null);
  }
  return loadSectionData(sectionId, showMessage);
}
function loadSectionData(sectionId, showMessage=false){
  return fetch(`get_section_students.php?section_id=${encodeURIComponent(sectionId)}`, {headers:{'Accept':'application/json'}})
    .then(response => response.json())
    .then(data => {
      if(!data.success){
        showToast(data.message || 'Failed to load section data.', 'error', 'Error');
        return null;
      }
      window.URAMS_ACTIVE_SECTION_ID = parseInt(sectionId, 10);
      syncTeacherGlobals(data.students, data.components, data.section);
      renderTeacherSectionMeta();
      renderComponentSelect();
      renderResultTable();
      initMarksTable();
      updateSubmitView();
      if(showMessage) showToast('Section loaded from database.', 'success', 'Loaded');
      return data;
    })
    .catch(err => {
      console.error(err);
      showToast('Could not load section data.', 'error', 'Error');
      return null;
    });
}
function renderTeacherSectionMeta(){
  const sec = window.URAMS_TEACHER_SECTION || {};
  const titleText = sec.course_title ? `${sec.course_title} — Section ${sec.section || ''}` : 'Selected Section';
  const subText = `${sec.trimester || ''} · ${STUDENTS.length} students · Result: ${String(sec.status || 'draft').toUpperCase()}`;
  const title = document.getElementById('teacher-section-title');
  const sub = document.getElementById('teacher-section-subtitle');
  const headSub = document.getElementById('teacher-header-subtitle');
  if(title) title.textContent = titleText;
  if(sub) sub.textContent = subText;
  if(headSub) headSub.textContent = `${sec.trimester || 'Teacher Panel'}${sec.section ? ' · Section ' + sec.section : ''}`;
  const studentCount = document.getElementById('student-count');
  if(studentCount) studentCount.textContent = STUDENTS.length;
  const last = document.getElementById('teacher-last-updated');
  if(last) last.textContent = new Date().toLocaleTimeString([], {hour:'2-digit', minute:'2-digit'});
  const statStudents = document.getElementById('teacher-stat-students');
  const statComponents = document.getElementById('teacher-stat-components');
  const statStatus = document.getElementById('teacher-stat-status');
  if(statStudents) statStudents.textContent = STUDENTS.length;
  if(statComponents) statComponents.textContent = TEACHER_COMPONENTS.length;
  if(statStatus) statStatus.textContent = String(sec.status || 'Draft').replace(/^./, c => c.toUpperCase());
}
function renderComponentSelect(){
  const select = document.getElementById('edit-component-select');
  if(!select) return;
  if(!TEACHER_COMPONENTS.length){
    select.innerHTML = '<option value="">No component</option>';
    return;
  }
  select.innerHTML = TEACHER_COMPONENTS.map(c => `<option value="${escHtml(c.component_key)}">${escHtml(c.component_name)} (${formatMark(c.convert_to)})</option>`).join('');
  if(!TEACHER_COMPONENTS.some(c => c.component_key === window.currentEditComponent)){
    window.currentEditComponent = TEACHER_COMPONENTS[0].component_key;
  }
  currentEditComponent = window.currentEditComponent;
  select.value = window.currentEditComponent;
  updateComponentConfigFields();
}
function updateComponentConfigFields(){
  const comp = getComponentByKey(window.currentEditComponent);
  const taken = document.getElementById('conf-taken');
  const convert = document.getElementById('conf-convert');
  if(taken) taken.value = comp ? formatMark(comp.taken_out_of) : '0';
  if(convert) convert.value = comp ? formatMark(comp.convert_to) : '0';
  const actualHead = document.getElementById('marks-actual-head');
  const convHead = document.getElementById('marks-converted-head');
  if(actualHead) actualHead.innerHTML = `Actual Marks <span style="font-weight:400">(max: ${comp ? formatMark(comp.taken_out_of) : '0'})</span>`;
  if(convHead) convHead.textContent = comp ? `Converted (/${formatMark(comp.taken_out_of)} × ${formatMark(comp.convert_to)})` : 'Converted';
  const title = document.getElementById('marks-table-title');
  if(title) title.textContent = comp ? `Student Marks Entry — ${comp.component_name}` : 'Student Marks Entry';
  const chartTitle = document.getElementById('marks-chart-title');
  if(chartTitle) chartTitle.innerHTML = `<i class="fas fa-chart-bar" style="color:var(--primary)"></i> ${comp ? escHtml(comp.component_name) : 'Marks'} Distribution`;
}
function renderResultTable(){
  const thead = document.getElementById('result-thead');
  const tbody = document.getElementById('result-tbody');
  if(!thead || !tbody) return;
  if(!STUDENTS.length){
    thead.innerHTML = '<tr><th>Photo</th><th>UIU ID</th><th>Name</th><th>Status</th></tr>';
    tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;padding:24px">No students found for this section.</td></tr>';
    return;
  }
  const componentHeaders = TEACHER_COMPONENTS.map(c => `
    <th>
      ${escHtml(c.component_name)} <span style="font-weight:400;color:var(--text3)">(${formatMark(c.convert_to)})</span>
      <div style="display:flex;gap:3px;margin-top:3px">
        <button class="btn btn-sm btn-ghost" style="padding:1px 4px;font-size:10px" onclick="teacherNav('marks',null); changeEditComponent('${escHtml(c.component_key)}')"><i class="fas fa-eye"></i></button>
        <button class="btn btn-sm btn-ghost" style="padding:1px 4px;font-size:10px" onclick="showPercentModal('${escHtml(c.component_name)}')">%</button>
      </div>
    </th>`).join('');
  thead.innerHTML = `<tr><th>Photo</th><th>UIU ID</th><th>Name</th>${componentHeaders}<th>Total</th><th>Grade</th><th>Status</th></tr>`;
  tbody.innerHTML = STUDENTS.map(student => {
    const initials = String(student.name || 'S').split(' ').map(p => p[0]).join('').slice(0,2).toUpperCase();
    const cells = TEACHER_COMPONENTS.map(c => {
      const mark = getComponentMark(student, c);
      return `<td>${formatMark(mark.converted_marks)}</td>`;
    }).join('');
    return `<tr>
      <td><div class="student-avatar-sm">${escHtml(initials)}</div></td>
      <td class="td-id">${escHtml(student.student_id || student.id)}</td>
      <td class="td-name" onclick="openStudentModal('${escHtml(student.name)}','${escHtml(student.student_id || student.id)}')">${escHtml(student.name)}</td>
      ${cells}
      <td style="font-weight:800">${formatMark(student.total_marks)}</td>
      <td><span class="grade-${String(student.grade || 'F').replace('+','-plus').replace('-','-minus')}">${escHtml(student.grade || '-')}</span></td>
      <td>${statusBadge(student.result_status || window.URAMS_TEACHER_SECTION?.status)}</td>
    </tr>`;
  }).join('');
}
function filterStudents(){
  const q = (document.getElementById('student-search')?.value || '').toLowerCase();
  document.querySelectorAll('#result-tbody tr').forEach(tr => tr.style.display = tr.textContent.toLowerCase().includes(q) ? '' : 'none');
}
function teacherNav(view, navEl){
  teacherViews.forEach(v => {
    const el = document.getElementById('view-'+v);
    if(el) el.style.display = v === view ? '' : 'none';
  });
  if(navEl){
    document.querySelectorAll('#teacher-sidebar .nav-item').forEach(n => n.classList.remove('active'));
    navEl.classList.add('active');
  }
  const titles = {dashboard:'Dashboard',marks:'Add / Edit Marks',attendance:'Attendance',submit:'Submit Results',pdf:'Download PDF'};
  const titleEl = document.getElementById('teacher-page-title');
  if(titleEl) titleEl.textContent = titles[view] || view;
  if(view === 'marks') initMarksTable();
  if(view === 'submit') updateSubmitView();
  if(view === 'marks' && marksChartVisible) drawMarksChart();
}
function changeEditComponent(compKey){
  if(!compKey) return;
  window.currentEditComponent = compKey;
  currentEditComponent = compKey;
  const select = document.getElementById('edit-component-select');
  if(select) select.value = compKey;
  updateComponentConfigFields();
  initMarksTable();
  if(marksChartVisible) drawMarksChart();
}
function initMarksTable(){
  const tbody = document.getElementById('marks-tbody');
  if(!tbody) return;
  const comp = getComponentByKey(window.currentEditComponent);
  updateComponentConfigFields();
  if(!comp){
    tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:20px">No component found. Add a marks column first.</td></tr>';
    return;
  }
  if(!STUDENTS.length){
    tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:20px">No students found.</td></tr>';
    return;
  }
  tbody.innerHTML = STUDENTS.map((s,i) => {
    const mark = getComponentMark(s, comp);
    const raw = num(mark.raw_marks);
    const absent = parseInt(mark.is_absent || 0, 10) === 1;
    const initials = String(s.name || 'S').split(' ').map(p => p[0]).join('').slice(0,2).toUpperCase();
    return `<tr id="marks-row-${i}">
      <td>${i+1}</td>
      <td><div class="student-avatar-sm">${escHtml(initials)}</div></td>
      <td class="td-id">${escHtml(s.student_id || s.id)}</td>
      <td class="td-name">${escHtml(s.name)}</td>
      <td><input class="marks-input" type="number" min="0" max="${num(comp.taken_out_of)}" step="0.01" value="${raw.toFixed(2)}" id="actual-${i}" oninput="calculateConversion(${i})" readonly></td>
      <td><span class="marks-converted" id="conv-${i}">${formatMark(mark.converted_marks)}</span></td>
      <td><input type="checkbox" id="abs-${i}" ${absent ? 'checked' : ''} onchange="markAbsent(${i})" disabled></td>
      <td><div class="btn-group">
        <button class="btn btn-sm btn-ghost" id="edit-btn-${i}" onclick="editRow(${i})"><i class="fas fa-edit"></i></button>
        <button class="btn btn-sm btn-success" id="save-btn-${i}" onclick="saveRow(${i})" style="display:none"><i class="fas fa-save"></i></button>
      </div></td>
    </tr>`;
  }).join('');
}
function editRow(i){
  const input = document.getElementById(`actual-${i}`);
  const absent = document.getElementById(`abs-${i}`);
  if(input){ input.removeAttribute('readonly'); input.style.border = '2px solid var(--primary)'; input.focus(); }
  if(absent) absent.disabled = false;
  const editBtn = document.getElementById(`edit-btn-${i}`);
  const saveBtn = document.getElementById(`save-btn-${i}`);
  if(editBtn) editBtn.style.display = 'none';
  if(saveBtn) saveBtn.style.display = '';
}
function calculateConversion(i){
  const comp = getComponentByKey(window.currentEditComponent);
  if(!comp) return;
  const raw = Math.max(0, Math.min(num(comp.taken_out_of), num(document.getElementById(`actual-${i}`)?.value)));
  const converted = num(comp.taken_out_of) > 0 ? (raw / num(comp.taken_out_of)) * num(comp.convert_to) : 0;
  const el = document.getElementById(`conv-${i}`);
  if(el) el.textContent = Math.min(converted, num(comp.convert_to)).toFixed(2);
}
function markAbsent(i){
  const absent = document.getElementById(`abs-${i}`)?.checked;
  const input = document.getElementById(`actual-${i}`);
  const conv = document.getElementById(`conv-${i}`);
  if(absent){
    if(input){ input.value = '0'; input.disabled = true; }
    if(conv) conv.textContent = '0.00';
  } else {
    if(input){ input.disabled = false; calculateConversion(i); }
  }
}
function saveRow(i){
  const student = STUDENTS[i];
  const comp = getComponentByKey(window.currentEditComponent);
  if(!student || !comp){ showToast('Missing student/component.', 'error', 'Save Failed'); return; }
  const payload = {
    enrollment_id: student.enrollment_id,
    result_id: student.result_id,
    component_id: comp.id,
    component: comp.component_key,
    raw_marks: num(document.getElementById(`actual-${i}`)?.value),
    is_absent: document.getElementById(`abs-${i}`)?.checked ? 1 : 0
  };
  fetch('save_marks.php', {method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'}, body:JSON.stringify(payload)})
    .then(r => r.json())
    .then(data => {
      if(!data.success){ showToast(data.message || 'Failed to save marks.', 'error', 'Save Failed'); return; }
      showToast(`Marks saved for ${student.name}`, 'success', 'Saved');
      return loadCurrentTeacherSection(false);
    })
    .then(() => changeEditComponent(comp.component_key))
    .catch(err => { console.error(err); showToast('Unable to save marks.', 'error', 'Save Failed'); });
}
function saveAllMarks(){
  const comp = getComponentByKey(window.currentEditComponent);
  if(!comp){ showToast('No component selected.', 'warning', 'Nothing to Save'); return; }
  const updates = STUDENTS.map((student,i) => ({
    enrollment_id: student.enrollment_id,
    result_id: student.result_id,
    component_id: comp.id,
    raw_marks: num(document.getElementById(`actual-${i}`)?.value),
    is_absent: document.getElementById(`abs-${i}`)?.checked ? 1 : 0
  })).filter(row => row.enrollment_id || row.result_id);
  if(!updates.length){ showToast('No student records available to save.', 'warning', 'Nothing to Save'); return; }
  fetch('save_marks.php', {method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'}, body:JSON.stringify({component_id:comp.id, component:comp.component_key, updates})})
    .then(r => r.json())
    .then(data => {
      if(!data.success){ showToast(data.message || 'Failed to save marks.', 'error', 'Save Failed'); return; }
      showToast('All marks saved successfully.', 'success', 'Saved');
      return loadCurrentTeacherSection(false);
    })
    .then(() => changeEditComponent(comp.component_key))
    .catch(err => { console.error(err); showToast('Unable to save marks.', 'error', 'Save Failed'); });
}
function filterMarksTable(q){
  q = String(q || '').toLowerCase();
  document.querySelectorAll('#marks-tbody tr').forEach(tr => tr.style.display = tr.textContent.toLowerCase().includes(q) ? '' : 'none');
}

function saveConfig(){
  if(isTeacherResultLocked && isTeacherResultLocked()){
    showToast(teacherLockMessage ? teacherLockMessage() : 'Submitted/approved result cannot be edited.', 'warning', 'Locked');
    return;
  }

  const comp = getComponentByKey(window.currentEditComponent);
  const sectionId = getCurrentSectionId();
  if(!sectionId || !comp){
    showToast('Select a section and component first.', 'warning', 'Missing Selection');
    return;
  }

  const taken = num(document.getElementById('conf-taken')?.value);
  const convert = num(document.getElementById('conf-convert')?.value);
  const grace = num(document.getElementById('conf-grace')?.value);

  if(taken <= 0 || convert <= 0){
    showToast('Exam Taken Out Of and Convert To must be greater than 0.', 'error', 'Invalid Config');
    return;
  }
  if(grace < 0){
    showToast('Grace cannot be negative.', 'error', 'Invalid Grace');
    return;
  }

  fetch('update_component_config.php', {
    method: 'POST',
    headers: {'Content-Type':'application/json','Accept':'application/json'},
    body: JSON.stringify({
      section_id: sectionId,
      component_id: comp.id,
      taken_out_of: taken,
      convert_to: convert,
      add_grace: grace
    })
  })
  .then(async r => {
    const text = await r.text();
    try { return JSON.parse(text); }
    catch(e){ throw new Error(text || 'Invalid JSON response'); }
  })
  .then(data => {
    if(!data.success){
      showToast(data.message || 'Failed to update component config.', 'error', 'Save Failed');
      return;
    }
    showToast(data.message || 'Component config updated.', 'success', 'Config Saved');
    if(document.getElementById('conf-grace')) document.getElementById('conf-grace').value = 0;
    const keepKey = data.component?.component_key || comp.component_key;
    window.currentEditComponent = keepKey;
    return loadCurrentTeacherSection(false).then(() => changeEditComponent(keepKey));
  })
  .catch(err => {
    console.error(err);
    showToast(err.message || 'Unable to update component config.', 'error', 'Save Failed');
  });
}

function openAddMarksModal(){
  const sectionId = getCurrentSectionId();
  if(!sectionId){ showToast('Select a section first.', 'warning', 'No Section'); return; }
  const modal = document.getElementById('modal-add-marks');
  if(!modal){ showToast('Add Marks modal not found.', 'error', 'Error'); return; }
  const type = document.getElementById('exam-type-select');
  const custom = document.getElementById('exam-type-custom');
  const taken = document.getElementById('am-taken');
  const convert = document.getElementById('am-convert');
  const date = document.getElementById('am-date');
  const best = document.getElementById('am-bestof');
  if(type) type.value = '';
  if(custom) custom.value = '';
  if(taken) taken.value = '';
  if(convert) convert.value = '';
  if(date) date.value = '';
  if(best) best.checked = false;
  toggleBestOf();
  openModal('modal-add-marks');
}
function examTypeChanged(){
  const type = document.getElementById('exam-type-select')?.value || '';
  const taken = document.getElementById('am-taken');
  const convert = document.getElementById('am-convert');
  if(!taken || !convert) return;
  const map = {
    'CT':[30,15], 'Assignment':[10,10], 'Mid':[50,25], 'Final':[80,40],
    'Lab Report':[25,10], 'Quiz':[20,10], 'Presentation':[20,10], 'Report':[20,10]
  };
  if(map[type]){ taken.value = map[type][0]; convert.value = map[type][1]; }
}
function toggleBestOf(){
  const wrap = document.getElementById('bestof-count-wrap');
  const chk = document.getElementById('am-bestof');
  if(wrap && chk) wrap.style.display = chk.checked ? '' : 'none';
}
function submitAddMarks(){
  const selectedType = (document.getElementById('exam-type-select')?.value || '').trim();
  const customName = (document.getElementById('exam-type-custom')?.value || '').trim();
  const componentName = customName || selectedType;
  const taken = num(document.getElementById('am-taken')?.value);
  const convert = num(document.getElementById('am-convert')?.value);
  if(!componentName || taken <= 0 || convert <= 0){
    showToast('Exam name, Taken Out Of, and Convert To are required.', 'warning', 'Missing Data');
    return;
  }
  const payload = {
    section_id: getCurrentSectionId(),
    component_name: componentName,
    taken_out_of: taken,
    convert_to: convert,
    weight: convert,
    exam_date: document.getElementById('am-date')?.value || null,
    is_best_of_group: document.getElementById('am-bestof')?.checked ? 1 : 0,
    best_of_group: document.getElementById('am-bestof')?.checked ? String(componentName).toLowerCase().replace(/[^a-z0-9]+/g,'_') : null
  };
  fetch('add_marks_component.php', {method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'}, body:JSON.stringify(payload)})
    .then(r => r.json())
    .then(data => {
      if(!data.success){ showToast(data.message || 'Failed to add component.', 'error', 'Failed'); return; }
      closeModal('modal-add-marks');
      showToast('New marks column saved to database.', 'success', 'Column Added');
      window.currentEditComponent = data.component?.component_key || window.currentEditComponent;
      return loadCurrentTeacherSection(false);
    })
    .then(() => {
      if(window.currentEditComponent) changeEditComponent(window.currentEditComponent);
    })
    .catch(err => { console.error(err); showToast('Unable to add marks column.', 'error', 'Failed'); });
}
function updateSubmitView(){
  const sec = window.URAMS_TEACHER_SECTION || {};
  const title = document.getElementById('submit-current-section');
  const students = document.getElementById('submit-students-count');
  const comps = document.getElementById('submit-components-count');
  const status = document.getElementById('submit-status-label');
  if(title) title.textContent = sec.course_title ? `${sec.course_title} — Section ${sec.section}` : '---';
  if(students) students.textContent = STUDENTS.length;
  if(comps) comps.textContent = TEACHER_COMPONENTS.length;
  if(status) status.textContent = String(sec.status || 'Draft').replace(/^./, c => c.toUpperCase());
}
function confirmSubmitResult(){
  const sectionTitle = window.URAMS_TEACHER_SECTION?.course_title || 'this section';
  showConfirm('Submit Results', `Are you sure you want to submit ${sectionTitle} results to Admin? You cannot edit while submitted.`, 'success', () => submitResultsToAdmin());
}
function submitResultsToAdmin(){
  const sectionId = getCurrentSectionId();
  if(!sectionId){ showToast('No section selected.', 'warning', 'No Section'); return; }
  fetch('submit_results.php', {method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'}, body:JSON.stringify({section_id:sectionId})})
    .then(r => r.json())
    .then(data => {
      if(!data.success){ showToast(data.message || 'Failed to submit result.', 'error', 'Failed'); return; }
      showToast(data.message || 'Results submitted to Admin.', 'success', 'Submitted');
      return loadCurrentTeacherSection(false);
    })
    .catch(err => { console.error(err); showToast('Unable to submit results.', 'error', 'Error'); });
}
function drawMarksChart(){
  const canvas = document.getElementById('marks-bar-chart');
  const comp = getComponentByKey(window.currentEditComponent);
  if(!canvas || !comp) return;
  const labels = STUDENTS.map(s => String(s.name || '').split(' ')[0]);
  const data = STUDENTS.map(s => getComponentMark(s, comp).converted_marks || 0);
  drawBarChart(canvas, labels, data, `${comp.component_name} Marks`);
}
function showPercentModal(exam){
  const comp = TEACHER_COMPONENTS.find(c => c.component_name === exam) || getComponentByKey(window.currentEditComponent);
  if(!comp){ showToast('No component selected.', 'warning', 'No Data'); return; }
  const title = document.getElementById('percent-modal-title');
  if(title) title.textContent = `${comp.component_name} — % Distribution`;
  openModal('modal-percent');
  setTimeout(() => {
    const canvas = document.getElementById('percent-chart');
    const labels = STUDENTS.map(s => String(s.name || '').split(' ')[0]);
    const data = STUDENTS.map(s => {
      const mark = getComponentMark(s, comp);
      return comp.convert_to > 0 ? ((num(mark.converted_marks) / num(comp.convert_to)) * 100).toFixed(0) : 0;
    });
    drawBarChart(canvas, labels, data, `${comp.component_name} Percentage`, true);
  }, 50);
}
function applyBestCT(){
  const ctComponents = TEACHER_COMPONENTS.filter(c => c.component_type === 'ct');
  if(!ctComponents.length){ showToast('No CT components found.', 'warning', 'No Data'); return; }
  STUDENTS.forEach(s => {
    s.best_ct = Math.max(...ctComponents.map(c => num(getComponentMark(s, c).converted_marks)));
  });
  renderResultTable();
  showToast('Best CT is calculated from database components.', 'success', 'Best CT');
}
function applyBestAssign(){
  const assignComponents = TEACHER_COMPONENTS.filter(c => c.component_type === 'assignment');
  if(!assignComponents.length){ showToast('No Assignment components found.', 'warning', 'No Data'); return; }
  const maxMark = Math.max(...STUDENTS.flatMap(s => assignComponents.map(c => num(getComponentMark(s, c).converted_marks))));
  document.querySelectorAll('#result-tbody tr').forEach(row => {
    row.classList.toggle('best-mark', row.textContent.includes(maxMark.toFixed(1)));
  });
  showToast('Best assignment highlighted from database marks.', 'success', 'Best Assign');
}


/* ══════════════════════════════════════════════════════════════════
   TEACHER UI FIX OVERRIDE — grouped totals, chart, attendance, profile
   ══════════════════════════════════════════════════════════════════ */
function isTeacherResultLocked(){
  const st = String(window.URAMS_TEACHER_SECTION?.status || '').toLowerCase();
  return st === 'submitted' || st === 'approved';
}
function teacherLockMessage(){
  const st = String(window.URAMS_TEACHER_SECTION?.status || '').toUpperCase() || 'SUBMITTED/APPROVED';
  return `This result is ${st}. Marks editing is locked.`;
}
function getCurrentSectionId(){
  const secSelect = document.getElementById('filter-section');
  if(secSelect){
    if(secSelect.value === '') return 0;
    if(secSelect.value) return parseInt(secSelect.value, 10) || 0;
  }
  if (window.URAMS_ACTIVE_SECTION_ID) return parseInt(window.URAMS_ACTIVE_SECTION_ID, 10);
  if (window.URAMS_TEACHER_SECTION?.section_id) return parseInt(window.URAMS_TEACHER_SECTION.section_id, 10);
  const sections = Array.isArray(window.URAMS_TEACHER_SECTIONS) ? window.URAMS_TEACHER_SECTIONS : [];
  return sections.length ? parseInt(sections[0].section_id, 10) : 0;
}
function teacherUniqueOptions(sections, labelBuilder){
  const seen = new Set();
  const rows = [];
  sections.forEach(s => {
    const label = labelBuilder(s);
    const key = `${s.section_id}:${label}`;
    if(!seen.has(key)){
      seen.add(key);
      rows.push({section_id:s.section_id, label});
    }
  });
  return rows;
}
function populateTeacherFilters(){
  const sections = Array.isArray(window.URAMS_TEACHER_SECTIONS) ? window.URAMS_TEACHER_SECTIONS : [];
  const triSelect = document.getElementById('filter-trimester');
  const courseSelect = document.getElementById('filter-course');
  const secSelect = document.getElementById('filter-section');
  if(!triSelect || !courseSelect || !secSelect) return;
  const makeOptions = (placeholder, rows) => `<option value="">${placeholder}</option>` + rows.map(r => `<option value="${escHtml(r.section_id)}">${escHtml(r.label)}</option>`).join('');
  triSelect.innerHTML = makeOptions('Select trimester', teacherUniqueOptions(sections, s => s.trimester_name || 'Unknown Trimester'));
  courseSelect.innerHTML = makeOptions('Select course', teacherUniqueOptions(sections, s => `${s.course_name || ''} (${s.course_code || ''})`));
  secSelect.innerHTML = makeOptions('Select section', teacherUniqueOptions(sections, s => s.section_name || 'Section'));
  const active = window.URAMS_ACTIVE_SECTION_ID || (sections[0]?.section_id || '');
  [triSelect, courseSelect, secSelect].forEach(sel => { if(active) sel.value = String(active); });
  const statCourses = document.getElementById('teacher-stat-courses');
  if(statCourses) statCourses.textContent = sections.length;
}
function renderTeacherEmptySelection(){
  syncTeacherGlobals([], [], null);
  const title = document.getElementById('teacher-section-title');
  const sub = document.getElementById('teacher-section-subtitle');
  const thead = document.getElementById('result-thead');
  const tbody = document.getElementById('result-tbody');
  if(title) title.textContent = 'No section selected';
  if(sub) sub.textContent = 'Select trimester, course and section, then click Apply.';
  if(thead) thead.innerHTML = '<tr><th>Photo</th><th>UIU ID</th><th>Name</th><th>Status</th></tr>';
  if(tbody) tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;padding:24px;color:var(--text2)">No section selected.</td></tr>';
  ['teacher-stat-students','teacher-stat-components','student-count','submit-students-count','submit-components-count'].forEach(id => { const el = document.getElementById(id); if(el) el.textContent = '0'; });
  const st = document.getElementById('teacher-stat-status');
  if(st) st.textContent = '---';
  const last = document.getElementById('teacher-last-updated');
  if(last) last.textContent = '---';
}
function filterChanged(){
  const id = parseInt((document.getElementById('filter-section')?.value || document.getElementById('filter-course')?.value || document.getElementById('filter-trimester')?.value || '0'), 10);
  if(id){
    ['filter-trimester','filter-course','filter-section'].forEach(elId => {
      const el = document.getElementById(elId);
      if(el) el.value = String(id);
    });
    window.URAMS_ACTIVE_SECTION_ID = id;
  } else {
    window.URAMS_ACTIVE_SECTION_ID = null;
    renderTeacherEmptySelection();
  }
}
function applyFilter(){
  filterChanged();
  const id = getCurrentSectionId();
  if(!id){
    renderTeacherEmptySelection();
    showToast('Please select a section first.', 'warning', 'No Section');
    return;
  }
  loadCurrentTeacherSection(true);
}
function renderTeacherSectionMeta(){
  const sec = window.URAMS_TEACHER_SECTION || {};
  const titleText = sec.course_title ? `${sec.course_title} — Section ${sec.section || ''}` : 'Selected Section';
  const subText = `${sec.trimester || ''} · ${STUDENTS.length} students · Result: ${String(sec.status || 'draft').toUpperCase()}`;
  const title = document.getElementById('teacher-section-title');
  const sub = document.getElementById('teacher-section-subtitle');
  const headSub = document.getElementById('teacher-header-subtitle');
  if(title) title.textContent = titleText;
  if(sub) sub.textContent = subText + (isTeacherResultLocked() ? ' · Editing locked' : '');
  if(headSub) headSub.textContent = `${sec.trimester || 'Teacher Panel'}${sec.section ? ' · Section ' + sec.section : ''}`;
  const studentCount = document.getElementById('student-count');
  if(studentCount) studentCount.textContent = STUDENTS.length;
  const last = document.getElementById('teacher-last-updated');
  if(last) last.textContent = new Date().toLocaleTimeString([], {hour:'2-digit', minute:'2-digit'});
  const statStudents = document.getElementById('teacher-stat-students');
  const statComponents = document.getElementById('teacher-stat-components');
  const statStatus = document.getElementById('teacher-stat-status');
  if(statStudents) statStudents.textContent = STUDENTS.length;
  if(statComponents) statComponents.textContent = TEACHER_COMPONENTS.length;
  if(statStatus) statStatus.textContent = String(sec.status || 'Draft').replace(/^./, c => c.toUpperCase());
}
function renderResultTable(){
  const thead = document.getElementById('result-thead');
  const tbody = document.getElementById('result-tbody');
  if(!thead || !tbody) return;
  if(!window.URAMS_TEACHER_SECTION){
    renderTeacherEmptySelection();
    return;
  }
  if(!STUDENTS.length){
    thead.innerHTML = '<tr><th>Photo</th><th>UIU ID</th><th>Name</th><th>Status</th></tr>';
    tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;padding:24px">No students found for this section.</td></tr>';
    return;
  }
  const componentHeaders = TEACHER_COMPONENTS.map(c => `
    <th data-component-key="${escHtml(c.component_key)}" data-component-type="${escHtml(c.component_type)}">
      ${escHtml(c.component_name)} <span style="font-weight:400;color:var(--text3)">(${formatMark(c.convert_to)})</span>
      <div style="display:flex;gap:3px;margin-top:3px">
        <button class="btn btn-sm btn-ghost" style="padding:1px 4px;font-size:10px" onclick="teacherNav('marks',null); changeEditComponent('${escHtml(c.component_key)}')"><i class="fas fa-eye"></i></button>
        <button class="btn btn-sm btn-ghost" style="padding:1px 4px;font-size:10px" onclick="showPercentModal('${escHtml(c.component_name)}')">%</button>
      </div>
    </th>`).join('');
  thead.innerHTML = `<tr><th>Photo</th><th>UIU ID</th><th>Name</th>${componentHeaders}<th>Total</th><th>Grade</th><th>Status</th></tr>`;
  tbody.innerHTML = STUDENTS.map((student, rowIndex) => {
    const initials = String(student.name || 'S').split(' ').map(p => p[0]).join('').slice(0,2).toUpperCase();
    const cells = TEACHER_COMPONENTS.map(c => {
      const mark = getComponentMark(student, c);
      return `<td data-student-index="${rowIndex}" data-component-key="${escHtml(c.component_key)}" data-component-type="${escHtml(c.component_type)}">${formatMark(mark.converted_marks)}</td>`;
    }).join('');
    return `<tr data-student-index="${rowIndex}">
      <td><div class="student-avatar-sm">${escHtml(initials)}</div></td>
      <td class="td-id">${escHtml(student.student_id || student.id)}</td>
      <td class="td-name" onclick="openStudentModal('${escHtml(student.name)}','${escHtml(student.student_id || student.id)}')">${escHtml(student.name)}</td>
      ${cells}
      <td style="font-weight:800">${formatMark(Math.min(100, num(student.total_marks)))}</td>
      <td><span class="grade-${String(student.grade || 'F').replace('+','-plus').replace('-','-minus')}">${escHtml(student.grade || '-')}</span></td>
      <td>${statusBadge(student.result_status || window.URAMS_TEACHER_SECTION?.status)}</td>
    </tr>`;
  }).join('');
}
function updateComponentConfigFields(){
  const comp = getComponentByKey(window.currentEditComponent);
  const taken = document.getElementById('conf-taken');
  const convert = document.getElementById('conf-convert');
  const grace = document.getElementById('conf-grace');
  if(taken) taken.value = comp ? formatMark(comp.taken_out_of) : '0';
  if(convert) convert.value = comp ? formatMark(comp.convert_to) : '0';
  if(grace) grace.disabled = isTeacherResultLocked();
  const actualHead = document.getElementById('marks-actual-head');
  const convHead = document.getElementById('marks-converted-head');
  if(actualHead) actualHead.innerHTML = `Actual Marks <span style="font-weight:400">(max: ${comp ? formatMark(comp.taken_out_of) : '0'})</span>`;
  if(convHead) convHead.textContent = comp ? `Converted (/${formatMark(comp.taken_out_of)} × ${formatMark(comp.convert_to)})` : 'Converted';
  const title = document.getElementById('marks-table-title');
  if(title) title.textContent = comp ? `Student Marks Entry — ${comp.component_name}` : 'Student Marks Entry';
  const chartTitle = document.getElementById('marks-chart-title');
  if(chartTitle) chartTitle.innerHTML = `<i class="fas fa-chart-bar" style="color:var(--primary)"></i> ${comp ? escHtml(comp.component_name) : 'Marks'} Distribution`;
}
function initMarksTable(){
  const tbody = document.getElementById('marks-tbody');
  if(!tbody) return;
  const comp = getComponentByKey(window.currentEditComponent);
  updateComponentConfigFields();
  if(!window.URAMS_TEACHER_SECTION){
    tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:20px">Select a section first.</td></tr>';
    return;
  }
  if(!comp){
    tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:20px">No component found. Add a marks column first.</td></tr>';
    return;
  }
  if(!STUDENTS.length){
    tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:20px">No students found.</td></tr>';
    return;
  }
  const locked = isTeacherResultLocked();
  tbody.innerHTML = STUDENTS.map((s,i) => {
    const mark = getComponentMark(s, comp);
    const raw = num(mark.raw_marks);
    const absent = parseInt(mark.is_absent || 0, 10) === 1;
    const initials = String(s.name || 'S').split(' ').map(p => p[0]).join('').slice(0,2).toUpperCase();
    return `<tr id="marks-row-${i}">
      <td>${i+1}</td>
      <td><div class="student-avatar-sm">${escHtml(initials)}</div></td>
      <td class="td-id">${escHtml(s.student_id || s.id)}</td>
      <td class="td-name">${escHtml(s.name)}</td>
      <td><input class="marks-input" type="number" min="0" max="${num(comp.taken_out_of)}" step="0.01" value="${raw.toFixed(2)}" id="actual-${i}" oninput="calculateConversion(${i})" readonly ${locked ? 'disabled' : ''}></td>
      <td><span class="marks-converted" id="conv-${i}">${formatMark(mark.converted_marks)}</span></td>
      <td><input type="checkbox" id="abs-${i}" ${absent ? 'checked' : ''} onchange="markAbsent(${i})" disabled></td>
      <td><div class="btn-group">
        <button class="btn btn-sm btn-ghost" id="edit-btn-${i}" onclick="editRow(${i})" ${locked ? 'disabled title="Locked"' : ''}><i class="fas fa-edit"></i></button>
        <button class="btn btn-sm btn-success" id="save-btn-${i}" onclick="saveRow(${i})" style="display:none"><i class="fas fa-save"></i></button>
      </div></td>
    </tr>`;
  }).join('');
  const saveAllBtn = document.querySelector('button[onclick="saveAllMarks()"]');
  if(saveAllBtn){
    saveAllBtn.disabled = locked;
    saveAllBtn.title = locked ? teacherLockMessage() : '';
  }
}
function editRow(i){
  if(isTeacherResultLocked()){
    showToast(teacherLockMessage(), 'warning', 'Locked');
    return;
  }
  const input = document.getElementById(`actual-${i}`);
  const absent = document.getElementById(`abs-${i}`);
  if(input){ input.removeAttribute('readonly'); input.disabled = false; input.style.border = '2px solid var(--primary)'; input.focus(); }
  if(absent) absent.disabled = false;
  const editBtn = document.getElementById(`edit-btn-${i}`);
  const saveBtn = document.getElementById(`save-btn-${i}`);
  if(editBtn) editBtn.style.display = 'none';
  if(saveBtn) saveBtn.style.display = '';
}
function saveRow(i){
  if(isTeacherResultLocked()){
    showToast(teacherLockMessage(), 'warning', 'Locked');
    return;
  }
  const student = STUDENTS[i];
  const comp = getComponentByKey(window.currentEditComponent);
  if(!student || !comp){ showToast('Missing student/component.', 'error', 'Save Failed'); return; }
  const payload = {
    enrollment_id: student.enrollment_id,
    result_id: student.result_id,
    component_id: comp.id,
    component: comp.component_key,
    raw_marks: num(document.getElementById(`actual-${i}`)?.value),
    is_absent: document.getElementById(`abs-${i}`)?.checked ? 1 : 0
  };
  fetch('save_marks.php', {method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'}, body:JSON.stringify(payload)})
    .then(r => r.json())
    .then(data => {
      if(!data.success){ showToast(data.message || 'Failed to save marks.', 'error', 'Save Failed'); return; }
      showToast(`Marks saved for ${student.name}`, 'success', 'Saved');
      return loadCurrentTeacherSection(false);
    })
    .then(() => changeEditComponent(comp.component_key))
    .catch(err => { console.error(err); showToast('Unable to save marks.', 'error', 'Save Failed'); });
}
function saveAllMarks(){
  if(isTeacherResultLocked()){
    showToast(teacherLockMessage(), 'warning', 'Locked');
    return;
  }
  const comp = getComponentByKey(window.currentEditComponent);
  if(!comp){ showToast('No component selected.', 'warning', 'Nothing to Save'); return; }
  const updates = STUDENTS.map((student,i) => ({
    enrollment_id: student.enrollment_id,
    result_id: student.result_id,
    component_id: comp.id,
    raw_marks: num(document.getElementById(`actual-${i}`)?.value),
    is_absent: document.getElementById(`abs-${i}`)?.checked ? 1 : 0
  })).filter(row => row.enrollment_id || row.result_id);
  if(!updates.length){ showToast('No student records available to save.', 'warning', 'Nothing to Save'); return; }
  fetch('save_marks.php', {method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'}, body:JSON.stringify({component_id:comp.id, component:comp.component_key, updates})})
    .then(r => r.json())
    .then(data => {
      if(!data.success){ showToast(data.message || 'Failed to save marks.', 'error', 'Save Failed'); return; }
      showToast('All marks saved successfully.', 'success', 'Saved');
      return loadCurrentTeacherSection(false);
    })
    .then(() => changeEditComponent(comp.component_key))
    .catch(err => { console.error(err); showToast('Unable to save marks.', 'error', 'Save Failed'); });
}
function openAddMarksModal(){
  if(isTeacherResultLocked()){
    showToast(teacherLockMessage(), 'warning', 'Locked');
    return;
  }
  const sectionId = getCurrentSectionId();
  if(!sectionId){ showToast('Select a section first.', 'warning', 'No Section'); return; }
  const modal = document.getElementById('modal-add-marks');
  if(!modal){ showToast('Add Marks modal not found.', 'error', 'Error'); return; }
  ['exam-type-select','exam-type-custom','am-taken','am-convert','am-date'].forEach(id => { const el = document.getElementById(id); if(el) el.value = ''; });
  const best = document.getElementById('am-bestof');
  if(best) best.checked = false;
  toggleBestOf();
  openModal('modal-add-marks');
}
function submitAddMarks(){
  if(isTeacherResultLocked()){
    showToast(teacherLockMessage(), 'warning', 'Locked');
    return;
  }
  const selectedType = (document.getElementById('exam-type-select')?.value || '').trim();
  const customName = (document.getElementById('exam-type-custom')?.value || '').trim();
  const componentName = customName || selectedType;
  const taken = num(document.getElementById('am-taken')?.value);
  const convert = num(document.getElementById('am-convert')?.value);
  if(!componentName || taken <= 0 || convert <= 0){
    showToast('Exam name, Taken Out Of, and Convert To are required.', 'warning', 'Missing Data');
    return;
  }
  const lower = componentName.toLowerCase();
  const componentType = lower.startsWith('ct') ? 'ct' : lower.startsWith('assign') ? 'assignment' : lower.startsWith('mid') ? 'mid' : lower.startsWith('final') ? 'final' : lower.startsWith('attendance') ? 'attendance' : lower.startsWith('quiz') ? 'quiz' : 'custom';
  const payload = {
    section_id: getCurrentSectionId(),
    component_name: componentName,
    component_type: componentType,
    taken_out_of: taken,
    convert_to: convert,
    weight: convert,
    exam_date: document.getElementById('am-date')?.value || null,
    is_best_of_group: (componentType === 'ct' || componentType === 'assignment' || document.getElementById('am-bestof')?.checked) ? 1 : 0,
    best_of_group: componentType === 'ct' ? 'ct' : componentType === 'assignment' ? 'assignment' : (document.getElementById('am-bestof')?.checked ? String(componentName).toLowerCase().replace(/[^a-z0-9]+/g,'_') : null)
  };
  fetch('add_marks_component.php', {method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'}, body:JSON.stringify(payload)})
    .then(r => r.json())
    .then(data => {
      if(!data.success){ showToast(data.message || 'Failed to add component.', 'error', 'Failed'); return; }
      closeModal('modal-add-marks');
      showToast('New marks column saved to database.', 'success', 'Column Added');
      window.currentEditComponent = data.component?.component_key || window.currentEditComponent;
      return loadCurrentTeacherSection(false);
    })
    .then(() => { if(window.currentEditComponent) changeEditComponent(window.currentEditComponent); })
    .catch(err => { console.error(err); showToast('Unable to add marks column.', 'error', 'Failed'); });
}
function teacherCssEscape(value){
  if(window.CSS && typeof window.CSS.escape === 'function') return CSS.escape(String(value));
  return String(value).replace(/[^a-zA-Z0-9_-]/g, '\\$&');
}
function highlightBestCells(type){
  renderResultTable();
  const components = TEACHER_COMPONENTS.filter(c => c.component_type === type);
  if(!components.length){
    showToast(type === 'ct' ? 'No CT components found.' : 'No Assignment components found.', 'warning', 'No Data');
    return;
  }
  STUDENTS.forEach((student, rowIndex) => {
    let bestKey = null;
    let bestVal = -Infinity;
    components.forEach(c => {
      const val = num(getComponentMark(student, c).converted_marks);
      if(val > bestVal){ bestVal = val; bestKey = c.component_key; }
    });
    const cell = document.querySelector(`#result-tbody tr[data-student-index="${rowIndex}"] td[data-component-key="${teacherCssEscape(bestKey)}"]`);
    if(cell) cell.classList.add('best-mark');
  });
}
function applyBestCT(){
  highlightBestCells('ct');
  showToast('Best CT highlighted for each student. Total uses best CT group.', 'success', 'Best CT');
}
function applyBestAssign(){
  highlightBestCells('assignment');
  showToast('Best Assignment highlighted for each student. Total uses best assignment group.', 'success', 'Best Assign');
}
function toggleMarksChart(force){
  const wrap = document.getElementById('marks-chart-wrapper');
  if(!wrap) return;
  marksChartVisible = typeof force === 'boolean' ? force : !marksChartVisible;
  wrap.style.display = marksChartVisible ? '' : 'none';
  if(marksChartVisible) setTimeout(drawMarksChart, 50);
}
function openChartView(){
  teacherNav('marks', null);
  toggleMarksChart();
}
function drawMarksChart(){
  const canvas = document.getElementById('marks-bar-chart');
  const comp = getComponentByKey(window.currentEditComponent);
  if(!canvas || !comp) return;
  const labels = STUDENTS.map(s => String(s.name || '').split(' ')[0]);
  const data = STUDENTS.map(s => getComponentMark(s, comp).converted_marks || 0);
  drawBarChart(canvas, labels, data, `${comp.component_name} Marks`);
}
function renderTeacherAttendance(){
  const tbody = document.getElementById('attendance-tbody');
  const sub = document.getElementById('attendance-subtitle');
  if(!tbody) return;
  const comp = TEACHER_COMPONENTS.find(c => c.component_type === 'attendance' || c.component_key === 'attendance');
  if(!window.URAMS_TEACHER_SECTION){
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;padding:24px">Select a section first.</td></tr>';
    return;
  }
  if(!comp){
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;padding:24px">No Attendance component found. Add Attendance in Add/Edit Marks first.</td></tr>';
    return;
  }
  if(sub) sub.textContent = `${comp.component_name} · Max ${formatMark(comp.convert_to)} marks`;
  tbody.innerHTML = STUDENTS.map((s,i) => {
    const mark = getComponentMark(s, comp);
    const absent = parseInt(mark.is_absent || 0, 10) === 1;
    return `<tr>
      <td>${i+1}</td>
      <td class="td-id">${escHtml(s.student_id || s.id)}</td>
      <td class="td-name">${escHtml(s.name)}</td>
      <td>${formatMark(mark.raw_marks)}</td>
      <td style="font-weight:700">${formatMark(mark.converted_marks)}</td>
      <td>${absent ? '<span class="badge badge-danger">Absent</span>' : '<span class="badge badge-success">Present/Marked</span>'}</td>
    </tr>`;
  }).join('');
}
function openAttendanceMarks(){
  const comp = TEACHER_COMPONENTS.find(c => c.component_type === 'attendance' || c.component_key === 'attendance');
  if(!comp){
    showToast('No Attendance component found.', 'warning', 'No Attendance');
    return;
  }
  teacherNav('marks', null);
  changeEditComponent(comp.component_key);
}
function teacherStatNavigate(target){
  if(target === 'sections'){
    document.getElementById('filter-section')?.focus();
    showToast('Use the section filters and Apply button to switch sections.', 'info', 'Sections');
  } else if(target === 'students'){
    document.getElementById('student-search')?.focus();
    showToast('Student table is shown below for the selected section.', 'info', 'Students');
  } else if(target === 'components'){
    teacherNav('marks', null);
    document.getElementById('edit-component-select')?.focus();
  } else if(target === 'status'){
    teacherNav('submit', null);
  }
}
function teacherNav(view, navEl){
  teacherViews.forEach(v => {
    const el = document.getElementById('view-'+v);
    if(el) el.style.display = v === view ? '' : 'none';
  });
  if(navEl){
    document.querySelectorAll('#teacher-sidebar .nav-item').forEach(n => n.classList.remove('active'));
    navEl.classList.add('active');
  }
  const titles = {dashboard:'Dashboard',marks:'Add / Edit Marks',attendance:'Attendance',submit:'Submit Results',pdf:'Download PDF',profile:'My Profile'};
  const titleEl = document.getElementById('teacher-page-title');
  if(titleEl) titleEl.textContent = titles[view] || view;
  if(view === 'marks') initMarksTable();
  if(view === 'attendance') renderTeacherAttendance();
  if(view === 'submit') updateSubmitView();
  if(view === 'marks' && marksChartVisible) drawMarksChart();
}

/* ══════════════════════════════════════════════════════════════════
   TEACHER HOTFIX 006 — filter empty state + old attendance UI restore
   ══════════════════════════════════════════════════════════════════ */
(function(){
  function $id(id){ return document.getElementById(id); }
  function safeSections(){ return Array.isArray(window.URAMS_TEACHER_SECTIONS) ? window.URAMS_TEACHER_SECTIONS : []; }
  function optionHtml(value, label){ return `<option value="${escHtml(value)}">${escHtml(label)}</option>`; }

  window.populateTeacherFilters = function(){
    const sections = safeSections();
    const triSelect = $id('filter-trimester');
    const courseSelect = $id('filter-course');
    const secSelect = $id('filter-section');
    if(!triSelect || !courseSelect || !secSelect) return;

    // Keep all filters blank by default. Do not auto-pick the first section.
    const current = window.URAMS_ACTIVE_SECTION_ID || '';
    triSelect.innerHTML = optionHtml('', 'Select trimester') + sections.map(s => optionHtml(s.section_id, s.trimester_name || 'Trimester')).join('');
    courseSelect.innerHTML = optionHtml('', 'Select course') + sections.map(s => optionHtml(s.section_id, `${s.course_name || 'Course'} (${s.course_code || ''})`)).join('');
    secSelect.innerHTML = optionHtml('', 'Select section') + sections.map(s => optionHtml(s.section_id, s.section_name || 'Section')).join('');

    if(current){
      [triSelect, courseSelect, secSelect].forEach(sel => { sel.value = String(current); });
      window.URAMS_ACTIVE_SECTION_ID = parseInt(current, 10);
    } else {
      [triSelect, courseSelect, secSelect].forEach(sel => { sel.value = ''; });
      window.URAMS_ACTIVE_SECTION_ID = null;
    }
    const statCourses = $id('teacher-stat-courses');
    if(statCourses) statCourses.textContent = sections.length;
  };

  window.getCurrentSectionId = function(){
    const sec = $id('filter-section');
    const course = $id('filter-course');
    const tri = $id('filter-trimester');
    // A section must be selected explicitly. Do not fall back to old active/default data.
    if(sec && sec.value === '') return 0;
    const raw = sec?.value || course?.value || tri?.value || '';
    const id = parseInt(raw, 10);
    return Number.isFinite(id) && id > 0 ? id : 0;
  };

  window.filterChanged = function(){
    const sec = $id('filter-section');
    const course = $id('filter-course');
    const tri = $id('filter-trimester');
    const raw = sec?.value || course?.value || tri?.value || '';
    const id = parseInt(raw, 10);
    if(Number.isFinite(id) && id > 0){
      [tri, course, sec].forEach(sel => { if(sel) sel.value = String(id); });
      window.URAMS_ACTIVE_SECTION_ID = id;
    } else {
      [tri, course, sec].forEach(sel => { if(sel) sel.value = ''; });
      window.URAMS_ACTIVE_SECTION_ID = null;
      window.URAMS_TEACHER_SECTION = null;
      window.URAMS_TEACHER_STUDENTS = [];
      window.URAMS_TEACHER_COMPONENTS = [];
      window.STUDENTS = [];
      window.TEACHER_COMPONENTS = [];
      renderTeacherEmptySelection();
    }
  };

  window.applyFilter = function(){
    filterChanged();
    const id = getCurrentSectionId();
    if(!id){
      renderTeacherEmptySelection();
      showToast('Please select trimester, course and section first.', 'warning', 'No Section');
      return;
    }
    loadCurrentTeacherSection(true);
  };

  window.renderTeacherEmptySelection = function(){
    const thead = $id('result-thead');
    const tbody = $id('result-tbody');
    if(thead) thead.innerHTML = '<tr><th>Photo</th><th>UIU ID</th><th>Name</th><th>Status</th></tr>';
    if(tbody) tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;padding:28px;color:var(--text2)">Select trimester, course and section, then click Apply.</td></tr>';
    const title = $id('teacher-section-title');
    const sub = $id('teacher-section-subtitle');
    if(title) title.textContent = 'No section selected';
    if(sub) sub.textContent = 'Select filters to load students and marks.';
    ['teacher-stat-students','teacher-stat-components','student-count','submit-students-count','submit-components-count'].forEach(id => { const el = $id(id); if(el) el.textContent = '0'; });
    const status = $id('teacher-stat-status');
    if(status) status.textContent = '---';
  };

  window.initTeacherDashboard = function(){
    populateTeacherFilters();
    renderTeacherEmptySelection();
    const dash = $id('view-dashboard');
    if(dash) dash.style.display = '';
    if(Array.isArray(window.teacherViews)){
      window.teacherViews.filter(v => v !== 'dashboard').forEach(v => {
        const el = $id('view-' + v);
        if(el) el.style.display = 'none';
      });
    }
  };

  function getAttendanceComponent(){
    return (window.TEACHER_COMPONENTS || []).find(c => c.component_type === 'attendance' || c.component_key === 'attendance' || c.component_key === 'attendance_marks');
  }
  function getAttDates(){
    if(!Array.isArray(window.ATTENDANCE_DATES) || !window.ATTENDANCE_DATES.length){
      window.ATTENDANCE_DATES = ['14 Jun','17 Jun','21 Jun','24 Jun','28 Jun'];
    }
    return window.ATTENDANCE_DATES;
  }
  function initials(name){ return String(name || '').split(' ').filter(Boolean).map(w=>w[0]).join('').slice(0,2).toUpperCase() || 'ST'; }

  window.getAttendanceMetrics = function(dates){
    const total = dates.length;
    const present = dates.filter(d=>d==='P' || d==='L').length;
    const absent = dates.filter(d=>d==='A').length;
    const pct = total ? Math.round((present / total) * 100) : 0;
    const comp = getAttendanceComponent();
    const maxMark = comp ? num(comp.convert_to, 10) : 10;
    const attMarks = total ? Math.round((pct / 100) * maxMark * 100) / 100 : 0;
    return {total, present, absent, pct, attMarks};
  };

  window.initAttendanceTable = function(){
    const tbody = $id('att-tbody');
    const headRow = $id('att-head-row');
    const sub = $id('attendance-page-subtitle');
    if(!tbody) return;
    if(!window.URAMS_TEACHER_SECTION){
      tbody.innerHTML = '<tr><td colspan="13" style="text-align:center;padding:24px">Select a section first.</td></tr>';
      return;
    }
    const comp = getAttendanceComponent();
    const dates = getAttDates();
    if(headRow){
      headRow.innerHTML = '<th>Photo</th><th>UIU ID</th><th>Name</th>' + dates.map(d=>`<th>${escHtml(d)}</th>`).join('') + '<th>Classes</th><th>Present</th><th>Absent</th><th>%</th><th>Att. Marks</th>';
    }
    if(sub){
      const sec = window.URAMS_TEACHER_SECTION || {};
      sub.textContent = `${sec.course_code || sec.course_title || 'Course'} · Section ${sec.section || ''} · ${sec.trimester || ''}`;
    }
    if(!STUDENTS.length){
      tbody.innerHTML = `<tr><td colspan="${dates.length+8}" style="text-align:center;padding:24px">No students found.</td></tr>`;
      return;
    }
    window.ATTENDANCE_DATA = STUDENTS.map(s => {
      const existing = (window.ATTENDANCE_DATA || []).find(a => String(a.id) === String(s.id || s.student_id));
      let rowDates = existing?.dates;
      if(!Array.isArray(rowDates) || rowDates.length !== dates.length){
        rowDates = Array.from({length: dates.length}, (_, i) => existing?.dates?.[i] || 'P');
      }
      const mark = comp ? getComponentMark(s, comp) : null;
      if(mark && mark.converted_marks !== undefined && !existing){
        const maxMark = comp ? num(comp.convert_to, 10) : 10;
        if(num(mark.converted_marks, 0) <= 0){ rowDates = ['P','P','A','A','P'].slice(0, dates.length); while(rowDates.length < dates.length) rowDates.push('P'); }
        else if(num(mark.converted_marks, 0) >= maxMark){ rowDates = Array.from({length: dates.length}, ()=>'P'); }
      }
      return { id: s.id || s.student_id, result_id: s.result_id, enrollment_id: s.enrollment_id, name: s.name, dates: rowDates };
    });
    tbody.innerHTML = ATTENDANCE_DATA.map((s,i)=>{
      const metrics = getAttendanceMetrics(s.dates);
      const dateCells = s.dates.map((d,di)=>`<td><button type="button" class="att-toggle att-${d}" id="att-${i}-${di}">${d}</button></td>`).join('');
      return `<tr>
        <td><div class="td-avatar">${escHtml(initials(s.name))}</div></td>
        <td class="td-id">${escHtml(s.id)}</td>
        <td class="td-name">${escHtml(s.name)}</td>
        ${dateCells}
        <td style="font-weight:700">${metrics.total}</td>
        <td id="att-present-${i}" style="color:var(--success);font-weight:700">${metrics.present}</td>
        <td id="att-absent-${i}" style="color:var(--danger);font-weight:700">${metrics.absent}</td>
        <td><div style="display:flex;align-items:center;gap:8px"><div class="progress-bar-wrap" style="width:50px"><div class="progress-bar-fill" id="att-bar-${i}" style="width:${metrics.pct}%;background:${metrics.pct>=75?'var(--success)':'var(--danger)'}"></div></div><span id="att-pct-${i}" style="font-weight:700;color:${metrics.pct>=75?'var(--success)':'var(--danger)'}">${metrics.pct}%</span></div></td>
        <td id="att-marks-${i}" style="font-weight:700;color:${metrics.attMarks>0?'var(--success)':'var(--danger)'}">${formatMark(metrics.attMarks)}</td>
      </tr>`;
    }).join('');
    bindAttendanceEvents();
  };

  window.addAttendanceClassDate = function(){
    const dates = getAttDates();
    const next = dates.length + 1;
    dates.push(`Class ${next}`);
    if(Array.isArray(window.ATTENDANCE_DATA)) window.ATTENDANCE_DATA.forEach(r => r.dates.push('P'));
    initAttendanceTable();
  };

  window.filterAttendanceRows = function(){
    const q = String($id('attendance-search')?.value || '').toLowerCase();
    document.querySelectorAll('#att-tbody tr').forEach(tr => { tr.style.display = tr.textContent.toLowerCase().includes(q) ? '' : 'none'; });
  };

  window.saveAttendance = function(){
    if(typeof isTeacherResultLocked === 'function' && isTeacherResultLocked()){
      showToast(teacherLockMessage(), 'warning', 'Locked');
      return;
    }
    const comp = getAttendanceComponent();
    if(!comp){ showToast('No Attendance component found. Add Attendance component first.', 'warning', 'No Attendance'); return; }
    const updates = (window.ATTENDANCE_DATA || []).map(row => {
      const metrics = getAttendanceMetrics(row.dates || []);
      return { enrollment_id: row.enrollment_id, result_id: row.result_id, component_id: comp.id, raw_marks: metrics.attMarks, converted_marks: metrics.attMarks, is_absent: 0 };
    }).filter(r => r.enrollment_id || r.result_id);
    if(!updates.length){ showToast('No attendance records to save.', 'warning', 'Nothing to Save'); return; }
    fetch('save_marks.php', { method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'}, body:JSON.stringify({component_id: comp.id || null, component: comp.component_key || 'attendance', updates}) })
      .then(r => r.json())
      .then(data => {
        if(!data.success){ showToast(data.message || 'Failed to save attendance.', 'error', 'Failed'); return; }
        showToast('Attendance saved successfully.', 'success', 'Saved');
        return loadCurrentTeacherSection(false);
      })
      .then(() => initAttendanceTable())
      .catch(err => { console.error(err); showToast('Unable to save attendance.', 'error', 'Save Failed'); });
  };

  window.toggleAttendanceChart = function(){
    const wrap = $id('attendance-chart-wrapper');
    if(!wrap) return;
    wrap.style.display = wrap.style.display === 'none' ? '' : 'none';
    if(wrap.style.display !== 'none'){
      const canvas = $id('attendance-chart');
      const labels = (window.ATTENDANCE_DATA || []).map(s => String(s.name || '').split(' ')[0]);
      const data = (window.ATTENDANCE_DATA || []).map(s => getAttendanceMetrics(s.dates || []).pct);
      if(canvas) drawBarChart(canvas, labels, data, 'Attendance %');
    }
  };

  const oldTeacherNav = window.teacherNav;
  window.teacherNav = function(view, navEl){
    if(typeof oldTeacherNav === 'function') oldTeacherNav(view, navEl);
    if(view === 'attendance') initAttendanceTable();
  };
})();

/* ══════════════════════════════════════════════════════════════════
   LEGACY EXCEL-LIKE RESULT SHEET UI + BACKEND HOOKS
   Matches the old full marks sheet workflow: Assessment, Excel,
   Grace, Grade Process, CT Average, Grade Details.
   ══════════════════════════════════════════════════════════════════ */
(function(){
  function $id(id){ return document.getElementById(id); }
  function h(v){ return (typeof escHtml === 'function') ? escHtml(v) : String(v ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c])); }
  function n(v, fallback=0){ const x = parseFloat(v); return Number.isFinite(x) ? x : fallback; }
  function fmt(v){ return n(v).toFixed(2).replace(/\.00$/, '.0'); }
  function currentSectionId(){ return (typeof getCurrentSectionId === 'function') ? getCurrentSectionId() : parseInt(window.URAMS_ACTIVE_SECTION_ID || 0, 10); }
  function locked(){ return (typeof isTeacherResultLocked === 'function') ? isTeacherResultLocked() : false; }
  function lockMsg(){ return (typeof teacherLockMessage === 'function') ? teacherLockMessage() : 'Submitted/approved result cannot be edited.'; }
  function toast(msg, type='info', title='URAMS'){ if(typeof showToast === 'function') showToast(msg, type, title); else alert((title ? title + ': ' : '') + msg); }
  function comps(){ return Array.isArray(window.TEACHER_COMPONENTS) ? window.TEACHER_COMPONENTS : []; }
  function students(){ return Array.isArray(window.STUDENTS) ? window.STUDENTS : []; }
  function markOf(student, comp){ return (typeof getComponentMark === 'function') ? getComponentMark(student, comp) : ((student.component_marks || {})[comp.component_key] || {raw_marks:0, converted_marks:0, is_absent:0}); }
  function gradeClass(grade){ return String(grade || 'F').replace('+','-plus').replace('-','-minus'); }

  window.renderLegacyComponentFilter = function(){
    const sel = $id('legacy-assessment-filter');
    if(!sel) return;
    const previous = sel.value || '';
    sel.innerHTML = '<option value="">All Assessment</option>' + comps().map(c => `<option value="${h(c.component_key)}">${h(c.component_name)}</option>`).join('');
    if(previous && comps().some(c => String(c.component_key) === String(previous))) sel.value = previous;
  };

  function visibleComponents(){
    const selected = $id('legacy-assessment-filter')?.value || '';
    const all = comps();
    if(!selected) return all;
    return all.filter(c => String(c.component_key) === String(selected));
  }

  window.renderLegacyGradeSheet = function(){
    renderLegacyComponentFilter();
    const thead = $id('legacy-grade-thead');
    const tbody = $id('legacy-grade-tbody');
    if(!thead || !tbody) return;
    if(!window.URAMS_TEACHER_SECTION){
      thead.innerHTML = '<tr><th>SL</th><th>Student ID</th><th>Student Name</th><th>Status</th><th>Total</th><th>Grade</th></tr>';
      tbody.innerHTML = '<tr><td colspan="6" style="padding:24px;text-align:center;color:var(--text2)">Select trimester, course and section, then click Apply.</td></tr>';
      return;
    }
    const selectedComps = visibleComponents();
    if(!students().length){
      thead.innerHTML = '<tr><th>SL</th><th>Student ID</th><th>Student Name</th><th>Status</th><th>Total</th><th>Grade</th></tr>';
      tbody.innerHTML = '<tr><td colspan="6" style="padding:24px;text-align:center;color:var(--text2)">No students found for this section.</td></tr>';
      return;
    }
    if(!selectedComps.length){
      thead.innerHTML = '<tr><th>SL</th><th>Student ID</th><th>Student Name</th><th>Status</th><th>Total</th><th>Grade</th></tr>';
      tbody.innerHTML = '<tr><td colspan="6" style="padding:24px;text-align:center;color:var(--text2)">No assessment component found.</td></tr>';
      return;
    }

    const grouped = [];
    selectedComps.forEach(c => {
      const type = c.component_type || 'custom';
      let g = grouped.find(x => x.type === type);
      if(!g){ g = {type, label: type === 'ct' ? 'Class Tests' : type.replace(/^./, ch => ch.toUpperCase()), items: []}; grouped.push(g); }
      g.items.push(c);
    });
    const groupRow = '<tr>' +
      '<th rowspan="2">SL</th><th rowspan="2">Student ID</th><th rowspan="2">Student Name</th><th rowspan="2">Status</th>' +
      grouped.map(g => `<th colspan="${g.items.length}">${h(g.label)}<span class="legacy-mini-note">${fmt(g.items.reduce((sum,c)=>sum+n(c.convert_to),0))}</span></th>`).join('') +
      '<th rowspan="2">Total<br>100.00</th><th rowspan="2">Grade</th></tr>';
    const compRow = '<tr>' + grouped.map(g => g.items.map(c => `<th>${h(c.component_name)}<span class="legacy-mini-note">${fmt(c.convert_to)}</span></th>`).join('')).join('') + '</tr>';
    thead.innerHTML = groupRow + compRow;

    const disabledAttr = locked() ? 'disabled title="Locked"' : '';
    tbody.innerHTML = students().map((s, i) => {
      const compCells = selectedComps.map(c => {
        const mark = markOf(s, c);
        const raw = n(mark.raw_marks);
        const converted = n(mark.converted_marks);
        const maxRaw = Math.max(0.01, n(c.taken_out_of, 100));
        return `<td data-component-key="${h(c.component_key)}">
          <input class="legacy-mark-input" type="number" min="0" max="${h(maxRaw)}" step="0.01" value="${raw.toFixed(2)}" ${disabledAttr}
                 data-student-index="${i}" data-component-id="${h(c.id)}" data-component-key="${h(c.component_key)}" data-taken="${h(maxRaw)}" data-convert="${h(c.convert_to)}"
                 oninput="legacyRecalculateCell(this)">
          <span class="legacy-converted" id="legacy-conv-${i}-${h(c.component_key)}">${fmt(converted)}</span>
        </td>`;
      }).join('');
      return `<tr>
        <td>${i+1}</td>
        <td class="td-id">${h(s.student_id || s.id || '')}</td>
        <td class="legacy-student-name">${h(s.name || '')}</td>
        <td>${typeof statusBadge === 'function' ? statusBadge(s.result_status || window.URAMS_TEACHER_SECTION?.status) : h(s.result_status || '')}</td>
        ${compCells}
        <td style="font-weight:900" id="legacy-total-${i}">${fmt(Math.min(100, n(s.total_marks)))}</td>
        <td><span class="grade-${gradeClass(s.grade)}" id="legacy-grade-${i}">${h(s.grade || '-')}</span></td>
      </tr>`;
    }).join('');
  };

  window.legacyRecalculateCell = function(input){
    const row = input.getAttribute('data-student-index');
    const key = input.getAttribute('data-component-key');
    const taken = Math.max(0.01, n(input.getAttribute('data-taken'), 100));
    const convertTo = n(input.getAttribute('data-convert'), 0);
    let raw = n(input.value, 0);
    if(raw < 0) raw = 0;
    if(raw > taken) raw = taken;
    const converted = convertTo > 0 ? Math.min(convertTo, (raw / taken) * convertTo) : 0;
    const conv = $id(`legacy-conv-${row}-${key}`);
    if(conv) conv.textContent = fmt(converted);
  };

  function collectLegacyUpdates(){
    const selectedComps = visibleComponents();
    const updates = [];
    students().forEach((student, i) => {
      selectedComps.forEach(c => {
        const input = document.querySelector(`.legacy-mark-input[data-student-index="${i}"][data-component-key="${window.CSS && window.CSS.escape ? window.CSS.escape(String(c.component_key)) : String(c.component_key)}"]`);
        if(!input) return;
        updates.push({
          enrollment_id: student.enrollment_id,
          result_id: student.result_id,
          component_id: c.id,
          component: c.component_key,
          raw_marks: n(input.value, 0),
          is_absent: 0
        });
      });
    });
    return updates;
  }

  window.saveLegacyGradeSheet = function(){
    if(locked()){ toast(lockMsg(), 'warning', 'Locked'); return Promise.resolve(false); }
    const sectionId = currentSectionId();
    if(!sectionId || !window.URAMS_TEACHER_SECTION){ toast('Select trimester, course and section first.', 'warning', 'No Section'); return Promise.resolve(false); }
    const updates = collectLegacyUpdates();
    if(!updates.length){ toast('No marks available to save.', 'warning', 'Nothing to Save'); return Promise.resolve(false); }
    return fetch('save_marks.php', {
      method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'},
      body:JSON.stringify({updates})
    })
    .then(async r => { const text = await r.text(); try { return JSON.parse(text); } catch(e){ throw new Error(text || 'Invalid JSON response'); } })
    .then(data => {
      if(!data.success){ toast(data.message || 'Failed to save grade sheet.', 'error', 'Save Failed'); return false; }
      toast('Full marks sheet saved successfully.', 'success', 'Saved');
      return loadCurrentTeacherSection(false).then(() => { renderLegacyGradeSheet(); return true; });
    })
    .catch(err => { console.error(err); toast(err.message || 'Unable to save grade sheet.', 'error', 'Save Failed'); return false; });
  };

  window.gradeProcessLegacy = function(){
    if(locked()){ toast(lockMsg(), 'warning', 'Locked'); return; }
    const sectionId = currentSectionId();
    if(!sectionId || !window.URAMS_TEACHER_SECTION){ toast('Select a section first.', 'warning', 'No Section'); return; }
    const grace = n($id('legacy-grace-value')?.value, 0);
    saveLegacyGradeSheet().then(ok => {
      if(ok === false) return;
      fetch('grade_process.php', {
        method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'},
        body:JSON.stringify({section_id: sectionId, grace_value: grace})
      })
      .then(async r => { const text = await r.text(); try { return JSON.parse(text); } catch(e){ throw new Error(text || 'Invalid JSON response'); } })
      .then(data => {
        if(!data.success){ toast(data.message || 'Grade process failed.', 'error', 'Failed'); return; }
        toast(data.message || 'Grade process completed.', 'success', 'Grade Process');
        loadCurrentTeacherSection(false).then(renderLegacyGradeSheet);
      })
      .catch(err => { console.error(err); toast(err.message || 'Grade process failed.', 'error', 'Failed'); });
    });
  };

  window.recalculateAttendanceLegacy = function(){
    const sectionId = currentSectionId();
    if(!sectionId || !window.URAMS_TEACHER_SECTION){ toast('Select a section first.', 'warning', 'No Section'); return; }
    fetch('recalculate_section.php', {
      method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'},
      body:JSON.stringify({section_id: sectionId})
    })
    .then(async r => { const text = await r.text(); try { return JSON.parse(text); } catch(e){ throw new Error(text || 'Invalid JSON response'); } })
    .then(data => {
      if(!data.success){ toast(data.message || 'Recalculate failed.', 'error', 'Failed'); return; }
      toast(data.message || 'Attendance/result recalculated.', 'success', 'Recalculated');
      loadCurrentTeacherSection(false).then(renderLegacyGradeSheet);
    })
    .catch(err => { console.error(err); toast(err.message || 'Recalculate failed.', 'error', 'Failed'); });
  };

  window.downloadMarksExcel = function(){
    const sectionId = currentSectionId();
    if(!sectionId || !window.URAMS_TEACHER_SECTION){ toast('Select a section first.', 'warning', 'No Section'); return; }
    window.location.href = `download_marks_excel.php?section_id=${encodeURIComponent(sectionId)}`;
  };

  window.uploadMarksExcel = function(input){
    const file = input.files && input.files[0];
    const sectionId = currentSectionId();
    if(!file){ return; }
    if(!sectionId || !window.URAMS_TEACHER_SECTION){ toast('Select a section first.', 'warning', 'No Section'); input.value = ''; return; }
    if(locked()){ toast(lockMsg(), 'warning', 'Locked'); input.value = ''; return; }
    const form = new FormData();
    form.append('section_id', sectionId);
    form.append('marks_file', file);
    fetch('upload_marks_excel.php', {method:'POST', headers:{'Accept':'application/json'}, body: form})
      .then(async r => { const text = await r.text(); try { return JSON.parse(text); } catch(e){ throw new Error(text || 'Invalid JSON response'); } })
      .then(data => {
        if(!data.success){ toast(data.message || 'Upload failed.', 'error', 'Upload Failed'); return; }
        toast(data.message || 'Excel marks uploaded.', 'success', 'Uploaded');
        loadCurrentTeacherSection(false).then(renderLegacyGradeSheet);
      })
      .catch(err => { console.error(err); toast(err.message || 'Upload failed.', 'error', 'Upload Failed'); })
      .finally(() => { input.value = ''; });
  };

  window.calculateCtAverageLegacy = function(){
    const ctComps = comps().filter(c => c.component_type === 'ct');
    if(!ctComps.length){ toast('No Class Test components found.', 'warning', 'No CT'); return; }
    renderLegacyGradeSheet();
    students().forEach((student, i) => {
      let bestKey = null, best = -Infinity;
      ctComps.forEach(c => { const val = n(markOf(student, c).converted_marks); if(val > best){ best = val; bestKey = c.component_key; } });
      if(bestKey){
        const cell = document.querySelector(`#legacy-grade-table tbody tr:nth-child(${i+1}) td[data-component-key="${window.CSS && window.CSS.escape ? window.CSS.escape(String(bestKey)) : String(bestKey)}"]`);
        if(cell) cell.style.background = 'rgba(16,185,129,.12)';
      }
    });
    toast('Best CT / CT average view calculated and highlighted.', 'success', 'CT Average');
  };

  window.showGradeDetailsLegacy = function(){
    const msg = 'Grade Rules:\nA+ = 90-100\nA = 85-89\nA- = 80-84\nB+ = 75-79\nB = 70-74\nB- = 65-69\nC+ = 60-64\nC = 55-59\nD = 50-54\nF = below 50';
    alert(msg);
  };

  window.showLegacyMarksInstruction = function(){
    alert('Marks Entry Instruction:\n1. Select Trimester, Course and Section, then click Apply.\n2. Enter actual marks in each assessment column.\n3. System converts marks automatically according to each component weight.\n4. Click Save Full Sheet before Grade Process.\n5. Use Download CSV (Excel)/Upload CSV for bulk entry. Keep the downloaded CSV format.');
  };

  const oldRenderComponentSelect = window.renderComponentSelect;
  window.renderComponentSelect = function(){
    if(typeof oldRenderComponentSelect === 'function') oldRenderComponentSelect();
    renderLegacyComponentFilter();
    renderLegacyGradeSheet();
  };

  const oldRenderTeacherEmptySelection = window.renderTeacherEmptySelection;
  window.renderTeacherEmptySelection = function(){
    if(typeof oldRenderTeacherEmptySelection === 'function') oldRenderTeacherEmptySelection();
    renderLegacyGradeSheet();
  };

  const oldLoadSectionData = window.loadSectionData;
  window.loadSectionData = function(sectionId, showMessage=false){
    if(typeof oldLoadSectionData !== 'function') return Promise.resolve(null);
    return oldLoadSectionData(sectionId, showMessage).then(data => { renderLegacyComponentFilter(); renderLegacyGradeSheet(); return data; });
  };

  const oldTeacherNavLegacy = window.teacherNav;
  window.teacherNav = function(view, navEl){
    if(typeof oldTeacherNavLegacy === 'function') oldTeacherNavLegacy(view, navEl);
    if(view === 'marks') setTimeout(() => { renderLegacyComponentFilter(); renderLegacyGradeSheet(); }, 50);
  };

  document.addEventListener('DOMContentLoaded', () => setTimeout(() => { renderLegacyComponentFilter(); renderLegacyGradeSheet(); }, 200));
})();

/* ══════════════════════════════════════════════════════════════════
   TEACHER DASHBOARD CLEANUP — notification + professional cards
   ══════════════════════════════════════════════════════════════════ */
(function(){
  function $id(id){ return document.getElementById(id); }
  function h(v){ return String(v ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c])); }
  function safeSections(){ return Array.isArray(window.URAMS_TEACHER_SECTIONS) ? window.URAMS_TEACHER_SECTIONS : []; }
  function statusText(s){ return String(s || 'running').replace(/_/g,' ').replace(/^./, c => c.toUpperCase()); }
  function totalStudentCount(){ return safeSections().reduce((sum, s) => sum + (parseInt(s.student_count || 0, 10) || 0), 0); }
  function pendingSections(){
    return safeSections().filter(s => !['submitted','approved','published'].includes(String(s.status || '').toLowerCase()));
  }
  function routineRows(){ return safeSections(); }

  function setText(id, value){ const el = $id(id); if(el) el.textContent = value; }

  window.refreshTeacherDashboardCards = function(){
    const sections = safeSections();
    setText('teacher-stat-courses', sections.length);
    setText('teacher-stat-students', totalStudentCount());
    setText('teacher-stat-routine', routineRows().length);
    setText('teacher-stat-status', pendingSections().length);
    const badge = $id('teacher-notif-badge');
    if(badge){
      const count = pendingSections().length;
      badge.textContent = count > 9 ? '9+' : String(count);
      badge.style.display = count > 0 ? 'flex' : 'none';
    }
  };

  function detailTable(headers, rows, empty){
    if(!rows.length){ return `<div style="text-align:center;color:var(--text2);padding:24px">${h(empty || 'No data found.')}</div>`; }
    return `<div class="table-wrap"><table><thead><tr>${headers.map(x=>`<th>${h(x)}</th>`).join('')}</tr></thead><tbody>${rows.join('')}</tbody></table></div>`;
  }

  function openTeacherDetail(title, body){
    const titleEl = $id('teacher-dashboard-detail-title');
    const bodyEl = $id('teacher-dashboard-detail-body');
    if(titleEl) titleEl.textContent = title;
    if(bodyEl) bodyEl.innerHTML = body;
    if(typeof openModal === 'function') openModal('modal-teacher-dashboard-detail');
  }

  function sectionLabel(s){ return `${s.course_name || 'Course'} (${s.course_code || ''})`; }

  window.showTeacherSectionsDetail = function(){
    const rows = safeSections().map(s => `<tr>
      <td style="font-weight:700">${h(sectionLabel(s))}</td>
      <td>${h(s.section_name || '-')}</td>
      <td>${h(s.trimester_name || '-')}</td>
      <td><span class="badge badge-info">${h(parseInt(s.student_count || 0, 10) || 0)} students</span></td>
      <td>${h(statusText(s.status))}</td>
    </tr>`);
    openTeacherDetail('Active Sections with Enrolled Students', detailTable(['Course','Section','Trimester','Enrolled','Status'], rows, 'No assigned section found.'));
  };

  window.showTeacherRoutineDetail = function(){
    const rows = routineRows().map(s => `<tr>
      <td style="font-weight:700">${h(sectionLabel(s))}</td>
      <td>${h(s.section_name || '-')}</td>
      <td>${h(s.trimester_name || '-')}</td>
      <td>${h(s.class_schedule || 'Schedule not set')}</td>
      <td>${h(s.room || 'Room not set')}</td>
    </tr>`);
    openTeacherDetail('Class Routine / Assigned Schedule', detailTable(['Course','Section','Trimester','Schedule','Room'], rows, 'No routine found.'));
  };

  window.showTeacherPendingDetail = function(){
    const rows = pendingSections().map(s => `<tr>
      <td style="font-weight:700">${h(sectionLabel(s))}</td>
      <td>${h(s.section_name || '-')}</td>
      <td>${h(s.trimester_name || '-')}</td>
      <td><span class="badge badge-warning">${h(statusText(s.status))}</span></td>
      <td>${h(parseInt(s.student_count || 0, 10) || 0)} students</td>
    </tr>`);
    openTeacherDetail('Pending Result Work', detailTable(['Course','Section','Trimester','Status','Enrolled'], rows, 'No pending result work.'));
  };

  window.showTeacherStudentsDetail = function(){
    const sections = safeSections();
    if(!sections.length){
      openTeacherDetail('Students with Section', '<div style="text-align:center;color:var(--text2);padding:24px">No assigned section found.</div>');
      return;
    }
    openTeacherDetail('Students with Section', '<div style="text-align:center;color:var(--text2);padding:24px">Loading students...</div>');
    const requests = sections.map(sec => fetch(`get_section_students.php?section_id=${encodeURIComponent(sec.section_id)}`, {headers:{'Accept':'application/json'}})
      .then(async r => { const text = await r.text(); try { return JSON.parse(text); } catch(e){ return {success:false, students:[], message:text}; } })
      .then(data => ({sec, data}))
      .catch(err => ({sec, data:{success:false, students:[], message:err.message}}))
    );
    Promise.all(requests).then(results => {
      const rows = [];
      results.forEach(({sec, data}) => {
        (Array.isArray(data.students) ? data.students : []).forEach(st => {
          rows.push(`<tr>
            <td style="font-weight:700">${h(st.student_id || st.id || '-')}</td>
            <td>${h(st.name || '-')}</td>
            <td>${h(sectionLabel(sec))}</td>
            <td>${h(sec.section_name || '-')}</td>
            <td>${h(sec.trimester_name || '-')}</td>
            <td>${h(statusText(st.result_status || sec.status))}</td>
          </tr>`);
        });
      });
      openTeacherDetail('Students with Section', detailTable(['Student ID','Student Name','Course','Section','Trimester','Result Status'], rows, 'No enrolled student found.'));
      refreshTeacherDashboardCards();
    });
  };

  window.teacherStatNavigate = function(target){
    if(target === 'sections') return showTeacherSectionsDetail();
    if(target === 'students') return showTeacherStudentsDetail();
    if(target === 'routine') return showTeacherRoutineDetail();
    if(target === 'status') return showTeacherPendingDetail();
    if(target === 'marks') return teacherNav('marks', null);
  };

  window.toggleTeacherNotifications = function(){
    const dd = $id('teacher-notif-dropdown');
    if(dd) dd.classList.toggle('open');
  };

  window.markAllTeacherNotifications = function(){
    document.querySelectorAll('#teacher-notif-dropdown .notif-item').forEach(el => el.classList.remove('unread'));
    document.querySelectorAll('#teacher-notif-dropdown .notif-dot').forEach(dot => dot.style.opacity = '0');
    const badge = $id('teacher-notif-badge');
    if(badge) badge.style.display = 'none';
    if(typeof showToast === 'function') showToast('Teacher notifications marked as read.', 'info', 'Notifications');
  };

  document.addEventListener('click', function(){
    const dd = $id('teacher-notif-dropdown');
    if(dd) dd.classList.remove('open');
  });

  const oldPopulate = window.populateTeacherFilters;
  window.populateTeacherFilters = function(){
    if(typeof oldPopulate === 'function') oldPopulate();
    refreshTeacherDashboardCards();
  };

  const oldEmpty = window.renderTeacherEmptySelection;
  window.renderTeacherEmptySelection = function(){
    if(typeof oldEmpty === 'function') oldEmpty();
    refreshTeacherDashboardCards();
  };

  const oldMeta = window.renderTeacherSectionMeta;
  window.renderTeacherSectionMeta = function(){
    if(typeof oldMeta === 'function') oldMeta();
    refreshTeacherDashboardCards();
  };

  const oldInit = window.initTeacherDashboard;
  window.initTeacherDashboard = function(){
    if(typeof oldInit === 'function') oldInit();
    refreshTeacherDashboardCards();
  };

  document.addEventListener('DOMContentLoaded', () => setTimeout(refreshTeacherDashboardCards, 250));
})();


/* ══════════════════════════════════════════════════════════════════
   TEACHER DASHBOARD FINAL POLISH — clickable bell + teacher routine
   ══════════════════════════════════════════════════════════════════ */
(function(){
  function $id(id){ return document.getElementById(id); }
  function esc(v){ return String(v ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c])); }
  function sections(){ return Array.isArray(window.URAMS_TEACHER_SECTIONS) ? window.URAMS_TEACHER_SECTIONS : []; }
  function cleanStatus(s){ return String(s || 'running').replace(/_/g,' ').replace(/^./, c => c.toUpperCase()); }
  function pendingSections(){ return sections().filter(s => !['submitted','approved','published'].includes(String(s.status || 'running').toLowerCase())); }
  function totalStudents(){ return sections().reduce((sum, s) => sum + (parseInt(s.student_count || s.enrolled_students || 0, 10) || 0), 0); }
  function uniqueTrimesters(){
    const map = new Map();
    sections().forEach(s => {
      const key = s.trimester_name || 'Unknown Trimester';
      if(!map.has(key)) map.set(key, {id:s.trimester_id || key, name:key});
    });
    return [...map.values()];
  }
  function parseSchedule(schedule){
    const text = String(schedule || '').trim();
    if(!text) return [{day:'---', time:'Schedule not set'}];
    return text.split(/[;,]+/).map(x => x.trim()).filter(Boolean).map(part => {
      const m = part.match(/^([A-Za-z]{2,9})\s+(.+)$/);
      return m ? {day:m[1], time:m[2]} : {day:'---', time:part};
    });
  }
  function sectionLabel(s){ return `${s.course_name || 'Course'} (${s.course_code || ''})`; }

  function notifyItems(){
    const p = pendingSections();
    const todayRoutine = sections().filter(s => String(s.class_schedule || '').trim()).length;
    const items = [];
    if(p.length){
      items.push({text:`${p.length} section result still needs marks/review before submit.`, time:'Pending'});
    }else{
      items.push({text:'All assigned section results are currently clear. No pending result warning.', time:'Done'});
    }
    if(todayRoutine){
      items.push({text:`${todayRoutine} class routine entry available. Click Class Routine card to view trimester-wise schedule.`, time:'Routine'});
    }else{
      items.push({text:'No room/schedule is set yet. Admin can set Room and Class Schedule while creating a section.', time:'Routine'});
    }
    items.push({text:`You have ${sections().length} active section(s) and ${totalStudents()} enrolled student(s).`, time:'Summary'});
    return items;
  }

  window.refreshTeacherDashboardCards = function(){
    const sec = sections();
    const pending = pendingSections();
    const setText = (id, value) => { const el = $id(id); if(el) el.textContent = value; };
    setText('teacher-stat-courses', sec.length);
    setText('teacher-stat-students', totalStudents());
    setText('teacher-stat-routine', sec.length);
    setText('teacher-stat-status', pending.length);
    const badge = $id('teacher-notif-badge');
    if(badge){
      const count = notifyItems().filter(Boolean).length;
      badge.textContent = count > 9 ? '9+' : String(count);
      badge.style.display = count > 0 ? 'flex' : 'none';
    }
    renderTeacherNotificationList();
  };

  window.renderTeacherNotificationList = function(){
    const list = $id('teacher-notif-list');
    if(!list) return;
    list.innerHTML = notifyItems().map(item => `
      <div class="notif-item unread" onclick="markNotifRead(this)">
        <span class="notif-dot"></span>
        <div class="notif-text">${esc(item.text)}</div>
        <div class="notif-time">${esc(item.time)}</div>
      </div>
    `).join('');
  };

  window.toggleTeacherNotifications = function(ev){
    if(ev && ev.stopPropagation) ev.stopPropagation();
    renderTeacherNotificationList();
    const dd = $id('teacher-notif-dropdown');
    if(!dd) return;
    dd.classList.toggle('open');
  };

  window.markAllTeacherNotifications = function(){
    document.querySelectorAll('#teacher-notif-dropdown .notif-item').forEach(el => el.classList.remove('unread'));
    document.querySelectorAll('#teacher-notif-dropdown .notif-dot').forEach(dot => dot.style.opacity = '0');
    const badge = $id('teacher-notif-badge');
    if(badge) badge.style.display = 'none';
    if(typeof showToast === 'function') showToast('Notifications marked as read.', 'info', 'Notifications');
  };

  // Keep global function robust for the teacher dropdown.
  window.markNotifRead = function(el){
    if(!el) return;
    el.classList.remove('unread');
    const dot = el.querySelector('.notif-dot');
    if(dot) dot.style.opacity = '0';
  };

  function routineOptions(selected){
    const tr = uniqueTrimesters();
    return '<option value="">Select trimester</option>' + tr.map(t => `<option value="${esc(t.name)}" ${t.name===selected?'selected':''}>${esc(t.name)}</option>`).join('');
  }
  function routineTable(trimester){
    let filtered = sections();
    if(trimester) filtered = filtered.filter(s => String(s.trimester_name || '') === String(trimester));
    const rows = [];
    filtered.forEach(s => {
      parseSchedule(s.class_schedule).forEach(slot => {
        rows.push(`<tr>
          <td>${esc(s.course_code || '')}</td>
          <td class="td-name">${esc(s.course_name || '')}</td>
          <td>${esc(slot.day || '---')}</td>
          <td>${esc(s.room || 'Room not set')}</td>
          <td>${esc(slot.time || 'Schedule not set')}</td>
          <td>${esc(s.section_name || '')}</td>
          <td>${esc(parseInt(s.student_count || 0,10) || 0)}</td>
        </tr>`);
      });
    });
    if(!rows.length){
      return '<div style="text-align:center;color:var(--text2);padding:24px">No class routine found for this trimester.</div>';
    }
    return `<div class="table-wrap"><table class="teacher-routine-table"><thead><tr><th>Course Code</th><th>Course Title</th><th>Day</th><th>Room</th><th>Time Slot</th><th>Section</th><th>Students</th></tr></thead><tbody>${rows.join('')}</tbody></table></div>`;
  }
  window.renderTeacherRoutineTable = function(){
    const tri = $id('teacher-routine-trimester')?.value || '';
    const out = $id('teacher-routine-output');
    if(out) out.innerHTML = routineTable(tri);
  };

  window.showTeacherRoutineDetail = function(){
    const defaultTri = uniqueTrimesters()[0]?.name || '';
    const body = `
      <div class="teacher-routine-title">Teacher Class Routine</div>
      <div class="teacher-routine-note">Select a trimester to view only your assigned classes, rooms, times and sections.</div>
      <div class="teacher-routine-filter">
        <div class="form-group" style="margin:0"><label class="form-label">Teacher</label><input class="form-control" value="Current Logged-in Teacher" disabled></div>
        <div class="form-group" style="margin:0"><label class="form-label">Trimester</label><select id="teacher-routine-trimester" class="form-control">${routineOptions(defaultTri)}</select></div>
        <button class="btn btn-primary" onclick="renderTeacherRoutineTable()"><i class="fas fa-eye"></i> View Class Routine</button>
      </div>
      <div id="teacher-routine-output">${routineTable(defaultTri)}</div>
    `;
    const titleEl = $id('teacher-dashboard-detail-title');
    const bodyEl = $id('teacher-dashboard-detail-body');
    if(titleEl) titleEl.textContent = 'Class Routine';
    if(bodyEl) bodyEl.innerHTML = body;
    if(typeof openModal === 'function') openModal('modal-teacher-dashboard-detail');
  };

  document.addEventListener('click', function(e){
    const dd = $id('teacher-notif-dropdown');
    const btn = $id('teacher-notif-button');
    if(dd && !dd.contains(e.target) && btn && !btn.contains(e.target)) dd.classList.remove('open');
  });

  document.addEventListener('DOMContentLoaded', () => setTimeout(window.refreshTeacherDashboardCards, 250));
})();

/* ══════════════════════════════════════════════════════════════════
   FINAL OVERRIDE — Legacy Attendance Entry UI in current project file
   Course With Section + Load Students + Get Emails + Find in Page
   ══════════════════════════════════════════════════════════════════ */
(function(){
  'use strict';
  const $ = (id) => document.getElementById(id);
  const h = (v) => String(v ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
  const n = (v, d=0) => { const x = parseFloat(v); return Number.isFinite(x) ? x : d; };
  const sections = () => Array.isArray(window.URAMS_TEACHER_SECTIONS) ? window.URAMS_TEACHER_SECTIONS : [];
  const students = () => Array.isArray(window.STUDENTS) ? window.STUDENTS : [];
  const components = () => Array.isArray(window.TEACHER_COMPONENTS) ? window.TEACHER_COMPONENTS : [];
  const initials = (name) => String(name || '').split(/\s+/).filter(Boolean).map(x => x[0]).join('').slice(0,2).toUpperCase() || 'ST';
  const currentSection = () => window.URAMS_TEACHER_SECTION || {};

  function attendanceComponent(){
    return components().find(c => {
      const key = String(c.component_key || '').toLowerCase();
      const type = String(c.component_type || '').toLowerCase();
      const name = String(c.component_name || '').toLowerCase();
      return type === 'attendance' || key === 'attendance' || key === 'attendance_marks' || name.includes('attendance');
    }) || null;
  }
  function attendanceComponentForUi(){
    return attendanceComponent() || {
      id: null,
      component_key: 'attendance',
      component_name: 'Attendance',
      component_type: 'attendance',
      taken_out_of: 10,
      convert_to: 10
    };
  }

  function componentMark(student, comp){
    if(!student || !comp) return {raw_marks:0, converted_marks:0, is_absent:0, remarks:''};
    if(typeof window.getComponentMark === 'function') return window.getComponentMark(student, comp) || {raw_marks:0, converted_marks:0, is_absent:0, remarks:''};
    return (student.component_marks && student.component_marks[comp.component_key]) || {raw_marks:0, converted_marks:0, is_absent:0, remarks:''};
  }

  function isLocked(){
    if(typeof window.isTeacherResultLocked === 'function') return window.isTeacherResultLocked();
    const status = String(currentSection().status || '').toLowerCase();
    return status === 'submitted' || status === 'approved';
  }

  function lockedMessage(){
    if(typeof window.teacherLockMessage === 'function') return window.teacherLockMessage();
    return 'This section is submitted/approved and cannot be edited.';
  }

  function selectedAttendanceSectionId(){
    const sel = $('attendance-section-select');
    const val = parseInt(sel?.value || '0', 10);
    return Number.isFinite(val) && val > 0 ? val : 0;
  }

  function sectionLabel(sec){
    return `${sec.section_name || sec.section || ''} - ${sec.course_code || ''} - ${sec.course_name || sec.course_title || ''}`.replace(/\s+/g,' ').trim();
  }

  window.renderAttendanceSectionDropdown = function(){
    const sel = $('attendance-section-select');
    if(!sel) return;
    const previous = sel.value || (window.URAMS_ACTIVE_SECTION_ID ? String(window.URAMS_ACTIVE_SECTION_ID) : '');
    const rows = sections();
    sel.innerHTML = '<option value="">Select Course & Section</option>' + rows.map(sec => {
      const id = String(sec.section_id || sec.id || '');
      const selected = id && id === String(previous) ? ' selected' : '';
      return `<option value="${h(id)}"${selected}>${h(sectionLabel(sec))}</option>`;
    }).join('');
  };

  function attendanceStatus(student, comp){
    const mark = componentMark(student, comp);
    if(parseInt(mark.is_absent || 0, 10) === 1) return 'absent';
    if(n(mark.converted_marks, 0) > 0 || n(mark.raw_marks, 0) > 0) return 'present';
    return 'notset';
  }

  function absentCount(student, comp){
    return attendanceStatus(student, comp) === 'absent' ? 1 : 0;
  }

  function rowPhoto(student){
    const photo = student.photo || student.profile_photo || student.photo_path || '';
    if(photo) return `<span class="att-photo"><img src="${h(photo)}" alt="photo"></span>`;
    return `<span class="att-photo">${h(initials(student.name))}</span>`;
  }

  function radioGroup(rowIndex, status){
    const name = `att-status-${rowIndex}`;
    const checked = (x) => status === x ? ' checked' : '';
    return `<div class="att-radio-group">
      <label class="att-radio-option"><input type="radio" name="${name}" value="present"${checked('present')}> Present</label>
      <label class="att-radio-option"><input type="radio" name="${name}" value="absent"${checked('absent')}> Absent</label>
      <label class="att-radio-option"><input type="radio" name="${name}" value="notset"${checked('notset')}> Not Set</label>
    </div>`;
  }

  window.renderAttendanceLegacyTable = function(){
    const tbody = $('att-tbody');
    const subtitle = $('attendance-page-subtitle');
    const tableSub = $('attendance-table-subtitle');
    const tableTitle = $('attendance-table-title');
    if(!tbody) return;
    renderAttendanceSectionDropdown();

    const sec = currentSection();
    const comp = attendanceComponentForUi();
    const courseCode = sec.course_code || '';
    const courseName = sec.course_name || sec.course_title || 'Course';
    const secName = sec.section || sec.section_name || '';
    const trim = sec.trimester || sec.trimester_name || '';

    if(subtitle) subtitle.textContent = sec.section_id ? `${courseName} (${courseCode}) · Section ${secName} · ${trim}` : 'Select a course with section, load students, then save attendance.';
    if(tableTitle) tableTitle.textContent = sec.section_id ? `${courseName} (${courseCode}) — Section ${secName}` : 'Student Attendance List';
    if(tableSub) tableSub.textContent = sec.section_id ? `${students().length} students loaded · Class type: ${$('attendance-class-type')?.value || 'Regular'}` : 'No section loaded.';

    if(!sec.section_id){
      tbody.innerHTML = '<tr><td colspan="8" class="att-empty-state">Select Course With Section and click Load Students.</td></tr>';
      return;
    }
    // Even if an old section has no Attendance row yet, keep the table visible.
    // Backend will auto-create the Attendance component during load/save.
    if(!students().length){
      tbody.innerHTML = '<tr><td colspan="8" class="att-empty-state">No students found for this section.</td></tr>';
      return;
    }

    tbody.innerHTML = students().map((s, i) => {
      const status = attendanceStatus(s, comp);
      const mark = componentMark(s, comp);
      const comment = String(mark.remarks || '').replace(/^Class Type:.*?;\s*/i, '');
      return `<tr data-att-row="${i}" data-search="${h(`${s.student_id || s.id || ''} ${s.name || ''} ${courseCode} ${courseName}`.toLowerCase())}">
        <td>${i + 1}</td>
        <td>${rowPhoto(s)}</td>
        <td class="td-id">${h(s.student_id || s.id || '')}</td>
        <td class="td-name">${h(s.name || '')}</td>
        <td>${h(courseCode)}</td>
        <td id="att-absent-count-${i}" style="font-weight:800">${absentCount(s, comp)}</td>
        <td class="att-status-cell">${radioGroup(i, status)}</td>
        <td><input type="text" class="att-comment-input" id="att-comment-${i}" value="${h(comment)}" placeholder="Comment"></td>
      </tr>`;
    }).join('');

    filterAttendanceRows();
  };

  window.initAttendanceTable = function(){
    renderAttendanceSectionDropdown();
    const dateEl = $('attendance-class-date');
    if(dateEl && !dateEl.value){
      const d = new Date();
      dateEl.value = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
    }
    renderAttendanceLegacyTable();
  };

  window.loadAttendanceStudentsLegacy = function(){
    const id = selectedAttendanceSectionId();
    if(!id){
      if(typeof showToast === 'function') showToast('Please select Course With Section first.', 'warning', 'No Section');
      renderAttendanceLegacyTable();
      return Promise.resolve(null);
    }
    window.URAMS_ACTIVE_SECTION_ID = id;
    const dashSec = $('filter-section');
    const dashCourse = $('filter-course');
    const dashTri = $('filter-trimester');
    [dashSec, dashCourse, dashTri].forEach(el => { if(el) el.value = String(id); });

    if(typeof window.loadSectionData === 'function'){
      return window.loadSectionData(id, false).then(data => {
        // Ensure globals are synced even if loadSectionData implementation changes.
        if (data && data.success) {
          window.URAMS_TEACHER_SECTION = data.section || window.URAMS_TEACHER_SECTION || null;
          window.URAMS_TEACHER_STUDENTS = Array.isArray(data.students) ? data.students : (window.URAMS_TEACHER_STUDENTS || []);
          window.URAMS_TEACHER_COMPONENTS = Array.isArray(data.components) ? data.components : (window.URAMS_TEACHER_COMPONENTS || []);
          window.STUDENTS = window.URAMS_TEACHER_STUDENTS;
          window.TEACHER_COMPONENTS = window.URAMS_TEACHER_COMPONENTS;
        }
        renderAttendanceSectionDropdown();
        const sel = $('attendance-section-select');
        if(sel) sel.value = String(id);
        renderAttendanceLegacyTable();
        if(data && typeof showToast === 'function') showToast(`${students().length} student(s) loaded for attendance.`, students().length ? 'success' : 'warning', 'Loaded');
        return data;
      });
    }
    return fetch(`get_section_students.php?section_id=${encodeURIComponent(id)}`, {headers:{'Accept':'application/json'}})
      .then(r => r.json())
      .then(data => {
        if(!data.success) throw new Error(data.message || 'Failed to load students.');
        window.URAMS_TEACHER_SECTION = data.section || null;
        window.URAMS_TEACHER_STUDENTS = data.students || [];
        window.URAMS_TEACHER_COMPONENTS = data.components || [];
        window.STUDENTS = data.students || [];
        window.TEACHER_COMPONENTS = data.components || [];
        renderAttendanceLegacyTable();
        return data;
      })
      .catch(err => { console.error(err); if(typeof showToast === 'function') showToast(err.message || 'Could not load students.', 'error', 'Error'); return null; });
  };

  window.setAttendanceAll = function(status){
    if(!students().length){
      if(typeof showToast === 'function') showToast('Load students first.', 'warning', 'No Students');
      return;
    }
    document.querySelectorAll('#att-tbody input[type="radio"]').forEach(r => { if(r.value === status) r.checked = true; });
    document.querySelectorAll('#att-tbody tr[data-att-row]').forEach(tr => {
      const i = tr.getAttribute('data-att-row');
      const cell = $(`att-absent-count-${i}`);
      if(cell) cell.textContent = status === 'absent' ? '1' : '0';
    });
  };

  document.addEventListener('change', function(e){
    const radio = e.target.closest('#att-tbody input[type="radio"]');
    if(!radio) return;
    const row = radio.closest('tr[data-att-row]');
    if(!row) return;
    const i = row.getAttribute('data-att-row');
    const cell = $(`att-absent-count-${i}`);
    if(cell) cell.textContent = radio.value === 'absent' ? '1' : '0';
  });

  window.filterAttendanceRows = function(){
    const q = String($('attendance-search')?.value || '').trim().toLowerCase();
    let matches = 0;
    document.querySelectorAll('#att-tbody tr[data-att-row]').forEach(tr => {
      const hit = !q || String(tr.getAttribute('data-search') || tr.textContent || '').toLowerCase().includes(q);
      tr.style.display = hit ? '' : 'none';
      if(hit) matches++;
    });
    const sub = $('attendance-table-subtitle');
    if(sub && students().length){
      const sec = currentSection();
      sub.textContent = q ? `${matches} match(es) found · ${sec.trimester || ''}` : `${students().length} students loaded · Class type: ${$('attendance-class-type')?.value || 'Regular'}`;
    }
  };

  window.getAttendanceEmails = function(){
    const showEmails = () => {
      const emails = students().map(s => String(s.email || '').trim()).filter(Boolean);
      const box = $('attendance-email-box');
      const area = $('attendance-email-list');
      if(box) box.style.display = 'block';
      if(area) area.value = emails.join(', ');
      if(typeof showToast === 'function') showToast(emails.length ? `${emails.length} email address(es) found.` : 'No student emails found.', emails.length ? 'success' : 'warning', 'Email List');
    };
    if(!students().length && selectedAttendanceSectionId()){
      loadAttendanceStudentsLegacy().then(showEmails);
    }else{
      showEmails();
    }
  };

  window.copyAttendanceEmails = function(){
    const area = $('attendance-email-list');
    const text = area?.value || '';
    if(!text){ if(typeof showToast === 'function') showToast('No emails to copy.', 'warning', 'Empty'); return; }
    if(navigator.clipboard && navigator.clipboard.writeText){
      navigator.clipboard.writeText(text).then(() => { if(typeof showToast === 'function') showToast('Emails copied to clipboard.', 'success', 'Copied'); });
    }else{
      area.select(); document.execCommand('copy');
      if(typeof showToast === 'function') showToast('Emails copied to clipboard.', 'success', 'Copied');
    }
  };


  function attendanceReportParams(){
    const id = selectedAttendanceSectionId() || parseInt(currentSection().section_id || '0', 10) || 0;
    if(!id){
      if(typeof showToast === 'function') showToast('Please select Course With Section first.', 'warning', 'No Section');
      return null;
    }
    const classType = $('attendance-class-type')?.value || 'Regular';
    const classDate = $('attendance-class-date')?.value || '';
    return `section_id=${encodeURIComponent(id)}&class_type=${encodeURIComponent(classType)}&class_date=${encodeURIComponent(classDate)}`;
  }

  window.downloadAttendanceExcel = function(){
    const params = attendanceReportParams();
    if(!params) return;
    window.location.href = `download_attendance_excel.php?${params}`;
  };

  window.openAttendanceDetailsReport = function(){
    const params = attendanceReportParams();
    if(!params) return;
    window.open(`attendance_details_report.php?${params}`, '_blank', 'noopener');
  };

  window.saveAttendance = function(){
    if(isLocked()){
      if(typeof showToast === 'function') showToast(lockedMessage(), 'warning', 'Locked');
      return;
    }
    const comp = attendanceComponentForUi();
    if(!students().length){ if(typeof showToast === 'function') showToast('Load students first.', 'warning', 'No Students'); return; }

    const classType = $('attendance-class-type')?.value || 'Regular';
    const classDate = $('attendance-class-date')?.value || '';
    const taken = Math.max(0.01, n(comp.taken_out_of, comp.convert_to || 5));
    const updates = [];

    students().forEach((s, i) => {
      const selected = document.querySelector(`#att-tbody input[name="att-status-${i}"]:checked`);
      const status = selected ? selected.value : 'notset';
      if(status === 'notset') return;
      const comment = String($(`att-comment-${i}`)?.value || '').trim();
      const remarks = `Class Type: ${classType}; Date: ${classDate || 'N/A'}; Status: ${status === 'present' ? 'Present' : 'Absent'}${comment ? '; Comment: ' + comment : ''}`;
      const rowUpdate = {
        enrollment_id: s.enrollment_id,
        result_id: s.result_id,
        component: comp.component_key || 'attendance',
        raw_marks: status === 'present' ? taken : 0,
        is_absent: status === 'absent' ? 1 : 0,
        remarks
      };
      if (comp.id) rowUpdate.component_id = comp.id;
      updates.push(rowUpdate);
    });

    if(!updates.length){
      if(typeof showToast === 'function') showToast('No Present/Absent rows selected. Not Set rows are skipped.', 'warning', 'Nothing to Save');
      return;
    }

    fetch('save_marks.php', {
      method:'POST',
      headers:{'Content-Type':'application/json','Accept':'application/json'},
      body:JSON.stringify({component_id: comp.id || null, component: comp.component_key || 'attendance', updates})
    })
    .then(r => r.json())
    .then(data => {
      if(!data.success){
        if(typeof showToast === 'function') showToast(data.message || 'Failed to save attendance.', 'error', 'Failed');
        return null;
      }
      if(typeof showToast === 'function') showToast('Attendance saved successfully.', 'success', 'Saved');
      if(typeof window.loadSectionData === 'function') return window.loadSectionData(currentSection().section_id || selectedAttendanceSectionId(), false);
      return null;
    })
    .then(() => renderAttendanceLegacyTable())
    .catch(err => { console.error(err); if(typeof showToast === 'function') showToast('Unable to save attendance.', 'error', 'Save Failed'); });
  };

  const previousTeacherNav = window.teacherNav;
  window.teacherNav = function(view, navEl){
    if(typeof previousTeacherNav === 'function') previousTeacherNav(view, navEl);
    if(view === 'attendance') setTimeout(initAttendanceTable, 50);
  };

  document.addEventListener('DOMContentLoaded', () => setTimeout(() => {
    renderAttendanceSectionDropdown();
    if($('view-attendance') && $('view-attendance').style.display !== 'none') initAttendanceTable();
  }, 300));
})();

/* ══════════════════════════════════════════════════════════════════
   FINAL MARKS ENTRY FIX — section loader + old style full sheet + backend hooks
   ══════════════════════════════════════════════════════════════════ */
(function(){
  function $(id){ return document.getElementById(id); }
  function esc(v){ return String(v ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c])); }
  function num(v, fallback=0){ const x = parseFloat(v); return Number.isFinite(x) ? x : fallback; }
  function fmt(v){ return num(v).toFixed(2); }
  function toast(msg, type='info', title='URAMS'){ if(typeof showToast === 'function') showToast(msg, type, title); else alert((title ? title + ': ' : '') + msg); }
  function sections(){ return Array.isArray(window.URAMS_TEACHER_SECTIONS) ? window.URAMS_TEACHER_SECTIONS : []; }
  function students(){ return Array.isArray(STUDENTS) ? STUDENTS : (Array.isArray(window.URAMS_TEACHER_STUDENTS) ? window.URAMS_TEACHER_STUDENTS : []); }
  function comps(){ return Array.isArray(TEACHER_COMPONENTS) ? TEACHER_COMPONENTS : (Array.isArray(window.URAMS_TEACHER_COMPONENTS) ? window.URAMS_TEACHER_COMPONENTS : []); }
  function currentSec(){ return window.URAMS_TEACHER_SECTION || null; }
  function isLocked(){
    if(typeof isTeacherResultLocked === 'function') return isTeacherResultLocked();
    const status = String(currentSec()?.status || '').toLowerCase();
    return status === 'submitted' || status === 'approved';
  }
  function lockMessage(){ return (typeof teacherLockMessage === 'function') ? teacherLockMessage() : 'Submitted/approved result cannot be edited.'; }
  function sectionLabel(s){ return `${s.section_name || s.section || ''} - ${s.course_code || ''} - ${s.course_name || s.course_title || ''}${s.trimester_name ? ' - ' + s.trimester_name : ''}`.replace(/\s+/g,' ').trim(); }
  function activeId(){ return (typeof getCurrentSectionId === 'function') ? getCurrentSectionId() : parseInt(window.URAMS_ACTIVE_SECTION_ID || 0, 10) || 0; }
  function componentMark(student, comp){
    if(!student || !comp) return {raw_marks:0, converted_marks:0, is_absent:0};
    if(typeof getComponentMark === 'function') return getComponentMark(student, comp) || {raw_marks:0, converted_marks:0, is_absent:0};
    return (student.component_marks && student.component_marks[comp.component_key]) || {raw_marks:0, converted_marks:0, is_absent:0};
  }
  function gradeClass(grade){ return String(grade || 'F').replace('+','-plus').replace('-','-minus'); }
  function getGradeByTotal(total){
    const t = num(total,0);
    for(const r of GRADE_RULES){ if(t >= r.min && t <= r.max) return r.grade; }
    return 'F';
  }
  function syncDashboardSelects(id){
    ['filter-trimester','filter-course','filter-section'].forEach(elId => { const el = $(elId); if(el) el.value = String(id); });
  }
  function selectedMarksSectionId(){
    const val = parseInt($('marks-section-select')?.value || '0', 10);
    return Number.isFinite(val) && val > 0 ? val : activeId();
  }
  function setMarksStatus(text){ const el = $('marks-loader-status'); if(el) el.textContent = text; }

  window.renderMarksSectionDropdown = function(){
    const sel = $('marks-section-select');
    if(!sel) return;
    const previous = sel.value || (window.URAMS_ACTIVE_SECTION_ID ? String(window.URAMS_ACTIVE_SECTION_ID) : '');
    sel.innerHTML = '<option value="">Select Course & Section</option>' + sections().map(sec => {
      const id = String(sec.section_id || sec.id || '');
      const selected = id && id === String(previous) ? ' selected' : '';
      return `<option value="${esc(id)}"${selected}>${esc(sectionLabel(sec))}</option>`;
    }).join('');
    const sec = currentSec();
    if(sec && sec.section_id){
      setMarksStatus(`${students().length} student(s) loaded · ${sec.course_code || ''} Section ${sec.section || sec.section_name || ''}`);
    }else{
      setMarksStatus('No section loaded.');
    }
  };

  window.loadMarksStudentsLegacy = function(){
    const id = selectedMarksSectionId();
    if(!id){
      toast('Please select Course With Section first.', 'warning', 'No Section');
      renderLegacyGradeSheet();
      return Promise.resolve(null);
    }
    window.URAMS_ACTIVE_SECTION_ID = id;
    syncDashboardSelects(id);
    setMarksStatus('Loading students and assessment components...');
    const afterLoad = (data) => {
      if(data && data.success){
        if(typeof syncTeacherGlobals === 'function') syncTeacherGlobals(data.students || [], data.components || [], data.section || null);
        else{
          STUDENTS = Array.isArray(data.students) ? data.students : [];
          TEACHER_COMPONENTS = Array.isArray(data.components) ? data.components : [];
          window.URAMS_TEACHER_STUDENTS = STUDENTS;
          window.URAMS_TEACHER_COMPONENTS = TEACHER_COMPONENTS;
          window.URAMS_TEACHER_SECTION = data.section || null;
        }
      }
      window.renderMarksSectionDropdown();
      window.renderLegacyComponentFilter();
      if(typeof renderComponentSelect === 'function') renderComponentSelect();
      window.renderLegacyGradeSheet();
      const count = students().length;
      setMarksStatus(`${count} student(s) loaded.`);
      toast(`${count} student(s) loaded for marks entry.`, count ? 'success' : 'warning', 'Loaded');
      return data;
    };
    if(typeof loadSectionData === 'function'){
      return loadSectionData(id, false).then(afterLoad).catch(err => { console.error(err); setMarksStatus('Could not load section.'); toast(err.message || 'Could not load marks section.', 'error', 'Error'); return null; });
    }
    return fetch(`get_section_students.php?section_id=${encodeURIComponent(id)}`, {headers:{'Accept':'application/json'}})
      .then(async r => { const text = await r.text(); try { return JSON.parse(text); } catch(e){ throw new Error(text || 'Invalid JSON response'); } })
      .then(data => { if(!data.success) throw new Error(data.message || 'Failed to load marks section.'); return afterLoad(data); })
      .catch(err => { console.error(err); setMarksStatus('Could not load section.'); toast(err.message || 'Could not load marks section.', 'error', 'Error'); return null; });
  };

  window.renderLegacyComponentFilter = function(){
    const sel = $('legacy-assessment-filter');
    if(!sel) return;
    const previous = sel.value || '';
    const list = comps();
    sel.innerHTML = '<option value="">All Assessment</option>' + list.map(c => `<option value="${esc(c.component_key)}">${esc(c.component_name)}</option>`).join('');
    if(previous && list.some(c => String(c.component_key) === String(previous))) sel.value = previous;
  };

  function visibleComponents(){
    const selected = $('legacy-assessment-filter')?.value || '';
    const list = comps().filter(c => String(c.component_key || '').toLowerCase() !== 'grace' || num(c.convert_to,0) > 0);
    return selected ? list.filter(c => String(c.component_key) === String(selected)) : list;
  }
  function groupFor(c){
    const type = String(c.component_type || 'custom').toLowerCase();
    if(type === 'ct') return {key:'ct', label:'Class Tests', best:true};
    if(type === 'assignment') return {key:'assignment', label:'Assignment', best:true};
    if(type === 'mid') return {key:'mid', label:'Mid-term Exam', best:true};
    if(type === 'final') return {key:'final', label:'Final Exam', best:true};
    if(type === 'attendance') return {key:'attendance', label:'Attendance', best:true};
    return {key:String(c.component_key || c.id), label:c.component_name || 'Assessment', best:false};
  }
  function buildGroups(list){
    const map = new Map();
    list.forEach(c => {
      const g = groupFor(c);
      if(!map.has(g.key)) map.set(g.key, {key:g.key, label:g.label, best:g.best, items:[]});
      map.get(g.key).items.push(c);
    });
    return [...map.values()];
  }
  function groupCap(g){
    if(g.best) return g.items.reduce((m,c)=>Math.max(m, num(c.convert_to,0)), 0);
    return g.items.reduce((s,c)=>s+num(c.convert_to,0), 0);
  }

  window.renderLegacyGradeSheet = function(){
    window.renderMarksSectionDropdown();
    window.renderLegacyComponentFilter();
    const thead = $('legacy-grade-thead');
    const tbody = $('legacy-grade-tbody');
    if(!thead || !tbody) return;
    const sec = currentSec();
    const emptyHead = '<tr><th>SL</th><th>Student ID</th><th>Student Name</th><th>Status</th><th>Total</th><th>Grade</th></tr>';
    if(!sec || !sec.section_id){
      thead.innerHTML = emptyHead;
      tbody.innerHTML = '<tr><td colspan="6" style="padding:24px;text-align:center;color:var(--text2)">Select Course With Section, then click Load Students.</td></tr>';
      return;
    }
    const list = visibleComponents();
    if(!students().length){
      thead.innerHTML = emptyHead;
      tbody.innerHTML = '<tr><td colspan="6" style="padding:24px;text-align:center;color:var(--text2)">No students found for this section.</td></tr>';
      return;
    }
    if(!list.length){
      thead.innerHTML = emptyHead;
      tbody.innerHTML = '<tr><td colspan="6" style="padding:24px;text-align:center;color:var(--text2)">No assessment component found for this section.</td></tr>';
      return;
    }
    const groups = buildGroups(list);
    const groupRow = '<tr>' +
      '<th rowspan="2">SL</th><th rowspan="2">Student ID</th><th rowspan="2">Student Name</th><th rowspan="2">Status</th>' +
      groups.map(g => `<th class="legacy-group-head" colspan="${g.items.length}">${esc(g.label)}<span class="legacy-mini-note">${fmt(groupCap(g))}</span></th>`).join('') +
      '<th rowspan="2">Total<br>100.00</th><th rowspan="2">Grade</th></tr>';
    const compRow = '<tr>' + groups.map(g => g.items.map(c => `<th>${esc(c.component_name)}<span class="legacy-mini-note">${fmt(c.convert_to)}</span></th>`).join('')).join('') + '</tr>';
    thead.innerHTML = groupRow + compRow;
    const disabled = isLocked() ? 'disabled title="Locked"' : '';
    tbody.innerHTML = students().map((s,i) => {
      const cells = list.map(c => {
        const mark = componentMark(s,c);
        const raw = num(mark.raw_marks,0);
        const conv = num(mark.converted_marks,0);
        const maxRaw = Math.max(0.01, num(c.taken_out_of, 100));
        return `<td data-component-key="${esc(c.component_key)}" data-component-type="${esc(c.component_type)}">
          <input class="legacy-mark-input" type="number" min="0" max="${esc(maxRaw)}" step="0.01" value="${raw.toFixed(2)}" ${disabled}
            data-student-index="${i}" data-component-id="${esc(c.id)}" data-component-key="${esc(c.component_key)}" data-component-type="${esc(c.component_type)}" data-taken="${esc(maxRaw)}" data-convert="${esc(c.convert_to)}"
            oninput="legacyRecalculateCell(this)">
          <span class="legacy-converted" id="legacy-conv-${i}-${esc(c.component_key)}">${fmt(conv)}</span>
        </td>`;
      }).join('');
      return `<tr data-student-index="${i}" data-search="${esc(`${s.student_id || s.id || ''} ${s.name || ''}`.toLowerCase())}">
        <td>${i+1}</td>
        <td class="td-id">${esc(s.student_id || s.id || '')}</td>
        <td class="legacy-student-name">${esc(s.name || '')}</td>
        <td>${typeof statusBadge === 'function' ? statusBadge(s.result_status || sec.status) : esc(s.result_status || sec.status || '')}</td>
        ${cells}
        <td style="font-weight:900" id="legacy-total-${i}">${fmt(Math.min(100, num(s.total_marks)))}</td>
        <td><span class="grade-${gradeClass(s.grade)}" id="legacy-grade-${i}">${esc(s.grade || '-')}</span></td>
      </tr>`;
    }).join('');
  };

  window.legacyRecalculateCell = function(input){
    const row = input.getAttribute('data-student-index');
    const key = input.getAttribute('data-component-key');
    const taken = Math.max(0.01, num(input.getAttribute('data-taken'), 100));
    const convertTo = num(input.getAttribute('data-convert'), 0);
    let raw = num(input.value, 0);
    if(raw < 0) raw = 0;
    if(raw > taken) raw = taken;
    const converted = convertTo > 0 ? Math.min(convertTo, (raw / taken) * convertTo) : 0;
    const conv = $(`legacy-conv-${row}-${key}`);
    if(conv) conv.textContent = fmt(converted);
  };

  function collectLegacyUpdates(){
    const list = visibleComponents();
    const updates = [];
    students().forEach((student, i) => {
      list.forEach(c => {
        const input = document.querySelector(`.legacy-mark-input[data-student-index="${i}"][data-component-id="${c.id}"]`);
        if(!input) return;
        updates.push({
          enrollment_id: student.enrollment_id,
          result_id: student.result_id,
          component_id: c.id,
          component: c.component_key,
          raw_marks: num(input.value, 0),
          is_absent: 0
        });
      });
    });
    return updates;
  }

  window.saveLegacyGradeSheet = function(){
    if(isLocked()){ toast(lockMessage(), 'warning', 'Locked'); return Promise.resolve(false); }
    const sectionId = selectedMarksSectionId();
    if(!sectionId || !currentSec()){ toast('Select Course With Section and click Load Students first.', 'warning', 'No Section'); return Promise.resolve(false); }
    const updates = collectLegacyUpdates();
    if(!updates.length){ toast('No marks available to save.', 'warning', 'Nothing to Save'); return Promise.resolve(false); }
    return fetch('save_marks.php', {
      method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'},
      body:JSON.stringify({updates})
    })
    .then(async r => { const text = await r.text(); try { return JSON.parse(text); } catch(e){ throw new Error(text || 'Invalid JSON response'); } })
    .then(data => {
      if(!data.success){ toast(data.message || 'Failed to save grade sheet.', 'error', 'Save Failed'); return false; }
      toast('Full marks sheet saved successfully.', 'success', 'Saved');
      return window.loadMarksStudentsLegacy().then(() => true);
    })
    .catch(err => { console.error(err); toast(err.message || 'Unable to save grade sheet.', 'error', 'Save Failed'); return false; });
  };

  window.gradeProcessLegacy = function(){
    if(isLocked()){ toast(lockMessage(), 'warning', 'Locked'); return; }
    const sectionId = selectedMarksSectionId();
    if(!sectionId || !currentSec()){ toast('Select Course With Section and click Load Students first.', 'warning', 'No Section'); return; }
    const grace = num($('legacy-grace-value')?.value, 0);
    saveLegacyGradeSheet().then(ok => {
      if(ok === false) return;
      fetch('grade_process.php', {
        method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'},
        body:JSON.stringify({section_id: sectionId, grace_value: grace})
      })
      .then(async r => { const text = await r.text(); try { return JSON.parse(text); } catch(e){ throw new Error(text || 'Invalid JSON response'); } })
      .then(data => {
        if(!data.success){ toast(data.message || 'Grade process failed.', 'error', 'Failed'); return; }
        toast(data.message || 'Grade process completed.', 'success', 'Grade Process');
        window.loadMarksStudentsLegacy();
      })
      .catch(err => { console.error(err); toast(err.message || 'Grade process failed.', 'error', 'Failed'); });
    });
  };

  window.recalculateAttendanceLegacy = function(){
    const sectionId = selectedMarksSectionId();
    if(!sectionId){ toast('Select Course With Section first.', 'warning', 'No Section'); return; }
    fetch('recalculate_section.php', {
      method:'POST', headers:{'Content-Type':'application/json','Accept':'application/json'},
      body:JSON.stringify({section_id: sectionId})
    })
    .then(async r => { const text = await r.text(); try { return JSON.parse(text); } catch(e){ throw new Error(text || 'Invalid JSON response'); } })
    .then(data => {
      if(!data.success){ toast(data.message || 'Recalculate failed.', 'error', 'Failed'); return; }
      toast(data.message || 'Attendance/result recalculated.', 'success', 'Recalculated');
      window.loadMarksStudentsLegacy();
    })
    .catch(err => { console.error(err); toast(err.message || 'Recalculate failed.', 'error', 'Failed'); });
  };

  window.downloadMarksExcel = function(){
    const sectionId = selectedMarksSectionId();
    if(!sectionId){ toast('Select Course With Section first.', 'warning', 'No Section'); return; }
    window.location.href = `download_marks_excel.php?section_id=${encodeURIComponent(sectionId)}`;
  };

  window.uploadMarksExcel = function(input){
    const file = input.files && input.files[0];
    const sectionId = selectedMarksSectionId();
    if(!file) return;
    if(!sectionId || !currentSec()){ toast('Select Course With Section and click Load Students first.', 'warning', 'No Section'); input.value=''; return; }
    if(isLocked()){ toast(lockMessage(), 'warning', 'Locked'); input.value=''; return; }
    const form = new FormData();
    form.append('section_id', sectionId);
    form.append('marks_file', file);
    fetch('upload_marks_excel.php', {method:'POST', headers:{'Accept':'application/json'}, body:form})
      .then(async r => { const text = await r.text(); try { return JSON.parse(text); } catch(e){ throw new Error(text || 'Invalid JSON response'); } })
      .then(data => {
        if(!data.success){ toast(data.message || 'Upload failed.', 'error', 'Upload Failed'); return; }
        toast(data.message || 'Excel marks uploaded.', 'success', 'Uploaded');
        window.loadMarksStudentsLegacy();
      })
      .catch(err => { console.error(err); toast(err.message || 'Upload failed.', 'error', 'Upload Failed'); })
      .finally(() => { input.value=''; });
  };

  window.calculateCtAverageLegacy = function(){
    const ctComps = comps().filter(c => String(c.component_type || '').toLowerCase() === 'ct');
    if(!ctComps.length){ toast('No Class Test components found.', 'warning', 'No CT'); return; }
    window.renderLegacyGradeSheet();
    students().forEach((student, i) => {
      let bestId = null;
      let best = -Infinity;
      ctComps.forEach(c => {
        const val = num(componentMark(student, c).converted_marks, 0);
        if(val > best){ best = val; bestId = c.id; }
      });
      if(bestId){
        const cell = document.querySelector(`#legacy-grade-table tbody tr:nth-child(${i+1}) td input[data-component-id="${bestId}"]`)?.closest('td');
        if(cell) cell.style.background = 'rgba(16,185,129,.15)';
      }
    });
    toast('Best CT value highlighted for each student.', 'success', 'CT Average');
  };

  window.showGradeDetailsLegacy = function(){
    alert('Grade Rules:\nA+ = 90-100\nA = 85-89\nA- = 80-84\nB+ = 75-79\nB = 70-74\nB- = 65-69\nC+ = 60-64\nC = 55-59\nD = 50-54\nF = below 50');
  };

  window.showLegacyMarksInstruction = function(){
    alert('Marks Entry Instruction:\n1. Select Course With Section and click Load Students.\n2. Select All Assessment or one assessment.\n3. Enter actual marks in the sheet.\n4. Click Save Full Sheet.\n5. Use Grade Process after checking all marks.\n6. Download/Upload Excel works with the downloaded CSV format.');
  };

  const oldTeacherNavMarksFinal = window.teacherNav;
  window.teacherNav = function(view, navEl){
    if(typeof oldTeacherNavMarksFinal === 'function') oldTeacherNavMarksFinal(view, navEl);
    if(view === 'marks'){
      setTimeout(() => {
        window.renderMarksSectionDropdown();
        if(activeId() && !currentSec()) window.loadMarksStudentsLegacy();
        else window.renderLegacyGradeSheet();
      }, 60);
    }
  };

  const oldLoadSectionDataMarksFinal = window.loadSectionData;
  window.loadSectionData = function(sectionId, showMessage=false){
    if(typeof oldLoadSectionDataMarksFinal !== 'function') return Promise.resolve(null);
    return oldLoadSectionDataMarksFinal(sectionId, showMessage).then(data => {
      if(data && data.success){
        window.URAMS_ACTIVE_SECTION_ID = parseInt(sectionId,10);
        window.renderMarksSectionDropdown();
        window.renderLegacyComponentFilter();
        window.renderLegacyGradeSheet();
      }
      return data;
    });
  };

  document.addEventListener('DOMContentLoaded', () => setTimeout(() => {
    window.renderMarksSectionDropdown();
    window.renderLegacyComponentFilter();
    window.renderLegacyGradeSheet();
  }, 350));
})();


/* ══════════════════════════════════════════════════════════════════
   TEACHER PROFILE PHOTO UPLOAD
   ══════════════════════════════════════════════════════════════════ */
window.uploadTeacherProfilePhoto = async function(input){
  const file = input && input.files ? input.files[0] : null;
  if(!file) return;
  const allowed = ['image/jpeg','image/png','image/webp','image/gif'];
  if(!allowed.includes(file.type)){
    showToast('Only JPG, PNG, WEBP or GIF images are allowed.', 'warning', 'Invalid Image');
    input.value = '';
    return;
  }
  if(file.size > 2 * 1024 * 1024){
    showToast('Image size must be 2 MB or less.', 'warning', 'Too Large');
    input.value = '';
    return;
  }

  const fd = new FormData();
  fd.append('profile_photo', file);
  try{
    showToast('Uploading profile photo...', 'info', 'Please wait');
    const res = await fetch('upload_profile_photo.php', {method:'POST', body:fd, headers:{'Accept':'application/json'}});
    const data = await res.json();
    if(!data.success){
      showToast(data.message || 'Photo upload failed.', 'error', 'Upload Failed');
      input.value = '';
      return;
    }
    const url = String(data.photo_url || '');
    document.querySelectorAll('[data-profile-avatar]').forEach(el => {
      el.innerHTML = `<img src="${url}?v=${Date.now()}" alt="Profile Photo" class="urams-avatar-img">`;
    });
    showToast(data.message || 'Profile photo updated.', 'success', 'Updated');
    input.value = '';
  }catch(err){
    console.error(err);
    showToast('Unable to upload photo. Please try again.', 'error', 'Upload Failed');
    input.value = '';
  }
};


/* STUDENT TEAMMATE MERGE OVERRIDES - keeps teacher/admin frontend untouched */
(function(){
  function getStudentHistoryData(){
    if (Array.isArray(window.URAMS_STUDENT_HISTORY) && window.URAMS_STUDENT_HISTORY.length) return window.URAMS_STUDENT_HISTORY;
    if (Array.isArray(window.URAMS_TRIMESTER_RESULTS) && window.URAMS_TRIMESTER_RESULTS.length) return window.URAMS_TRIMESTER_RESULTS.map(t=>({
      trimester_name:t.tri || t.trimester_name,
      gpa:t.gpa,
      cgpa:t.cgpa,
      status:'approved',
      courses:t.courses || []
    }));
    return [];
  }
  window.getHistoryData = getStudentHistoryData;

  window.formatGPAValue = function(value){
    if(value===null || value===undefined || value==='') return '-';
    const n=Number(value);
    return Number.isFinite(n) ? n.toFixed(2) : '-';
  };

  window.getGradeBadgeClass = function(grade){
    const g=String(grade||'').toUpperCase();
    if(g==='A+') return 'grade-A-plus';
    if(g.startsWith('A')) return 'grade-A';
    if(g.startsWith('B')) return 'grade-B';
    if(g.startsWith('C')) return 'grade-C';
    if(g.startsWith('D')) return 'grade-D';
    return 'grade-F';
  };

  function esc(v){ return String(v ?? '').replace(/[&<>'"]/g, m=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[m])); }

  window.studentNav = function(view, navEl){
    ['dashboard','continuous','history','profile'].forEach(v=>{
      const el=document.getElementById('s-view-'+v);
      if(el) el.style.display=(v===view?'':'none');
    });
    document.querySelectorAll('#student-sidebar .nav-item').forEach(n=>n.classList.remove('active'));
    if(navEl){
      navEl.classList.add('active');
    }else{
      const label = {dashboard:'Dashboard',continuous:'Continuous Eval',history:'Result History',profile:'My Profile'}[view] || '';
      const item = Array.from(document.querySelectorAll('#student-sidebar .nav-item')).find(n=>n.textContent.trim().startsWith(label));
      if(item) item.classList.add('active');
    }
    const title=document.getElementById('student-page-title');
    if(title) title.textContent={dashboard:'My Dashboard',continuous:'Continuous Evaluation',history:'Result History',profile:'My Profile'}[view]||view;
    if(view==='dashboard' || view==='history' || view==='continuous') window.refreshStudentDashboard();
  };

  window.previewStudentPhoto = function(event){
    const file=event.target.files && event.target.files[0];
    if(file) window.uploadStudentPhoto(file);
  };

  window.uploadStudentPhoto = async function(file){
    const fd=new FormData();
    fd.append('profile_photo', file);
    try{
      const res=await fetch('upload_profile_photo.php',{method:'POST',body:fd});
      const data=await res.json();
      if(!data.success) throw new Error(data.message || 'Upload failed');
      const url=data.photo_url || data.photo || URL.createObjectURL(file);
      const update=(el)=>{
        if(!el) return;
        el.style.backgroundImage=`url(${url})`;
        el.style.backgroundSize='cover';
        el.style.backgroundPosition='center';
        el.style.backgroundRepeat='no-repeat';
        el.style.color='transparent';
        el.innerHTML='';
      };
      update(document.getElementById('student-profile-avatar'));
      document.querySelectorAll('#page-student .sidebar-avatar,#page-student .header-avatar').forEach(update);
      if(typeof showToast==='function') showToast('Profile photo saved successfully.','success','Saved');
    }catch(e){
      console.error(e);
      if(typeof showToast==='function') showToast(e.message || 'Photo upload failed.','error','Error');
    }
  };

  window.updateStudentSummary = function(summary){
    const vals={
      'student-cgpa': summary?.cgpa ?? '0.00',
      'student-last-gpa': summary?.last_gpa ?? '0.00',
      'student-trimesters': summary?.trimesters ?? 0,
      'student-credits-done': summary?.credits_done ?? '0'
    };
    Object.entries(vals).forEach(([id,val])=>{ const el=document.getElementById(id); if(el) el.textContent=val; });
  };

  window.buildStudentSummaryFromHistory = function(history){
    if(!Array.isArray(history)||!history.length) return null;
    let credits=0, weightedPoints=0, weightedCredits=0, lastGpa=null;
    history.forEach(term=>{
      let termPoints=0, termCredits=0;
      (term.courses||[]).forEach(c=>{
        const credit = Number(c.credit)||0;
        const gp = Number(c.grade_point);
        credits += credit;
        if(Number.isFinite(gp)){
          termPoints += gp * credit;
          termCredits += credit;
          weightedPoints += gp * credit;
          weightedCredits += credit;
        }
      });
      if(termCredits>0) lastGpa = termPoints / termCredits;
    });
    return {
      cgpa: weightedCredits? (weightedPoints/weightedCredits).toFixed(2):'0.00',
      last_gpa: lastGpa!==null?lastGpa.toFixed(2):'0.00',
      trimesters:history.length,
      credits_done:credits.toFixed(0)
    };
  };

  window.renderStudentCourses = function(courses, trimesterTitle){
    const body=document.getElementById('student-courses-body');
    const title=document.getElementById('student-current-trimester-title');
    if(title) title.textContent=`Current Semester Courses — ${trimesterTitle || 'N/A'}`;
    if(!body) return;
    if(!Array.isArray(courses)||!courses.length){
      body.innerHTML='<tr><td colspan="5" style="text-align:center">No enrolled courses found for your account.</td></tr>';
      return;
    }
    body.innerHTML=courses.map(c=>{
      const status=String(c.status||'running').toLowerCase();
      let badge='<span class="badge badge-warning pending-badge"><i class="fas fa-clock"></i> Running</span>';
      if(status==='approved') badge='<span class="badge badge-success"><i class="fas fa-check"></i> Result Approved</span>';
      else if(status==='submitted') badge='<span class="badge badge-primary"><i class="fas fa-paper-plane"></i> Submitted</span>';
      return `<tr><td class="td-id">${esc(c.course_code)}</td><td class="td-name">${esc(c.course_name)}</td><td>${Number(c.credit||0).toFixed(1)}</td><td>${esc(c.teacher_name||'')} (${esc(String(c.teacher_identifier||'').toUpperCase())})</td><td>${badge}</td></tr>`;
    }).join('');
  };

  window.renderClassRoutine = async function(){
    const el=document.getElementById('class-routine-body');
    if(!el) return;
    el.innerHTML='<div style="text-align:center;color:var(--text2);padding:24px">Loading class routine...</div>';
    try{
      const res=await fetch('api_student_routine.php',{cache:'no-store'});
      const data=await res.json();
      const rows=(data && data.success && Array.isArray(data.routine)) ? data.routine : [];
      if(!rows.length){
        el.innerHTML='<div style="text-align:center;color:var(--text2);padding:24px">No class routine found.</div>';
        return;
      }
      const grouped={};
      rows.forEach(r=>{ const day=r.day || 'Schedule'; (grouped[day] ||= []).push(r); });
      el.innerHTML=Object.entries(grouped).map(([day,items])=>`<div class="routine-day"><div class="routine-day-title">${esc(day)}</div>${items.map(r=>`<div class="routine-item"><span>${esc(r.course_code)} - ${esc(r.course_name)} <small>Sec ${esc(r.section||'')}</small>${r.room?`<br><small>${esc(r.room)}</small>`:''}</span><span class="routine-time">${esc(r.time||'TBD')}</span></div>`).join('')}</div>`).join('');
    }catch(e){
      el.innerHTML='<div style="text-align:center;color:var(--danger);padding:24px">Unable to load routine.</div>';
    }
  };

  window.renderStudentAttendanceSummary = async function(){
    const canvas=document.getElementById('att-bar-chart');
    const list=document.getElementById('student-attendance-list');
    if(!canvas && !list) return;
    const emptyList = (msg)=>{
      if(list) list.innerHTML=`<div class="empty-state" style="padding:18px;text-align:center;color:var(--text2)">${esc(msg)}</div>`;
      if(canvas){
        const ctx=canvas.getContext('2d');
        const W=canvas.offsetWidth||400, H=canvas.height||160; canvas.width=W; ctx.clearRect(0,0,W,H); ctx.fillStyle='#64748b'; ctx.font='13px Outfit,sans-serif'; ctx.textAlign='center'; ctx.fillText(msg, W/2, H/2);
      }
    };
    try{
      const res=await fetch('api_student_attendance.php',{cache:'no-store'});
      const data=await res.json();
      const rows=(data && data.success && Array.isArray(data.data)) ? data.data : [];
      if(!rows.length){ emptyList('No attendance data yet'); return; }
      if(list){
        list.innerHTML=`<table class="student-attendance-mini-table"><thead><tr><th>Course</th><th>Section</th><th>Attendance</th></tr></thead><tbody>${rows.map(r=>{
          const pct=Math.max(0, Math.min(100, Number(r.attendance_percent)||0));
          const badge=pct>=80?'badge-success':(pct>=60?'badge-warning':'badge-danger');
          return `<tr><td><strong>${esc(r.course_code||'')}</strong><br><span>${esc(r.course_name||'')}</span></td><td>${esc(r.section||'-')}</td><td><span class="badge ${badge}">${pct}%</span></td></tr>`;
        }).join('')}</tbody></table>`;
      }
      if(canvas && typeof drawBarChart==='function') drawBarChart(canvas, rows.map(r=>r.course_code), rows.map(r=>Number(r.attendance_percent)||0), 'Attendance %', true);
    }catch(e){ console.warn('attendance summary error',e); emptyList('Unable to load attendance'); }
  };

  window.refreshStudentDashboard = async function(){
    try{
      const res=await fetch('api_student_history.php',{cache:'no-store'});
      const data=await res.json();
      if(data && data.success){
        window.URAMS_STUDENT_HISTORY=Array.isArray(data.studentHistory)?data.studentHistory:[];
        window.URAMS_STUDENT_COURSES=Array.isArray(data.studentCourses)?data.studentCourses:[];
        const summary=data.studentSummary || window.buildStudentSummaryFromHistory(window.URAMS_STUDENT_HISTORY) || {};
        window.updateStudentSummary(summary);
        window.renderStudentCourses(window.URAMS_STUDENT_COURSES, data.trimesterTitle || 'N/A');
      }
    }catch(e){ console.warn('student refresh failed',e); }
    window.populateStudentContinuousFilters();
    window.setStudentGPAChartMode(window.__uramsStudentGpaMode || 'both');
    window.renderStudentAttendanceSummary();
    window.renderClassRoutine();
    window.initResultHistory();
  };

  window.populateStudentContinuousFilters = function(){
    const tri=document.getElementById('student-continuous-trimester-filter');
    const course=document.getElementById('student-continuous-course-filter');
    if(!tri || !course) return;
    const courses=Array.isArray(window.URAMS_STUDENT_COURSES)?window.URAMS_STUDENT_COURSES:[];
    const tris=[...new Set(courses.map(c=>c.trimester_name).filter(Boolean))];
    tri.innerHTML=tris.length?tris.map(t=>`<option value="${esc(t)}">${esc(t)}</option>`).join(''):'<option value="">No trimester</option>';
    const selected=tri.value || tris[0] || '';
    const filtered=courses.filter(c=>!selected || c.trimester_name===selected);
    course.innerHTML=filtered.length?filtered.map(c=>`<option value="${esc(c.course_code)}">${esc(c.course_name)} (${esc(c.course_code)})</option>`).join(''):'<option value="">No course</option>';
    tri.onchange=window.populateStudentContinuousFilters;
  };

  window.initStudentDashboard = function(){ window.refreshStudentDashboard(); if(typeof renderNotifications==='function') renderNotifications('student'); };

  window.initResultHistory = function(){
    const el=document.getElementById('result-history-accordion');
    const panel=document.getElementById('result-history-panel');
    if(!el && !panel) return;
    const history=getStudentHistoryData();
    if(!history.length){
      const empty='<div class="empty-state">No result history available yet.</div>';
      if(el) el.innerHTML=empty; if(panel) panel.innerHTML=empty; return;
    }
    const html=history.map((term,i)=>{
      const rows=(term.courses||[]).map(c=>`<tr><td class="td-id">${esc(c.course_code)}</td><td class="td-name">${esc(c.course_name)}</td><td>${Number(c.credit||0).toFixed(1)}</td><td style="font-weight:700;color:var(--primary)">${c.grade_point!==null&&c.grade_point!==undefined?Number(c.grade_point).toFixed(2):'-'}</td><td><span class="${window.getGradeBadgeClass(c.grade)}">${esc(c.grade||'N/A')}</span></td><td><span class="badge ${String(c.status||'').toLowerCase()==='approved'?'badge-success':'badge-warning'}">${String(c.status||'').toLowerCase()==='approved'?'Pass':'Pending'}</span></td></tr>`).join('');
      return `<div class="accordion-item"><div class="accordion-header ${i===0?'open':''}" onclick="toggleAccordion(this)"><div><span style="font-weight:700">${esc(term.trimester_name)}</span><span style="margin-left:12px;color:var(--text2);font-size:12px">GPA: <strong>${window.formatGPAValue(term.gpa)}</strong> · CGPA: <strong>${window.formatGPAValue(term.cgpa)}</strong></span><span class="badge ${term.status==='approved'?'badge-success':'badge-warning'}" style="margin-left:8px">${term.status==='approved'?'Approved':'Partial'}</span></div><i class="fas fa-chevron-down accordion-arrow" style="${i===0?'transform:rotate(180deg)':''}"></i></div><div class="accordion-body ${i===0?'open':''}"><div class="table-wrap" style="padding:0"><table><thead><tr><th>Code</th><th>Course</th><th>Credit</th><th>GPA</th><th>Grade</th><th>Remarks</th></tr></thead><tbody>${rows}</tbody></table></div><div style="padding:12px 16px;border-top:1px solid var(--border);display:flex;justify-content:flex-end"><button class="btn btn-secondary btn-sm" onclick="printResultCard(${i})"><i class="fas fa-print"></i> Print Card</button></div></div></div>`;
    }).join('');
    if(el) el.innerHTML=html; if(panel) panel.innerHTML=html;
  };

  window.toggleAccordion = function(header){
    const body=header?.nextElementSibling; const arrow=header?.querySelector('.accordion-arrow');
    if(!body) return; header.classList.toggle('open'); body.classList.toggle('open'); if(arrow) arrow.style.transform=body.classList.contains('open')?'rotate(180deg)':'rotate(0deg)';
  };

  window.loadContinuousEval = function(){
    const result=document.getElementById('continuous-eval-result'); if(!result) return;
    const code=document.getElementById('student-continuous-course-filter')?.value;
    const courses=Array.isArray(window.URAMS_STUDENT_COURSES)?window.URAMS_STUDENT_COURSES:[];
    const c=courses.find(x=>x.course_code===code) || courses[0];
    if(!c){ result.innerHTML='<div class="card-body" style="text-align:center;padding:40px;color:var(--text2)">No course data found.</div>'; return; }
    result.innerHTML=`<div class="table-wrap"><table><thead><tr><th>CT1</th><th>CT2</th><th>Best CT</th><th>Assignment</th><th>Mid</th><th>Final</th><th>Attendance</th><th>Total</th><th>Grade</th><th>Status</th></tr></thead><tbody><tr><td>${Number(c.ct1||0).toFixed(2)}</td><td>${Number(c.ct2||0).toFixed(2)}</td><td>${Number(c.best_ct||0).toFixed(2)}</td><td>${Number(c.assignment||0).toFixed(2)}</td><td>${Number(c.mid||0).toFixed(2)}</td><td>${Number(c.final||0).toFixed(2)}</td><td>${Number(c.attendance_marks||0).toFixed(2)}</td><td style="font-weight:800">${Number(c.total_marks||0).toFixed(2)}</td><td><span class="${window.getGradeBadgeClass(c.grade)}">${esc(c.grade||'N/A')}</span></td><td>${esc(c.status||'draft')}</td></tr></tbody></table></div><div style="padding:12px 20px;font-size:12px;color:var(--text2);border-top:1px solid var(--border)"><i class="fas fa-lock" style="margin-right:4px"></i> Read-only view. Contact your teacher for changes.</div>`;
  };

  window.downloadTranscript = function(){ window.print(); };
  window.printResultCard = function(index){
    const history=getStudentHistoryData(); const term=history[index];
    if(!term){ if(typeof showToast==='function') showToast('Unable to print result card.','error','Error'); return; }
    const win=window.open('','_blank'); if(!win) return;
    const rows=(term.courses||[]).map(c=>`<tr><td>${esc(c.course_code)}</td><td>${esc(c.course_name)}</td><td>${Number(c.credit||0).toFixed(1)}</td><td>${c.grade_point!==null&&c.grade_point!==undefined?Number(c.grade_point).toFixed(2):'-'}</td><td>${esc(c.grade||'N/A')}</td><td>${String(c.status||'').toLowerCase()==='approved'?'Pass':'Pending'}</td></tr>`).join('');
    win.document.write(`<!doctype html><html><head><meta charset="utf-8"><title>Result Card</title><style>body{font-family:Arial,sans-serif;padding:24px}table{width:100%;border-collapse:collapse;margin-top:18px}th,td{border:1px solid #ccc;padding:10px;text-align:left}th{background:#f6f8fb}</style></head><body><h1>Result Card</h1><p><strong>Trimester:</strong> ${esc(term.trimester_name)}</p><p><strong>GPA:</strong> ${window.formatGPAValue(term.gpa)} &nbsp; <strong>CGPA:</strong> ${window.formatGPAValue(term.cgpa)}</p><table><thead><tr><th>Code</th><th>Course</th><th>Credit</th><th>GPA</th><th>Grade</th><th>Remarks</th></tr></thead><tbody>${rows}</tbody></table></body></html>`);
    win.document.close(); win.focus(); win.print(); win.close();
  };

  window.setStudentGPAChartMode = function(mode){
    window.__uramsStudentGpaMode=mode || 'both';
    document.querySelectorAll('.gpa-toggle-btn').forEach(btn=>btn.classList.toggle('active', btn.dataset.mode===window.__uramsStudentGpaMode));
    const title=document.getElementById('student-gpa-chart-title');
    if(title) title.textContent=window.__uramsStudentGpaMode==='gpa'?'GPA Progression':window.__uramsStudentGpaMode==='cgpa'?'CGPA Progression':'GPA / CGPA Progression';
    window.drawGPAChart('student-gpa-chart', window.__uramsStudentGpaMode);
  };

  const originalDrawGPAChart = window.drawGPAChart;
  window.drawGPAChart = function(canvasId, mode){
    const canvas=document.getElementById(canvasId); if(!canvas) return;
    if(canvasId !== 'student-gpa-chart' && typeof originalDrawGPAChart === 'function') return originalDrawGPAChart(canvasId, mode);
    const history=getStudentHistoryData();
    if(!history.length){
      const ctx=canvas.getContext('2d'); const W=canvas.offsetWidth||700,H=canvas.height||200; canvas.width=W; ctx.clearRect(0,0,W,H); ctx.fillStyle='#64748b'; ctx.font='14px Outfit,sans-serif'; ctx.textAlign='center'; ctx.fillText('No GPA data yet', W/2, H/2); return;
    }
    const seasonMap={Summer:'Su',Spring:'Sp',Fall:'Fa'};
    const labels=history.map(t=>{ const p=String(t.trimester_name||'').split(' '); return `${seasonMap[p[0]]||p[0]||''}${p[1]?p[1].slice(2):''}`; });
    const datasets=[]; const m=mode||window.__uramsStudentGpaMode||'both';
    if(m==='both'||m==='gpa') datasets.push({label:'GPA',data:history.map(t=>Number(t.gpa)||0)});
    if(m==='both'||m==='cgpa') datasets.push({label:'CGPA',data:history.map(t=>Number(t.cgpa)||0)});
    if(typeof drawLineChart==='function') drawLineChart(canvas, labels, datasets, 'GPA / CGPA Progression');
  };

  window.addEventListener('focus',()=>{ if(document.getElementById('page-student') && (window.currentRole==='student' || document.getElementById('page-student').classList.contains('active'))) window.refreshStudentDashboard(); });
})();

/* FINAL PARENT ANALYTICS OVERRIDE — clean native canvas charts, no external library */
function parentSafeTrimesterResults(){
  return Array.isArray(window.URAMS_TRIMESTER_RESULTS) ? window.URAMS_TRIMESTER_RESULTS : [];
}
function parentShortTri(label){
  const parts = String(label || '').split(/\s+/);
  if(parts.length >= 2) return `${parts[0].slice(0,2)} ${String(parts[1]).slice(-2)}`;
  return String(label || 'Term');
}
function drawParentGPAChart(canvasId){
  const canvas = document.getElementById(canvasId);
  if(!canvas) return;
  const ctx = canvas.getContext('2d');
  const rectW = canvas.parentElement ? canvas.parentElement.clientWidth : canvas.offsetWidth;
  const W = Math.max(340, rectW || 720);
  const H = parseInt(canvas.getAttribute('height') || '260', 10) || 260;
  canvas.width = W;
  canvas.height = H;
  ctx.clearRect(0,0,W,H);
  const dataDesc = parentSafeTrimesterResults();
  const data = [...dataDesc].reverse().filter(t => Number.isFinite(parseFloat(t.gpa)) || Number.isFinite(parseFloat(t.cgpa)));
  const dark = document.body.classList.contains('dark-mode');
  const text = dark ? '#cbd5e1' : '#475569';
  const muted = dark ? '#94a3b8' : '#64748b';
  const grid = dark ? 'rgba(255,255,255,.08)' : 'rgba(15,23,42,.08)';
  if(!data.length){
    ctx.fillStyle = muted;
    ctx.font = '600 15px Outfit, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('No approved GPA data yet', W/2, H/2);
    return;
  }
  const pad = {top:34,right:34,bottom:56,left:54};
  const chartW = W - pad.left - pad.right;
  const chartH = H - pad.top - pad.bottom;
  function y(val){ return pad.top + chartH - ((parseFloat(val)||0) / 4.0) * chartH; }
  function x(i){ return data.length === 1 ? pad.left + chartW/2 : pad.left + (i/(data.length-1)) * chartW; }

  // Background
  const bg = ctx.createLinearGradient(0,pad.top,0,pad.top+chartH);
  bg.addColorStop(0, dark ? 'rgba(26,86,219,.10)' : 'rgba(26,86,219,.07)');
  bg.addColorStop(1, 'rgba(26,86,219,0)');
  ctx.fillStyle = bg;
  ctx.fillRect(pad.left,pad.top,chartW,chartH);

  // Grid + y axis labels
  ctx.font = '11px Outfit, sans-serif';
  ctx.textAlign = 'right';
  ctx.fillStyle = muted;
  for(let i=0;i<=4;i++){
    const val = i;
    const yy = y(val);
    ctx.strokeStyle = grid;
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(pad.left, yy); ctx.lineTo(pad.left+chartW, yy); ctx.stroke();
    ctx.fillText(val.toFixed(2), pad.left-8, yy+4);
  }

  function drawSeries(key, color, label, offsetY){
    const pts = data.map((d,i)=>({x:x(i), y:y(d[key]), v:parseFloat(d[key])||0}));
    ctx.beginPath();
    ctx.strokeStyle = color;
    ctx.lineWidth = 3;
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    pts.forEach((p,i)=> i ? ctx.lineTo(p.x,p.y) : ctx.moveTo(p.x,p.y));
    ctx.stroke();
    pts.forEach((p,i)=>{
      ctx.beginPath(); ctx.arc(p.x,p.y,5,0,Math.PI*2); ctx.fillStyle = color; ctx.fill();
      ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.stroke();
      // Avoid messy labels: show first, last and when <=4 points.
      if(data.length <= 4 || i === 0 || i === data.length - 1){
        ctx.fillStyle = text;
        ctx.font = '700 11px Outfit, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(p.v.toFixed(2), p.x, p.y + offsetY);
      }
    });
    // Legend
    const lx = label === 'GPA' ? pad.left : pad.left + 96;
    ctx.fillStyle = color; ctx.fillRect(lx, H-18, 24, 4);
    ctx.fillStyle = text; ctx.font = '12px Outfit, sans-serif'; ctx.textAlign = 'left';
    ctx.fillText(label, lx+32, H-14);
  }
  drawSeries('gpa', '#1a56db', 'GPA', -12);
  drawSeries('cgpa', '#f59e0b', 'CGPA', 18);

  // X labels
  ctx.fillStyle = muted;
  ctx.font = '11px Outfit, sans-serif';
  ctx.textAlign = 'center';
  data.forEach((d,i)=>{
    const label = parentShortTri(d.tri);
    ctx.fillText(label, x(i), pad.top + chartH + 22);
  });
}
function initParentDashboard(){
  initParentResults(true);
  setTimeout(()=>drawParentGPAChart('parent-gpa-chart'), 80);
  refreshApprovedResultsFromApi(()=>{
    initParentResults(true);
    setTimeout(()=>drawParentGPAChart('parent-gpa-chart'), 80);
    setTimeout(()=>drawParentGPAChart('parent-result-gpa-chart'), 80);
  });
}
function initParentResults(force=false){
  initResultHistory('parent-history-accordion', force);
  setTimeout(()=>drawParentGPAChart('parent-result-gpa-chart'), 80);
}
function parentNav(view, navEl){
  parentViews.forEach(v=>{ const el=document.getElementById('p-view-'+v); if(el) el.style.display = v===view ? '' : 'none'; });
  if(navEl){ document.querySelectorAll('#parent-sidebar .nav-item').forEach(n=>n.classList.remove('active')); navEl.classList.add('active'); }
  const title = document.getElementById('parent-page-title');
  if(title) title.textContent = view === 'results' ? 'Result Viewer' : 'Parent Dashboard';
  if(view === 'results') initParentResults(true);
  if(view === 'dashboard') setTimeout(()=>drawParentGPAChart('parent-gpa-chart'), 80);
}
window.addEventListener('resize', ()=>{
  if(document.getElementById('page-parent')){
    setTimeout(()=>drawParentGPAChart('parent-gpa-chart'), 60);
    setTimeout(()=>drawParentGPAChart('parent-result-gpa-chart'), 60);
  }
});


/* ══════════════════════════════════════════════════════════════════
   FINAL PRINT / PDF ISOLATION FIX — Student + Teacher
   This overrides broad window.print() so only the transcript/report is printed.
   ══════════════════════════════════════════════════════════════════ */
(function(){
  function esc(value){
    return String(value ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[ch]));
  }
  function num(value, decimals=2){
    const n = parseFloat(value);
    return Number.isFinite(n) ? n.toFixed(decimals) : (0).toFixed(decimals);
  }
  function cleanStatus(status){
    const s = String(status || '').toLowerCase();
    if(s === 'approved') return 'Approved';
    if(s === 'submitted') return 'Submitted';
    if(s === 'rejected') return 'Rejected';
    return 'Running';
  }
  function openPrintOnlyWindow(title, bodyHtml, extraCss=''){
    const win = window.open('', '_blank', 'width=1100,height=800,scrollbars=yes');
    if(!win){
      if(typeof showToast === 'function') showToast('Please allow pop-ups to download/print PDF.','warning','Popup Blocked');
      return;
    }
    const css = `
      @page{size:A4;margin:14mm;}
      *{box-sizing:border-box;}
      body{font-family:Arial,Helvetica,sans-serif;color:#111827;background:#fff;margin:0;padding:24px;font-size:13px;}
      .print-header{display:flex;justify-content:space-between;align-items:flex-start;border-bottom:3px solid #1d4ed8;padding-bottom:14px;margin-bottom:18px;}
      .brand h1{margin:0;color:#1d4ed8;font-size:26px;letter-spacing:.2px}.brand p{margin:5px 0 0;color:#4b5563;font-size:12px;line-height:1.5}
      .doc-title{text-align:right}.doc-title h2{margin:0;font-size:22px;color:#111827}.doc-title p{margin:6px 0 0;color:#6b7280;font-size:12px}
      .info-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:18px 0;}.info-box{border:1px solid #dbe3f0;border-radius:10px;padding:12px;background:#f8fafc}.info-label{text-transform:uppercase;color:#6b7280;font-size:10px;font-weight:700;letter-spacing:.5px}.info-value{font-weight:900;font-size:18px;margin-top:4px;color:#0f172a}.section-title{font-size:18px;font-weight:900;margin:22px 0 10px;color:#0f172a}.term-subtitle{margin:0 0 10px;color:#374151;font-size:13px}.report-table{width:100%;border-collapse:collapse;margin-bottom:18px;}.report-table th{background:#1e3a8a;color:#fff;text-align:left;padding:9px;border:1px solid #1e40af;font-size:12px;text-transform:uppercase}.report-table td{padding:9px;border:1px solid #d1d5db;font-size:12px;vertical-align:top}.report-table tr:nth-child(even) td{background:#f8fafc}.grade-pill{display:inline-block;padding:3px 8px;border-radius:999px;background:#dcfce7;color:#166534;font-weight:800}.footer-note{margin-top:24px;border-top:1px solid #d1d5db;padding-top:10px;color:#6b7280;font-size:11px;display:flex;justify-content:space-between}.print-actions{position:sticky;top:0;background:#fff;border-bottom:1px solid #e5e7eb;padding:10px 0;margin:-24px -24px 18px;display:flex;gap:10px;justify-content:flex-end;padding-right:24px;z-index:10}.print-actions button{border:0;border-radius:8px;padding:9px 14px;font-weight:700;cursor:pointer}.btn-print{background:#1d4ed8;color:#fff}.btn-close{background:#e5e7eb;color:#111827}@media print{.print-actions{display:none!important}body{padding:0}.info-grid{break-inside:avoid}.report-table{page-break-inside:auto}tr{page-break-inside:avoid;page-break-after:auto}}
      ${extraCss || ''}`;
    win.document.open();
    win.document.write(`<!doctype html><html><head><meta charset="utf-8"><title>${esc(title)}</title><style>${css}</style></head><body><div class="print-actions"><button class="btn-print" onclick="window.print()">Print / Save as PDF</button><button class="btn-close" onclick="window.close()">Close</button></div>${bodyHtml}</body></html>`);
    win.document.close();
    win.focus();
    setTimeout(()=>{ try{ win.print(); }catch(e){} }, 500);
  }
  function studentProfile(){
    const p = window.URAMS_STUDENT_PROFILE || {};
    return {
      name: p.name || document.querySelector('.sidebar-user-name')?.textContent?.trim() || 'Student',
      identifier: p.identifier || document.querySelector('.sidebar-user-role')?.textContent?.replace(/^Student\s*[·:-]?\s*/i,'').trim() || '',
      department: p.department || 'CSE Department',
      program: p.program || 'BSc Engineering',
      cgpa: p.cgpa || document.getElementById('student-cgpa')?.textContent?.trim() || '0.00',
      last_gpa: p.last_gpa || document.getElementById('student-last-gpa')?.textContent?.trim() || '0.00',
      trimesters: p.trimesters || document.getElementById('student-trimesters')?.textContent?.trim() || '0',
      credits_done: p.credits_done || document.getElementById('student-credits-done')?.textContent?.trim() || '0'
    };
  }
  function getStudentHistory(){
    return Array.isArray(window.URAMS_STUDENT_HISTORY) ? window.URAMS_STUDENT_HISTORY : [];
  }
  function buildStudentTranscript(){
    const p = studentProfile();
    const history = getStudentHistory();
    const termsHtml = history.length ? history.map(term => {
      const rows = (term.courses || []).map(c => `<tr><td>${esc(c.course_code)}</td><td>${esc(c.course_name)}</td><td>${num(c.credit,1)}</td><td>${c.grade_point!==null && c.grade_point!==undefined ? num(c.grade_point,2) : '-'}</td><td><span class="grade-pill">${esc(c.grade || 'N/A')}</span></td><td>${String(c.status || '').toLowerCase()==='approved' ? 'Pass' : cleanStatus(c.status)}</td></tr>`).join('');
      return `<div class="section-title">${esc(term.trimester_name || 'Trimester')}</div><p class="term-subtitle">GPA: <strong>${num(term.gpa,2)}</strong> · CGPA: <strong>${num(term.cgpa,2)}</strong> · Status: <strong>${esc(cleanStatus(term.status))}</strong></p><table class="report-table"><thead><tr><th>Code</th><th>Course</th><th>Credit</th><th>GP</th><th>Grade</th><th>Remarks</th></tr></thead><tbody>${rows || '<tr><td colspan="6">No course data found.</td></tr>'}</tbody></table>`;
    }).join('') : '<p style="color:#6b7280;padding:20px;border:1px solid #e5e7eb;border-radius:10px">No approved result history found for this student.</p>';
    return `<div class="print-header"><div class="brand"><h1>United International University</h1><p>United City, Madani Avenue, Badda, Dhaka - 1212<br>Email: info@uiu.ac.bd · Phone: +88 0964 848 848</p></div><div class="doc-title"><h2>Official Transcript</h2><p>Generated: ${new Date().toLocaleString()}</p></div></div><h2 style="margin:0 0 4px">${esc(p.name)}</h2><p style="margin:0;color:#4b5563">${esc(p.identifier)} · ${esc(p.department)} · ${esc(p.program)}</p><div class="info-grid"><div class="info-box"><div class="info-label">CGPA</div><div class="info-value">${esc(p.cgpa)}</div></div><div class="info-box"><div class="info-label">Last GPA</div><div class="info-value">${esc(p.last_gpa)}</div></div><div class="info-box"><div class="info-label">Trimesters</div><div class="info-value">${esc(p.trimesters)}</div></div><div class="info-box"><div class="info-label">Credits Done</div><div class="info-value">${esc(p.credits_done)}</div></div></div>${termsHtml}<div class="footer-note"><span>URAMS generated academic transcript</span><span>Read-only student copy</span></div>`;
  }
  function getTeacherStudents(){
    if(Array.isArray(window.STUDENTS)) return window.STUDENTS;
    if(Array.isArray(window.URAMS_TEACHER_STUDENTS)) return window.URAMS_TEACHER_STUDENTS;
    return [];
  }
  function getTeacherComponents(){
    if(Array.isArray(window.TEACHER_COMPONENTS)) return window.TEACHER_COMPONENTS;
    if(Array.isArray(window.URAMS_TEACHER_COMPONENTS)) return window.URAMS_TEACHER_COMPONENTS;
    return [];
  }
  function componentMark(student, comp){
    if(window.getComponentMark) return window.getComponentMark(student, comp) || {converted_marks:0,raw_marks:0};
    return (student.component_marks && student.component_marks[comp.component_key]) || {converted_marks:0,raw_marks:0};
  }
  function buildTeacherReport(){
    const sec = window.URAMS_TEACHER_SECTION || {};
    const students = getTeacherStudents();
    const comps = getTeacherComponents();
    const compHeads = comps.map(c => `<th>${esc(c.component_name || c.component_key)}<br><small>${num(c.convert_to,2)}</small></th>`).join('');
    const rows = students.length ? students.map((s,i) => {
      const marks = comps.map(c => `<td>${num(componentMark(s,c).converted_marks,2)}</td>`).join('');
      return `<tr><td>${i+1}</td><td>${esc(s.student_id || s.id || '')}</td><td>${esc(s.name || '')}</td>${marks}<td><strong>${num(s.total_marks,2)}</strong></td><td><span class="grade-pill">${esc(s.grade || '-')}</span></td><td>${esc(cleanStatus(s.result_status || sec.status))}</td></tr>`;
    }).join('') : '<tr><td colspan="6">No loaded student data found. Select a section and click Load Students first.</td></tr>';
    return `<div class="print-header"><div class="brand"><h1>United International University</h1><p>URAMS Teacher Result Sheet<br>Generated: ${new Date().toLocaleString()}</p></div><div class="doc-title"><h2>Result Sheet</h2><p>${esc(sec.trimester || sec.trimester_name || '')}</p></div></div><div class="info-grid"><div class="info-box"><div class="info-label">Course</div><div class="info-value" style="font-size:15px">${esc(sec.course_name || sec.course_title || 'Selected Course')}</div></div><div class="info-box"><div class="info-label">Code</div><div class="info-value">${esc(sec.course_code || '-')}</div></div><div class="info-box"><div class="info-label">Section</div><div class="info-value">${esc(sec.section || sec.section_name || '-')}</div></div><div class="info-box"><div class="info-label">Status</div><div class="info-value">${esc(cleanStatus(sec.status))}</div></div></div><table class="report-table"><thead><tr><th>SL</th><th>Student ID</th><th>Student Name</th>${compHeads}<th>Total</th><th>Grade</th><th>Status</th></tr></thead><tbody>${rows}</tbody></table><div class="footer-note"><span>Teacher copy — marks/report card</span><span>URAMS generated PDF</span></div>`;
  }
  window.downloadTranscript = function(){ openPrintOnlyWindow('Official Transcript', buildStudentTranscript()); };
  window.printStudentTranscriptOnly = window.downloadTranscript;
  window.downloadPDF = function(){
    const role = window.URAMS_CURRENT_ROLE || window.currentRole || '';
    if(role === 'student') return window.downloadTranscript();
    if(role === 'teacher') return openPrintOnlyWindow('Teacher Result Sheet', buildTeacherReport(), '.info-grid{grid-template-columns:repeat(4,1fr)} .report-table th,.report-table td{font-size:10px;padding:6px}');
    const content = document.querySelector('.content')?.innerHTML || '<p>No printable content found.</p>';
    openPrintOnlyWindow('URAMS Report', `<div class="print-header"><div class="brand"><h1>URAMS Report</h1></div><div class="doc-title"><h2>Print View</h2></div></div>${content}`);
  };
})();


/* TEACHER SELECTED SECTION RESULT PDF BUTTON FIX
   This function is used beside Course With Section in Add/Edit Marks.
   It loads the selected section first, then opens a print-only result sheet.
   It does not print the entire dashboard screen. */
(function(){
  window.downloadTeacherSelectedResultPdf = function(){
    const sel = document.getElementById('marks-section-select');
    const selectedId = sel && sel.value ? parseInt(sel.value, 10) : 0;
    const activeId = parseInt(window.URAMS_ACTIVE_SECTION_ID || 0, 10);
    const needsLoad = selectedId && selectedId !== activeId;
    if(!selectedId && !activeId){
      if(typeof showToast === 'function') showToast('Select Course With Section first.', 'warning', 'No Section');
      return;
    }
    const openPdf = () => {
      if(typeof window.downloadPDF === 'function'){
        window.downloadPDF();
      }else{
        window.print();
      }
    };
    if(needsLoad || !(Array.isArray(window.URAMS_TEACHER_STUDENTS) && window.URAMS_TEACHER_STUDENTS.length)){
      if(typeof window.loadMarksStudentsLegacy === 'function'){
        const p = window.loadMarksStudentsLegacy();
        if(p && typeof p.then === 'function'){
          p.then(()=>setTimeout(openPdf, 250));
        }else{
          setTimeout(openPdf, 500);
        }
        return;
      }
    }
    openPdf();
  };
})();
