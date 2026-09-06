# Phase C-5 — Optic Disc / Fovea Detector

**Track:** Colab | **Owner:** CNN lead | **Day:** 4
**Depends on:** C-1 | **Blocks:** MATLAB M-3

---

## Goal
Localize the optic disc centroid and estimate the fovea position from IDRiD
optic disc masks. Export as `od_detector.onnx` for MATLAB.

---

## Features

### F1 — OD Segmentation Model
Use the same U-Net template as C-3/C-4 but trained on IDRiD OD masks.
OD is large and well-defined — this is the easiest segmentation task.
```python
od_model = smp.Unet(
    encoder_name='resnet34',
    encoder_weights='imagenet',
    in_channels=1,
    classes=1,
    activation=None
).cuda()
# Train with standard bce_dice_loss (OD is not sparse)
# Target: Dice > 0.90 (OD is large and clear)
```

---

### F2 — Centroid Extraction (post-processing in MATLAB)
The model outputs a binary mask. Centroid is extracted in MATLAB from the mask —
no need to bake it into the ONNX model.

MATLAB post-processing (for reference — goes in M-3):
```matlab
% After importing od_detector.onnx and running inference:
odMask = logical(odOutput > 0.5);
props = regionprops(odMask, 'Centroid', 'Area');
if ~isempty(props)
    [~, idx] = max([props.Area]);
    odCentroid = props(idx).Centroid; % [x, y]
    % Fovea estimate: ~2.5 disc diameters temporal to OD
    discRadius = sqrt(props(idx).Area / pi);
    foveaX = odCentroid(1) - 2.5 * discRadius * 2; % temporal direction
    foveaY = odCentroid(2);
end
```

---

### F3 — Export
```python
od_model.eval()
dummy = torch.randn(1, 1, 512, 512).cuda()
torch.onnx.export(
    od_model, dummy,
    '/content/drive/MyDrive/Netra/models/od_detector.onnx',
    opset_version=11,
    input_names=['green_channel'],
    output_names=['od_mask'],
    dynamic_axes={'green_channel': {0: 'batch'}, 'od_mask': {0: 'batch'}}
)
```

---

## Done when
- [ ] OD Dice > 0.90 on IDRiD test split
- [ ] `od_detector.onnx` exported and validated
- [ ] Upload to Google Drive
