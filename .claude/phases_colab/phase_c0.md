# Phase C-0 — Colab Environment Setup

**Track:** Colab | **Owner:** CNN lead | **Day:** 1
**Blocks:** C-1, C-2, C-3, C-4, C-5

---

## Goal
Get Colab running with GPU, all libraries installed, all datasets downloaded,
and confirm you can load an image + label before writing any model code.

---

## Features

### F1 — GPU Runtime
Switch runtime to GPU before anything else.
```
Runtime → Change runtime type → Hardware accelerator → T4 GPU → Save
```
Confirm:
```python
!nvidia-smi
# Should show Tesla T4 or V100 with memory info
```
If no GPU shows: free Colab may be throttled — try reconnecting or use Kaggle (also free, more consistent GPU).

---

### F2 — Library Installation
```python
!pip install -q \
  torch torchvision \
  albumentations \
  segmentation-models-pytorch \
  scikit-learn \
  pandas matplotlib \
  onnx onnxruntime \
  kaggle \
  opencv-python-headless

# Verify key imports
import torch
print(torch.__version__)
print(torch.cuda.is_available())  # must be True
```

---

### F3 — Google Drive Mount
```python
from google.colab import drive
drive.mount('/content/drive')

# Create project folders on Drive
import os
os.makedirs('/content/drive/MyDrive/Netra/models', exist_ok=True)
os.makedirs('/content/drive/MyDrive/Netra/checkpoints', exist_ok=True)
```
All ONNX exports go to `/content/drive/MyDrive/Netra/models/` so they survive session resets.

---

### F4 — Kaggle API Setup
```python
# Upload your kaggle.json (from kaggle.com → Account → Create API Token)
from google.colab import files
files.upload()  # select kaggle.json

import os
os.makedirs('/root/.kaggle', exist_ok=True)
!cp kaggle.json /root/.kaggle/
!chmod 600 /root/.kaggle/kaggle.json
!kaggle --version  # confirm works
```

---

### F5 — Dataset Download
```python
# APTOS 2019 — DR grading (~9GB)
!kaggle competitions download -c aptos2019-blindness-detection -p /content/aptos
!unzip -q /content/aptos/aptos2019-blindness-detection.zip -d /content/aptos

# DRIVE — vessel segmentation (~10MB)
!kaggle datasets download -d andrewmvd/drive-digital-retinal-images-for-vessel-extraction -p /content/drive_ds
!unzip -q /content/drive_ds/*.zip -d /content/drive_ds

# IDRiD — lesion segmentation (~1.5GB)
!kaggle datasets download -d mariaherrerot/idrid-dataset -p /content/idrid
!unzip -q /content/idrid/*.zip -d /content/idrid
```

Messidor-2: download separately from the official site → upload to
`/content/drive/MyDrive/Netra/messidor2/` and **never touch during training**.

---

### F6 — Class Distribution Check
```python
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv('/content/aptos/train.csv')
print(df['diagnosis'].value_counts().sort_index())

df['diagnosis'].value_counts().sort_index().plot(kind='bar', color='steelblue')
plt.xlabel('DR Grade (0=No DR, 4=Proliferative)')
plt.ylabel('Image Count')
plt.title('APTOS 2019 — Class Distribution')
plt.tight_layout()
plt.savefig('/content/drive/MyDrive/Netra/aptos_class_dist.png')
plt.show()
```
Expected: severe imbalance — grade 0 dominates (~49%), grade 4 is rare (~7%).

---

## Done when
- [ ] `torch.cuda.is_available()` returns `True`
- [ ] All three datasets unzipped and loadable
- [ ] Class distribution histogram saved to Drive
- [ ] ONNX and onnxruntime import without errors
