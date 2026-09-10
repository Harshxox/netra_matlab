# Netra — Project Tracker
**SIH 2026 | PS 26038 | Last updated: 2026-09-07**

Update this file as features complete. Check boxes as you go.

---

## Overall Status

| Track | Phase | Status |
|---|---|---|
| Colab | C-0 Environment | ⬜ Not started |
| Colab | C-1 Data pipeline | ⬜ Not started |
| Colab | C-2 DR grader | ⬜ Not started |
| Colab | C-3 Vessel U-Net | ⬜ Not started |
| Colab | C-4 Lesion U-Nets | ⬜ Not started |
| Colab | C-5 OD detector | ⬜ Not started |
| Colab | C-6 Handoff | ⬜ Not started |
| MATLAB | M-0 Setup | ✅ Done (R2026a, all toolboxes + ONNX converter, ONNX import OK, uihtml bridge OK) |
| MATLAB | M-1 Preprocessing | ✅ Done — 12/12 real APTOS images gradable; blur/dark/partial-frame correctly downgraded; thresholds tuned 2026-09-09 |
| MATLAB | M-2 Grading inference | 🔄 Rules grader done + ONNX ResNet-50 path ready. Eval on 28 labelled APTOS: QWK 0.43, referable sens 53% / spec 100%, within-1 75%. Classical tops out here — **90% sensitivity target NEEDS dr_grader.onnx from Colab.** |
| MATLAB | M-3 Segmentation inference | 🔄 Classical path done (morphology: vessels, OD, MA/HE/EX + overlay). Value = explainability overlay + offline fallback, not benchmark accuracy. ONNX U-Net path stubbed. |
| MATLAB | M-4 Explainability | ✅ Heatmap (lesion-evidence now, real Grad-CAM when ONNX arrives) + evidence view + one-page-ish PDF report. All generate. Healthy→clean heatmap, severe→lit. |
| MATLAB | M-5 Data layer | ✅ .mat table: saveScreening / getHistory (trend string) / saveReviewDecision / dbStats. Persists across sessions. |
| MATLAB | M-6 Simulink | ✅ `simulink/netra_telemedicine.slx` (7-block SimEvents model + 2 scopes, simulates clean) built by `buildTelemedicineModel.m`, run by `simulateTelemedicine.m`. Rigorous numbers from `queueSim.m`/`runSimulation.m`: district (100k/yr) needs **3 ophthalmologists** for p95 wait <24h; bandwidth 2 vs 50 Mbps barely matters. |
| MATLAB | M-7 Frontend | ✅ NetraApp.m (uifigure+uihtml, no App Designer) + dashboard.html/css/js. Renders correctly for gradable + ungradable (screenshots in images/_debug/). Agree/Override/Open-PDF wired. Images sent as base64 data URIs. |
| MATLAB | M-8 Integration | 🔄 runPipeline.m end-to-end (~9s cold / 3s warm). Ungradable early-exit + 5 error cases handled (test_errors). APTOS eval (evalGrading): QWK 0.44, sens 59%/spec 100% (rules). validateMessidor2.m built + wiring-tested (parses Kaggle/Google/ADCIS CSV formats, parfor, subset limit) — needs the dataset downloaded to data/messidor2/. PPT + real Messidor-2 run + demo pending. |

**Status key:** ⬜ Not started · 🔄 In progress · ✅ Done · 🔴 Blocked

---

## ONNX Bridge — Delivery Tracker
These files go from Colab → Google Drive → MATLAB team. This is the critical handoff.

| File | Produced in | Needed by | Uploaded | MATLAB imported |
|---|---|---|---|---|
| `dr_grader.onnx` | C-2 | M-2 | ⬜ | ⬜ |
| `referable_threshold.txt` | C-2 | M-2 | ⬜ | ⬜ |
| `temperature.mat` | C-2 | M-4 | ⬜ | ⬜ |
| `vessel_unet.onnx` | C-3 | M-3 | ⬜ | ⬜ |
| `ma_unet.onnx` | C-4 | M-3 | ⬜ | ⬜ |
| `he_unet.onnx` | C-4 | M-3 | ⬜ | ⬜ |
| `ex_unet.onnx` | C-4 | M-3 | ⬜ | ⬜ |
| `nv_unet.onnx` | C-4 | M-3 | ⬜ | ⬜ |
| `od_detector.onnx` | C-5 | M-3 | ⬜ | ⬜ |

