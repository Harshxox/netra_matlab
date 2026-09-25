# Netra — Prototype Demo Recording Script

> Two versions below: a **60-second cut** (Part 0) and the **full 3-minute** script.
> Audience: SIH evaluators. Tone: confident, clinical, honest.

---

## PART 0 — THE 60-SECOND CUT

**Pre-stage before you hit record** (so no time is wasted on setup):
- `seedDemoPatients` has been run.
- `NetraApp` is open, **already signed in as `phc` / `phc2026`**.
- A patient is **already registered and selected** — you're sitting on the
  "Ready to screen" landing page (just clicked "Register & start screening"
  for *Anita Sharma, 54, Rampur PHC*).
- `003f0afdcd15.png` is on the desktop / easy to reach in the file dialog.
- Have the `admin` window OR a second run ready — OR just do the sidebar logout.

Read the narration at a **calm, steady pace**. Actions in **bold**.
Total spoken ≈ 135 words.

| Time | Narration | Action on screen |
|---|---|---|
| **0:00–0:07** | "India has 77 million diabetics and almost no eye specialists in rural areas. **Netra** screens them in seconds." | Hold on the "Ready to screen" landing page. |
| **0:07–0:12** | "A health worker uploads a fundus photograph…" | **Click "Open fundus image" → select `003f0afdcd15.png`.** Scanning animation plays. |
| **0:12–0:25** | "…and our MATLAB pipeline checks image quality, segments the retinal lesions, and grades diabetic retinopathy on the clinical zero-to-four scale. Here — **Grade 2, Moderate. Refer to a specialist** — with a calibrated confidence score." | Dashboard renders. Let it sit. Small mouse move across the grade → verdict → the three gauges. |
| **0:25–0:38** | "It shows *why*: an attention map of the regions driving the decision, a colour-coded lesion overlay, and a plain-language reason tied to clinical criteria." | **Click layer buttons: Attention → Lesions.** Then **scroll down once** to reveal the "Why this grade" line and the findings table. |
| **0:38–0:46** | "So an ophthalmologist validates each case in under thirty seconds — they Agree, or Override. Every decision is saved to the patient's record." | **Scroll back up. Click "Agree with AI".** Status shows "Decision saved". |
| **0:46–0:52** | "One click produces a patient report…" | **Click "Open report".** PDF flashes up. **Close it.** |
| **0:52–0:60** | "…and the district officer sees every patient, every screening, the referral rate. Explainable, offline, MATLAB-native retinal screening for rural India." | **Sidebar → logout → sign in `admin` / `netra2026`.** Land on the District Console (stat tiles + patient table). Freeze here. |

**Tips for the 60s cut**
- The screening pipeline takes ~5 s — talk straight through the animation.
- Don't wait for pages to settle; keep moving, keep talking.
- If it runs to 65–70 s that's fine. Over 75 s, cut the report line (0:46–0:52).
- Record the admin login as the *last* beat — end on the district-scale view, it's the strongest final image.

---

## PART A — FULL 3-MINUTE SCRIPT

> Target length: **3 minutes** (2:30–3:30 is fine).

---

## PART A — Before you record

### 1. Clean the data + warm the app
```matlab
cd 'C:\Users\sharm\Desktop\SIH PROJECT\netra2.0\netra'
addpath(genpath('src')); addpath('app'); addpath('simulink')
seedDemoPatients          % 8 demo patients for the admin console
NetraApp                  % wait for status: "Ready"
```
Then **close NetraApp and open it once more** — the second launch is instant (caches warm).

### 2. Pick your images (from `data\samples\`)
| Role in demo | File | Expected |
|---|---|---|
| Main case (referable) | `003f0afdcd15.png` | Grade 2 – Moderate, focal evidence heatmap |
| Second case (healthy) | `0097f532ac9f.png` | Grade 0 – No DR |
| (optional) ungradable | make a blurry copy | RECAPTURE path |

Do a full dry run with these exact files **3 times** before recording. Know every click.

