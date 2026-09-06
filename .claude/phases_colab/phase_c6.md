# Phase C-6 — ONNX Validation & Handoff

**Track:** Colab | **Owner:** CNN lead | **Day:** 5
**Depends on:** C-2, C-3, C-4, C-5 | **Blocks:** MATLAB M-2, M-3

---

## Goal
Validate all exported ONNX files, document them in the model registry,
and formally hand off to the MATLAB team for import and integration.

---

## Features

### F1 — Full ONNX Validation Suite
Run this for every model before declaring handoff complete.
```python
import onnx
import onnxruntime as ort
import numpy as np

def validate_onnx(onnx_path, input_shape, input_name):
    # 1. Check model is well-formed
    model = onnx.load(onnx_path)
    onnx.checker.check_model(model)
    print(f"[{onnx_path}] Model structure: OK")

    # 2. Run inference
    sess = ort.InferenceSession(onnx_path)
    dummy = np.random.randn(*input_shape).astype(np.float32)
    out = sess.run(None, {input_name: dummy})
    print(f"[{onnx_path}] Output shape: {out[0].shape} — OK")

    # 3. Check opset
    opset = model.opset_import[0].version
    assert opset == 11, f"Wrong opset: {opset} (expected 11)"
    print(f"[{onnx_path}] Opset: {opset} — OK")
    return True

# Run for all models
models = [
    ('dr_grader.onnx',    (1, 3, 224, 224), 'fundus_image'),
    ('vessel_unet.onnx',  (1, 1, 512, 512), 'green_channel'),
    ('ma_unet.onnx',      (1, 1, 512, 512), 'green_channel'),
    ('he_unet.onnx',      (1, 1, 512, 512), 'green_channel'),
    ('ex_unet.onnx',      (1, 1, 512, 512), 'green_channel'),
    ('nv_unet.onnx',      (1, 1, 512, 512), 'green_channel'),
    ('od_detector.onnx',  (1, 1, 512, 512), 'green_channel'),
]

drive_path = '/content/drive/MyDrive/Netra/models'
for name, shape, inp in models:
    validate_onnx(f'{drive_path}/{name}', shape, inp)
```

---

### F2 — Model Registry
Create `docs/model_registry.md` (commit to git — no Drive link needed, MATLAB team reads it).

```markdown
# Model Registry

| Model | Architecture | Dataset | Best Metric | Input | Output | Opset | Drive Link |
|---|---|---|---|---|---|---|---|
| dr_grader.onnx | ResNet-50 | APTOS 2019 | QWK=0.XX, Sens=XX% | (1,3,224,224) | (1,5) logits | 11 | [link] |
| vessel_unet.onnx | U-Net/ResNet-34 | DRIVE | Dice=0.XX | (1,1,512,512) | (1,1,512,512) | 11 | [link] |
| ma_unet.onnx | U-Net/ResNet-34 | IDRiD | Dice=0.XX | (1,1,512,512) | (1,1,512,512) | 11 | [link] |
| he_unet.onnx | U-Net/ResNet-34 | IDRiD | Dice=0.XX | (1,1,512,512) | (1,1,512,512) | 11 | [link] |
| ex_unet.onnx | U-Net/ResNet-34 | IDRiD | Dice=0.XX | (1,1,512,512) | (1,1,512,512) | 11 | [link] |
| nv_unet.onnx | U-Net/ResNet-34 | IDRiD | Dice=0.XX | (1,1,512,512) | (1,1,512,512) | 11 | [link] |
| od_detector.onnx | U-Net/ResNet-34 | IDRiD | Dice=0.XX | (1,1,512,512) | (1,1,512,512) | 11 | [link] |
```

---

### F3 — Handoff Checklist
Before notifying MATLAB team:
- [ ] All 7 ONNX files in Google Drive folder
- [ ] `referable_threshold.txt` in same folder
- [ ] All validation checks green
- [ ] Model registry filled with actual metrics and Drive links
- [ ] Colab notebooks committed to `/colab/` in git repo
- [ ] Notify MATLAB team on group chat with Drive folder link

---

## Done when
- [ ] All 7 ONNX files validated (structure OK, opset 11, correct output shapes)
- [ ] Model registry committed to `docs/model_registry.md`
- [ ] MATLAB team has the Drive link and can import at least `dr_grader.onnx`
