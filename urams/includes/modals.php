<?php
// includes/modals.php
// Step: Common modal HTML. Teacher/Admin/Student panel er popup ekhane ache.
?>
<!-- ═══════════════════════════════════════════════════════════════
     MODALS
     ═══════════════════════════════════════════════════════════════ -->

<!-- Add Marks Modal -->
<div class="modal-overlay" id="modal-add-marks">
  <div class="modal">
    <div class="modal-header">
      <div class="modal-title"><i class="fas fa-plus-circle" style="color:var(--primary)"></i> Add Exam Column</div>
      <button class="modal-close" onclick="closeModal('modal-add-marks')"><i class="fas fa-times"></i></button>
    </div>
    <div class="modal-body">
      <p style="color:var(--text2);font-size:13px;margin-bottom:20px">Create a new exam column for this section. This will appear in the result table.</p>
      <div class="form-group">
        <label class="form-label">Exam Type Name</label>
        <select class="form-control" id="exam-type-select" onchange="examTypeChanged()">
          <option value="">-- Select or type custom --</option>
          <option>CT</option><option>Assignment</option><option>Mid</option><option>Final</option>
          <option>Lab Report</option><option>Quiz</option><option>Presentation</option><option>Report</option>
        </select>
        <input type="text" class="form-control" placeholder="Or type custom exam name..." id="exam-type-custom" style="margin-top:8px">
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <div class="form-group">
          <label class="form-label">Taken Out Of</label>
          <input type="number" class="form-control" placeholder="e.g. 30" id="am-taken">
        </div>
        <div class="form-group">
          <label class="form-label">Convert To</label>
          <input type="number" class="form-control" placeholder="e.g. 15" id="am-convert">
        </div>
      </div>
      <div class="form-group">
        <label class="form-label">Exam Date</label>
        <input type="date" class="form-control" id="am-date">
      </div>
      <div class="form-group">
        <label class="form-label" style="display:flex;align-items:center;gap:6px">
          <input type="checkbox" id="am-bestof" onchange="toggleBestOf()"> Best of N logic (picks highest scores)
        </label>
      </div>
      <div id="bestof-count-wrap" style="display:none">
        <div class="form-group">
          <label class="form-label">Pick Best N (count)</label>
          <input type="number" class="form-control" value="1" min="1" id="am-bestof-count">
        </div>
      </div>
    </div>
    <div class="modal-footer">
      <button class="btn btn-secondary" onclick="closeModal('modal-add-marks')">Cancel</button>
      <button class="btn btn-primary" onclick="submitAddMarks()"><i class="fas fa-plus"></i> Add Column</button>
    </div>
  </div>
</div>

<!-- Grace Modal -->
<div class="modal-overlay" id="modal-grace">
  <div class="modal">
    <div class="modal-header">
      <div class="modal-title"><i class="fas fa-star" style="color:var(--gold)"></i> Add Grace Marks</div>
      <button class="modal-close" onclick="closeModal('modal-grace')"><i class="fas fa-times"></i></button>
    </div>
    <div class="modal-body">
      <div class="form-group">
        <label class="form-label">Apply To</label>
        <select class="form-control">
          <option>All Students</option><option>Select Individual Students</option>
        </select>
      </div>
      <div class="form-group">
        <label class="form-label">Grace Marks to Add</label>
        <input type="number" class="form-control" min="0" max="10" value="1" id="grace-amount">
      </div>
      <div style="background:rgba(245,158,11,0.1);border:1px solid rgba(245,158,11,0.3);border-radius:8px;padding:12px;font-size:12px;color:var(--text2)">
        ⚠️ Grace marks will be added on top of converted marks. Max 5 grace allowed per exam.
      </div>
    </div>
    <div class="modal-footer">
      <button class="btn btn-secondary" onclick="closeModal('modal-grace')">Cancel</button>
      <button class="btn btn-warning" onclick="applyGrace()"><i class="fas fa-star"></i> Apply Grace</button>
    </div>
  </div>
</div>

<!-- Confirm Dialog -->
<div class="modal-overlay" id="modal-confirm">
  <div class="modal confirm-dialog">
    <div class="modal-body" style="text-align:center;padding:32px 24px">
      <div class="confirm-icon" id="confirm-icon" style="background:rgba(16,185,129,0.12);color:var(--success)"><i class="fas fa-check-circle"></i></div>
      <h3 id="confirm-title" style="margin-bottom:8px">Are you sure?</h3>
      <p id="confirm-msg" style="color:var(--text2);font-size:13px"></p>
    </div>
    <div class="modal-footer" style="justify-content:center">
      <button class="btn btn-secondary" onclick="closeModal('modal-confirm')">Cancel</button>
      <button class="btn btn-success" id="confirm-ok-btn" onclick="confirmAction()">Confirm</button>
    </div>
  </div>
</div>

<!-- Student Detail Modal -->
<div class="modal-overlay" id="modal-student">
  <div class="modal modal-lg">
    <div class="modal-header">
      <div class="modal-title">Student Profile</div>
      <button class="modal-close" onclick="closeModal('modal-student')"><i class="fas fa-times"></i></button>
    </div>
    <div class="modal-body" id="modal-student-body"></div>
  </div>
</div>

<!-- Percent Modal -->
<div class="modal-overlay" id="modal-percent">
  <div class="modal">
    <div class="modal-header">
      <div class="modal-title" id="percent-modal-title">% Distribution</div>
      <button class="modal-close" onclick="closeModal('modal-percent')"><i class="fas fa-times"></i></button>
    </div>
    <div class="modal-body">
      <canvas id="percent-chart" height="220"></canvas>
    </div>
  </div>
</div>

<!-- Forgot Password Modal -->
<div class="modal-overlay" id="modal-forgot">
  <div class="modal">
    <div class="modal-header">
      <div class="modal-title">Forgot Password</div>
      <button class="modal-close" onclick="closeModal('modal-forgot')"><i class="fas fa-times"></i></button>
    </div>
    <div class="modal-body" style="text-align:center;padding:32px 24px">
      <div style="font-size:48px;margin-bottom:16px">📧</div>
      <h3 style="margin-bottom:8px">Need help?</h3>
      <p style="color:var(--text2);margin-bottom:16px;font-size:13px">Contact UIU IT Support to reset your password.</p>
      <a href="mailto:support@uiu.ac.bd" class="btn btn-primary" style="display:inline-flex"><i class="fas fa-envelope"></i> support@uiu.ac.bd</a>
    </div>
  </div>
</div>

<!-- Reject Modal -->
<div class="modal-overlay" id="modal-reject">
  <div class="modal">
    <div class="modal-header">
      <div class="modal-title"><i class="fas fa-times-circle" style="color:var(--danger)"></i> Reject Result</div>
      <button class="modal-close" onclick="closeModal('modal-reject')"><i class="fas fa-times"></i></button>
    </div>
    <div class="modal-body">
      <div class="form-group">
        <label class="form-label">Rejection Reason</label>
        <textarea class="form-control" rows="4" placeholder="Enter the reason for rejection..." id="reject-reason"></textarea>
      </div>
    </div>
    <div class="modal-footer">
      <button class="btn btn-secondary" onclick="closeModal('modal-reject')">Cancel</button>
      <button class="btn btn-danger" onclick="submitReject()"><i class="fas fa-times"></i> Reject &amp; Notify Teacher</button>
    </div>
  </div>
</div>

