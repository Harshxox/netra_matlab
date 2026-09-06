# Phase C-2 — DR Grading Classifier

**Track:** Colab | **Owner:** CNN lead | **Day:** 2–3
**Depends on:** C-1 | **Blocks:** MATLAB M-2

---

## Goal
Fine-tune ResNet-50 on APTOS 2019 to classify DR severity (grades 0–4).
Hit QWK > 0.80 and sensitivity > 90% for referable DR (grade ≥ 2).
Export as `dr_grader.onnx` for MATLAB import.

---

## Features

### F1 — Model Architecture
```python
import torch
import torch.nn as nn
import torchvision.models as models

def build_grader():
    model = models.resnet50(pretrained=True)
    # Freeze early layers — fine-tune from layer3 onwards
    for name, param in model.named_parameters():
        if 'layer1' in name or 'layer2' in name:
            param.requires_grad = False
    # Replace FC head for 5-class ordinal classification
    model.fc = nn.Sequential(
        nn.Dropout(p=0.3),
        nn.Linear(2048, 256),
        nn.ReLU(),
        nn.Linear(256, 5)
    )
    return model.cuda()

model = build_grader()
print(f"Trainable params: {sum(p.numel() for p in model.parameters() if p.requires_grad):,}")
```

---

### F2 — Loss Function & Optimizer
```python
from torch.optim import Adam
from torch.optim.lr_scheduler import CosineAnnealingLR

criterion = nn.CrossEntropyLoss(weight=class_weights)  # class_weights from C-1

optimizer = Adam([
    {'params': model.layer3.parameters(), 'lr': 1e-5},
    {'params': model.layer4.parameters(), 'lr': 1e-4},
    {'params': model.fc.parameters(),     'lr': 1e-3},
])

scheduler = CosineAnnealingLR(optimizer, T_max=30, eta_min=1e-6)
```

---

### F3 — QWK Metric
Primary metric — must track this, not just accuracy.
```python
from sklearn.metrics import cohen_kappa_score

def quadratic_weighted_kappa(y_true, y_pred):
    return cohen_kappa_score(y_true, y_pred, weights='quadratic')

def get_predictions(outputs):
    return torch.argmax(outputs, dim=1).cpu().numpy()
```

---

### F4 — Training Loop
```python
def train_epoch(model, loader, optimizer, criterion):
    model.train()
    total_loss, all_preds, all_labels = 0, [], []
    for imgs, labels in loader:
        imgs, labels = imgs.cuda(), labels.cuda()
        optimizer.zero_grad()
        outputs = model(imgs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        total_loss += loss.item()
        all_preds.extend(get_predictions(outputs))
        all_labels.extend(labels.cpu().numpy())
    qwk = quadratic_weighted_kappa(all_labels, all_preds)
    return total_loss / len(loader), qwk

def val_epoch(model, loader, criterion):
    model.eval()
    total_loss, all_preds, all_labels, all_probs = 0, [], [], []
    with torch.no_grad():
        for imgs, labels in loader:
            imgs, labels = imgs.cuda(), labels.cuda()
            outputs = model(imgs)
            loss = criterion(outputs, labels)
            probs = torch.softmax(outputs, dim=1)
            total_loss += loss.item()
            all_preds.extend(get_predictions(outputs))
            all_labels.extend(labels.cpu().numpy())
            all_probs.extend(probs.cpu().numpy())
    qwk = quadratic_weighted_kappa(all_labels, all_preds)
    return total_loss / len(loader), qwk, all_probs, all_labels

# Training run
best_qwk = 0
for epoch in range(30):
    train_loss, train_qwk = train_epoch(model, train_loader, optimizer, criterion)
    val_loss, val_qwk, val_probs, val_labels = val_epoch(model, val_loader, criterion)
    scheduler.step()
    print(f"Epoch {epoch+1:02d} | Train QWK: {train_qwk:.4f} | Val QWK: {val_qwk:.4f}")
    if val_qwk > best_qwk:
        best_qwk = val_qwk
        torch.save(model.state_dict(), '/content/drive/MyDrive/Netra/checkpoints/dr_grader_best.pth')
        print(f"  ✓ Best model saved (QWK={best_qwk:.4f})")
```

---

### F5 — Referable Threshold Tuning
```python
from sklearn.metrics import roc_curve
import numpy as np

val_probs_arr = np.array(val_probs)

# P(referable) = P(grade >= 2) = sum of probs for grades 2, 3, 4
p_referable = val_probs_arr[:, 2:].sum(axis=1)
binary_labels = [1 if l >= 2 else 0 for l in val_labels]

fpr, tpr, thresholds = roc_curve(binary_labels, p_referable)

# Find threshold giving sensitivity > 90%
valid = thresholds[tpr >= 0.90]
# Pick the highest threshold (most specific) that still meets sensitivity
best_threshold = valid.max() if len(valid) > 0 else 0.5

print(f"Best threshold: {best_threshold:.4f}")
print(f"At this threshold — Sensitivity: {tpr[thresholds >= best_threshold][0]:.3f}")

# Save threshold for MATLAB
with open('/content/drive/MyDrive/Netra/models/referable_threshold.txt', 'w') as f:
    f.write(str(best_threshold))
```

---

### F6 — ONNX Export
```python
import torch
import onnx

model.load_state_dict(torch.load('/content/drive/MyDrive/Netra/checkpoints/dr_grader_best.pth'))
model.eval()

dummy_input = torch.randn(1, 3, 224, 224).cuda()

torch.onnx.export(
    model,
    dummy_input,
    '/content/drive/MyDrive/Netra/models/dr_grader.onnx',
    opset_version=11,
    input_names=['fundus_image'],
    output_names=['class_logits'],
    dynamic_axes={
        'fundus_image': {0: 'batch_size'},
        'class_logits': {0: 'batch_size'}
    }
)
print("ONNX export complete")
```

---

### F7 — ONNX Sanity Check
```python
import onnxruntime as ort
import numpy as np

sess = ort.InferenceSession('/content/drive/MyDrive/Netra/models/dr_grader.onnx')
dummy_np = np.random.randn(1, 3, 224, 224).astype(np.float32)

# PyTorch output
with torch.no_grad():
    pt_out = model(torch.tensor(dummy_np).cuda()).cpu().numpy()

# ONNX output
onnx_out = sess.run(None, {'fundus_image': dummy_np})[0]

max_diff = np.abs(pt_out - onnx_out).max()
print(f"Max absolute difference PyTorch vs ONNX: {max_diff:.6f}")
assert max_diff < 1e-4, "ONNX output diverges from PyTorch — check export"
print("Sanity check passed")
```

---

## Done when
- [ ] Val QWK > 0.80 on APTOS validation set
- [ ] Sensitivity > 90% for referable DR at chosen threshold
- [ ] `dr_grader.onnx` exported and uploaded to Google Drive
- [ ] `referable_threshold.txt` saved alongside ONNX
- [ ] ONNX sanity check passes (max diff < 1e-4)
- [ ] MATLAB team notified to download and test import
