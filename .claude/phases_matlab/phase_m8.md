# Phase M-8 — Integration, Validation & Deck

**Track:** MATLAB | **Owner:** B4 + all | **Day:** 6–7
**Depends on:** M-1 through M-7 all done

---

## Goal
Wire all modules into one end-to-end flow. Validate on Messidor-2.
Fix errors. Build the PPT deck. Rehearse the demo.

---

## Features

### F1 — Master Pipeline (`src/runPipeline.m`)
Single entry point that calls every module in order.
```matlab
function record = runPipeline(imagePath, patientId, eye)
    % --- Init ---
    nets       = loadSegmentationNets();
    gradingNet = loadGradingNet();

    % --- Build base record ---
    record.patientId = patientId;
    record.eye       = eye;
    record.date      = datestr(now, 'yyyy-mm-dd HH:MM');

    % --- Phase 1: Quality + Preprocess ---
    [processedImg, qualityBlock, routing] = runQualityPipeline(imagePath);
    record.quality  = qualityBlock;
    record.routing  = routing;
    record.images.original = imagePath;

    if strcmp(routing, 'recapture')
        record.result  = [];
        record.lesions = [];
        return                          % early exit — ungradable
    end

    % --- Phase 3: Segmentation ---
    [lesionsBlock, segImagePaths] = runSegmentationPipeline(nets, processedImg, patientId);
    record.lesions = lesionsBlock;
    record.images.lesionOverlay = segImagePaths.lesionOverlay;
    record.images.vesselMap     = segImagePaths.vesselMap;

    % --- Phase 2: Grading ---
    resultBlock = runGradingPipeline(processedImg);
    record.result = resultBlock;

    % --- Phase 4: Explainability ---
    [explainPaths, reportPath] = runExplainPipeline(gradingNet, processedImg, record, lesionsBlock);
    record.images.gradcam  = explainPaths.gradcam;
    record.images.evidence = explainPaths.evidence;

    % --- Phase 5: History ---
    [history, ~] = getHistory(patientId);
    record.history = history;

    % --- Routing ---
    if record.result.referable
        record.routing = 'refer_specialist';
    else
        record.routing = 'routine_followup';
    end

    % --- Save ---
    saveScreening(record);

    % --- Review status ---
    record.review.status    = 'pending';
    record.review.finalGrade = NaN;
    record.review.notes      = '';
end
```

---

### F2 — End-to-End Smoke Test
```matlab
% Run this on a known APTOS image before Messidor-2 validation
record = runPipeline('data/test_image.png', 'PT-TEST-001', 'OD');

assert(~isempty(record.result), 'Result block is empty');
assert(record.result.grade >= 0 && record.result.grade <= 4, 'Grade out of range');
assert(isfield(record.images, 'gradcam'), 'Grad-CAM path missing');
assert(isfile(record.images.gradcam), 'Grad-CAM image not saved');
assert(isfile(record.images.lesionOverlay), 'Lesion overlay not saved');

fprintf('Smoke test passed — Grade %d, Referable: %d\n', ...
    record.result.grade, record.result.referable);
```

---

