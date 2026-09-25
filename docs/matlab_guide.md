# MATLAB Track — Solo 3-Day Build Guide

> You, alone, 3 days, beginner. This overrides the 7-day / 5-person plan in
> `phases_matlab.md`. Scope is cut to what one person can demo.

---

## Running the app

```matlab
cd  <repo>\netra
addpath(genpath('src')); addpath('app')
NetraApp
```

**Login (prototype credentials — `src/datalayer/checkAuth.m`):**

| User | Password | Role |
|---|---|---|
| `phc` | `phc2026` | operator — register patients, run screenings |
| `doctor` | `doctor2026` | operator |
| `admin` | `netra2026` | district console — all patients + data |

**Flow:** login → (operator) find or register a patient → screening dashboard
(open fundus image → results → Agree/Override → Open report) · (admin) console
with stat tiles + patient table → click a patient for the full dossier.

**Data:** `netra_patients.mat` (profiles) + `netra_db.mat` (screenings), linked
by patient id, both persist across sessions. `seedDemoPatients` populates a demo
cohort; `test_app` checks the data layer.

---

## 0. The one strategic decision

**Do not bet the demo on the Colab ONNX models arriving on time and working.**
They might not. So the pipeline is built on **classical MATLAB image processing**
as the backbone, and ONNX models are *slotted in if/when they arrive*.

| Piece | Primary (always works) | Upgrade (if Colab delivers) |
|---|---|---|
| Lesion detection | Morphology: top-hat / bottom-hat on green channel | `ma/he/ex_unet.onnx` |
| DR grade | Rules from lesion counts (see §4) | `dr_grader.onnx` |
| Explainability | Lesion overlay + rule breakdown | + Grad-CAM heatmap |
| Vessels | `fibermetric` / Frangi filter (built-in) | `vessel_unet.onnx` |

Everything below is the classical path. Each module has a `useONNX` flag you
flip later.

---

## 3-Day timetable

### DAY 1 — setup + preprocessing + lesion detection
- [ ] **M-0 (≈2h)** — run the 3 setup scripts (see §1). Get all 3 to pass.
- [ ] Download **10–20 APTOS fundus images** into `data/samples/` (Kaggle:
      "APTOS 2019 Blindness Detection"). Pick a spread: some grade 0, some 3–4.
- [ ] **M-1 preprocessing** (`src/quality/`) — crop FOV, green channel, CLAHE,
      quality score + gradable/borderline/ungradable. Test on your 20 images.
- [ ] **Lesion detection v1** (`src/segment/detectLesionsClassical.m`) —
      microaneurysms + hemorrhages (dark blobs) via bottom-hat; exudates
      (bright blobs) via top-hat. Count them. Save a colour overlay PNG.

### DAY 2 — grading + explainability + report
- [ ] **M-2 grading** (`src/grade/`) — `gradeFromRules(lesionCounts)` returns
      grade 0–4 + referable + a confidence proxy. If `dr_grader.onnx` exists,
      add `runGradingONNX()` and prefer it.
- [ ] **M-4 explainability** (`src/explain/`) — evidence overlay (lesion
      contours on the fundus) + "why this grade" bullet list. Add Grad-CAM
      **only if** the ONNX grader works.
- [ ] **PDF report** (`src/explain/generateReport.m`) — MATLAB Report
      Generator, one page: grade, referable, overlay image, lesion table,
      disclaimer.
- [ ] **M-8 `runPipeline.m`** — wire M-1 → lesions → grade → explain → PDF
      into one function returning the data-contract struct.

### DAY 3 — UI + Simulink slide + deck + rehearse
- [ ] **M-7 UI** — minimal. Two options, pick by 11:00:
      - A) `uihtml` dashboard (if `poc_test` passed cleanly) — verdict badge,
        grade pips, confidence bar, image with 3 layer toggles, Agree button.
      - B) **Plain App Designer** — `uiimage` + `uilabel`s + 3 `uibutton`
        toggles. Uglier, zero risk. Totally fine for a 3-day prototype.
- [ ] **M-6 substitute** — `simulink/queueSim.m` (plain MATLAB, ~60 lines,
      given in §5). Produces the "district needs N reviewers" number for the
      slide. Build a 4-block SimEvents model only if you have spare time.
- [ ] **Minimal data layer** — `src/datalayer/saveScreening.m` +
      `getHistory.m` over a struct array in a `.mat` file. 30 min.
- [ ] **PPT (7 slides)** — template in `phases_matlab.md` M-8 F5. Use real
      screenshots from your pipeline.
- [ ] **Rehearse the < 30s demo** 5 times.

**If you fall behind:** drop the `uihtml` dashboard (use App Designer B),
drop the SimEvents model (keep `queueSim.m`), drop patient history. Never
drop: preprocessing, lesion overlay, a grade, the PDF, the deck.

---