Google Drive folder link: *(add when created)*

---

---

# COLAB TRACK

---

## C-0 — Environment & Setup
**Owner:** Colab-A | **Day:** 1 | **Detail:** `.claude/phases_colab/phase_c0.md`

- [ ] GPU confirmed in Colab runtime (T4 or V100)
- [ ] All packages installed: `torch torchvision albumentations segmentation-models-pytorch onnxruntime scikit-learn kaggle`
- [ ] Google Drive mounted at `/content/drive/MyDrive/netra/`
- [ ] Kaggle API key uploaded (`kaggle.json`)
- [ ] APTOS 2019 dataset downloaded and unzipped
- [ ] IDRiD dataset downloaded and unzipped
- [ ] DRIVE dataset downloaded and unzipped
- [ ] Class distribution histogram plotted — imbalance visible

**Done when:** GPU confirmed, all 3 datasets loaded, histogram shows class skew.

---

## C-1 — Data Pipeline & Augmentation
**Owner:** Colab-A + Colab-B | **Day:** 1–2 | **Detail:** `.claude/phases_colab/phase_c1.md`
**Blocks:** C-2, C-3, C-4, C-5 — nothing else can start until this is done.

- [ ] `extract_green_channel(img)` — returns single-channel green image
- [ ] `crop_fov(img)` — detects and crops retinal disc, pads to square
- [ ] `preprocess_classifier(img)` — resize 224×224, ImageNet normalization
- [ ] `preprocess_segmentation(img)` — green channel, resize 512×512, [0,1] range
- [ ] `APTOSDataset` class — loads image + label, applies classifier transforms
- [ ] `SegmentationDataset` class — loads image + mask, handles missing masks
- [ ] Classifier augmentation pipeline — flip, rotate ±30°, color jitter, cutout
- [ ] Segmentation augmentation pipeline — flip, rotate, elastic, no color jitter
- [ ] Stratified train/val/test split (70/15/15) on APTOS
- [ ] Class weights computed via `compute_class_weight('balanced')`
- [ ] Single image end-to-end test: load → preprocess → tensor shape correct

**Done when:** `APTOSDataset[0]` and `SegmentationDataset[0]` return correct tensor shapes with no errors.

---

## C-2 — DR Grading Classifier (ResNet-50)
**Owner:** Colab-A | **Day:** 2–4 | **Detail:** `.claude/phases_colab/phase_c2.md`
**Depends on:** C-1 | **Blocks:** M-2

- [ ] `build_grader()` — ResNet-50 pretrained, freeze layers 1–2, custom FC head (Dropout → Linear → ReLU → Linear)
- [ ] Class-weighted CrossEntropyLoss with computed weights
- [ ] Adam optimizer with layer-wise learning rates (backbone 1e-4, head 1e-3)
- [ ] CosineAnnealingLR scheduler
- [ ] QWK tracked each epoch (target > 0.80 on val)
- [ ] Best model checkpoint saved (by val QWK)
- [ ] Training curve plotted (loss + QWK)
- [ ] ROC curve on val set for referable (grade ≥ 2)
- [ ] Referable threshold tuned → sensitivity > 90%
- [ ] `dr_grader.onnx` exported (opset 11, dynamic batch axis)
- [ ] `referable_threshold.txt` saved (single float)
- [ ] `temperature.mat` saved (temperature scalar for calibration)
- [ ] onnxruntime sanity check: max abs diff from PyTorch < 1e-4
- [ ] Model uploaded to Google Drive

**Metrics target:** Val QWK > 0.80 | Referable sensitivity > 90%

**Done when:** ONNX passes sanity check, uploaded to Drive, threshold file saved.

---

## C-3 — Vessel Segmentation (DRIVE)
**Owner:** Colab-B | **Day:** 2–4 | **Detail:** `.claude/phases_colab/phase_c3.md`
**Depends on:** C-1 | **Parallel with:** C-2, C-4, C-5

- [ ] `DRIVEDataset` — loads 584×565 images, extracts random 512×512 patches (n=8/image)
- [ ] U-Net with ResNet-34 encoder, 1 input channel (green), 1 output channel
- [ ] Combined BCE + Dice loss
- [ ] IoU and Dice tracked per epoch
- [ ] ReduceLROnPlateau scheduler (patience=5)
- [ ] 60 epochs training
- [ ] Best model checkpoint saved (by val Dice)
- [ ] `vessel_unet.onnx` exported (opset 11)
- [ ] onnxruntime sanity check passes
- [ ] Model uploaded to Google Drive

