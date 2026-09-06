# Phase M-2 — DR Grading Inference

**Track:** MATLAB | **Owner:** B1 | **Day:** 3–4
**Depends on:** M-0, M-1, Colab C-2 (dr_grader.onnx ready) | **Blocks:** M-4

---

## Goal
Import the ONNX grading model, run inference, and emit the full `result`
block of the data contract. All code in `src/grade/`.

---

## Features

### F1 — Model Import & Cache (`loadGradingNet.m`)
Import once at startup — not per image. Use `persistent` to cache.
```matlab
function net = loadGradingNet()
    persistent cachedNet
    if isempty(cachedNet)
        disp('Loading DR grading network...')
        try
            cachedNet = importONNXNetwork('models/dr_grader.onnx', ...
                'OutputLayerType', 'classification');
        catch
            % Try newer API (R2023b+)
            cachedNet = importNetworkFromONNX('models/dr_grader.onnx');
        end
        disp('Grading network loaded.')
    end
    net = cachedNet;
end
```

---

### F2 — Preprocessing for Classifier (`preprocessForGrader.m`)
ResNet-50 expects 224×224 RGB, ImageNet normalized.
```matlab
function dlImg = preprocessForGrader(img)
    % img: H x W x 3 double [0,1] from quality pipeline
    img224 = imresize(img, [224 224]);

    % ImageNet normalization
    mean_val = reshape([0.485 0.456 0.406], 1, 1, 3);
    std_val  = reshape([0.229 0.224 0.225], 1, 1, 3);
    img224 = (img224 - mean_val) ./ std_val;

    % Convert to dlarray (MATLAB deep learning format)
    % Format: S=spatial, C=channel, B=batch
    dlImg = dlarray(single(img224), 'SSC');
    dlImg = dlImg(:,:,:);   % H x W x C
    dlImg = permute(dlImg, [1 2 3]);
end
```

---

### F3 — Run Inference (`runGrading.m`)
```matlab
function [grade, probs, logits] = runGrading(net, img)
    % img: preprocessed dlarray from preprocessForGrader
    dlImg = preprocessForGrader(img);

    % Add batch dimension: H x W x C → 1 x H x W x C (MATLAB convention)
    dlImg = reshape(dlImg, [1 size(dlImg)]);

    % Forward pass
    logits = predict(net, dlImg);
    logits = extractdata(logits);        % dlarray → regular array

    % Softmax probabilities
    probs = exp(logits) ./ sum(exp(logits));

    % Grade = argmax (0-indexed → add 0 offset)
    [~, gradeIdx] = max(probs);
    grade = gradeIdx - 1;               % MATLAB is 1-indexed, grades are 0-4
end
```

---

### F4 — Referable Decision (`isReferable.m`)
```matlab
function referable = isReferable(probs)
    % Load threshold calibrated by Colab (saved in models/)
    persistent threshold
    if isempty(threshold)
        fid = fopen('models/referable_threshold.txt', 'r');
        threshold = fscanf(fid, '%f');
        fclose(fid);
    end
    % P(referable) = P(grade >= 2) = sum of probs for grades 3,4,5 (1-indexed)
    pReferable = sum(probs(3:5));
    referable = pReferable >= threshold;
end
```

---

### F5 — Grade Label Map (`gradeLabel.m`)
```matlab
function label = gradeLabel(grade)
    labels = {'No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative DR'};
    label  = labels{grade + 1};           % grade 0→index 1
end
```

---

### F6 — Result Block Builder (`buildResultBlock.m`)
```matlab
function block = buildResultBlock(grade, probs, referable)
    block.grade             = grade;
    block.gradeLabel        = gradeLabel(grade);
    block.referable         = referable;
    block.confidence        = max(probs);
    block.classProbabilities = probs(:)';  % row vector [p0 p1 p2 p3 p4]
end
```

---

### F7 — Main Entry Point (`runGradingPipeline.m`)
```matlab
function resultBlock = runGradingPipeline(processedImg)
    net = loadGradingNet();
    [grade, probs, ~] = runGrading(net, processedImg);
    referable = isReferable(probs);
    resultBlock = buildResultBlock(grade, probs, referable);
end
```

---

### F8 — Smoke Test
Run this after import to confirm MATLAB predictions match Colab:
```matlab
% Load a test image, run through quality pipeline, then grading
img = imread('data/test_sample.png');
[processed, ~, routing] = runQualityPipeline('data/test_sample.png');
if ~strcmp(routing, 'recapture')
    result = runGradingPipeline(processed);
    fprintf('Grade: %d (%s) | Referable: %d | Confidence: %.1f%%\n', ...
        result.grade, result.gradeLabel, result.referable, result.confidence * 100);
end
% Compare output grade to Colab's prediction on the same image
```

---

## Done when
- [ ] `loadGradingNet()` imports ONNX without errors
- [ ] `runGradingPipeline(img)` returns grade 0–4 + referable flag + confidence
- [ ] Output matches Colab predictions on 5 test images (same grade)
- [ ] Result block fields match `data_contract.json` exactly
