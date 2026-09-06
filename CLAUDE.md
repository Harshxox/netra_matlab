# CLAUDE.md — Explainable AI for Diabetic Retinopathy Screening (SIH 2026, PS 26038)

> Project context for Claude Code. This file is the source of truth for what
> we're building, the constraints, and the decisions already locked. Read it
> before writing any code.

## What this is

Smart India Hackathon 2026, Problem Statement **26038** (MathWorks, MedTech).
An **explainable AI pipeline for Diabetic Retinopathy (DR) screening in rural
India**. It takes a retinal **fundus image**, grades DR severity (0–4), decides
**referable vs. not**, and **explains why** — so an ophthalmologist can review
each case in **under 30 seconds** (human-in-the-loop).

Why it matters: India has ~77M diabetics and almost no eye specialists in rural
areas. Mass manual screening is infeasible. This tool triages at primary health
centres (PHCs) and refers only those who need a doctor.

## Hard constraints

- **Built entirely in MATLAB.** This is a MathWorks PS — staying on-platform is
  a judging factor. The *only* exception is the frontend HTML/CSS/JS, which runs
  **inside MATLAB via the `uihtml` component**, not as a separate web stack.
- **~1 week build, team of 6** (2 members with little CS background).
- **Deliverables:** a working prototype + a PPT deck for judges.

## Success metrics

- **Referable DR (grade ≥ 2): sensitivity > 90%, specificity > 85%.**
- **Grading:** track **Quadratic Weighted Kappa (QWK)** — the APTOS metric —
  alongside accuracy. Treat grades 0–4 as **ordinal**.
- Explainability rated clinically useful; a case reviewable in < 30s.
- **External validation on Messidor-2** (never trained on) to prove it generalizes.

## Architecture (pipeline)

```
Fundus image
 → [1] Quality check (focus/illumination/FOV) → enhance or reject (recapture)
 → [2] Preprocess (crop FOV, resize, normalize, green channel)
 → [3] Segment structures (optic disc/fovea, vessels, lesions: MA/HE/EX/neovascularization)
 → [4] Grade DR severity 0–4 (+ referable decision)
 → [5] Explain (Grad-CAM + lesion overlay + calibrated confidence + PDF report)
 → [6] Ophthalmologist review (Agree / Override)
 ‖  Simulink models telemedicine logistics (throughput, bandwidth, review capacity)
```

## Tech stack

- **MATLAB R2023b+**, MATLAB Project + Git for version control.
  License: **30-day free trial** per member (no campus license available).
- **Toolboxes:** Image Processing, Computer Vision, Deep Learning
  (+ *Deep Learning Toolbox Model for ResNet-50* support package),
  Statistics & ML, Simulink + SimEvents, Parallel Computing, Medical Imaging Toolbox.
- **Model training:** Python + PyTorch on **Google Colab** (free GPU). Models
  exported as **ONNX (opset 11)** and imported into MATLAB via
  `importONNXNetwork()`. Training is offline — the runtime pipeline is
  fully MATLAB-native. See `docs/tech_stack.md` for full training stack.
- **Frontend:** App Designer + polished dashboard via **`uihtml`** (HTML/CSS/JS
  hosted in MATLAB, data passed via the component's `Data` property +
  `sendEventToHTMLSource` two-way messaging).
- **Data layer:** MATLAB **`table` persisted to a `.mat` file** for the build
  (SQLite as a stretch). **Store image file paths, never image blobs.**
- **Reporting:** MATLAB Report Generator → one-page annotated PDF per patient.

## Datasets

- **APTOS 2019** — primary grading classifier training set (grades 0–4).
- **IDRiD** — Indian; has lesion masks (microaneurysm/hemorrhage/exudate/
  neovascularization/optic disc) *and* grades → drives lesion segmentation + Indian validation.
- **DRIVE** — vessel segmentation (40 images with vessel masks).
- **Messidor-2** — held out for **external validation only** (never train on it).

## Data contract

A single JSON payload per screening drives the whole app. Canonical file:
**`data_contract.json`** in `/docs`. Both the pipeline and the frontend code
against it and must not diverge. Each module fills only its own block.

- `confidence` and all probabilities are **0–1 floats** (frontend formats to %).
- Fixed enums:
  - `eye`: `OD` | `OS`
  - `quality.status`: `gradable` | `borderline` | `ungradable`
  - `grade` / `finalGrade`: integer `0–4`
  - `routing`: `refer_specialist` | `routine_followup` | `recapture`
  - `review.status`: `pending` | `reviewed`
- The `clinical` and `secondaryFindings` blocks exist now but are **nullable**,
  so optional features (LLM agent, glaucoma flag) need **no contract change**.

## Conventions

- Do lesion/vessel image processing on the **green channel** (best contrast).
- Suggested folder layout:
  `/data`, `/src/<module>`, `/models`, `/app`, `/simulink`,
  `/images/<patientId>`, `/reports`, `/docs`.
- **Freeze the data contract before parallel work begins.**

## Key decisions (locked)

- MATLAB, not Python (runtime pipeline).
- **Model training on Google Colab (PyTorch → ONNX opset 11 → `importONNXNetwork`
  in MATLAB).** No MATLAB GPU training — Colab provides free GPU.
- Frontend via **`uihtml`** (not a separate React/web stack) — but **prove the
  two-way messaging bridge with a Day-1 "hello world" PoC** before betting the
  frontend on it.
- `.mat` table for storage in the build.
- JSON data contract fixed up front.
- **Git branching: one branch per phase** (`phase-0-setup`, `phase-1-preprocessing`,
  etc.). PR into `main` when the phase's "Done when" bar is met.
- **Large files not in git:** datasets downloaded from Kaggle directly; trained
  ONNX models shared via Google Drive. Only `.m`, `.mlx`, `.slx`, `.mlapp`,
  `.html/.css/.js`, `.ipynb` are committed.

## Guardrails

- The optional **LLM agent is decision-support + patient communication, NOT
  diagnosis.** Every answer must be grounded in the pipeline's structured
  outputs (grade, lesion counts, confidence, history) — no free-floating
  medical claims.
- **Never store images in the database** — store paths only.
- This is a prototype for a hackathon, not a certified medical device — say so.

## Build order

See **`phases.md`**. Phases 2 & 3 (grading + segmentation) run in parallel, as
do 5 & 6 (data layer + Simulink), once Phase 0–1 land. The optional phase is
last and only if the team is ahead of schedule.
