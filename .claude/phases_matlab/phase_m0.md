# Phase M-0 — Environment & Repo Setup

**Track:** MATLAB | **Owner:** All MATLAB members | **Day:** 1
**Blocks:** everything

---

## Goal
Every MATLAB member has MATLAB running, the repo cloned, two Day-1 proofs
done (ONNX import + uihtml bridge), and the data contract frozen.

---

## Features

### F1 — MATLAB Free Trial
Each member signs up individually at:
`mathworks.com/campaigns/products/trials.html`

Toolboxes to select during signup:
- Image Processing Toolbox
- Computer Vision Toolbox
- Deep Learning Toolbox
- Deep Learning Toolbox Model for ResNet-50 (support package — install separately from Add-On Explorer)
- Statistics and Machine Learning Toolbox
- Medical Imaging Toolbox
- Simulink
- SimEvents
- Parallel Computing Toolbox
- MATLAB Report Generator

---

### F2 — MATLAB Project + GitHub Repo
One member (team lead or B4) does this once:
```
MATLAB → Home → New → Project → Blank Project
Project name: Netra
Location: C:\Users\<name>\Netra
```
Create folder structure inside the project:
```matlab
folders = {'/data','/src/quality','/src/grade','/src/segment',...
           '/src/explain','/src/datalayer','/models','/app',...
           '/simulink','/images','/reports','/docs','/colab'};
for i = 1:numel(folders)
    mkdir(fullfile(projectRoot, folders{i}));
end
```
Initialize git, push to GitHub, create all phase branches.

---

### F3 — .gitignore
Create `/.gitignore` in the project root:
```
/data/
/models/*.onnx
/images/
/reports/
*.mat
.matlab/
*.asv
```

---

### F4 — Day-1 ONNX Import Test (non-negotiable)
Download any small ONNX model (e.g., squeezenet from ONNX Model Zoo) into `/models/`.
```matlab
% Run this before any other MATLAB work
try
    net = importONNXNetwork('models/test.onnx', 'OutputLayerType', 'classification');
    disp('ONNX import: OK')
catch e
    disp('ONNX import FAILED:')
    disp(e.message)
    % If this fails: check Deep Learning Toolbox version, try importNetworkFromONNX
end
```
If `importONNXNetwork` errors, try the newer API (R2023b+):
```matlab
net = importNetworkFromONNX('models/test.onnx');
```
Flag immediately if neither works — this blocks M-2 and M-3.

---

### F5 — Day-1 uihtml PoC (non-negotiable)
Proves two-way messaging before the dashboard is built on top of it.

Create `app/poc/poc.html`:
```html
<!DOCTYPE html>
<html>
<body>
  <button onclick="sendToMATLAB()">Ping MATLAB</button>
  <div id="reply">Waiting...</div>
  <script>
    function sendToMATLAB() {
      window.dispatchEvent(new CustomEvent('mlEvent', {detail: {type:'ping', data:{}}}));
    }
    window.addEventListener('message', function(e) {
      if (e.data.type === 'pong') {
        document.getElementById('reply').innerText = e.data.msg;
      }
    });
  </script>
</body>
</html>
```

Create `app/poc/PocApp.mlapp` in App Designer:
- Add a `uihtml` component pointing to `poc.html`
- Add `HTMLEventReceived` callback:
```matlab
function HTMLEventReceived(app, event)
    if strcmp(event.HTMLEventName, 'ping')
        sendEventToHTMLSource(app.HTMLComponent, 'pong', struct('msg','Hello from MATLAB'));
    end
end
```
Run the app — clicking the button should update the div with "Hello from MATLAB".
Flag immediately if the event does not fire — the whole dashboard depends on this.

---

### F6 — Data Contract
Create `docs/data_contract.json` — freeze this before parallel work begins.
```json
{
  "schemaVersion": "1.0",
  "patientId": "",
  "eye": "OD",
  "date": "",
  "quality": {
    "status": "gradable",
    "focusScore": 0,
    "illuminationScore": 0,
    "fovRatio": 0,
    "enhanced": false
  },
  "result": {
    "grade": 0,
    "gradeLabel": "No DR",
    "referable": false,
    "confidence": 0,
    "classProbabilities": [0, 0, 0, 0, 0]
  },
  "lesions": {
    "maCount": 0,
    "heCount": 0,
    "exudateAreaPct": 0,
    "nvPresent": false,
    "odCentroid": [0, 0]
  },
  "images": {
    "original": "",
    "enhanced": "",
    "gradcam": "",
    "lesionOverlay": "",
    "vesselMap": "",
    "evidence": ""
  },
  "history": {
    "priorGrades": [],
    "trend": ""
  },
  "routing": "routine_followup",
  "review": {
    "status": "pending",
    "finalGrade": null,
    "notes": "",
    "reviewerId": "",
    "timestamp": ""
  },
  "clinical": null,
  "secondaryFindings": null
}
```

---

## Done when
- [ ] All members have MATLAB running with all toolboxes
- [ ] Repo cloned and MATLAB Project opens cleanly on every machine
- [ ] `importONNXNetwork` test passes on at least one machine
- [ ] uihtml PoC — button → MATLAB → HTML reply working
- [ ] `data_contract.json` committed to `/docs/` and frozen