**Metrics target:** Val Dice > 0.80

**Done when:** ONNX uploaded, Dice > 0.80 on DRIVE val.

---

## C-4 — Lesion Segmentation (IDRiD)
**Owner:** Colab-B | **Day:** 3–5 | **Detail:** `.claude/phases_colab/phase_c4.md`
**Depends on:** C-1 | **Parallel with:** C-2, C-3

- [ ] `LesionDataset` class — loads IDRiD image + lesion mask, missing mask = zero mask
- [ ] `get_pos_weight()` — computes per-lesion positive weight from pixel ratio
- [ ] `weighted_bce_dice_loss()` — combined loss with pos_weight for sparse lesions
- [ ] **MA (Microaneurysm) U-Net** trained — target Dice > 0.40
- [ ] `ma_unet.onnx` exported and validated
- [ ] **HE (Hemorrhage) U-Net** trained — target Dice > 0.60
- [ ] `he_unet.onnx` exported and validated
- [ ] **EX (Exudate) U-Net** trained — target Dice > 0.70
- [ ] `ex_unet.onnx` exported and validated
- [ ] **NV (Neovascularization) U-Net** trained — target Dice > 0.50
- [ ] `nv_unet.onnx` exported and validated
- [ ] All 4 ONNX files uploaded to Google Drive

**Metrics targets:** MA > 0.40 | HE > 0.60 | EX > 0.70 | NV > 0.50

**Done when:** All 4 ONNX files pass sanity check and are uploaded.

---

## C-5 — Optic Disc Detector (IDRiD)
**Owner:** Colab-B | **Day:** 4–5 | **Detail:** `.claude/phases_colab/phase_c5.md`
**Depends on:** C-1 | **Parallel with:** C-2, C-3, C-4

- [ ] `ODDataset` class — loads IDRiD images + OD masks
- [ ] U-Net with ResNet-34 encoder, 1 output channel
- [ ] BCE + Dice loss
- [ ] 40 epochs training
- [ ] Best model checkpoint saved (by val Dice)
- [ ] `od_detector.onnx` exported (opset 11)
- [ ] onnxruntime sanity check passes
- [ ] Model uploaded to Google Drive

**Note:** Fovea location is estimated in MATLAB as 2.5 disc diameters temporal to OD centroid — not baked into the ONNX.

**Metrics target:** Val Dice > 0.90 (OD is large, this is achievable)

**Done when:** ONNX uploaded, Dice > 0.90.

---

## C-6 — ONNX Validation & Handoff
**Owner:** Colab-A + Colab-B | **Day:** 5 | **Detail:** `.claude/phases_colab/phase_c6.md`
**Depends on:** C-2, C-3, C-4, C-5 all done

- [ ] `validate_onnx()` run on all 7 model files — checks: loads, opset==11, output shape correct, no errors
- [ ] All 7 models pass validation
- [ ] `docs/model_registry.md` filled in (filename, architecture, dataset, metrics, Drive link)
- [ ] Google Drive folder link posted in team channel
- [ ] MATLAB team notified: "ONNX files ready — import test"
- [ ] MATLAB team confirms `importONNXNetwork` or `importNetworkFromONNX` works on at least 1 file

**Done when:** MATLAB team confirms import works. Colab track complete.

---

---

# MATLAB TRACK

---

## M-0 — Environment & Repository Setup
**Owner:** Everyone | **Day:** 1 | **Detail:** `.claude/phases_matlab/phase_m0.md`

- [ ] MATLAB R2023b 30-day trial activated (each member, personal email)
- [ ] Toolboxes verified: Image Processing, Computer Vision, Deep Learning, Deep Learning Model for ResNet-50, Statistics & ML, Simulink + SimEvents, Parallel Computing, Medical Imaging
- [ ] MATLAB Project created and linked to GitHub repo
- [ ] Folder structure created: `/data /src /models /app /simulink /images /reports /docs /colab`
- [ ] `.gitignore` configured (excludes `.mat` data files, `.onnx` models, datasets)
- [ ] **Day-1 ONNX import test:** `importONNXNetwork` (or `importNetworkFromONNX`) runs without error on a dummy model
- [ ] **Day-1 uihtml PoC:** HTML button click → MATLAB callback fires → reply sent back to HTML
- [ ] `docs/data_contract.json` committed to repo
- [ ] Phase branches created on GitHub: `phase-0-setup` through `phase-8-integration`

