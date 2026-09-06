# MATLAB Track — Pipeline Phases (PS 26038)

> Owners: 5 MATLAB members.
> Tool: MATLAB R2023b+ (30-day free trial — sign up individually at mathworks.com).
> Input: raw fundus image + ONNX models from the shared Google Drive.
> Output: grade, explanation, PDF report, dashboard, Simulink model.

All code lives in `/src/<module>/*.m`, `/app/`, `/simulink/`.

---

## M-0 — Environment & Repo Setup  *(Day 1 — blocks everyone)*

- [ ] Every member signs up for MATLAB 30-day free trial (individual emails)
- [ ] Install toolboxes: Image Processing, Computer Vision, Deep Learning +
      ResNet-50 support package, Statistics & ML, Simulink + SimEvents,
      Parallel Computing, Medical Imaging
- [ ] One member creates the **MATLAB Project** (`.prj`) + GitHub repo
- [ ] Agree and create folder layout:
      `/data`, `/src`, `/models`, `/app`, `/simulink`, `/images`, `/reports`, `/docs`, `/colab`
- [ ] Add `.gitignore`:
      `/data/`, `/models/*.onnx`, `/images/`, `/reports/`, `*.mat`, `.matlab/`
- [ ] Create GitHub branches:
      `phase-0-setup`, `phase-1-preprocessing`, `phase-2-grading`,
      `phase-3-segmentation`, `phase-4-explainability`, `phase-5-datalayer`,
      `phase-6-simulink`, `phase-7-frontend`, `phase-8-integration`
- [ ] **Day-1 ONNX import test** (non-negotiable — do before anything else):
  ```matlab
  % Download any dummy .onnx from the internet into /models/
  net = importONNXNetwork('models/test.onnx', 'OutputLayerType', 'classification');
  disp('ONNX import works') % if this errors, flag immediately
  ```
- [ ] **Day-1 `uihtml` PoC** (non-negotiable — do before building the dashboard):
  ```matlab
  % Create a minimal App Designer app with a uihtml component
  % HTML: button click → sendEventToMATLAB('ping', {})
  % MATLAB: HTMLEventReceived callback → sendEventToHTMLSource(comp, 'pong', struct('msg','hello'))
  % HTML: receives pong → updates a div with 'hello'
  ```
  If the two-way bridge does not work, do not build the dashboard on top of it.
- [ ] Add `data_contract.json` to `/docs/` — freeze before parallel work begins
- [ ] All members clone the repo and confirm MATLAB Project opens cleanly

**Done when:** every MATLAB member has MATLAB running, ONNX import tested, `uihtml` bridge proven, repo cloned and open.

---

## M-1 — Preprocessing & Quality Check  *(src/quality/)*

- [ ] `cropFOV(img)` — detect retina circle via thresholding on green channel, return cropped image + circle mask
- [ ] `resizeNormalize(img, targetSize)` — resize to `targetSize`, normalize pixel values to [0,1]
- [ ] `extractGreenChannel(img)` — returns single-channel green image for downstream use
- [ ] `qualityScore(img)` — returns three scores:
  - `focusScore` — Laplacian variance of green channel
  - `illuminationScore` — mean intensity of green channel
  - `fovRatio` — retina circle area / total image area
- [ ] `classifyQuality(scores)` → `'gradable'` / `'borderline'` / `'ungradable'`
      (tune thresholds on a small held-out set of known good/bad images)
- [ ] `enhanceImage(img)` — for borderline images:
  - CLAHE: `adapthisteq(greenChannel, 'ClipLimit', 0.02)`
  - Illumination normalization
  - Gaussian denoise: `imgaussfilt(img, 1)`
- [ ] `buildQualityBlock(scores, status)` → fills `quality` block of the JSON struct
- [ ] Reject path: if `status == 'ungradable'` → set `routing = 'recapture'` and return early

**Done when:** `runQualityPipeline(imagePath)` returns enhanced image + filled `quality` JSON block for any input image.

---

## M-2 — DR Grading Inference  *(src/grade/)*

> Depends on Colab delivering `dr_grader.onnx` + `referable_threshold.txt`.

- [ ] Download `dr_grader.onnx` from Google Drive into `/models/`
- [ ] Import and cache the network at startup:
  ```matlab
  net = importONNXNetwork('models/dr_grader.onnx', 'OutputLayerType', 'classification');
  ```
- [ ] `preprocessForClassifier(img)` — resize to 224×224, normalize with ImageNet mean/std, convert to `dlarray`
- [ ] `runGrading(net, img)` → returns raw logits + softmax probabilities
- [ ] Apply softmax: `probs = softmax(logits, 'DataFormat', 'CB')`
- [ ] Map probabilities → `grade` (argmax), `gradeLabel` string, `confidence` (max prob)
- [ ] Load `referable_threshold.txt`; apply to P(grade≥2) → `referable` boolean
- [ ] `buildResultBlock(grade, probs, referable)` → fills `result` block of JSON struct

