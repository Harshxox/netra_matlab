# Phase C-4 — Lesion Segmentation (IDRiD)

**Track:** Colab | **Owner:** CNN lead | **Day:** 3–4
**Depends on:** C-1 | **Blocks:** MATLAB M-3

---

## Goal
Train four binary U-Nets on IDRiD lesion masks:
microaneurysms (MA), hemorrhages (HE), exudates (EX), neovascularization (NV).
Export four ONNX files for MATLAB import.

---

## Features

### F1 — IDRiD Dataset Structure
```python
# IDRiD folder structure
# /content/idrid/
#   A. Segmentation/
#     a. Training Set/
#       1. Original Images/
#       2. All Segmentation Groundtruths/
#         1. Microaneurysms/        ← *_MA.tif
#         2. Haemorrhages/          ← *_HE.tif
#         3. Hard Exudates/         ← *_EX.tif
#         4. Optic Disc/            ← *_OD.tif
#         (NV masks may be sparse — check availability)

import glob

base = '/content/idrid/A. Segmentation/a. Training Set'
img_dir  = f'{base}/1. Original Images'

lesion_dirs = {
    'MA': f'{base}/2. All Segmentation Groundtruths/1. Microaneurysms',
    'HE': f'{base}/2. All Segmentation Groundtruths/2. Haemorrhages',
    'EX': f'{base}/2. All Segmentation Groundtruths/3. Hard Exudates',
    'OD': f'{base}/2. All Segmentation Groundtruths/4. Optic Disc',
}

for name, path in lesion_dirs.items():
    masks = glob.glob(f'{path}/*.tif')
    print(f"{name}: {len(masks)} masks")
```

Note: IDRiD does not always include NV masks separately. If absent,
train NV detector on Retinal Lesions dataset or skip NV and use a rule-based
flag (grade 4 images assumed NV present).

---

### F2 — Lesion Dataset Class
```python
class LesionDataset(Dataset):
    def __init__(self, img_paths, mask_paths, size=512, transform=None):
        self.img_paths = img_paths
        self.mask_paths = mask_paths
        self.size = size
        self.transform = transform
        # Some images may have no corresponding mask (lesion absent)
        self.has_mask = [os.path.exists(m) for m in mask_paths]

    def __len__(self):
        return len(self.img_paths)

    def __getitem__(self, idx):
        img = cv2.imread(self.img_paths[idx])
        green = img[:, :, 1]
        green = cv2.resize(green, (self.size, self.size))

        if self.has_mask[idx]:
            mask = cv2.imread(self.mask_paths[idx], cv2.IMREAD_GRAYSCALE)
            mask = cv2.resize(mask, (self.size, self.size))
            mask = (mask > 127).astype(np.float32)
        else:
            mask = np.zeros((self.size, self.size), dtype=np.float32)

        green = green.astype(np.float32) / 255.0

        if self.transform:
            result = self.transform(image=(green * 255).astype(np.uint8), mask=mask)
            green = result['image'][0].float() / 255.0
            mask  = result['mask']

        return torch.tensor(green).unsqueeze(0), torch.tensor(mask).unsqueeze(0)
```

---

### F3 — Weighted Loss for Sparse Lesions
MA and NV are extremely sparse (< 1% foreground pixels). Standard BCE will
predict all-zeros and achieve 99% accuracy. Use pos_weight to fix this.
```python
def get_pos_weight(mask_paths, size=512):
    total_pixels, fg_pixels = 0, 0
    for mp in mask_paths:
        if os.path.exists(mp):
            m = cv2.imread(mp, cv2.IMREAD_GRAYSCALE)
            m = cv2.resize(m, (size, size))
            fg_pixels    += (m > 127).sum()
            total_pixels += m.size
    ratio = (total_pixels - fg_pixels) / (fg_pixels + 1)
    return torch.tensor([ratio]).cuda()

def weighted_bce_dice_loss(pred, target, pos_weight):
    bce  = F.binary_cross_entropy_with_logits(pred, target, pos_weight=pos_weight)
    dice = dice_loss(pred, target)
    return bce + dice
```

