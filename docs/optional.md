# optional.md — Stretch Features (PS 26038)

> Pick these up only if the core build (M-0 through M-8) is complete.
> Each feature is self-contained — implement any one independently without
> touching the others. The data contract needs no changes (nullable blocks
> already exist).
>
> Ranked by ROI: judge impact vs. build effort.

---

## How to add any feature

1. Check the "Unlocks after" phase is done and merged to `main`
2. Create a new branch: `git checkout -b optional/<feature-name>`
3. Follow the build steps below
4. PR into `main` when the "Done when" bar is met

---

## O-1 — Glaucoma Risk Flag
**Effort:** Low | **Judge impact:** Very high | **Unlocks after:** M-3

### What it does
Uses the optic disc already segmented in M-3 to estimate the **cup-to-disc
ratio (CDR)**. CDR > 0.65 is a clinical flag for glaucoma risk. One camera,
two screenings — strong rural value story for judges.

### Track
MATLAB only. No new model training needed.

### How to build

**Step 1 — Estimate cup boundary from OD mask** (`src/segment/glaucomaFlag.m`):
```matlab
function [cdr, flag] = glaucomaFlag(odMask)
    % odMask: binary mask of optic disc from od_detector.onnx output
    % The optic cup is the bright central region inside the OD
    % Threshold the green channel within the OD bounding box
    odRegion = applyMask(greenChannel, odMask);
    cupMask = odRegion > prctile(odRegion(:), 85); % top 15% intensity = cup
    
    discDiameter = sqrt(4 * sum(odMask(:)) / pi);
    cupDiameter  = sqrt(4 * sum(cupMask(:)) / pi);
    cdr = cupDiameter / discDiameter;
    flag = cdr > 0.65; % clinical threshold
end
```

**Step 2 — Add to pipeline** after M-3 segmentation runs:
```matlab
[cdr, glaucomaRisk] = glaucomaFlag(odMask);
```

**Step 3 — Fill `secondaryFindings` block in JSON** (already nullable):
```matlab
record.secondaryFindings.glaucoma.cdr = cdr;
record.secondaryFindings.glaucoma.flag = glaucomaRisk;
record.secondaryFindings.glaucoma.note = "CDR > 0.65 — refer for tonometry";
```

**Step 4 — Show in dashboard**: add a small "Glaucoma Risk" chip in the right
sidebar below the DR verdict. Green = low risk, red = flag.

**Step 5 — Add to PDF report**: one line — "Glaucoma risk: CDR = 0.71 (flagged)"

### Done when
CDR is calculated and shown in the dashboard + PDF for every screening.

---

## O-2 — Vernacular + Voice Output
**Effort:** Low | **Judge impact:** High | **Unlocks after:** M-4

### What it does
Generates the patient-facing summary (not the clinical report) in **Hindi or
Kannada** and reads it aloud using MATLAB text-to-speech. Directly addresses
the rural India communication problem — patients at PHCs may not read English.

### Track
MATLAB only.

### How to build

**Step 1 — Patient summary templates** (`src/explain/vernacularReport.m`):
```matlab
function text = buildPatientSummary(grade, referable, lang)
    templates.english.refer = ...
        "Your eye scan shows signs of diabetic eye disease. " + ...
        "Please see an eye specialist soon.";
    templates.english.routine = ...
        "Your eye scan looks stable. Continue regular checkups.";
    templates.hindi.refer = ...
        "आपकी आंख की जांच में मधुमेह संबंधी बदलाव दिखे हैं। " + ...
        "कृपया जल्द ही नेत्र विशेषज्ञ से मिलें।";
    templates.hindi.routine = ...
        "आपकी आंख की जांच सामान्य है। नियमित जांच जारी रखें।";
    templates.kannada.refer = ...
        "ನಿಮ್ಮ ಕಣ್ಣಿನ ಸ್ಕ್ಯಾನ್‌ನಲ್ಲಿ ಮಧುಮೇಹ ಸಂಬಂಧಿತ ಬದಲಾವಣೆಗಳು ಕಂಡುಬಂದಿವೆ।";
    templates.kannada.routine = ...
        "ನಿಮ್ಮ ಕಣ್ಣಿನ ಸ್ಕ್ಯಾನ್ ಸಾಮಾನ್ಯವಾಗಿದೆ। ನಿಯಮಿತ ತಪಾಸಣೆ ಮುಂದುವರಿಸಿ।";
    
    routing = "routine";
    if referable; routing = "refer"; end
    text = templates.(lang).(routing);
end
```

