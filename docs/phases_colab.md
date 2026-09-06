# Colab Track — Training Phases (PS 26038)

> Owner: CNN lead (1 person).
> Tool: Google Colab (free GPU — T4/V100).
> Output: trained `.onnx` files uploaded to the shared Google Drive folder.
> Runtime: Python only. No Python runs at inference time — Colab is training-only.

Everything here runs in `/colab/*.ipynb` notebooks committed to git.

---

## C-0 — Environment Setup  *(Day 1)*

- [ ] Open new Colab notebook; switch runtime to GPU (`Runtime → Change runtime type → T4 GPU`)
- [ ] Confirm GPU available: `!nvidia-smi`
- [ ] Install dependencies:
  ```
  pip install torch torchvision albumentations segmentation-models-pytorch
  pip install scikit-learn pandas matplotlib onnx onnxruntime kaggle
  ```
- [ ] Mount Google Drive: `drive.mount('/content/drive')`
- [ ] Set up Kaggle API (`kaggle.json` → `~/.kaggle/`)
- [ ] Download datasets:
  - `kaggle competitions download -c aptos2019-blindness-detection` → APTOS 2019
  - `kaggle datasets download -d mariaherrerot/idrid-dataset` → IDRiD
  - `kaggle datasets download -d andrewmvd/drive-digital-retinal-images-for-vessel-extraction` → DRIVE
- [ ] Download Messidor-2 separately — store in `/content/drive/messidor2/` and **never load during training**
- [ ] Plot APTOS class distribution histogram — confirm severe class imbalance (grade 0 dominates)

**Done when:** GPU confirmed, all datasets downloaded, class imbalance visible in histogram.

---

## C-1 — Data Pipeline & Augmentation  *(shared across all models)*

- [ ] Write a reusable `RetinalDataset` class (PyTorch `Dataset`):
  - Loads image from path
  - Applies augmentation pipeline
  - Returns `(image_tensor, label)`
- [ ] Augmentation pipeline via `albumentations`:
  ```
  RandomRotate90, HorizontalFlip, VerticalFlip,
  RandomBrightnessContrast, HueSaturationValue,
  GaussianBlur, GridDistortion (for segmentation only)
  ```
- [ ] Green channel extraction function — used for all lesion/vessel preprocessing
- [ ] FOV crop + resize utility:
  - Detect retina circle via thresholding
  - Crop black border
  - Resize: 224×224 for grading classifier, 512×512 for segmentation U-Nets
- [ ] Normalization: ImageNet mean/std for ResNet-50; [0,1] for U-Nets

**Done when:** `DataLoader` yields correctly shaped, augmented batches for both classifier and segmentation tasks.

---

## C-2 — DR Grading Classifier  *(CORE — highest priority)*

- [ ] Stratified train / val / test split on APTOS 2019 (70/15/15)
- [ ] Load pretrained `resnet50` from torchvision (`pretrained=True`)
- [ ] Replace FC head: `model.fc = nn.Linear(2048, 5)` for grades 0–4
- [ ] Class-weighted loss:
  ```python
  weights = compute_class_weight('balanced', classes=[0,1,2,3,4], y=train_labels)
  criterion = nn.CrossEntropyLoss(weight=torch.tensor(weights).float())
  ```
- [ ] Optimizer: Adam, lr=1e-4; scheduler: CosineAnnealingLR
- [ ] Train for 20–30 epochs on Colab GPU; log per epoch:
  - Training loss
  - Validation accuracy
  - **Quadratic Weighted Kappa (QWK)** — primary metric
- [ ] Referable threshold tuning:
  - Pool grades 2+3+4 as "referable" vs 0+1 as "not referable"
  - Plot ROC curve on validation set
  - Find threshold that hits **sensitivity > 90%** — record this threshold value
- [ ] Save best checkpoint: `dr_grader_best.pth`
- [ ] Export to ONNX:
  ```python
  torch.onnx.export(
      model, dummy_input, 'dr_grader.onnx',
      opset_version=11,
      input_names=['fundus_image'],
      output_names=['class_logits'],
      dynamic_axes={'fundus_image': {0: 'batch'}}
  )
  ```
