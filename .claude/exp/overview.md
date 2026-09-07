# Netra — Project Overview in Simple Words

---

## 1. Understanding the Eye & the Disease (Read this first)

### What is a Retina?
The retina is a thin layer at the back of your eye — think of it like the film in an old camera. It captures light and sends images to your brain. All the blood vessels that feed your eye are visible on the retina, which is why doctors can look at it to detect diseases.

### What is a Fundus Image?
A fundus image is a photograph of the back of your eye (the retina). A special camera shines light into your eye and takes a picture. This is the image our AI works with. It looks like a circular orange/red photograph with blood vessels branching out from a bright spot in the centre.

### What is Diabetic Retinopathy (DR)?
When someone has diabetes for a long time, high blood sugar damages the small blood vessels in the retina. This is called Diabetic Retinopathy. Over time, these damaged vessels can leak, bleed, or grow abnormally — and this slowly destroys vision. It is the leading cause of blindness in working-age adults worldwide. The scary part: it has no symptoms in early stages. By the time a person notices blurry vision, serious damage has already happened.

### The 5 Grades of DR
Doctors grade DR on a scale of 0 to 4:

| Grade | Name | What's happening in the eye |
|---|---|---|
| 0 | No DR | Eye looks healthy. No damage. |
| 1 | Mild | A few tiny blood vessel leaks called microaneurysms (MA). Barely visible. |
| 2 | Moderate | More MAs, some small bleeds (hemorrhages), some deposits (exudates). |
| 3 | Severe | Many bleeds, blocked vessels, significant damage. Risk of vision loss soon. |
| 4 | Proliferative DR | New abnormal blood vessels are growing (neovascularization). Most dangerous stage. |

**Grades 0–1 → Patient can be monitored.** Annual check is enough.
**Grades 2–4 → Referable DR.** Patient MUST see an eye specialist (ophthalmologist) soon.

### The Lesions We Look For
Lesions are the visible signs of damage on the retina. Our AI is trained to detect all of them:

- **Microaneurysms (MA)** — Tiny red dots. The earliest sign of DR. Very small, easy to miss manually.
- **Hemorrhages (HE)** — Larger red blotches where blood has leaked from broken vessels.
- **Exudates (EX)** — Yellow/white deposits. Fat and protein that leaked out of damaged vessels.
- **Neovascularization (NV)** — New, fragile blood vessels growing in abnormal places. Sign of Grade 4 (most dangerous).