## 1. M-0 — do this now (all files are in `setup/` and `app/poc/`)

```matlab
>> cd  C:\Users\sharm\Desktop\SIH PROJECT\netra2.0\netra
>> setup\m0_setup                 % makes folders, Project, adds path
>> setup\m0_check_toolboxes       % all REQUIRED rows must say OK
>> setup\m0_onnx_test             % needs models\test.onnx first (see below)
>> app\poc\poc_test               % click the button -> box must update
```

**Get a test ONNX model** before `m0_onnx_test`: download ResNet-50 opset-11
from the ONNX Model Zoo (github.com/onnx/models → vision → classification →
resnet), save as `models\test.onnx`.

**M-0 passes when:**
- `m0_check_toolboxes` — every REQUIRED row is `OK`
- `m0_onnx_test` — imports, no placeholder layers, forward pass prints an output size
- `poc_test` — clicking "Ping MATLAB" changes the box to "Hello from MATLAB"

Then commit:
```bash
git add .gitignore docs/ setup/ app/poc/
git commit -m "M-0: setup scripts, data contract, corrected uihtml PoC"
```

### Why the PoC in phases_matlab.md is wrong
It uses `window.dispatchEvent(new CustomEvent('mlEvent'))` and
`window.addEventListener('message', ...)`. That is generic browser iframe
messaging — **`uihtml` does not use it.** The real API:

- MATLAB defines a **global JS function `setup(htmlComponent)`** — `uihtml`
  calls it automatically.
- `htmlComponent.sendEventToMATLAB(name, data)` — HTML → MATLAB
- `htmlComponent.addEventListener(name, cb)` — receives MATLAB → HTML
- MATLAB: `h.HTMLEventReceivedFcn` callback; `sendEventToHTMLSource(h, name, data)`

The corrected versions are in `app/poc/poc.html` and `app/poc/poc_test.m`.
The M-7 dashboard JS must follow the same pattern.

---

## 2. MATLAB concepts you'll trip on (read once)

1. **Image types.** `imread` → `uint8` (0–255). Models/math → `im2double` or
   `im2single` (0–1). A `double` image with 0–255 values shows as white.
   Always know which you hold.
2. **Green channel.** `g = img(:,:,2);` — best contrast for retinal lesions.
   Every phase works on it.
3. **`dlarray` formats** (only if you use ONNX). Label dims:
   `dlarray(x,'SSCB')` = height, width, channel, batch. **Batch is last** in
   MATLAB (PyTorch puts it first). Never `reshape` a `dlarray` — it strips
   the labels. `predict` auto-permutes based on labels.
4. **`importNetworkFromONNX`** (R2023b+, returns `dlnetwork`) — use this, not
   the older `importONNXNetwork`. `gradCAM`, `predict` all want `dlnetwork`.
5. **`persistent`** — load a model once, cache between calls:
   ```matlab
   function net = loadGradingNet()
       persistent n
       if isempty(n); n = importNetworkFromONNX("models/dr_grader.onnx"); end
       net = n;
   end
   ```
6. **The data contract is a struct.** `jsonencode`/`jsondecode`. Field names
   must match `docs/data_contract.json` exactly (case-sensitive). Each module
   fills only its block: `record.quality.*`, `record.result.*`, etc.

---

## 3. Lesion detection without training (Day 1–2)

Classic retinal morphology. `src/segment/detectLesionsClassical.m`:

```
green = img(:,:,2), im2double
g = adapthisteq(green, 'ClipLimit', 0.01)          % CLAHE
% dark lesions (MA + hemorrhages): they are darker than background
darkTH = imbothat(g, strel('disk', 8));            % bottom-hat = dark spots
darkBW = imbinarize(darkTH, graythresh(darkTH)*1.2);
darkBW = bwareafilt(darkBW, [4 400]);              % size filter
% small round -> MA ; larger/irregular -> HE  (split by area)
% bright lesions (exudates): brighter than background, exclude optic disc
brightTH = imtophat(g, strel('disk', 12));
brightBW = imbinarize(brightTH, graythresh(brightTH)*1.3);
brightBW = brightBW & ~opticDiscMask;             % OD is also bright
% counts
maCount = <# dark components with area < 30>
heCount = <# dark components with area >= 30>
exudateAreaPct = 100 * nnz(brightBW) / nnz(fovMask)
```

Optic disc (for excluding exudates + landmark): brightest large region —
`imdilate(imregionalmax(imgaussfilt(g,15)))` or just the max-intensity blob
after a big Gaussian blur. Good enough for a prototype.

Vessels (one dashboard layer): `fibermetric(g, 8, 'ObjectPolarity','dark')`
then threshold. Built-in, no training.

This gives you a real, defensible, **explainable** lesion overlay with zero
dependency on Colab.

---

## 4. Rules-based grader (Day 2 fallback)

