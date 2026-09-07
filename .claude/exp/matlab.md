# MATLAB Track — Phase Explanations

---

## M-0 — Environment & Repository Setup
**What:** Activate MATLAB free trials, install all required toolboxes, create the MATLAB Project, set up the folder structure, configure `.gitignore`, and prove two critical things work on Day 1: ONNX import and uihtml two-way messaging.
**Why:** The two biggest technical risks in the MATLAB track are (1) ONNX models not importing cleanly and (2) HTML↔MATLAB messaging not working. If either fails, the entire architecture collapses. Proving them on Day 1 gives the team time to pivot.
**How:** Run `importONNXNetwork` on a dummy model file. Build a minimal uihtml PoC: HTML button fires a custom event → MATLAB `HTMLEventReceived` callback logs it → MATLAB calls `sendEventToHTMLSource` → JS receives the reply. Commit `data_contract.json`.
**Why we need it:** Everyone starts here. Nothing else in the MATLAB track can begin until toolboxes are installed and the two PoCs pass.

---

## M-1 — Preprocessing & Quality Check
**What:** Build the image preprocessing pipeline that every fundus image passes through before any model sees it — FOV cropping, green channel extraction, quality scoring, and CLAHE enhancement.
**Why:** Raw fundus images vary wildly: different cameras, fields of view, lighting conditions. A model trained on clean images will fail silently on a blurry or overexposed input unless we check quality first and reject ungradable images at the door.
**How:** `cropFOV()` detects the retinal circle and crops to it. `qualityScore()` measures focus (Laplacian variance), illumination (mean intensity), and FOV coverage. `classifyQuality()` routes to gradable/borderline/ungradable. `enhanceImage()` applies CLAHE for contrast normalisation.
**Why we need it:** This module runs first on every image and feeds its output to M-2 (grading) and M-3 (segmentation). Getting this wrong corrupts every downstream result.

---

## M-2 — Grading Inference
**What:** Load the `dr_grader.onnx` from Colab into MATLAB and run inference — producing a grade 0–4, referable decision, and calibrated confidence score for each image.
**Why:** This is the primary clinical output of the whole system. The grade determines whether a patient gets referred to a specialist or monitored at the PHC. Everything else (lesions, Grad-CAM, PDF) exists to explain and support this decision.
**How:** `importONNXNetwork` with `persistent` caching so the model loads once per session. Preprocess image to 224×224 dlarray with ImageNet normalisation. Run `predict`, apply softmax, argmax for grade. Load `referable_threshold.txt` (from Colab C-2) and sum P(grade≥2) to decide referable.
**Why we need it:** Produces the `result` block that populates the dashboard verdict badge, grade pips, and confidence bar. Also needed by M-4 (Grad-CAM targets the predicted class).

---

## M-3 — Segmentation Inference
**What:** Load all six segmentation ONNX models (vessel, MA, HE, EX, NV, OD) and run them on each image to produce binary masks, lesion counts, OD centroid, and a colour-coded lesion overlay.
**Why:** The lesion masks are what makes the AI explainable. An ophthalmologist cannot trust "Grade 3" from a black box — but they can verify "18 microaneurysms in the temporal quadrant" against what they see. The overlay lets them do that in under 30 seconds.
**How:** `preprocessForSegmentation()` extracts green channel and resizes to 512×512 dlarray. Each model runs through `runSegModel()` (predict → sigmoid → threshold). `quantifyLesions()` counts MA/HE with `bwconncomp`, measures EX area%, detects NV presence. `generateLesionOverlay()` alpha-blends colour masks (MA=red, HE=blue, EX=yellow, NV=magenta).
**Why we need it:** Provides the lesion masks and overlay image used by M-4 (evidence view), M-7 (dashboard layer toggle), and the PDF report.

---

## M-4 — Explainability & Reporting
**What:** Generate Grad-CAM attention heatmaps on the grading model, build an evidence view that overlays both Grad-CAM and lesion contours, apply temperature calibration to confidence scores, and produce a one-page PDF report.
**Why:** The SIH problem statement explicitly requires explainability so an ophthalmologist can validate the AI decision. Grad-CAM shows *where* the model is looking; lesion contours show *what* it found. Together they let a reviewer agree or override in under 30 seconds.
**How:** MATLAB's `gradCAM()` works directly on imported ONNX `dlnetwork` objects. `bwperim()` extracts lesion contour lines for overlay. Temperature scaling (`logits / T`) calibrates overconfident softmax probabilities using scalar T from `models/temperature.mat`. MATLAB Report Generator builds the PDF programmatically.
**Why we need it:** The Grad-CAM image and PDF report are displayed in the dashboard and downloadable by the ophthalmologist. This is the module judges will look at most closely.

