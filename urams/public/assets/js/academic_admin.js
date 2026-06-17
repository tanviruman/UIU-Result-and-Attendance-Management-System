/* public/assets/js/academic_admin.js
   Academic Setup Admin UI patch. Loaded after script.js. */
(function(){
  if (typeof adminViews !== 'undefined' && Array.isArray(adminViews) && !adminViews.includes('academic')) {
    adminViews.push('academic');
  }

  window.URAMS_ACADEMIC = window.URAMS_ACADEMIC || {loaded:false, programs:[], curricula:[], courses:[], trimesters:[], teachers:[], students:[], sections:[]};

  const originalRenderCurrentAdminView = typeof renderCurrentAdminView === 'function' ? renderCurrentAdminView : null;
  if (originalRenderCurrentAdminView) {
    renderCurrentAdminView = function(){
      if (currentAdminView === 'academic') {
        renderAcademicSetup();
      } else {
        originalRenderCurrentAdminView();
      }
    };
  }

  const originalAdminNav = typeof adminNav === 'function' ? adminNav : null;
  if (originalAdminNav) {
    adminNav = function(view, navEl){
      originalAdminNav(view, navEl);
      if (view === 'academic') {
        const title = document.getElementById('admin-page-title');
        if (title) title.textContent = 'Academic Setup';
      }
    };
  }

  function opt(value, label, selected){
    return `<option value="${escHtml(String(value ?? ''))}" ${selected ? 'selected' : ''}>${escHtml(label ?? '')}</option>`;
  }

  window.loadAcademicData = function(force=false){
    if (URAMS_ACADEMIC.loaded && !force) {
      populateAcademicSelectors();
      renderAcademicTables();
      return Promise.resolve(URAMS_ACADEMIC);
    }
    return adminFetchJson('fetch_academic_setup.php')
      .then(data=>{
        URAMS_ACADEMIC = Object.assign(URAMS_ACADEMIC, data, {loaded:true});
        window.URAMS_ACADEMIC = URAMS_ACADEMIC;
        populateAcademicSelectors();
        renderAcademicTables();
        return URAMS_ACADEMIC;
      })
      .catch(err=>showToast(err.message || 'Could not load academic setup.','error','Academic Setup'));
  };

  window.renderAcademicSetup = function(){
    const el = document.getElementById('a-view-academic');
    if (!el) return;
    loadAcademicData(false);
  };

  function setSelectOptions(id, html){
    const el=document.getElementById(id);
    if(el) el.innerHTML=html;
  }

  window.populateAcademicSelectors = function(){
    const a = URAMS_ACADEMIC;
    const programs = a.programs || [];
    const curricula = a.curricula || [];
    const trimesters = a.trimesters || [];
    const teachers = a.teachers || [];
    const students = a.students || [];
    const sections = a.sections || [];

    const programHtml = programs.map(p=>opt(p.id, p.name)).join('');
    setSelectOptions('academic-section-program', programHtml);
    setSelectOptions('academic-course-filter', '<option value="">All Programs</option>' + programs.map(p=>opt(p.id, p.name)).join(''));

    const trimesterHtml = trimesters.map(t=>opt(t.id, `${t.name}${t.status==='active'?' (active)':''}`)).join('');
    setSelectOptions('academic-section-trimester', trimesterHtml);

    const teacherHtml = teachers.map(t=>opt(t.id, `${t.full_name} (${t.identifier})`)).join('');
    setSelectOptions('academic-section-teacher', teacherHtml);

    const studentHtml = students.map(s=>opt(s.id, `${s.identifier} - ${s.full_name}`)).join('');
    setSelectOptions('academic-enroll-student', studentHtml);

    const sectionHtml = sections.map(s=>opt(s.section_id, `${s.trimester_name} - ${s.course_code} ${s.section_name} (${s.teacher_initial || '---'})`)).join('');
    setSelectOptions('academic-enroll-section', sectionHtml);
    setSelectOptions('admin-user-section-id', '<option value="">No section now</option>' + sectionHtml);

    academicOnProgramChange('section');
    academicStudentProgramChanged();
  };

  window.academicOnProgramChange = function(scope){
    const programEl = document.getElementById(`academic-${scope}-program`);
    const curriculumEl = document.getElementById(`academic-${scope}-curriculum`);
    if(!programEl || !curriculumEl) return;
    const programId = Number(programEl.value || 0);
    const curricula = (URAMS_ACADEMIC.curricula || []).filter(c=>Number(c.program_id) === programId);
    curriculumEl.innerHTML = curricula.map(c=>opt(c.id, c.name)).join('');
    academicOnCurriculumChange(scope);
  };

  window.academicOnCurriculumChange = function(scope){
    const curriculumEl = document.getElementById(`academic-${scope}-curriculum`);
    const courseEl = document.getElementById(`academic-${scope}-course`);
    if(!curriculumEl || !courseEl) return;
    const cvId = Number(curriculumEl.value || 0);
    const courses = (URAMS_ACADEMIC.courses || []).filter(c=>Number(c.curriculum_version_id) === cvId);
    courseEl.innerHTML = courses.map(c=>opt(c.course_id, `${c.course_code} - ${c.course_name} (${Number(c.credit).toFixed(1)} cr)`)).join('');
  };

  window.renderAcademicTables = function(){
    const secBody = document.getElementById('academic-sections-tbody');
    if(secBody){
      const sections = URAMS_ACADEMIC.sections || [];
      secBody.innerHTML = sections.length ? sections.map(s=>`<tr>
        <td>${escHtml(s.trimester_name || '')}</td>
        <td>${escHtml(s.program_name || '---')}</td>
        <td class="td-name">${escHtml(s.course_code || '')} - ${escHtml(s.course_name || '')}</td>
        <td><span class="badge badge-primary">${escHtml(s.section_name || '')}</span></td>
        <td>${escHtml(s.teacher_initial || '')} - ${escHtml(s.teacher_name || '')}</td>
        <td>${Number(s.enrolled_students || 0)} / ${Number(s.capacity || 40)}</td>
        <td>${escHtml(s.room || '---')}</td>
        <td>${escHtml(s.class_schedule || '---')}</td>
        <td><span class="badge badge-${s.status==='approved'?'success':s.status==='rejected'?'danger':s.status==='submitted'?'warning':'neutral'}">${escHtml(s.status || 'running')}</span></td>
      </tr>`).join('') : '<tr><td colspan="9" style="text-align:center">No sections created yet.</td></tr>';
    }
    const courseBody = document.getElementById('academic-courses-tbody');
    if(courseBody){
      const filter = Number(document.getElementById('academic-course-filter')?.value || 0);
      let courses = URAMS_ACADEMIC.courses || [];
      if(filter) courses = courses.filter(c=>Number(c.program_id) === filter);
      courseBody.innerHTML = courses.length ? courses.map(c=>`<tr>
        <td>${escHtml(c.program_name || '')}</td>
        <td class="td-id">${escHtml(c.course_code || '')}</td>
        <td class="td-name">${escHtml(c.course_name || '')}</td>
        <td>${Number(c.credit || 0).toFixed(1)}</td>
        <td><span class="badge badge-neutral">${escHtml(c.course_type || 'core')}</span></td>
        <td>${escHtml([c.level_no, c.term_no].filter(Boolean).join('.'))}</td>
        <td style="font-size:12px;color:var(--text2)">${escHtml(c.prerequisites || 'None')}</td>
      </tr>`).join('') : '<tr><td colspan="7" style="text-align:center">No curriculum courses.</td></tr>';
    }
  };

  window.createAcademicSection = function(){
    const payload = {
      course_id: Number(document.getElementById('academic-section-course')?.value || 0),
      trimester_id: Number(document.getElementById('academic-section-trimester')?.value || 0),
      teacher_id: Number(document.getElementById('academic-section-teacher')?.value || 0),
      section_name: document.getElementById('academic-section-name')?.value.trim() || 'A',
      capacity: Number(document.getElementById('academic-section-capacity')?.value || 40),
      room: document.getElementById('academic-section-room')?.value.trim() || '',
      class_schedule: document.getElementById('academic-section-schedule')?.value.trim() || ''
    };
    if(!payload.course_id || !payload.trimester_id || !payload.teacher_id){ showToast('Course, trimester and teacher are required.','warning','Missing'); return; }
    adminFetchJson('create_section.php', payload)
      .then(data=>{ showToast(data.message || 'Section created.','success','Saved'); return loadAcademicData(true); })
      .then(()=>loadAdminData('academic'))
      .catch(err=>showToast(err.message || 'Could not create section.','error','Error'));
  };

  window.checkAcademicPrerequisites = function(){
    const payload = {
      student_id: Number(document.getElementById('academic-enroll-student')?.value || 0),
      section_id: Number(document.getElementById('academic-enroll-section')?.value || 0)
    };
    if(!payload.student_id || !payload.section_id){ showToast('Student and section are required.','warning','Missing'); return; }
    const out=document.getElementById('academic-prereq-result');
    if(out) out.innerHTML='Checking...';
    adminFetchJson('check_prerequisites.php', payload)
      .then(data=>{
        const missing = data.missing || [];
        if(!missing.length){
          if(out) out.innerHTML='<span class="badge badge-success">Eligible</span> Prerequisite check passed.';
          showToast('Student is eligible for this section.','success','Eligible');
        }else{
          if(out) out.innerHTML='<span class="badge badge-danger">Blocked</span> Missing: '+missing.map(m=>escHtml(m.course_code)).join(', ');
          showToast('Prerequisite missing: '+missing.map(m=>m.course_code).join(', '),'warning','Blocked');
        }
      })
      .catch(err=>{ if(out) out.innerHTML='Error: '+escHtml(err.message); showToast(err.message || 'Check failed.','error','Error'); });
  };

  window.enrollAcademicStudent = function(){
    const payload = {
      student_id: Number(document.getElementById('academic-enroll-student')?.value || 0),
      section_id: Number(document.getElementById('academic-enroll-section')?.value || 0),
      parent_identifier: document.getElementById('academic-enroll-parent')?.value.trim() || '',
      force: !!document.getElementById('academic-enroll-force')?.checked
    };
    if(!payload.student_id || !payload.section_id){ showToast('Student and section are required.','warning','Missing'); return; }
    adminFetchJson('enroll_student.php', payload)
      .then(data=>{ showToast(data.message || 'Student enrolled.','success','Enrolled'); return loadAcademicData(true); })
      .then(()=>loadAdminData('academic'))
      .catch(err=>showToast(err.message || 'Enrollment failed.','error','Error'));
  };

  const originalSetAdminUserForm = typeof setAdminUserForm === 'function' ? setAdminUserForm : null;
  if(originalSetAdminUserForm){
    setAdminUserForm = function(role, user=null){
      originalSetAdminUserForm(role, user);
      const isStudent = role === 'student';
      ['admin-user-curriculum-wrap','admin-user-parent-wrap','admin-user-section-wrap'].forEach(id=>{
        const el=document.getElementById(id); if(el) el.style.display=isStudent?'':'none';
      });
      if(isStudent){
        loadAcademicData(false).then(()=>{
          const programSelect=document.getElementById('admin-user-program');
          if(programSelect){
            const programs=URAMS_ACADEMIC.programs||[];
            programSelect.innerHTML=programs.map(p=>opt(p.name, p.name, user?.program_id && Number(user.program_id)===Number(p.id))).join('');
            if(user?.program && !user?.program_id) programSelect.value=user.program;
          }
          academicStudentProgramChanged(user?.curriculum_version_id || null);
          const parentField=document.getElementById('admin-user-parent-identifier');
          if(parentField) parentField.value='';
          const sectionField=document.getElementById('admin-user-section-id');
          if(sectionField) sectionField.value='';
        });
      }
    };
  }

  const originalGetAdminUserFormPayload = typeof getAdminUserFormPayload === 'function' ? getAdminUserFormPayload : null;
  if(originalGetAdminUserFormPayload){
    getAdminUserFormPayload = function(){
      const payload = originalGetAdminUserFormPayload();
      const programName = document.getElementById('admin-user-program')?.value || payload.program || '';
      const program = (URAMS_ACADEMIC.programs || []).find(p=>p.name===programName || p.code===programName);
      payload.program = programName;
      payload.program_id = program ? Number(program.id) : Number(document.getElementById('admin-user-program-id')?.value || 0);
      payload.curriculum_version_id = Number(document.getElementById('admin-user-curriculum-id')?.value || 0);
      payload.parent_identifier = document.getElementById('admin-user-parent-identifier')?.value.trim() || '';
      payload.section_id = Number(document.getElementById('admin-user-section-id')?.value || 0);
      payload.section_ids = payload.section_id ? [payload.section_id] : [];
      payload.force_enroll = false;
      return payload;
    };
  }

  window.academicStudentProgramChanged = function(selectedCurriculumId=null){
    const programName = document.getElementById('admin-user-program')?.value || '';
    const program = (URAMS_ACADEMIC.programs || []).find(p=>p.name===programName || p.code===programName);
    const programIdEl = document.getElementById('admin-user-program-id');
    if(programIdEl) programIdEl.value = program ? program.id : '';
    const cvEl = document.getElementById('admin-user-curriculum-id');
    if(cvEl){
      const cvs = (URAMS_ACADEMIC.curricula || []).filter(c=>program && Number(c.program_id)===Number(program.id));
      cvEl.innerHTML = cvs.map(c=>opt(c.id, c.name, selectedCurriculumId && Number(selectedCurriculumId)===Number(c.id))).join('');
    }
    const deptEl=document.getElementById('admin-user-department');
    if(deptEl && program && (!deptEl.value || ['CSE','EEE','BBA','Pharmacy'].includes(deptEl.value))) deptEl.value=program.department || '';
  };

})();