**Done when:** `runGrading(net, imagePath)` returns grade 0–4 + referable flag + confidence matching Colab validation numbers.

---

## M-3 — Segmentation Inference  *(src/segment/)*

> Depends on Colab delivering all 6 segmentation ONNX files.

- [ ] Download from Google Drive into `/models/`:
      `vessel_unet.onnx`, `ma_unet.onnx`, `he_unet.onnx`, `ex_unet.onnx`, `nv_unet.onnx`, `od_detector.onnx`
- [ ] Import all models at startup (cache in persistent variables — avoid re-loading per image)
- [ ] `preprocessForSegmentation(img)` — resize to 512×512, extract green channel, normalize to [0,1]
- [ ] `runVesselSegmentation(net, img)` → binary vessel mask
- [ ] `runLesionSegmentation(nets, img)` → four binary masks (MA, HE, EX, NV)
- [ ] `runODDetector(net, img)` → optic disc bounding box + centroid (x, y)
- [ ] Lesion quantification:
  - `maCount` — connected components in MA mask
  - `heCount` — connected components in HE mask
  - `nvPresent` — any NV pixels above threshold
  - `exudateAreaPct` — EX mask area / FOV circle area × 100
- [ ] Generate overlay images:
  - `lesion_overlay.png` — color-coded: MA=red, HE=blue, EX=yellow, NV=magenta
  - `vessel_map.png` — binary vessel mask as grayscale
  - Save to `/images/<patientId>/`
- [ ] `buildLesionsBlock(counts, paths)` → fills `lesions` block of JSON struct

**Done when:** `runSegmentation(nets, imagePath, patientId)` returns all four lesion masks + vessel map + counts + saved overlay images.

---

## M-4 — Explainability & Reporting  *(src/explain/)*

- [ ] `generateGradCAM(net, img, classIdx)`:
  ```matlab
  map = gradCAM(net, dlimg, classIdx);
  heatmap = imresize(map, [H W]);  % resize to original image dims
  ```
  Note: `gradCAM` works directly on the imported ONNX `dlnetwork` object
- [ ] `overlayHeatmap(img, heatmap)` — jet colormap alpha-blended onto fundus image; save as `gradcam.png`
- [ ] `buildEvidenceView(img, heatmap, lesionMasks)` — align lesion masks with Grad-CAM; save as `evidence.png`
- [ ] Optional: `occlusionSensitivity(net, img, classIdx)` — if Grad-CAM and occlusion agree on same region, flag `xaiAgreement = true`
- [ ] **Confidence calibration**:
  - Temperature scalar T calibrated by Colab team on validation logits
  - Store T in `models/temperature.mat`
  - Apply at inference: `calibratedProbs = softmax(logits / T)`
- [ ] **PDF report** via MATLAB Report Generator:
  - Patient ID, date, eye (OD/OS), quality status
  - Grade + referable verdict (large, bold)
  - Calibrated confidence + per-class probability bars
  - Grad-CAM heatmap image
  - Lesion overlay image + counts table (MA / HE / EX / NV)
  - Routing recommendation
  - Footer: *"Prototype only. Not a certified medical device."*
  - Save to `/reports/<patientId>_<date>.pdf`
- [ ] Update JSON `images` block with paths: `gradcam`, `lesionOverlay`, `vesselMap`, `evidence`

**Done when:** every prediction produces a Grad-CAM overlay, evidence view, calibrated confidence, and a one-page PDF — reviewable in under 30 seconds.

---

## M-5 — Data Layer & Patient History  *(src/datalayer/)*
*(runs parallel to M-6)*

- [ ] Define `ScreeningRecord` struct matching `data_contract.json` fields exactly
- [ ] `initDB()` — load `netra_db.mat` on startup; create empty table if file doesn't exist
- [ ] `saveScreening(record)` — append row to table + save `.mat` back to disk
- [ ] `getHistory(patientId)` → returns all prior records for that patient, sorted by date
- [ ] `buildHistoryBlock(records)` → fills `history` block of JSON:
  - Array of prior grades with timestamps
  - `trend` string: e.g. `"No DR → Mild → Moderate over 8 months"`
- [ ] Expose clean interface to pipeline:
  ```matlab
  saveScreening(record)        % called after every completed screening
  history = getHistory(pid)    % called at case load time
  ```

**Done when:** entering a known patient ID returns prior grades + a human-readable trend string.

---

## M-6 — Simulink Telemedicine Model  *(simulink/; one dedicated owner)*
*(runs parallel to M-5)*

- [ ] Create Simulink model file: `simulink/netra_telemedicine.slx`
- [ ] Model the pipeline flow using **SimEvents** discrete-event blocks:
  - **Source** — patient image arrivals (Poisson process, rate = 100,000/year = ~274/day)
  - **Queue** — bandwidth-limited upload queue (configurable: 2 / 10 / 50 Mbps)
  - **Server 1** — AI pipeline processing (configurable mean service time)
  - **Queue 2** — ophthalmologist review queue
  - **Server 2** — reviewer (configurable count: 1 to 10 reviewers)
  - **Sink** — completed cases