---

## M-5 — Data Layer & Patient History
**What:** Build the persistence layer — a MATLAB `table` saved to `netra_db.mat` — that stores every screening result and lets us retrieve a patient's screening history and trend over time.
**Why:** A single screening in isolation is less clinically useful than seeing "No DR → Mild → Moderate over 8 months." Trend data flags patients whose condition is worsening faster than expected. The database also powers the review workflow (pending → reviewed) and the optional district dashboard.
**How:** MATLAB `table` with 12 columns, saved to `.mat` file. `persistent` variables prevent reloading on every call. `getHistory()` sorts records by date and builds a trend string. `saveReviewDecision()` finds the most recent pending record for a patient and updates its status.
**Why we need it:** M-7 (frontend) and M-8 (integration) both call into this layer. Without it, no review decisions can be saved and no history is available to the dashboard.

---

## M-6 — Simulink Telemedicine Model
**What:** Model the end-to-end patient screening workflow as a discrete-event simulation in Simulink SimEvents — from patient arrival at a PHC through upload, AI processing, and ophthalmologist review — to find the optimal number of reviewers for a 100,000-patient district.
**Why:** The SIH PS asks us to model telemedicine logistics, not just build the AI. Simulink answers the operational question: "How many eye specialists does a district actually need to avoid patients waiting more than 24 hours for a result?" This goes directly on a PPT slide.
**How:** Entity Generator produces one patient every 315 seconds (100k/year). Attributes carry severity (weighted by APTOS distribution). Entity Servers model upload (bandwidth-dependent), AI processing (Normal(30,5)s), and ophthalmologist review (Normal(60,15)s, variable count). Parameter sweep across 3 bandwidths × 10 reviewer counts.
**Why we need it:** Produces the Simulink slide numbers and proves the system is designed for real-world rural telemedicine constraints, not just a lab demo.

---

## M-7 — Frontend (App Designer + uihtml)
**What:** Build the full Netra screening dashboard — a dark-navy HTML/CSS/JS interface hosted inside MATLAB via `uihtml` — with image layer toggles, a grade verdict panel, lesion counts, and Agree/Override/Generate PDF actions.
**Why:** The ophthalmologist needs to review each case in under 30 seconds. That requires a clean, fast interface that shows everything relevant at a glance — not MATLAB's default grey figure windows. The `uihtml` component lets us build a polished UI without leaving the MATLAB runtime.
**How:** App Designer holds one `uihtml` component that loads `dashboard.html`. MATLAB pushes JSON to JS via `sendEventToHTMLSource`. JS fires custom events (`mlEvent`) that MATLAB catches in `HTMLEventReceived`. All five image layers (Original/Enhanced/Grad-CAM/Lesions/Vessels) are pre-loaded paths; `setLayer()` just swaps the `<img>` src.
**Why we need it:** This is what the judges and the ophthalmologist interact with. A bad UI makes a good pipeline look weak. A clean UI makes the clinical value immediately obvious.

---

## M-8 — Integration, Validation & Deck
**What:** Wire all modules into a single `runPipeline()` entry point, validate the whole system on the held-out Messidor-2 dataset (never trained on), handle all error edge cases, build the 7-slide PPT deck, and rehearse the 30-second demo.
**Why:** Individual modules working in isolation doesn't mean the pipeline works end-to-end. Messidor-2 validation on unseen data is the proof that the model actually generalises to real-world images and isn't just memorising the training set.
**How:** `runPipeline(imagePath, patientId, eye)` calls every module in sequence with an early-exit for ungradable images. `validateMessidor2()` iterates over the Messidor-2 gradable subset, accumulates predictions, and computes sensitivity/specificity/QWK. PPT slides are filled with real numbers from M-6 (Simulink) and M-8 (Messidor-2).
**Why we need it:** This is the finish line. Sensitivity > 90% and specificity > 85% on Messidor-2 are the hard success criteria in the problem statement. Everything before this phase was building toward this number.
