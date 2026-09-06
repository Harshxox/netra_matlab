# Phase M-1 — Preprocessing & Quality Check

**Track:** MATLAB | **Owner:** B2 | **Day:** 1–2
**Depends on:** M-0 | **Blocks:** M-2, M-3, M-4

---

## Goal
Build the preprocessing pipeline that every image passes through before
any model inference. Output: enhanced image + filled `quality` JSON block.

All code in `src/quality/`.

---

## Features

### F1 — FOV Crop (`cropFOV.m`)
Detects and crops the retina circle, removes black border.
```matlab
function [croppedImg, circleMask] = cropFOV(img)
    gray = rgb2gray(img);
    bw   = gray > 10;                          % threshold black border
    bw   = imfill(bw, 'holes');
    bw   = bwareaopen(bw, 1000);               % remove noise
    props = regionprops(bw, 'BoundingBox', 'Area');
    if isempty(props)
        croppedImg = img;
        circleMask = true(size(gray));
        return
    end
    [~, idx] = max([props.Area]);
    bb = props(idx).BoundingBox;               % [x y w h]
    x = max(1, round(bb(1)));
    y = max(1, round(bb(2)));
    w = round(bb(3));
    h = round(bb(4));
    croppedImg = img(y:y+h-1, x:x+w-1, :);
    circleMask = bw(y:y+h-1, x:x+w-1);
end
```

---

### F2 — Resize & Normalize (`resizeNormalize.m`)
```matlab
function imgOut = resizeNormalize(img, targetSize)
    % targetSize: [H W] e.g. [224 224] or [512 512]
    imgOut = imresize(img, targetSize);
    imgOut = im2double(imgOut);                % [0, 1] range
end
```

---

### F3 — Green Channel Extraction (`extractGreenChannel.m`)
```matlab
function greenImg = extractGreenChannel(img)
    if size(img, 3) == 3
        greenImg = img(:, :, 2);              % channel 2 = green in RGB
    else
        greenImg = img;                       % already single channel
    end
end
```

---

### F4 — Quality Scoring (`qualityScore.m`)
```matlab
function scores = qualityScore(img)
    green = extractGreenChannel(img);
    green = im2double(green);

    % Focus: Laplacian variance — higher = sharper
    lap = del2(green);
    scores.focusScore = var(lap(:));

    % Illumination: mean intensity of green channel
    scores.illuminationScore = mean(green(:));

    % FOV ratio: retina area vs total image area
    bw = green > 0.05;
    bw = imfill(bw, 'holes');
    scores.fovRatio = sum(bw(:)) / numel(bw);
end
```

---

### F5 — Quality Classification (`classifyQuality.m`)
Thresholds — tune on a small set of known good/bad images.
```matlab
function status = classifyQuality(scores)
    FOCUS_GOOD  = 1e-5;   % Laplacian variance threshold
    FOCUS_BAD   = 5e-6;
    ILLUM_LOW   = 0.15;
    ILLUM_HIGH  = 0.85;
    FOV_MIN     = 0.30;

    focusOK = scores.focusScore > FOCUS_GOOD;
    focusMid = scores.focusScore > FOCUS_BAD;
    illumOK = scores.illuminationScore > ILLUM_LOW && ...
              scores.illuminationScore < ILLUM_HIGH;
    fovOK   = scores.fovRatio > FOV_MIN;

    if focusOK && illumOK && fovOK
        status = 'gradable';
    elseif focusMid && fovOK
        status = 'borderline';
    else
        status = 'ungradable';
    end
end
```

---

### F6 — Image Enhancement (`enhanceImage.m`)
Applied only to `borderline` images.
```matlab
function enhanced = enhanceImage(img)
    green = extractGreenChannel(img);
    green = im2double(green);

    % CLAHE on green channel
    greenCLAHE = adapthisteq(green, 'ClipLimit', 0.02, 'NumTiles', [8 8]);

    % Illumination normalization via morphological background estimation
    bg = imopen(greenCLAHE, strel('disk', 30));
    greenNorm = greenCLAHE - bg + mean(bg(:));
    greenNorm = mat2gray(greenNorm);

    % Gaussian denoise
    greenDenoised = imgaussfilt(greenNorm, 0.5);

    % Reconstruct RGB with enhanced green channel
    if size(img, 3) == 3
        enhanced = im2double(img);
        enhanced(:, :, 2) = greenDenoised;
    else
        enhanced = greenDenoised;
    end
end
```

---

### F7 — Quality Block Builder (`buildQualityBlock.m`)
```matlab
function block = buildQualityBlock(scores, status, wasEnhanced)
    block.status           = status;
    block.focusScore       = scores.focusScore;
    block.illuminationScore = scores.illuminationScore;
    block.fovRatio         = scores.fovRatio;
    block.enhanced         = wasEnhanced;
end
```

---

### F8 — Main Pipeline Entry Point (`runQualityPipeline.m`)
```matlab
function [processedImg, qualityBlock, routing] = runQualityPipeline(imagePath)
    img = imread(imagePath);
    [img, ~] = cropFOV(img);
    img = resizeNormalize(img, [512 512]);

    scores = qualityScore(img);
    status = classifyQuality(scores);

    wasEnhanced = false;
    if strcmp(status, 'borderline')
        img = enhanceImage(img);
        wasEnhanced = true;
    end

    qualityBlock = buildQualityBlock(scores, status, wasEnhanced);

    if strcmp(status, 'ungradable')
        routing = 'recapture';
    else
        routing = 'pending';
    end

    processedImg = img;
end
```

---

## Done when
- [ ] `runQualityPipeline(imagePath)` returns enhanced image + quality JSON block
- [ ] Ungradable images correctly routed to `'recapture'`
- [ ] Tested on at least 5 APTOS images covering good/blurry/dark cases
- [ ] Quality block fields match `data_contract.json` exactly