**Done when:** ONNX import test passes + uihtml two-way messaging works.

---

## M-1 — Preprocessing & Quality Check
**Owner:** MATLAB-A | **Day:** 1–2 | **Detail:** `.claude/phases_matlab/phase_m1.md`
**Depends on:** M-0 | **Blocks:** M-2, M-3, M-4

- [ ] `cropFOV(img)` — detects retinal circle via thresholding + Hough, crops + pads
- [ ] `resizeNormalize(img, targetSize)` — resize + normalize to [0,1]
- [ ] `extractGreenChannel(img)` — returns single-channel green image as double
- [ ] `qualityScore(img)` — returns (focusScore, illuminationScore, fovRatio)
  - [ ] Focus: Laplacian variance
  - [ ] Illumination: mean intensity of FOV region
  - [ ] FOV ratio: detected circle area / image area
- [ ] `classifyQuality(scores)` — returns `'gradable'` / `'borderline'` / `'ungradable'`
- [ ] `enhanceImage(img)` — CLAHE via `adapthisteq`, morphological illumination normalization, Gaussian denoise
- [ ] `buildQualityBlock(img, scores, status)` — returns quality struct matching data contract
- [ ] `runQualityPipeline(imagePath)` — entry point: load → crop → quality check → enhance → return

**Done when:** `runQualityPipeline('any_fundus.jpg')` returns processedImg + quality struct with correct status.

---

## M-2 — Grading Inference
**Owner:** MATLAB-A | **Day:** 3–4 | **Detail:** `.claude/phases_matlab/phase_m2.md`
**Depends on:** M-1, `dr_grader.onnx` from Colab | **Blocks:** M-4, M-8

- [ ] `loadGradingNet()` — imports ONNX with `persistent` cache, loads once per session
- [ ] `preprocessForGrader(img)` — resize 224×224, ImageNet normalization, `dlarray` with `'SSC'` format
- [ ] `runGrading(net, img)` — predict → softmax → argmax → grade (0–4) + probabilities
- [ ] `isReferable(probs)` — loads `referable_threshold.txt`, sums P(grade≥2), compares
- [ ] `gradeLabel(grade)` — maps 0→'No DR', 1→'Mild', ..., 4→'Proliferative DR'
- [ ] `buildResultBlock(grade, probs, referable)` — returns result struct matching data contract
- [ ] `runGradingPipeline(img)` — entry point combining all above
- [ ] Smoke test: grade output in 0–4, referable is logical, confidence in [0,1]

**Done when:** Smoke test passes on a known APTOS image with correct grade output.

---

## M-3 — Segmentation Inference
**Owner:** MATLAB-B | **Day:** 3–4 | **Detail:** `.claude/phases_matlab/phase_m3.md`
**Depends on:** M-1, all 6 segmentation ONNX files from Colab | **Blocks:** M-4, M-8

- [ ] `loadSegmentationNets()` — loads all 6 models with `persistent` cache
- [ ] `preprocessForSegmentation(img)` — green channel, 512×512, `dlarray` `'SSC'`
- [ ] `runSegModel(net, img, threshold)` — predict → sigmoid → threshold → binary mask
- [ ] `runVesselSegmentation(nets, img)` — returns binary vessel mask
- [ ] `runLesionSegmentation(nets, img)` — returns struct with MA/HE/EX/NV masks
- [ ] `runODDetector(nets, img)` — OD mask → centroid via `regionprops` → fovea estimate (2.5 × disc radius temporal)
- [ ] `quantifyLesions(masks, img)` — `bwconncomp` for MA/HE counts, EX area %, NV presence flag
- [ ] `generateLesionOverlay(img, masks)` — MA=red, HE=blue, EX=yellow, NV=magenta, alpha=0.45
- [ ] `runSegmentationPipeline(nets, img, patientId)` — entry point, saves overlay images to `/images/<patientId>/`

**Done when:** All masks generated, overlay image saved and visually correct on a test fundus image.

---

