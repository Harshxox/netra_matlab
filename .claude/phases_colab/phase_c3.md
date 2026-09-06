# Phase C-3 — Vessel Segmentation (DRIVE)

**Track:** Colab | **Owner:** CNN lead | **Day:** 3–4
**Depends on:** C-1 | **Blocks:** MATLAB M-3

---

## Goal
Train a U-Net to segment retinal blood vessels from the green channel.
Dataset: DRIVE (40 training images with binary vessel masks).
Export as `vessel_unet.onnx` for MATLAB import.

---

## Features

### F1 — DRIVE Dataset Loading
```python
import os
import glob

drive_base = '/content/drive_ds/DRIVE'

train_imgs  = sorted(glob.glob(f'{drive_base}/training/images/*.tif'))
train_masks = sorted(glob.glob(f'{drive_base}/training/1st_manual/*.gif'))
test_imgs   = sorted(glob.glob(f'{drive_base}/test/images/*.tif'))
test_masks  = sorted(glob.glob(f'{drive_base}/test/1st_manual/*.gif'))

print(f"Train: {len(train_imgs)} images | Test: {len(test_imgs)} images")

# Verify pairing
for img, mask in zip(train_imgs[:3], train_masks[:3]):
    print(os.path.basename(img), '←→', os.path.basename(mask))
```

---

### F2 — Dataset with Patch Extraction
DRIVE images are 584×565. Use random 512×512 crops during training
to augment the tiny dataset.
```python
from torch.utils.data import Dataset
import cv2, numpy as np, torch

class DRIVEDataset(Dataset):
    def __init__(self, img_paths, mask_paths, patch_size=512, n_patches=8, transform=None):
        self.img_paths = img_paths
        self.mask_paths = mask_paths
        self.patch_size = patch_size
        self.n_patches = n_patches  # patches per image per epoch
        self.transform = transform

    def __len__(self):
        return len(self.img_paths) * self.n_patches

    def __getitem__(self, idx):
        img_idx = idx // self.n_patches
        img  = cv2.imread(self.img_paths[img_idx])
        mask = cv2.imread(self.mask_paths[img_idx], cv2.IMREAD_GRAYSCALE)
        mask = (mask > 127).astype(np.float32)
        green = img[:, :, 1].astype(np.float32) / 255.0  # green channel

        # Random crop
        h, w = green.shape
        p = self.patch_size
        top  = np.random.randint(0, h - p + 1)
        left = np.random.randint(0, w - p + 1)
        green_patch = green[top:top+p, left:left+p]
        mask_patch  = mask[top:top+p, left:left+p]

        if self.transform:
            result = self.transform(image=(green_patch * 255).astype(np.uint8), mask=mask_patch)
            green_patch = result['image'][0].float() / 255.0
            mask_patch  = result['mask']

        return torch.tensor(green_patch).unsqueeze(0), torch.tensor(mask_patch).unsqueeze(0)
```

---

### F3 — U-Net Model
```python
import segmentation_models_pytorch as smp

vessel_net = smp.Unet(
    encoder_name='resnet34',
    encoder_weights='imagenet',
    in_channels=1,          # green channel only
    classes=1,              # binary vessel mask
    activation=None         # raw logits — apply sigmoid in loss
).cuda()

print(f"Vessel U-Net params: {sum(p.numel() for p in vessel_net.parameters()):,}")
```

---

### F4 — Combined Loss (BCE + Dice)
```python
import torch.nn.functional as F

def dice_loss(pred, target, smooth=1.0):
    pred = torch.sigmoid(pred)
    intersection = (pred * target).sum(dim=(2, 3))
    dice = (2 * intersection + smooth) / (pred.sum(dim=(2,3)) + target.sum(dim=(2,3)) + smooth)
    return 1 - dice.mean()

def bce_dice_loss(pred, target):
    bce  = F.binary_cross_entropy_with_logits(pred, target)
    dice = dice_loss(pred, target)
    return bce + dice
```

---

### F5 — Metrics
```python
def iou_score(pred, target, threshold=0.5):
    pred = (torch.sigmoid(pred) > threshold).float()
    intersection = (pred * target).sum(dim=(2, 3))
    union = pred.sum(dim=(2, 3)) + target.sum(dim=(2, 3)) - intersection
    return (intersection / (union + 1e-6)).mean().item()

def dice_score(pred, target, threshold=0.5):
    pred = (torch.sigmoid(pred) > threshold).float()
    intersection = (pred * target).sum(dim=(2, 3))
    return (2 * intersection / (pred.sum(dim=(2,3)) + target.sum(dim=(2,3)) + 1e-6)).mean().item()
```

---

### F6 — Training Loop
```python
from torch.optim import Adam
from torch.optim.lr_scheduler import ReduceLROnPlateau

optimizer = Adam(vessel_net.parameters(), lr=1e-3)
scheduler = ReduceLROnPlateau(optimizer, patience=5, factor=0.5)

best_dice = 0
for epoch in range(60):
    vessel_net.train()
    train_loss = 0
    for imgs, masks in train_loader:
        imgs, masks = imgs.cuda(), masks.cuda()
        optimizer.zero_grad()
        preds = vessel_net(imgs)
        loss = bce_dice_loss(preds, masks)
        loss.backward()
        optimizer.step()
        train_loss += loss.item()

    vessel_net.eval()
    val_dice = 0
    with torch.no_grad():
        for imgs, masks in val_loader:
            imgs, masks = imgs.cuda(), masks.cuda()
            preds = vessel_net(imgs)
            val_dice += dice_score(preds, masks)
    val_dice /= len(val_loader)
    scheduler.step(1 - val_dice)

    print(f"Epoch {epoch+1:02d} | Loss: {train_loss/len(train_loader):.4f} | Val Dice: {val_dice:.4f}")
    if val_dice > best_dice:
        best_dice = val_dice
        torch.save(vessel_net.state_dict(), '/content/drive/MyDrive/Netra/checkpoints/vessel_unet_best.pth')
        print(f"  ✓ Best saved (Dice={best_dice:.4f})")
```

---

### F7 — ONNX Export & Validation
```python
vessel_net.load_state_dict(torch.load('/content/drive/MyDrive/Netra/checkpoints/vessel_unet_best.pth'))
vessel_net.eval()

dummy = torch.randn(1, 1, 512, 512).cuda()

torch.onnx.export(
    vessel_net, dummy,
    '/content/drive/MyDrive/Netra/models/vessel_unet.onnx',
    opset_version=11,
    input_names=['green_channel'],
    output_names=['vessel_mask'],
    dynamic_axes={'green_channel': {0: 'batch'}, 'vessel_mask': {0: 'batch'}}
)

# Sanity check
sess = ort.InferenceSession('/content/drive/MyDrive/Netra/models/vessel_unet.onnx')
dummy_np = np.random.randn(1, 1, 512, 512).astype(np.float32)
with torch.no_grad():
    pt_out = vessel_net(torch.tensor(dummy_np).cuda()).cpu().numpy()
onnx_out = sess.run(None, {'green_channel': dummy_np})[0]
print(f"Max diff: {np.abs(pt_out - onnx_out).max():.6f}")
```

---

## Done when
- [ ] Val Dice > 0.80 on DRIVE test split
- [ ] `vessel_unet.onnx` exported to Google Drive
- [ ] ONNX sanity check passes (max diff < 1e-4)
