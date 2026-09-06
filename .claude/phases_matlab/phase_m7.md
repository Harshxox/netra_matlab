# Phase M-7 — Frontend (App Designer + uihtml)

**Track:** MATLAB | **Owner:** B3 | **Day:** 4–6
**Depends on:** M-0 (uihtml PoC done), M-5 | **Blocks:** M-8

---

## Goal
Build the Netra dashboard in HTML/CSS/JS hosted inside MATLAB via `uihtml`.
Wire it to the pipeline so upload → full dashboard renders → decision saves.
All frontend code in `app/`. App Designer file: `app/NetraApp.mlapp`.

---

## Features

### F1 — App Shell (App Designer)
Create `app/NetraApp.mlapp`:
- Window title: "Netra — DR Screening"
- Full-screen layout (no scroll)
- One `uihtml` component (`app.Dashboard`) filling the window
- `app.Dashboard.HTMLSource = fullfile(pwd, 'app/dashboard.html')`

App startup callback:
```matlab
function startupFcn(app)
    app.nets = loadSegmentationNets();
    app.gradingNet = loadGradingNet();
    app.db = initDB();
    app.Dashboard.HTMLSource = fullfile(pwd, 'app/dashboard.html');
end
```

---

### F2 — Dashboard HTML Structure (`app/dashboard.html`)
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="dashboard.css">
</head>
<body>
  <!-- TOP BAR -->
  <header id="topbar">
    <input id="patientId" type="text" placeholder="Patient ID">
    <div class="toggle-group">
      <button class="toggle active" onclick="setEye('OD')">OD</button>
      <button class="toggle" onclick="setEye('OS')">OS</button>
    </div>
    <span id="qualityChip" class="chip">—</span>
    <span id="queueCount">0 pending</span>
    <span id="timer">0:30</span>
  </header>

  <!-- MAIN CONTENT -->
  <main id="content">
    <!-- LEFT: queue list -->
    <aside id="queue-panel">
      <h3>Review Queue</h3>
      <ul id="queue-list"></ul>
    </aside>

    <!-- CENTER: image viewer -->
    <section id="image-panel">
      <img id="fundusImg" src="" alt="Fundus image">
      <div id="layer-toggles">
        <button onclick="setLayer('original')">Original</button>
        <button onclick="setLayer('enhanced')">Enhanced</button>
        <button onclick="setLayer('gradcam')">Grad-CAM</button>
        <button onclick="setLayer('lesions')">Lesions</button>
        <button onclick="setLayer('vessels')">Vessels</button>
      </div>
    </section>

    <!-- RIGHT: results sidebar -->
    <aside id="results-panel">
      <div id="verdict-badge">—</div>
      <div id="grade-pips">
        <span class="pip" data-grade="0">0</span>
        <span class="pip" data-grade="1">1</span>
        <span class="pip" data-grade="2">2</span>
        <span class="pip" data-grade="3">3</span>
        <span class="pip" data-grade="4">4</span>
      </div>
      <div id="confidence-bar"><div id="conf-fill"></div></div>
      <div id="why-grade">
        <h4>Why this grade</h4>
        <ul id="why-list"></ul>
      </div>
      <table id="lesion-table">
        <tr><th>Lesion</th><th>Count</th></tr>
      </table>
    </aside>
  </main>

  <!-- ACTION BAR -->
  <footer id="action-bar">
    <button id="btn-agree" onclick="sendDecision('agree')">✓ Agree</button>
    <button id="btn-override" onclick="toggleOverride()">✎ Override</button>
    <div id="override-panel" hidden>
      <select id="override-grade">
        <option value="0">Grade 0 — No DR</option>
        <option value="1">Grade 1 — Mild</option>
        <option value="2">Grade 2 — Moderate</option>
        <option value="3">Grade 3 — Severe</option>
        <option value="4">Grade 4 — Proliferative</option>
      </select>
      <input id="override-notes" type="text" placeholder="Notes...">
    </div>
    <button id="btn-report" onclick="sendEvent('generateReport',{})">⬇ Generate PDF</button>
  </footer>

  <script src="dashboard.js"></script>
</body>
</html>
```

---

### F3 — Dashboard CSS (`app/dashboard.css`)
Key styles — dark navy theme, teal accents:
```css
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: #0F172A; color: #E2E8F0; font-family: 'Inter', sans-serif; height: 100vh; display: flex; flex-direction: column; }

#topbar { background: #1E293B; padding: 8px 16px; display: flex; align-items: center; gap: 16px; border-bottom: 1px solid #334155; }
#content { display: flex; flex: 1; overflow: hidden; }
#queue-panel { width: 200px; background: #1E293B; padding: 12px; border-right: 1px solid #334155; overflow-y: auto; }
#image-panel { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 16px; }
#fundusImg { max-height: 70vh; border-radius: 8px; }
#layer-toggles { display: flex; gap: 8px; margin-top: 8px; }
#results-panel { width: 280px; background: #1E293B; padding: 16px; border-left: 1px solid #334155; overflow-y: auto; }
#action-bar { background: #1E293B; padding: 10px 16px; display: flex; gap: 12px; border-top: 1px solid #334155; }

