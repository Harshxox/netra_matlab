# Colab Track — Phase Explanations

---

## C-0 — Environment & Setup
**What:** Install all Python libraries, connect Google Drive, download the three datasets (APTOS, IDRiD, DRIVE) from Kaggle into Colab.
**Why:** MATLAB has no GPU. Colab gives us a free T4/V100 which is the only way we can train deep learning models within the hackathon budget. Everything that follows depends on having datasets ready and libraries installed.
**How:** Runtime → change to GPU, `pip install` the ML stack, mount Drive for persistent storage, use Kaggle API to pull datasets, plot a class histogram to confirm the data loaded correctly.
**Why we need it:** Without this, no model can be trained. It's the foundation of the entire Colab track.

---

## C-1 — Data Pipeline & Augmentation
**What:** Write the reusable image loading, preprocessing, and augmentation code that all five model training runs will share.
**Why:** Five different models (grader + 4 segmentation types) all need green channel extraction, FOV cropping, and normalization — writing it once and reusing it prevents bugs from inconsistency between model inputs.
**How:** `extract_green_channel()`, `crop_fov()`, two Dataset classes (`APTOSDataset`, `SegmentationDataset`), two augmentation pipelines (classifier uses color jitter, segmentation doesn't — same augment must apply to both image and mask).
**Why we need it:** If C-1 is wrong, every model trained after it learns from corrupted input. Get this right first — it blocks C-2, C-3, C-4, C-5.

---

## C-2 — DR Grading Classifier
**What:** Fine-tune ResNet-50 on APTOS 2019 to classify fundus images into DR grades 0–4, then find the probability threshold where sensitivity for referable DR (grade ≥ 2) exceeds 90%.
**Why:** This is the core diagnostic model of the entire project. Every other module supports it — segmentation explains it, the dashboard displays it, the PDF reports it.
**How:** Freeze early ResNet layers, add a custom classification head, train with class-weighted loss (APTOS is heavily skewed to grade 0), track Quadratic Weighted Kappa as the primary metric, tune threshold on ROC curve, export to ONNX opset 11.
**Why we need it:** The SIH judging criteria require sensitivity > 90% on referable DR. The ONNX file `dr_grader.onnx` is what the MATLAB pipeline actually runs at inference time.

---

## C-3 — Vessel Segmentation (DRIVE)
**What:** Train a U-Net to produce a binary mask of all blood vessels in the retinal image, using the DRIVE dataset (40 images with expert vessel annotations).
**Why:** Vessel structure is a key clinical feature — vessel tortuosity and calibre changes indicate DR severity. The vessel map is shown in the dashboard as one of the five image layers.
**How:** U-Net with ResNet-34 encoder, single green channel input, combined BCE + Dice loss (Dice handles class imbalance between vessel/background pixels), random 512×512 patch extraction since DRIVE images are only 584×565.
**Why we need it:** Provides the `vessel_unet.onnx` model that MATLAB loads in M-3 to generate vessel overlays for the ophthalmologist.

---

## C-4 — Lesion Segmentation (IDRiD)
**What:** Train four separate binary U-Nets — one each for microaneurysms (MA), hemorrhages (HE), exudates (EX), and neovascularization (NV) — on the IDRiD Indian retinal dataset.
**Why:** Lesion presence and count directly determine the DR grade. Microaneurysms → early DR; hemorrhages → moderate; neovascularization → proliferative (Grade 4). The lesion overlays are what makes the AI decision explainable to the ophthalmologist.
**How:** Shared `LesionDataset` class handles missing masks (some IDRiD images have no MA mask — treated as zero mask). Positive class weighting (`pos_weight`) prevents all-zero predictions for sparse lesions like MA and NV. Each of the four models exports its own ONNX file.
**Why we need it:** Four ONNX files (`ma/he/ex/nv_unet.onnx`) that MATLAB loads to produce the colour-coded lesion overlay — the most clinically important explainability output.

---

## C-5 — Optic Disc Detector (IDRiD)
**What:** Train a U-Net to segment the optic disc (the bright circular region in the fundus) and extract its centre coordinates. Fovea location is estimated from the disc position.
**Why:** The optic disc and fovea are anatomical landmarks. Knowing the disc centre lets us measure distances to lesions (important for grading near the macula). The fovea is also a key region for detecting macular oedema.
**How:** U-Net on IDRiD optic disc masks (Dice target > 0.90 — the disc is large so this is achievable). The model outputs a segmentation mask; centroid extraction and fovea estimation (2.5 disc diameters temporal) happen in MATLAB post-processing, not in the ONNX.
**Why we need it:** Produces `od_detector.onnx`. Enables MATLAB to locate anatomical landmarks and include them in the evidence view.

---

## C-6 — ONNX Validation & Handoff
**What:** Run a validation script on all 7 exported ONNX files to confirm they load correctly, have the right output shapes, and use opset 11. Then upload everything to Google Drive and notify the MATLAB team.
**Why:** An ONNX file that exports from PyTorch cleanly can still fail to import in MATLAB if it uses an unsupported op or the wrong opset. This phase catches that failure before the MATLAB team wastes a day on a broken model file.
**How:** `validate_onnx()` checks: file loads in onnxruntime, output shape matches expected, opset == 11, max difference from PyTorch output < 1e-4. Fill in `docs/model_registry.md` with metrics and Drive links. Ping MATLAB team to confirm import works.
**Why we need it:** The handoff from Colab to MATLAB is the biggest integration risk in the project. This phase exists specifically to de-risk it before M-2 and M-3 depend on these files.