**Step 2 — Text-to-speech playback**:
```matlab
% MATLAB built-in TTS (R2023b+)
text = buildPatientSummary(grade, referable, 'hindi');
tts(text); % plays audio through speakers
```

**Step 3 — Add to dashboard**: language selector dropdown (English / Hindi /
Kannada) in the action bar. "Play for Patient" button triggers TTS.

**Step 4 — Add patient summary to PDF**: second page of the report in selected
language, large font, plain language (no clinical jargon).

### Done when
Clicking "Play for Patient" reads the result aloud in the selected language.

---

## O-3 — Triage Queue (Sickest-First Sorting)
**Effort:** Medium | **Judge impact:** Medium-High | **Unlocks after:** M-5 + M-7

### What it does
Sorts the ophthalmologist review queue by **severity × confidence** score so
the most urgent and most certain cases are reviewed first. Ties into the
Simulink reviewer capacity story — fewer reviewers needed if they see the worst
cases first.

### Track
MATLAB (data layer + dashboard).

### How to build

**Step 1 — Triage score function** (`src/datalayer/triageScore.m`):
```matlab
function score = triageScore(grade, confidence)
    % grade: 0-4 (ordinal severity)
    % confidence: 0-1 (model certainty)
    % Higher score = review sooner
    gradeWeight = [0, 0.25, 0.6, 0.85, 1.0]; % non-linear — grade 4 critical
    score = gradeWeight(grade + 1) * confidence;
end
```

**Step 2 — Sort queue on load**:
```matlab
function queue = buildTriageQueue(db)
    pending = db(strcmp(db.reviewStatus, 'pending'), :);
    scores = arrayfun(@(r) triageScore(r.grade, r.confidence), pending);
    [~, idx] = sort(scores, 'descend');
    queue = pending(idx, :);
end
```

**Step 3 — Update dashboard queue panel**: show triage score badge on each
patient card. Color: red (score > 0.7) / amber (0.4–0.7) / green (< 0.4).

**Step 4 — Wire to Simulink**: pass the sorted referral rate into the
Simulink reviewer server as a priority queue (SimEvents `Priority Queue` block).

### Done when
The review queue in the dashboard is ordered sickest-first with visible
priority scores.

---

## O-4 — District Dashboard
**Effort:** Medium | **Judge impact:** Medium-High | **Unlocks after:** M-5 + M-6

### What it does
A second view in the app showing **aggregate stats** for the health officer —
referral rates, grade distribution, throughput, hotspot villages. Ties the
"100,000 patients/year" framing directly to a visible output.

### Track
MATLAB (data layer + new HTML view).

### How to build

**Step 1 — Aggregate stats from data layer** (`src/datalayer/districtStats.m`):
```matlab
function stats = districtStats(db)
    stats.totalScreened   = height(db);
    stats.referralRate    = sum(db.referable) / height(db);
    stats.gradeDistribution = histcounts(db.grade, 0:5) / height(db);
    stats.avgConfidence   = mean(db.confidence);
    stats.screenedToday   = sum(db.date == today);
    stats.pendingReview   = sum(strcmp(db.reviewStatus, 'pending'));
end
```

**Step 2 — New HTML page**: `app/district.html`
- Summary cards: Total screened / Referral rate % / Pending review / Screened today
- Bar chart: grade distribution (0–4) — vanilla JS `<canvas>` chart
- Line chart: daily screenings over the past 30 days
- Table: top 10 patients by triage score still pending

**Step 3 — Wire to MATLAB**: push `stats` struct via `uihtml` `Data` property
on a timer (refresh every 60 seconds).

**Step 4 — Tab in App Designer**: add a second tab "District View" alongside
the main screening tab.

### Done when
Health officer tab shows live aggregate stats updating from the `.mat` database.

---

## O-5 — Grounded LLM Agent
**Effort:** High | **Judge impact:** High | **Unlocks after:** M-4 + M-5

### What it does
Doctor types a question about the current case ("Why was this graded moderate?",
"What should I tell the patient?"). The LLM answers using **only the pipeline's
structured outputs** — grade, lesion counts, confidence, history, Grad-CAM
region. No free-floating medical claims. Decision-support only, NOT diagnosis.

### Track
MATLAB (LLM add-on) + dashboard chat UI.

### How to build

**Step 1 — Install MATLAB LLM add-on**:
Download "Large Language Models (LLMs) with MATLAB" from MATLAB Add-On Explorer.
This provides `openAIChat`, `azureChat` etc.