- [ ] Surface metrics via Dashboard blocks:
  - Queue wait time (mean + 95th percentile)
  - Reviewer utilization %
  - Total throughput (cases/day)
  - Referral rate
- [ ] Run three scenarios:
  - Low bandwidth (2 Mbps rural uplink)
  - Medium bandwidth (10 Mbps)
  - High bandwidth (50 Mbps)
- [ ] Sweep reviewer count (1 → 10); find the minimum count to keep wait time < 24 hours
- [ ] Export summary stats table for the PPT deck

**Done when:** model shows how many reviewers a district needs, where throughput bottlenecks, and how bandwidth affects queue wait times.

---

## M-7 — Frontend (App Designer + uihtml)  *(app/)*

> Do not start until the Day-1 `uihtml` PoC (M-0) is confirmed working.

### HTML/CSS/JS Dashboard  *(app/dashboard.html)*
- [ ] Dark navy theme (`#0F172A` background, `#0D9488` teal accents)
- [ ] **Top bar**: Patient ID input, OD/OS toggle, quality chip, queue counter, 30s countdown timer
- [ ] **Left panel**: case review queue — list of patient cards (ID, severity dot, timestamp); click to load
- [ ] **Center panel**: fundus image viewer + 5 toggle buttons (Original / Enhanced / Grad-CAM / Lesions / Vessels)
- [ ] **Right sidebar**:
  - Verdict badge — REFER (red) / ROUTINE (green) / RECAPTURE (amber)
  - Grade pips — 5 circles (0–4), filled up to current grade
  - Confidence bar (teal, calibrated %)
  - Per-class probability bars (grades 0–4)
  - "Why this grade" — bullet list (MA count, HE count, NV present, EX area%)
  - Lesion counts table (MA / HE / EX / NV)
- [ ] **Action bar**: Agree (green) / Override (amber → opens grade picker + notes field) / Route / Generate PDF
- [ ] Ungradable path: hide grading panel, show recapture message banner

### MATLAB App Designer Wiring  *(app/NetraApp.mlapp)*
- [ ] Create App Designer app; embed `uihtml` component pointing to `dashboard.html`
- [ ] On image upload: run full pipeline → populate JSON struct → push to HTML:
  ```matlab
  comp.Data = jsonencode(screeningRecord);
  ```
- [ ] `HTMLEventReceived` callback: receive `review` block from HTML → call `saveScreening()`
- [ ] Handle layer toggle events from HTML → load the correct image path → push back to HTML
- [ ] Handle "Generate PDF" event → call reporting module → open PDF

**Done when:** upload image in app → full dashboard renders from real pipeline output → Agree/Override saves to data layer.

---

## M-8 — Integration, Validation & Deck

- [ ] Wire all modules into one end-to-end call:
  ```
  image → qualityPipeline → segmentation → grading → explainability → saveScreening → dashboard
  ```
- [ ] Confirm all ONNX model versions documented in `docs/model_registry.md` with Drive links
- [ ] **External validation on Messidor-2** (never trained on):
  - Run full pipeline on all Messidor-2 images
  - Report: sensitivity, specificity for referable DR (grade ≥ 2)
  - Report: QWK for grading
  - Compare against published Messidor-2 benchmarks
- [ ] Error handling:
  - Ungradable → recapture path works end-to-end in the app
  - ONNX import failure → graceful error message
  - Unknown patient → new record created automatically
- [ ] **PPT deck** (7 slides):
  1. Problem — 77M diabetics, rural specialist shortage
  2. Pipeline diagram (use the workflow image generated earlier)
  3. Grad-CAM + lesion evidence screenshot from real output
  4. Simulink model + district numbers (reviewer count, wait times)
  5. Metrics — sensitivity, specificity, QWK vs. Messidor-2 benchmarks
  6. Rural impact + roadmap (offline mode, vernacular, district dashboard)
  7. Team + disclaimer (prototype, not a certified medical device)
- [ ] Rehearse the **< 30-second review demo** end-to-end with a real image

**Done when:** full pipeline runs live, Messidor-2 metrics documented, deck is presentation-ready.

---

## Summary — MATLAB Modules

| Module | Phase | Owner |
|---|---|---|
| Quality check + preprocessing | M-1 | B2 |
| Grading inference (ONNX import) | M-2 | B1 |
| Segmentation inference (ONNX import) | M-3 | B1 |
| Grad-CAM + PDF report | M-4 | B1 |
| Data layer + patient history | M-5 | B4 |
| Simulink telemedicine model | M-6 | B5 |
| App Designer + uihtml dashboard | M-7 | B3 |
| Integration + validation + deck | M-8 | B4 + all |