/* Verdict badge */
#verdict-badge { padding: 8px 16px; border-radius: 6px; font-weight: bold; text-align: center; margin-bottom: 12px; }
.verdict-refer   { background: #DC2626; }
.verdict-routine { background: #16A34A; }
.verdict-recapture { background: #D97706; }

/* Grade pips */
#grade-pips { display: flex; gap: 8px; margin-bottom: 12px; }
.pip { width: 32px; height: 32px; border-radius: 50%; border: 2px solid #475569; display: flex; align-items: center; justify-content: center; font-size: 12px; }
.pip.active { background: #0D9488; border-color: #0D9488; }

/* Confidence bar */
#confidence-bar { background: #334155; border-radius: 4px; height: 8px; margin-bottom: 12px; }
#conf-fill { background: #0D9488; height: 100%; border-radius: 4px; transition: width 0.3s; }

/* Buttons */
button { padding: 8px 16px; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; }
#btn-agree { background: #16A34A; color: white; }
#btn-override { background: #D97706; color: white; }
#btn-report { background: #475569; color: white; }
.toggle { background: #334155; color: #94A3B8; }
.toggle.active { background: #0D9488; color: white; }
.chip { padding: 4px 8px; border-radius: 12px; font-size: 12px; background: #334155; }
.chip.gradable { background: #16A34A; }
.chip.borderline { background: #D97706; }
.chip.ungradable { background: #DC2626; }
```

---

### F4 — Dashboard JS (`app/dashboard.js`)
```javascript
let currentData = {};
let selectedEye = 'OD';
let layerPaths = {};

// Receive data from MATLAB
window.addEventListener('message', function(e) {
  if (!e.data || !e.data.type) return;
  if (e.data.type === 'screeningData') {
    currentData = e.data.payload;
    renderDashboard(currentData);
  }
});

function renderDashboard(d) {
  // Quality chip
  const chip = document.getElementById('qualityChip');
  chip.textContent = d.quality.status;
  chip.className = 'chip ' + d.quality.status;

  // Verdict badge
  const badge = document.getElementById('verdict-badge');
  if (d.quality.status === 'ungradable') {
    badge.textContent = 'RECAPTURE';
    badge.className = 'verdict-recapture';
    return;
  }
  badge.textContent = d.result.referable ? 'REFER TO SPECIALIST' : 'ROUTINE FOLLOW-UP';
  badge.className = d.result.referable ? 'verdict-refer' : 'verdict-routine';

  // Grade pips
  document.querySelectorAll('.pip').forEach(p => {
    p.classList.toggle('active', parseInt(p.dataset.grade) <= d.result.grade);
  });

  // Confidence bar
  document.getElementById('conf-fill').style.width = (d.result.confidence * 100) + '%';

  // Why this grade
  const why = document.getElementById('why-list');
  why.innerHTML = [
    `<li>Microaneurysms: ${d.lesions.maCount}</li>`,
    `<li>Hemorrhages: ${d.lesions.heCount}</li>`,
    `<li>Exudate area: ${d.lesions.exudateAreaPct.toFixed(1)}%</li>`,
    `<li>Neovascularization: ${d.lesions.nvPresent ? 'Present' : 'Not detected'}</li>`
  ].join('');

  // Image layers
  layerPaths = {
    original: d.images.original,
    enhanced: d.images.enhanced,
    gradcam:  d.images.gradcam,
    lesions:  d.images.lesionOverlay,
    vessels:  d.images.vesselMap
  };
  setLayer('gradcam');
}

function setLayer(name) {
  if (layerPaths[name]) {
    document.getElementById('fundusImg').src = layerPaths[name];
  }
  document.querySelectorAll('#layer-toggles button').forEach(b => {
    b.classList.toggle('active', b.textContent.toLowerCase().includes(name));
  });
}

function setEye(eye) {
  selectedEye = eye;
  document.querySelectorAll('.toggle').forEach(b => b.classList.remove('active'));
  event.target.classList.add('active');
  sendEvent('eyeChanged', { eye: eye });
}

function sendDecision(type) {
  sendEvent('reviewDecision', {
    type: type,
    finalGrade: type === 'agree' ? currentData.result.grade : parseInt(document.getElementById('override-grade').value),
    notes: document.getElementById('override-notes').value
  });
}

function toggleOverride() {
  const p = document.getElementById('override-panel');
  p.hidden = !p.hidden;
}

function sendEvent(name, data) {
  window.dispatchEvent(new CustomEvent('mlEvent', { detail: { type: name, data: data }}));
}
```

---

### F5 — MATLAB Event Wiring (in `NetraApp.mlapp`)
```matlab
function HTMLEventReceived(app, event)
    switch event.HTMLEventName

        case 'reviewDecision'
            d = event.HTMLEventData;
            saveReviewDecision( ...
                app.currentRecord.patientId, ...
                app.currentRecord.eye, ...
                d.finalGrade, ...
                d.notes, ...
                'reviewer_001');

        case 'generateReport'
            reportPath = generateReport( ...
                app.currentRecord, ...
                app.currentRecord.images.gradcam, ...
                app.currentRecord.images.lesionOverlay);
            winopen(reportPath);

        case 'eyeChanged'
            app.currentEye = event.HTMLEventData.eye;
    end
end
```

---

### F6 — Push Pipeline Result to Dashboard
Called from main pipeline after all modules complete:
```matlab
function pushToDashboard(app, record)
    app.currentRecord = record;
    app.Dashboard.Data = jsonencode(record);
    % Trigger JS render via sendEventToHTMLSource
    sendEventToHTMLSource(app.Dashboard, 'screeningData', record);
end
```

---

## Done when
- [ ] Upload image in app → dashboard renders grade, confidence, overlays
- [ ] Layer toggle buttons switch between Original/Enhanced/Grad-CAM/Lesions/Vessels
- [ ] Agree button saves review to data layer
- [ ] Override sets finalGrade from dropdown + notes
- [ ] Generate PDF opens the report
- [ ] Ungradable path shows recapture banner, hides grading panel