**Step 2 — Build grounded context** (`src/explain/llmAgent.m`):
```matlab
function context = buildClinicalContext(record)
    % Converts structured pipeline output to a grounding prompt
    context = sprintf([...
        'Patient: %s | Eye: %s | Date: %s\n' ...
        'DR Grade: %d (%s) | Referable: %s | Confidence: %.0f%%\n' ...
        'Lesions: MA=%d, HE=%d, EX area=%.1f%%, NV=%s\n' ...
        'History: %s\n' ...
        'Grad-CAM: attention focused on %s region\n' ...
        'IMPORTANT: You are a decision-support tool only. ' ...
        'Do not make diagnoses. Ground every answer in the data above.'], ...
        record.patientId, record.eye, record.date, ...
        record.grade, record.gradeLabel, ...
        string(record.referable), record.confidence * 100, ...
        record.lesions.maCount, record.lesions.heCount, ...
        record.lesions.exudateAreaPct, string(record.lesions.nvPresent), ...
        record.history.trend, record.explanation.gradcamRegion);
end
```

**Step 3 — Answer generation**:
```matlab
function answer = askAgent(question, record, apiKey)
    context = buildClinicalContext(record);
    systemPrompt = ['You are a clinical decision-support assistant. ' ...
        'Answer questions about the retinal screening result below. ' ...
        'Use only the data provided. Never diagnose. ' ...
        'If asked something not in the data, say so.\n\n' context];
    chat = openAIChat(systemPrompt, 'APIKey', apiKey);
    answer = generate(chat, question);
end
```

**Step 4 — Chat UI in dashboard**: add a collapsible chat panel at the bottom
of the right sidebar. Text input + send button → `sendEventToMATLAB('ask', {question})` → MATLAB calls `askAgent()` → reply pushed back to HTML.

**Step 5 — Guardrails**: if the answer contains words like "diagnose", "certain",
"you have", reject it and return a safe fallback message.

### API key note
Use OpenAI API (pay-per-use, cheap for a demo) or route through Azure OpenAI
if the institution has a key. Store key in an environment variable, never in code.

### Done when
Doctor can ask a question in the dashboard and get a grounded, structured answer
within 5 seconds. Every answer cites a specific value from the pipeline output.

---

## O-6 — Offline / Store-and-Forward
**Effort:** Very high | **Judge impact:** Medium | **Unlocks after:** M-8 only

### What it does
Compiles the full app to a standalone `.exe` (no MATLAB license needed at
the PHC). Screenings are queued locally when there's no connectivity and synced
to a central server when the connection returns.

### Track
MATLAB (Application Compiler + sync logic).

### How to build

**Step 1 — Compile to standalone**:
```
MATLAB → Apps → Application Compiler
→ Add NetraApp.mlapp as main file
→ Add all /models/*.onnx and /src/**/*.m as files to include
→ Package → generates NetraApp_installer.exe
```

**Step 2 — Local queue** (`src/datalayer/offlineQueue.m`):
```matlab
% When network unavailable: save to local queue file
function queueScreening(record)
    queueFile = 'netra_queue.mat';
    if isfile(queueFile)
        q = load(queueFile).queue;
    else
        q = {};
    end
    q{end+1} = record;
    save(queueFile, 'q');
end
```

**Step 3 — Sync on reconnect**:
```matlab
function syncQueue(serverUrl)
    if ~isfile('netra_queue.mat'); return; end
    q = load('netra_queue.mat').queue;
    for i = 1:numel(q)
        response = webwrite(serverUrl + '/screening', q{i});
        if response.ok
            q(i) = []; % remove synced record
        end
    end
    save('netra_queue.mat', 'q');
end
```

**Step 4 — Network check + auto-sync**: run `syncQueue` on a timer every 60s.
Show a connectivity indicator in the top bar (green dot = online, grey = offline).

### Done when
App runs without MATLAB installed, queues screenings offline, and syncs
automatically when connectivity returns.

---

## Quick reference

| # | Feature | Effort | Unlocks after | Track |
|---|---|---|---|---|
| O-1 | Glaucoma risk flag | Low | M-3 | MATLAB |
| O-2 | Vernacular + voice | Low | M-4 | MATLAB |
| O-3 | Triage queue | Medium | M-5 + M-7 | MATLAB |
| O-4 | District dashboard | Medium | M-5 + M-6 | MATLAB |
| O-5 | Grounded LLM agent | High | M-4 + M-5 | MATLAB |
| O-6 | Offline / store-and-forward | Very high | M-8 | MATLAB |