### F3 — Messidor-2 Validation (`src/validateMessidor2.m`)
Run only when M-1 through M-7 are all working. Messidor-2 was never trained on.
```matlab
function metrics = validateMessidor2(messidor2Dir, labelsPath)
    % messidor2Dir: path to Messidor-2 images
    % labelsPath: CSV with columns [image_name, adjudicated_gradable, grade]

    labels = readtable(labelsPath);
    labels = labels(labels.adjudicated_gradable == 1, :); % gradable only

    allGrades    = [];
    allPredGrades = [];
    allReferable  = [];
    allPredRef    = [];

    for i = 1:height(labels)
        imgPath = fullfile(messidor2Dir, labels.image_name{i});
        if ~isfile(imgPath); continue; end

        record = runPipeline(imgPath, labels.image_name{i}, 'OD');
        if isempty(record.result); continue; end    % ungradable — skip

        allGrades(end+1)     = labels.grade(i);
        allPredGrades(end+1) = record.result.grade;
        allReferable(end+1)  = labels.grade(i) >= 2;
        allPredRef(end+1)    = record.result.referable;
    end

    % Sensitivity / Specificity for referable DR
    TP = sum( allReferable &  allPredRef);
    TN = sum(~allReferable & ~allPredRef);
    FP = sum(~allReferable &  allPredRef);
    FN = sum( allReferable & ~allPredRef);

    metrics.sensitivity = TP / (TP + FN);
    metrics.specificity = TN / (TN + FP);

    % QWK
    metrics.qwk = kappacalc(allGrades, allPredGrades);  % use Cohen's kappa w='quadratic'

    fprintf('=== Messidor-2 Validation ===\n')
    fprintf('n = %d gradable images\n', numel(allGrades))
    fprintf('Sensitivity: %.3f (target > 0.90)\n', metrics.sensitivity)
    fprintf('Specificity: %.3f (target > 0.85)\n', metrics.specificity)
    fprintf('QWK:         %.3f\n', metrics.qwk)
end
```

---

### F4 — Error Handling Checklist
Test each of these manually before the demo:
- [ ] Ungradable image → recapture message appears in dashboard, pipeline exits cleanly
- [ ] ONNX model file missing → `loadGradingNet` shows clear error message, app doesn't crash
- [ ] Unknown patient ID → new record created, history shows "First screening"
- [ ] Reviewerclicks Agree on already-reviewed case → warning shown, no duplicate record
- [ ] Image file path has spaces → test `imread` handles it

---

### F5 — PPT Deck (7 Slides)

**Slide 1 — Problem**
- 77M diabetics in India
- < 1 ophthalmologist per 100,000 people in rural areas
- Mass manual screening infeasible → missed diagnoses → preventable blindness

**Slide 2 — Pipeline Overview**
- Use the workflow diagram image generated from the prompts earlier
- One sentence per stage

**Slide 3 — Explainability**
- Screenshot of dashboard showing real Grad-CAM + lesion overlay
- "Ophthalmologist can validate in < 30 seconds"
- Show the evidence view with lesion contours aligned to heatmap

**Slide 4 — Simulink**
- Screenshot of the Simulink model
- Key numbers: optimal reviewer count, bottleneck identified, bandwidth impact

**Slide 5 — Metrics**
- Sensitivity, specificity on Messidor-2 vs. published benchmarks
- QWK on APTOS validation
- Table: Ours vs. benchmark papers

**Slide 6 — Rural Impact + Roadmap**
- Impact framing: X patients triaged per year, Y specialists' time saved
- Roadmap: offline mode, Hindi/Kannada output, glaucoma flag, district dashboard

**Slide 7 — Team + Disclaimer**
- Team names and roles
- "Prototype only. Not a certified medical device."
- SIH 2026 | PS 26038 | MathWorks

---

### F6 — Demo Rehearsal (< 30 seconds)
Practice this sequence until it's under 30 seconds:
```
1. Open NetraApp
2. Enter patient ID: PT-DEMO-001
3. Upload a Grade 3 fundus image
4. Watch pipeline run (~10 seconds)
5. Dashboard renders — show: grade badge, Grad-CAM heatmap, lesion counts
6. Toggle layers: Original → Grad-CAM → Lesions
7. Click Agree → "Decision saved" confirmation
8. Click Generate PDF → report opens
```

---

## Done when
- [ ] `runPipeline(imagePath, patientId, eye)` works end-to-end on any gradable image
- [ ] Ungradable path works end-to-end
- [ ] Messidor-2 metrics: sensitivity > 90%, specificity > 85%
- [ ] All error cases handled gracefully
- [ ] PPT deck complete and spell-checked
- [ ] Demo rehearsed under 30 seconds
