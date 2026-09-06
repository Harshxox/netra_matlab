# Tech Stack — Netra (PS 26038, SIH 2026)

> Locked decisions. Do not change without team lead sign-off.

---

## 1. Model Training — Google Colab

Training happens in Colab (free GPU). Models are exported as ONNX and imported
into MATLAB. The pipeline is fully MATLAB-native; training is just offline.

| Tool | Version | Purpose |
|---|---|---|
| Python | 3.10+ | Training language |
| PyTorch | 2.x | ResNet-50 fine-tuning + U-Net training |
| torchvision | latest | Pretrained ResNet-50 weights, transforms |
| albumentations | latest | Augmentation (rotation, flip, brightness, contrast) |
| segmentation-models-pytorch | latest | U-Net architecture |
| scikit-learn | latest | Metrics — QWK, sensitivity, specificity, ROC |
| pandas / numpy | latest | Data loading, label handling |
| torch.onnx | built-in | Export trained models to `.onnx` (opset 11) |
| Kaggle API | latest | Dataset download inside Colab |

**Datasets downloaded in Colab:**
- APTOS 2019 — grading classifier training (grades 0–4)
- IDRiD — lesion segmentation training (MA, HE, EX, neovascularization masks)
- DRIVE — vessel segmentation training (40 images + masks)
- Messidor-2 — held out, external validation only (never trained on)

---

## 2. MATLAB Pipeline

Each team member on the MATLAB side uses the **30-day free trial**
(mathworks.com/campaigns/products/trials.html — individual emails).

| Toolbox | Purpose |
|---|---|
| MATLAB R2023b+ | Core language + runtime |
| Image Processing Toolbox | CLAHE, FOV crop, green channel, denoising |
| Computer Vision Toolbox | Feature detection, optic disc/fovea localization |
| Deep Learning Toolbox | `importONNXNetwork`, `gradCAM`, `dlnetwork` inference |
| Deep Learning Toolbox — ResNet-50 support package | Pretrained weights (fallback if ONNX import fails) |
| Statistics & ML Toolbox | ROC curves, threshold tuning, calibration |
| Medical Imaging Toolbox | DICOM support (optional, listed in PS) |
| Simulink + SimEvents | Telemedicine logistics model (Phase 6) |
| Parallel Computing Toolbox | GPU inference if a local GPU is available |
| MATLAB Report Generator | Auto one-page annotated PDF per patient |

---

## 3. Model Bridge

| Step | Tool |
|---|---|
| Export from Colab | `torch.onnx.export(..., opset_version=11)` |
| Import into MATLAB | `importONNXNetwork('model.onnx', 'OutputLayerType', 'classification')` |
| Inference | `classify()` or `predict()` on imported `dlnetwork` |
| Explainability | `gradCAM(net, img, classIdx)` — works on imported ONNX networks |

**Rule:** always use `opset_version=11` and standard ops only (no custom layers).
Test ONNX import on Day 1 before committing to any architecture.

---

## 4. Frontend

| Tool | Purpose |
|---|---|
| MATLAB App Designer | Main app shell, layout, event wiring |
| `uihtml` component | Renders the polished HTML/CSS/JS dashboard inside MATLAB |
| HTML / CSS / JS (vanilla) | Dashboard UI — no external frameworks |
| `sendEventToHTMLSource` | Two-way messaging: MATLAB → HTML |
| `HTMLEventReceived` callback | Two-way messaging: HTML → MATLAB |

**Day-1 PoC required:** HTML button → MATLAB callback → value back to HTML.
Do not build the full dashboard until this bridge is proven working.

---

## 5. Data Layer

| Tool | Purpose |
|---|---|
| MATLAB `table` | Screening record storage |
| `.mat` file | Persistence (load on start, append per screening, save back) |
| JSON (`data_contract.json`) | Single payload per screening — pipeline + frontend contract |
| File paths only | Images stored on disk, paths in the table (never image blobs) |

---

## 6. Version Control

| Tool | Purpose |
|---|---|
| Git | Source control |
| MATLAB Project | Dependency tracking, path management |

---

## 7. Folder Layout

```
/data          — raw datasets (gitignored)
/src
  /quality     — Phase 1: preprocessing + quality check
  /segment     — Phase 3: vessel + lesion segmentation
  /grade       — Phase 2: DR grading classifier
  /explain     — Phase 4: Grad-CAM + report
  /datalayer   — Phase 5: .mat table + patient history
/models        — imported ONNX + any .mat model files
/app           — App Designer + uihtml HTML/CSS/JS
/simulink      — Phase 6: Simulink telemedicine model
/images        — per-patient overlays (/images/<patientId>/)
/reports       — generated PDF reports
/docs          — data_contract.json, tech_stack.md, architecture docs
/colab         — Colab training notebooks (.ipynb, tracked in git)
```

---

## 8. What is NOT in the stack

- No Python at runtime — Colab is training-only
- No React / Node / external web server — frontend is `uihtml` inside MATLAB
- No cloud database — `.mat` file only for the build
- No Docker — local MATLAB only
- No SQLite (stretch goal only, not in build scope)