- [ ] Quick sanity check with `onnxruntime` — confirm output matches PyTorch output
- [ ] Upload `dr_grader.onnx` + `referable_threshold.txt` to Google Drive

**Done when:** model hits **QWK > 0.80** and **sensitivity > 90% for referable DR** on APTOS validation set. ONNX exported and verified.

---

## C-3 — Vessel Segmentation (DRIVE)

- [ ] Load DRIVE dataset: 40 training images + binary vessel masks
- [ ] U-Net architecture via `segmentation-models-pytorch`:
  ```python
  model = smp.Unet(encoder_name='resnet34', in_channels=1, classes=1)
  # in_channels=1 because we use green channel only
  ```
- [ ] Loss: `BCEWithLogitsLoss` + Dice loss (combined)
- [ ] Train for 50 epochs (tiny dataset — fast); track IoU + Dice score per epoch
- [ ] Export:
  ```python
  torch.onnx.export(model, dummy, 'vessel_unet.onnx', opset_version=11)
  ```
- [ ] Upload `vessel_unet.onnx` to Google Drive

**Done when:** vessel U-Net achieves **Dice > 0.80** on DRIVE test split. ONNX exported.

---

## C-4 — Lesion Segmentation (IDRiD)

Four lesion targets from IDRiD pixel masks: **MA, HE, EX, NV (neovascularization)**

- [ ] Load IDRiD segmentation dataset: ~400 images + separate masks per lesion type
- [ ] Train one multi-class U-Net (4 output channels) OR four separate binary U-Nets
      Recommendation: **four binary U-Nets** — simpler, easier to debug, better per-class performance
- [ ] For each lesion type (MA / HE / EX / NV):
  - Heavy augmentation (lesions are sparse — needs elastic distortion + heavy flips)
  - Weighted loss: foreground pixels are rare; use `pos_weight` in `BCEWithLogitsLoss`
  - Track Dice score per lesion class
- [ ] Export each model separately:
  - `ma_unet.onnx` — microaneurysm detector
  - `he_unet.onnx` — hemorrhage detector
  - `ex_unet.onnx` — exudate detector
  - `nv_unet.onnx` — neovascularization detector
- [ ] Upload all four to Google Drive

**Done when:** each lesion U-Net achieves **Dice > 0.60** on IDRiD test split (MA is hardest — sub-pixel, may be lower). All four ONNX files exported.

---

## C-5 — Optic Disc / Fovea Detector (IDRiD)

- [ ] Use IDRiD optic disc masks (binary segmentation task)
- [ ] Lightweight U-Net or simple ResNet-based localizer
- [ ] Output: bounding box centroid (x, y) of optic disc + fovea estimate
      (fovea ≈ 2.5 disc diameters temporal to OD — can be rule-based from OD centroid)
- [ ] Export: `od_detector.onnx`
- [ ] Upload to Google Drive

**Done when:** OD centroid localized within 30px of ground truth on IDRiD test images. ONNX exported.

---

## C-6 — ONNX Validation & Handoff

- [ ] For every exported model, run a side-by-side comparison:
  - PyTorch output vs. `onnxruntime` output on 10 test images
  - Max absolute difference < 1e-4 (floating point tolerance)
- [ ] Document in `docs/model_registry.md`:
  - Model name, architecture, dataset, best metric, ONNX filename, Google Drive link, opset version
- [ ] Notify MATLAB team that models are ready for `importONNXNetwork`

**Done when:** all 6 ONNX files validated, model registry documented, MATLAB team can download and import.

---

## Summary — Colab Outputs

| File | Phase | What it does |
|---|---|---|
| `dr_grader.onnx` | C-2 | DR severity grading (grades 0–4) |
| `referable_threshold.txt` | C-2 | Calibrated threshold for referable DR |
| `vessel_unet.onnx` | C-3 | Blood vessel segmentation |
| `ma_unet.onnx` | C-4 | Microaneurysm detection |
| `he_unet.onnx` | C-4 | Hemorrhage detection |
| `ex_unet.onnx` | C-4 | Exudate detection |
| `nv_unet.onnx` | C-4 | Neovascularization detection |
| `od_detector.onnx` | C-5 | Optic disc / fovea localization |
