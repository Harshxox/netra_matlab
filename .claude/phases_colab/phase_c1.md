# Phase C-1 — Data Pipeline & Augmentation

**Track:** Colab | **Owner:** CNN lead | **Day:** 1–2
**Blocks:** C-2, C-3, C-4, C-5

---

## Goal
Build reusable data loading + augmentation utilities shared across all models.
Write once, use everywhere — grading classifier, vessel U-Net, lesion U-Nets.

---

## Features

### F1 — Green Channel Extraction
All lesion and vessel processing uses green channel only (best contrast).
```python
import cv2
import numpy as np

def extract_green_channel(img_bgr):
    # img_bgr: H x W x 3 numpy array (BGR from cv2.imread)
    return img_bgr[:, :, 1]  # green is index 1 in BGR
```

---

### F2 — FOV Crop
Remove the black border around the retina circle.
```python
def crop_fov(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img
    _, mask = cv2.threshold(gray, 10, 255, cv2.THRESH_BINARY)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return img
    c = max(contours, key=cv2.contourArea)
    x, y, w, h = cv2.boundingRect(c)
    return img[y:y+h, x:x+w]
```

---

### F3 — Resize & Normalize
Two target sizes: 224×224 for grading (ResNet-50), 512×512 for U-Nets.
```python
def preprocess_classifier(img, size=(224, 224)):
    img = crop_fov(img)
    img = cv2.resize(img, size)
    img = img.astype(np.float32) / 255.0
    # ImageNet normalization for ResNet-50
    mean = np.array([0.485, 0.456, 0.406])
    std  = np.array([0.229, 0.224, 0.225])
    img = (img - mean) / std
    return img.transpose(2, 0, 1)  # H,W,C → C,H,W

def preprocess_segmentation(img, size=(512, 512)):
    green = extract_green_channel(img)
    green = crop_fov(green)
    green = cv2.resize(green, size)
    green = green.astype(np.float32) / 255.0
    return green[np.newaxis, ...]  # add channel dim → 1,H,W
```

---

### F4 — Augmentation Pipelines
Two separate pipelines — classification and segmentation.
```python
import albumentations as A
from albumentations.pytorch import ToTensorV2

# For grading classifier — mimics field camera variation
classifier_aug = A.Compose([
    A.RandomRotate90(p=0.5),
    A.HorizontalFlip(p=0.5),
    A.VerticalFlip(p=0.3),
    A.RandomBrightnessContrast(brightness_limit=0.2, contrast_limit=0.2, p=0.5),
    A.HueSaturationValue(hue_shift_limit=10, sat_shift_limit=20, p=0.3),
    A.GaussianBlur(blur_limit=(3, 5), p=0.2),
    A.Normalize(mean=(0.485, 0.456, 0.406), std=(0.229, 0.224, 0.225)),
    ToTensorV2()
])

# For segmentation — needs spatial consistency between image and mask
segmentation_aug = A.Compose([
    A.RandomRotate90(p=0.5),
    A.HorizontalFlip(p=0.5),
    A.VerticalFlip(p=0.5),
    A.ElasticTransform(alpha=120, sigma=120*0.05, p=0.3),
    A.GridDistortion(p=0.3),
    A.RandomBrightnessContrast(p=0.3),
    A.GaussianBlur(p=0.2),
], additional_targets={'mask': 'mask'})
```

---

### F5 — PyTorch Dataset Classes
```python
from torch.utils.data import Dataset
import torch

class APTOSDataset(Dataset):
    def __init__(self, df, img_dir, transform=None):
        self.df = df
        self.img_dir = img_dir
        self.transform = transform

    def __len__(self):
        return len(self.df)

    def __getitem__(self, idx):
        row = self.df.iloc[idx]
        img = cv2.imread(f"{self.img_dir}/{row['id_code']}.png")
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        label = int(row['diagnosis'])
        if self.transform:
            result = self.transform(image=img)
            img = result['image']
        return img, label

class SegmentationDataset(Dataset):
    def __init__(self, img_paths, mask_paths, transform=None):
        self.img_paths = img_paths
        self.mask_paths = mask_paths
        self.transform = transform

    def __len__(self):
        return len(self.img_paths)

    def __getitem__(self, idx):
        img = cv2.imread(self.img_paths[idx])
        mask = cv2.imread(self.mask_paths[idx], cv2.IMREAD_GRAYSCALE)
        mask = (mask > 127).astype(np.float32)
        green = extract_green_channel(img)
        green_3ch = np.stack([green, green, green], axis=-1)  # albumentations needs 3ch
        if self.transform:
            result = self.transform(image=green_3ch, mask=mask)
            green_3ch = result['image']
            mask = result['mask']
        green_tensor = torch.tensor(green_3ch[0:1], dtype=torch.float32)  # 1,H,W
        mask_tensor = torch.tensor(mask, dtype=torch.float32).unsqueeze(0)
        return green_tensor, mask_tensor
```

---

### F6 — Train / Val / Test Split (APTOS)
```python
from sklearn.model_selection import train_test_split

df = pd.read_csv('/content/aptos/train.csv')

# Stratified split to preserve class balance
train_df, temp_df = train_test_split(df, test_size=0.3, stratify=df['diagnosis'], random_state=42)
val_df, test_df   = train_test_split(temp_df, test_size=0.5, stratify=temp_df['diagnosis'], random_state=42)

print(f"Train: {len(train_df)} | Val: {len(val_df)} | Test: {len(test_df)}")
# Verify grade distribution is preserved
print(train_df['diagnosis'].value_counts().sort_index())
```

---

### F7 — Class Weights (for imbalanced training)
```python
from sklearn.utils.class_weight import compute_class_weight

weights = compute_class_weight(
    class_weight='balanced',
    classes=np.array([0, 1, 2, 3, 4]),
    y=train_df['diagnosis'].values
)
class_weights = torch.tensor(weights, dtype=torch.float32).cuda()
print("Class weights:", weights)
# Expected: higher weights for grades 1, 3, 4 (minority classes)
```

---

## Done when
- [ ] `APTOSDataset` yields correct image tensors + integer labels
- [ ] `SegmentationDataset` yields paired (green_channel, mask) tensors
- [ ] Augmentation pipeline applied without shape errors
- [ ] Train/val/test split stratified and verified
- [ ] Class weights computed and match expected imbalance direction