## M-4 — Explainability & Reporting
**Owner:** MATLAB-A | **Day:** 4–5 | **Detail:** `.claude/phases_matlab/phase_m4.md`
**Depends on:** M-2, M-3 | **Blocks:** M-8

- [ ] `generateGradCAM(net, img, grade)` — `gradCAM()` on ONNX dlnetwork, resize output to original size
- [ ] `overlayHeatmap(img, heatmap, alpha)` — jet colormap alpha blend, returns uint8 RGB
- [ ] `buildEvidenceView(img, heatmap, masks)` — Grad-CAM + lesion contours via `bwperim`
- [ ] `calibrateConfidence(logits)` — loads `temperature.mat`, applies temperature scaling
- [ ] `generateReport(record, gradcamPath, overlayPath)` — MATLAB Report Generator, one-page PDF
  - [ ] Title page with patient ID
  - [ ] Grade + referable verdict (bold, colored)
  - [ ] Grad-CAM image
  - [ ] Lesion overlay image
  - [ ] Lesion counts table (MA, HE, EX area%, NV)
  - [ ] Routing recommendation
  - [ ] Prototype disclaimer (italic, small font)
- [ ] `runExplainPipeline(net, img, record, masks)` — entry point, saves gradcam.png + evidence.png + PDF

**Done when:** PDF generates correctly, Grad-CAM heatmap highlights relevant region (not background).

---

## M-5 — Data Layer & Patient History
**Owner:** MATLAB-C | **Day:** 1–4 | **Detail:** `.claude/phases_matlab/phase_m5.md`
**Depends on:** M-0 | **Parallel with:** M-6 | **Blocks:** M-7, M-8

- [ ] `initDB()` — creates 12-column MATLAB table, persists to `netra_db.mat`
- [ ] `saveScreening(record)` — appends new row, saves to disk. Handles first-ever run.
- [ ] `getHistory(patientId)` — returns prior grades array + trend string (e.g. "No DR → Mild → Moderate over 8 months")
  - [ ] Empty history → `'First screening'`
  - [ ] Single record → grade label only
  - [ ] Multiple records → full trend string with month span
- [ ] `saveReviewDecision(patientId, eye, finalGrade, notes, reviewerId)` — updates `reviewStatus` → `'reviewed'`
- [ ] `dbStats()` — total screened, referral rate, pending count, today count, grade distribution
- [ ] Persistence test: save → restart MATLAB → load → record still there

**Done when:** Save + history + review decision all work across MATLAB restarts.

---

## M-6 — Simulink Telemedicine Model
**Owner:** MATLAB-D | **Day:** 1–5 | **Detail:** `.claude/phases_matlab/phase_m6.md`
**Depends on:** M-0 | **Parallel with:** M-5

- [ ] `simulink/netra_telemedicine.slx` created (blank SimEvents model)
- [ ] Entity Generator block — period = 315s (100k patients/year)
- [ ] MATLAB Function block — `assignSeverity()` with APTOS distribution weights
- [ ] Bandwidth Entity Server — service time = 8/bw_mbps seconds
- [ ] AI Processing Entity Server — Normal(30, 5) seconds
- [ ] Priority Queue — sorted by severity attribute (descending)
- [ ] Ophthalmologist Review Server — Normal(60, 15) seconds, variable num_reviewers
- [ ] Scope / Display blocks — queue length, wait time, utilization, throughput
- [ ] Statistics blocks — average wait, server utilization
- [ ] Model runs 1 year (31,536,000 seconds) without errors
- [ ] `simulink/runSimulation.m` — parameter sweep: 3 bandwidths × 10 reviewer counts
- [ ] Sweep results: minimum reviewers for < 24h wait identified
- [ ] Key numbers extracted for PPT slide

**Done when:** Sweep complete, bottleneck identified (should be review queue, not upload/AI).

---

## M-7 — Frontend (App Designer + uihtml)
**Owner:** MATLAB-C | **Day:** 3–6 | **Detail:** `.claude/phases_matlab/phase_m7.md`
**Depends on:** M-0 (uihtml PoC), M-5 | **Blocks:** M-8