### 3. Screen setup
- **Maximise the NetraApp window.** Close the MATLAB command window / editor, or move them off-screen.
- Hide desktop icons, set a plain wallpaper, disable notifications (Windows: Focus assist ON).
- Resolution: record at **1920×1080, 30 fps**.

### 4. Recorder
- **OBS Studio** (free, best) — "Display Capture" source, or "Window Capture" on the app window.
- Or quick option: **Windows Game Bar** (`Win + G` → record) or PowerPoint → Insert → Screen Recording.
- Record **video + microphone**. If your mic is weak, record the screen silently and add voiceover after in any video editor (even Clipchamp, built into Windows).

### 5. Have Simulink ready in a second step
Before recording, run once so the figures exist:
```matlab
open_system('simulink/netra_telemedicine')
runSimulation            % prints the district numbers - screenshot the output
```

---

## PART B — The script (scene by scene)

Read the **narration** aloud (or record it separately). Actions in **bold**.

---

### SCENE 1 — The problem  *(0:00 – 0:20)*

*(On screen: a title slide, OR the Netra login page held still)*

> "India has over 77 million diabetic adults — the second highest in the world.
> Nearly one in five will develop diabetic retinopathy, a leading cause of
> **preventable** blindness. But rural India has fewer than one eye specialist
> per hundred thousand people, so most patients are never screened.
> **Netra** is an explainable, MATLAB-native AI that triages diabetic eye
> disease at the primary health centre — and shows the doctor exactly why."

---

### SCENE 2 — Sign in  *(0:20 – 0:32)*

**Show the login page. Type `phc` / `phc2026`. Click Sign in.**

> "Netra runs on a laptop at the health centre. A health worker signs in —
> here, a PHC operator. There's also a district-officer console, which I'll
> show later."

---

### SCENE 3 — Register a patient  *(0:32 – 0:55)*

**On the 'Screen a patient' view, fill the 'Register new patient' form:**
- Name: `Anita Sharma`  ·  Age: `54`  ·  Sex: `F`
- Phone: `9876543210`  ·  Village: `Rampur PHC`  ·  Years with diabetes: `9`

**Click "Register & start screening".**

> "A new patient arrives. The worker takes thirty seconds to create a profile —
> name, age, village, how long they've had diabetes. Everything is stored
> locally and linked to this patient. Existing patients can be found by name,
> ID, or phone."

---

### SCENE 4 — Run the screening  *(0:55 – 1:35)*

**Click "Open fundus image". Select `003f0afdcd15.png`.**
*(The scanning animation plays for ~5 seconds.)*

> "The worker captures a fundus photograph with a portable camera and uploads
> it. Now the full MATLAB pipeline runs — all on this device, no internet.
> First a quality check: is the image sharp enough, well-lit, in frame? If not,
> it asks for a retake. This one passes.
> Then classical image processing segments the retina — blood vessels, the
> optic disc, and the diabetic lesions: microaneurysms, haemorrhages, exudates.
> Those findings drive an International Clinical grading — zero to four."

**Dashboard renders. Pause 2 seconds on it.**

> "In about five seconds the doctor sees everything: **Grade 2, Moderate** —
> and the verdict, **Refer to specialist**. The three gauges show severity,
> the model's confidence — which is **calibrated** against labelled data, so
> seventy percent means roughly seventy percent correct — and the referable
> risk."

---

### SCENE 5 — Explainability  *(1:35 – 2:05)*

**Point to the chips under the grade.**

> "This is what makes it explainable. The attention map is an
> occlusion-sensitivity analysis — it shows which retinal regions actually
> drive the referral decision. And we check that the AI's attention lines up
> with the lesions we detected — here, ninety-one percent aligned."

**Click the layer buttons: Evidence → Attention → Lesions → Vessels.**
**Click the expand icon on the fundus to go fullscreen, then close it.**