---

### F4 — Train One Lesion Model (template — repeat for each)
```python
def train_lesion_model(lesion_name, train_loader, val_loader, pos_weight, epochs=50):
    model = smp.Unet(
        encoder_name='resnet34',
        encoder_weights='imagenet',
        in_channels=1,
        classes=1,
        activation=None
    ).cuda()

    optimizer = Adam(model.parameters(), lr=5e-4)
    scheduler = ReduceLROnPlateau(optimizer, patience=7, factor=0.5)
    best_dice = 0

    for epoch in range(epochs):
        model.train()
        for imgs, masks in train_loader:
            imgs, masks = imgs.cuda(), masks.cuda()
            optimizer.zero_grad()
            preds = model(imgs)
            loss = weighted_bce_dice_loss(preds, masks, pos_weight)
            loss.backward()
            optimizer.step()

        model.eval()
        val_dice = 0
        with torch.no_grad():
            for imgs, masks in val_loader:
                imgs, masks = imgs.cuda(), masks.cuda()
                preds = model(imgs)
                val_dice += dice_score(preds, masks)
        val_dice /= len(val_loader)
        scheduler.step(1 - val_dice)

        if val_dice > best_dice:
            best_dice = val_dice
            torch.save(model.state_dict(),
                f'/content/drive/MyDrive/Netra/checkpoints/{lesion_name}_best.pth')

    print(f"{lesion_name} best Dice: {best_dice:.4f}")
    return model

# Train all four
ma_model = train_lesion_model('ma_unet', ma_train_loader, ma_val_loader, ma_pos_weight)
he_model = train_lesion_model('he_unet', he_train_loader, he_val_loader, he_pos_weight)
ex_model = train_lesion_model('ex_unet', ex_train_loader, ex_val_loader, ex_pos_weight)
nv_model = train_lesion_model('nv_unet', nv_train_loader, nv_val_loader, nv_pos_weight)
```

---

### F5 — ONNX Export (all four)
```python
def export_lesion_onnx(model, name, checkpoint_path):
    model.load_state_dict(torch.load(checkpoint_path))
    model.eval()
    dummy = torch.randn(1, 1, 512, 512).cuda()
    out_path = f'/content/drive/MyDrive/Netra/models/{name}.onnx'
    torch.onnx.export(
        model, dummy, out_path,
        opset_version=11,
        input_names=['green_channel'],
        output_names=['lesion_mask'],
        dynamic_axes={'green_channel': {0: 'batch'}, 'lesion_mask': {0: 'batch'}}
    )
    # Quick sanity check
    sess = ort.InferenceSession(out_path)
    dummy_np = dummy.cpu().numpy()
    with torch.no_grad():
        pt = model(dummy).cpu().numpy()
    onnx = sess.run(None, {'green_channel': dummy_np})[0]
    print(f"{name} max diff: {np.abs(pt - onnx).max():.6f}")

export_lesion_onnx(ma_model, 'ma_unet', '.../ma_unet_best.pth')
export_lesion_onnx(he_model, 'he_unet', '.../he_unet_best.pth')
export_lesion_onnx(ex_model, 'ex_unet', '.../ex_unet_best.pth')
export_lesion_onnx(nv_model, 'nv_unet', '.../nv_unet_best.pth')
```

---

## Target metrics per lesion

| Lesion | Target Dice | Notes |
|---|---|---|
| MA | > 0.40 | Sub-pixel, hardest task — lower bar is realistic |
| HE | > 0.60 | Moderate difficulty |
| EX | > 0.70 | Largest lesions — most tractable |
| NV | > 0.50 | Sparse, only in grade 4 images |

---

## Done when
- [ ] All four models trained and best checkpoints saved
- [ ] All four ONNX files exported to Google Drive
- [ ] All ONNX sanity checks pass (max diff < 1e-4)
- [ ] Dice scores at or above target per lesion type