- [ ] `app/NetraApp.mlapp` — App Designer shell, uihtml component fills window
- [ ] Startup callback: loads nets + DB, sets HTMLSource
- [ ] `app/dashboard.html` — full structure: topbar, queue panel, image panel, results panel, action bar
- [ ] `app/dashboard.css` — dark navy (#0F172A) + teal (#0D9488) theme, all components styled
- [ ] `app/dashboard.js` — all functions implemented:
  - [ ] `renderDashboard(d)` — populates all fields from screening data
  - [ ] `setLayer(name)` — switches image between Original/Enhanced/Grad-CAM/Lesions/Vessels
  - [ ] `setEye(eye)` — OD/OS toggle, fires `eyeChanged` event
  - [ ] `sendDecision(type)` — fires `reviewDecision` event with grade + notes
  - [ ] `toggleOverride()` — shows/hides override panel
  - [ ] `sendEvent(name, data)` — dispatches `mlEvent` custom event
- [ ] MATLAB `HTMLEventReceived` callback handles: `reviewDecision`, `generateReport`, `eyeChanged`
- [ ] `pushToDashboard(app, record)` — `sendEventToHTMLSource` sends JSON to JS
- [ ] End-to-end: upload image → pipeline runs → dashboard renders grade/confidence/overlays
- [ ] Layer toggles switch images correctly
- [ ] Agree saves review decision
- [ ] Override sets custom grade + notes
- [ ] Generate PDF opens report
- [ ] Ungradable path shows recapture banner, hides grading section

**Done when:** Full flow working in NetraApp — image in, dashboard out, decision saved.

---

## M-8 — Integration, Validation & Deck
**Owner:** Everyone | **Day:** 6–7 | **Detail:** `.claude/phases_matlab/phase_m8.md`
**Depends on:** M-1 through M-7 all done

- [ ] `src/runPipeline(imagePath, patientId, eye)` — master entry point
  - [ ] Calls all modules in correct order
  - [ ] Early exit on `'recapture'` (ungradable)
  - [ ] `record.routing` set correctly post-grading
  - [ ] `record.review.status = 'pending'` set before return
- [ ] Smoke test passes on a known gradable APTOS image
- [ ] Ungradable path: pipeline exits cleanly, recapture shows in dashboard
- [ ] **Messidor-2 validation** (`src/validateMessidor2.m`):
  - [ ] Runs on full Messidor-2 gradable subset
  - [ ] Sensitivity > 90% ✓
  - [ ] Specificity > 85% ✓
  - [ ] QWK computed and logged
- [ ] **Error handling** — all 5 cases handled gracefully:
  - [ ] Ungradable image → recapture message, no crash
  - [ ] Missing ONNX file → clear error message, app doesn't crash
  - [ ] Unknown patient ID → "First screening", no crash
  - [ ] Duplicate review (already reviewed) → warning shown
  - [ ] Image path with spaces → `imread` handles correctly
- [ ] **PPT deck** (7 slides, use PowerPoint or Google Slides):
  - [ ] Slide 1: Problem (77M diabetics, < 1 specialist per 100k rural)
  - [ ] Slide 2: Pipeline overview diagram
  - [ ] Slide 3: Explainability (real Grad-CAM + lesion overlay screenshot)
  - [ ] Slide 4: Simulink (model screenshot + key numbers from M-6)
  - [ ] Slide 5: Metrics (sensitivity/specificity/QWK vs benchmarks table)
  - [ ] Slide 6: Rural impact + roadmap
  - [ ] Slide 7: Team + disclaimer
  - [ ] Spell-checked
- [ ] **Demo rehearsed** under 30 seconds:
  - [ ] Open NetraApp
  - [ ] Enter patient ID: PT-DEMO-001
  - [ ] Upload Grade 3 fundus image
  - [ ] Pipeline runs (~10s)
  - [ ] Dashboard renders — show grade badge, Grad-CAM, lesion counts
  - [ ] Toggle layers: Original → Grad-CAM → Lesions
  - [ ] Click Agree → "Decision saved"
  - [ ] Click Generate PDF → report opens

**Done when:** Messidor-2 hits targets, PPT spell-checked, demo under 30 seconds.

---

## Pending Items (not yet done)
- [ ] `docs/model_registry.md` — fill in after C-6
- [ ] Google Drive shared folder — create and share link with team
- [ ] Team member names assigned to B1–B5 slots (replace placeholders in phase files)
- [ ] `.gitignore` file written to disk (content is in phase_m0.md)
- [ ] `docs/data_contract.json` written to disk (template is in phase_m0.md)