`src/grade/gradeFromRules.m` — ICDR-inspired, from lesion counts:

```
if nvPresent                        -> grade 4 (Proliferative)
elseif heCount >= 20 || maCount>=20 in all 4 quadrants  -> grade 3 (Severe)
elseif heCount >= 1 || exudateAreaPct > 0 || maCount >= 6 -> grade 2 (Moderate)
elseif maCount >= 1                  -> grade 1 (Mild)
else                                -> grade 0 (No DR)
referable = grade >= 2
confidence = min(0.95, 0.55 + 0.1*distanceFromThreshold)   % a proxy, be honest it's heuristic
```

Say in the deck: "classical CV baseline; the ResNet-50 grader (trained on
APTOS, QWK 0.8x) plugs into the same interface." If `dr_grader.onnx` lands,
`runGradingONNX()` returns the same struct and `runPipeline` prefers it.

---

## 5. Simulink substitute — `simulink/queueSim.m`

Plain MATLAB discrete-event queue. Gives you the PPT number in one afternoon.

```matlab
function stats = queueSim(arrivalsPerDay, nReviewers, aiSec, revSec, days)
    lambda = arrivalsPerDay/86400;  T = days*86400;
    arr = cumsum(exprnd(1/lambda, [ceil(1.3*arrivalsPerDay*days) 1]));
    arr = arr(arr < T);  n = numel(arr);
    aiDone = zeros(n,1); revStart = zeros(n,1); revDone = zeros(n,1);
    srv = zeros(nReviewers,1); aiFree = 0;
    for i = 1:n
        aiFree = max(aiFree, arr(i)) + max(1, normrnd(aiSec, aiSec/6));
        aiDone(i) = aiFree;
        [t,s] = min(srv);
        revStart(i) = max(aiDone(i), t);
        revDone(i)  = revStart(i) + max(1, normrnd(revSec, revSec/4));
        srv(s) = revDone(i);
    end
    w = revStart - aiDone;
    stats.meanWaitHrs = mean(w)/3600;
    stats.p95WaitHrs  = prctile(w,95)/3600;
    stats.throughputPerDay = n/days;
    stats.reviewerUtil = sum(revDone-revStart)/(nReviewers*T);
end

% sweep for the slide:
for nRev = 1:10
    s = queueSim(274, nRev, 30, 60, 30);
    fprintf('%2d reviewers: mean %.1fh  p95 %.1fh  util %.0f%%\n', ...
        nRev, s.meanWaitHrs, s.p95WaitHrs, 100*s.reviewerUtil);
end
```

100k patients/year ≈ 274/day. Find the smallest `nRev` with `p95WaitHrs < 24`.

---

## 6. Known bugs in the phases_matlab.md pseudo-code

Fix these when you copy code out of the phase files:

| File | Bug | Fix |
|---|---|---|
| `phase_m0.md` F5, `phase_m7.md` F4 | uihtml PoC uses `postMessage`/`CustomEvent('mlEvent')` | Use `setup(htmlComponent)` + `sendEventToMATLAB` (see `app/poc/`) |
| `phase_m2.md` F2–F3 | `reshape(dlImg,[1 size(dlImg)])` to add batch | `dlarray(single(x),'SSCB')`, batch is implicit/last |
| `phase_m2.md` F3 | unconditional `exp/sum` softmax | ask Colab if ONNX already ends in Softmax; use max-subtracted softmax |
| `phase_m3.md` F1 | `'OutputLayerType','pixelclassification'` on a raw U-Net | `importNetworkFromONNX(file)` → dlnetwork, no output layer |
| `phase_m4.md` F1 | `gradCAM` auto-detects layers (fails on imported ONNX) | pass `'FeatureLayer'` (last conv) + `'ReductionLayer'`; or use `occlusionSensitivity` |
| `phase_m4.md` F5 | `Table({{...};{...}})` cell-of-cells | pass a 2-D cell array |
| `phase_m6.md` F7 | `simOut.avgWaitTime` — no such auto output | log via statistics ports, or use `queueSim.m` |
| `phase_m8.md` F1 | `datestr(now,...)` deprecated | `string(datetime('now'))` |
| `phase_m8.md` F3 | `kappacalc` not built-in | write QWK from `confusionmat` + quadratic weights |

---

## 7. Definition of "demo-ready" (end of Day 3)

- `runPipeline('data/samples/grade3.png','PT-DEMO-001','OD')` returns a full
  struct in < 15s.
- An overlay PNG shows colour-coded lesions on the fundus.
- A one-page PDF opens with grade, referable verdict, overlay, lesion table,
  disclaimer.
- Some UI (uihtml or App Designer) shows the verdict + image + an Agree button.
- `queueSim` sweep prints the reviewer number for the slide.
- 7-slide deck with real screenshots.
- You can run the whole demo in under 30 seconds without thinking.