> "The doctor can switch layers — the attention heatmap, the colour-coded
> lesion overlay, the vessel map — and zoom in. Below, a plain-language reason:
> *more than microaneurysms alone, with haemorrhages* — tied to the clinical
> criteria. And a findings table: each lesion, the normal range, what we
> detected, the threshold, and a status flag."

**Scroll down to show the findings table + 'Why this grade'.**

---

### SCENE 6 — Human-in-the-loop  *(2:05 – 2:20)*

**Click "Agree with AI".** *(Status shows "Decision saved".)*

> "The AI triages; the human decides. The ophthalmologist reviews remotely and
> clicks **Agree**, or **Override** with their own grade and a note. Either way
> it's recorded against the patient. Our target is a review in **under thirty
> seconds** — the interface is built for that."

---

### SCENE 7 — The report  *(2:20 – 2:35)*

**Click "Open report". The PDF opens.**

> "One click generates a one-page PDF — the grade, the verdict, the evidence
> image, the lesion table, and plain-language guidance the worker can give the
> patient. It carries the disclaimer: this is a screening aid, not a diagnosis."

**Close the PDF.**

---

### SCENE 8 — District console  *(2:35 – 3:00)*

**Click "New patient" → logout (sidebar) → sign in as `admin` / `netra2026`.**

> "The district health officer sees the whole programme. How many patients
> registered, how many screened, the referral rate, how many are still waiting
> for review."

**Click a patient row (e.g. Sita Devi) to open the dossier.**

> "Click any patient for their full history — profile, every screening, the
> grade trend over time, and a link to each report. This is how a district
> runs a hundred-thousand-patient screening programme."

---

### SCENE 9 — Simulink + close  *(3:00 – 3:20)*

**Switch to the `netra_telemedicine` Simulink model. Then show the `runSimulation` output.**

> "We also modelled the telemedicine workflow in Simulink SimEvents — patient
> arrivals, image upload, AI processing, ophthalmologist review. It answers the
> operational question: a district of a hundred thousand patients a year needs
> **three ophthalmologists** to keep every case reviewed within a day. And
> bandwidth barely matters — the bottleneck is human review, not the network.
> So Netra works on a two-megabit rural link."

*(Optional close on a slide)*

> "Netra — explainable, validated, MATLAB-native diabetic retinopathy screening
> for rural India. Built for SIH 2026, Problem Statement 26038."

---

## PART C — What NOT to say (evaluators will check)

- ❌ Don't claim **>90% sensitivity**. The classical grader is a baseline.
- ✅ Do say: *"grading runs on a transparent classical baseline; the trained
  ResNet-50 plugs into the same interface — the eval harness is ready to
  re-run it."*
- ❌ Don't say "Grad-CAM" for the current heatmap — say **"occlusion-sensitivity
  attention map"**. (Real Grad-CAM activates automatically when the CNN loads.)
- ❌ Don't call it a medical device. Say **"screening aid / decision support"**.
- If asked about neovascularization or fovea: *"detected by the trained U-Nets;
  the classical baseline flags the other four lesion types."*

---

## PART D — Recording tips

1. **Do 3 full dry runs first.** Muscle-memory every click.
2. Record in **one take** if you can — it feels more real. If you fumble, just
   pause, breathe, and redo that sentence; cut it in editing.
3. Speak **slower than feels natural.** Nervous = fast = unclear.
4. Keep the mouse **still while talking**; move it deliberately when you act.
5. If the pipeline takes longer than expected, that's fine — talk over the
   scanning animation.
6. Export **1080p MP4, H.264**. Keep it under ~100 MB if you're uploading.
7. Add a 3-second title card at the start and a disclaimer card at the end
   (Clipchamp / PowerPoint export both work).

## PART E — For the LIVE presentation (later)

- Have the recorded video as a **backup** in case the laptop misbehaves live.
- If demoing live: pre-seed the data, pre-warm the app, have the two images on
  the desktop, and rehearse to **exactly 3 minutes**.
- Keep a slide open behind the app with the 3 key numbers (77M · 3 ophthalmologists · <30s).