### Key Anatomical Landmarks
- **Optic Disc** — The bright circular spot where blood vessels enter the eye. No light receptors here (it's your blind spot). Reference point for measuring distances.
- **Fovea** — The centre of your vision. The sharpest point. Located ~2.5 disc widths to the side of the optic disc. If lesions are near the fovea, it's serious.
- **Blood Vessels** — Branch out from the optic disc like a tree. Tortuosity (twisting) and calibre (width) changes signal disease.

### Why Is This Hard to Do Manually?
India has ~77 million diabetics. Most live in rural areas where there is less than 1 eye specialist per 100,000 people. To screen everyone manually, a doctor would need to look at fundus photos one by one. That's impossible at scale. Most people never get screened, and by the time they notice vision loss it's too late.

### What "Explainable AI" Means Here
A regular AI might say "Grade 3" and give no reason. A doctor cannot trust that — they need to know why. Explainable AI shows the doctor: here is what I was looking at (heatmap), here is what I found (lesion overlay), here is how confident I am (calibrated probability). The doctor then agrees or overrides. The AI triages; the human decides.

---

## 2. What is Netra?

Netra is an AI-powered screening tool that takes a fundus photo of a patient's eye and in about 30 seconds tells a health worker:
- What grade of Diabetic Retinopathy the patient has (0–4)
- Whether the patient needs to be referred to a specialist immediately
- A visual explanation of why the AI made that decision
- A PDF report the health worker can send to the ophthalmologist

It runs on a laptop at a Primary Health Centre (PHC) — no internet connection required for inference. The ophthalmologist reviews the AI's decision remotely and can agree or override it.

**In one sentence:** Netra is an explainable AI that helps rural health workers triage diabetic eye disease before a patient goes blind.

---

## 3. Why Are We Building It?

**The problem:**
- 77 million diabetics in India
- DR causes blindness but is completely preventable if caught early
- There are almost no eye specialists in rural India
- Manual screening at scale is impossible

**The current situation:** Most rural diabetics never get their eyes checked. By the time they go to a doctor, they've already lost significant vision. This is preventable.

**What Netra does:** Automates the first level of screening. A health worker at a PHC takes a photo. Netra analyses it in seconds and flags who needs urgent referral. Only referred patients need to travel to a specialist — saving time and money for patients, and saving specialist time for only the cases that truly need it.

**Why explainable:** A doctor cannot legally or ethically act on a black-box AI output. Netra shows its reasoning so the ophthalmologist can review and take responsibility for the final decision.

**Why this hackathon:** SIH 2026, Problem Statement 26038 from MathWorks/MedTech specifically asks for this system. It's a real, impactful problem with a clear technical solution.

---

## 4. Tech Stack (Simple Version)

We're using two tools, each doing what it's best at:

### Google Colab (for training AI models)
- **What it is:** A free online coding environment from Google that gives you access to powerful GPUs (graphics cards used for AI training)
- **Why we use it:** Training AI models requires heavy computation. We don't have access to GPUs locally or through campus. Colab provides this for free.
- **What we do in it:** Write Python code to train our AI models. Once trained, we export each model as an ONNX file (a universal AI model format).
- **Language:** Python (PyTorch library)

### MATLAB (for the actual screening pipeline)
- **What it is:** A scientific computing software widely used in engineering and medical imaging
- **Why we use it:** The problem statement is from MathWorks (the company that makes MATLAB). Using MATLAB is a judging criterion. It also has excellent built-in tools for image processing and medical imaging.
- **What we do in it:** Load the trained ONNX models, process images, run the AI, generate Grad-CAM heatmaps, build the dashboard, generate PDF reports.
- **Language:** MATLAB

### The Bridge (ONNX)
ONNX (Open Neural Network Exchange) is a file format that lets you train a model in Python and run it in MATLAB. Think of it like a PDF — it works the same way regardless of which software opens it. We export all 7 of our AI models as ONNX files and import them into MATLAB.

### Frontend (Dashboard)
The interface is built in HTML/CSS/JavaScript — normal web technologies — but it runs inside MATLAB using a special component called `uihtml`. This gives us a polished, modern-looking dashboard without building a separate web app.

### Storage
Patient records are stored in a MATLAB `.mat` file (like a database but simpler). We store file paths to images, never the images themselves.

---

## 5. How the Finished Product Works (User's Perspective)

```
1. Health worker opens Netra on a laptop at a PHC

2. Takes a fundus photo of the patient's eye with a fundus camera

3. Uploads the photo into Netra and enters the patient's ID

4. Netra checks the image quality — is it clear enough to grade?
   → If blurry or too dark: "Please retake the photo"
   → If OK: continues

5. Netra runs the image through 7 AI models simultaneously:
   - DR grader → gives grade 0–4
   - Vessel detector → maps blood vessels
   - 4 lesion detectors → finds MA, HE, EX, NV
   - Optic disc detector → locates anatomical landmarks

6. Dashboard shows the result in ~10 seconds:
   - Big coloured badge: REFER TO SPECIALIST or ROUTINE FOLLOW-UP
   - Grade (0–4) shown as filled circles
   - Confidence bar (how sure is the AI)
   - Grad-CAM heatmap (where the AI was looking)
   - Lesion overlay (what it found, colour-coded)
   - Lesion counts: "18 microaneurysms, 3 hemorrhages"

7. Ophthalmologist reviews remotely:
   - Looks at the dashboard
   - Clicks "Agree" if they agree with the AI
   - Or selects "Override" and sets a different grade with notes

8. Health worker can download a PDF report to share with the patient

9. Every screening is saved — next visit shows the trend:
   "No DR → Mild → Moderate over 8 months"
```

---

## 6. How We Are Building It (Team's Perspective)

We split into two parallel teams working simultaneously:

### Colab Team (2 people) — trains the AI
```
Week 1:
Day 1:   Set up Colab, download all datasets, verify GPU works
Day 1-2: Build data loading and preprocessing code (used by all models)
Day 2-4: Train the DR grading model (ResNet-50 architecture)
Day 2-5: Train all 5 segmentation models (U-Net architecture) in parallel
Day 5:   Validate all 7 ONNX files, upload to Google Drive, hand off to MATLAB team
```

### MATLAB Team (4 people) — builds the pipeline and app
```
Week 1:
Day 1:   Everyone sets up MATLAB, proves ONNX import works, proves dashboard messaging works
Day 1-2: Build image preprocessing and quality check module
Day 1-3: Build data layer (database) + Simulink model (can start immediately, independent)
Day 3-4: Plug ONNX models in (once Colab hands them over) — grading inference + segmentation inference
Day 4-5: Build Grad-CAM explainability + PDF report generator
Day 4-6: Build the full HTML dashboard and wire it to MATLAB
Day 6-7: Integrate everything into one pipeline, validate on test data, build PPT, rehearse demo
```

### The Critical Handoff
The most important moment in the build week is when the Colab team uploads the ONNX files to Google Drive and the MATLAB team imports them. This should happen by Day 4. If it's delayed, MATLAB modules M-2 and M-3 are blocked and the integration timeline slips.

### Git Strategy
Each phase lives on its own Git branch (e.g. `phase-2-grading`, `phase-3-segmentation`). When a phase is done and tested, it gets merged into `main`. This way the team never breaks each other's work.

---

## 7. Key Numbers to Remember

| Number | What it means |
|---|---|
| 77 million | Diabetics in India |
| 0–4 | DR severity grades |
| Grade ≥ 2 | Referable DR — must see specialist |
| > 90% | Required sensitivity for detecting referable DR |
| > 85% | Required specificity |
| < 30 seconds | Time for ophthalmologist to review one case |
| 7 | Number of AI models in the pipeline |
| 9 | Number of ONNX files handed from Colab to MATLAB |
| 100,000 | Patients per year per district (Simulink model) |
| Messidor-2 | The test dataset — never trained on — used to prove the AI generalises |

---

## 8. Key Terms Glossary

| Term | Simple meaning |
|---|---|
| Fundus image | Photo of the back of the eye |
| Retina | Light-sensing layer at the back of the eye |
| Microaneurysm | Tiny red dot — earliest sign of DR |
| Hemorrhage | Bleed from a damaged blood vessel |
| Exudate | Yellow deposit from leaking vessels |
| Neovascularization | Dangerous new abnormal blood vessel growth |
| Optic disc | Bright spot where vessels enter the eye |
| Fovea | Centre of sharp vision |
| Grad-CAM | Heatmap showing which part of the image the AI focused on |
| ONNX | Universal model file format (train in Python, run in MATLAB) |
| Referable DR | Grade ≥ 2 — patient needs specialist referral |
| QWK | Quadratic Weighted Kappa — measures how close predictions are to real grades |
| Sensitivity | How good the AI is at catching real DR cases (not missing sick patients) |
| Specificity | How good the AI is at clearing healthy patients (not over-referring) |
| Temperature scaling | A technique to make the AI's confidence scores more accurate |
| U-Net | AI architecture used for finding things in images (segmentation) |
| ResNet-50 | AI architecture used for classifying images (grading) |
| PHC | Primary Health Centre — rural government clinic |
| SimEvents | Simulink tool for modelling queues and workflows |
