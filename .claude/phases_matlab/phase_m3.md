# Phase M-3 — Segmentation Inference

**Track:** MATLAB | **Owner:** B1 | **Day:** 3–4
**Depends on:** M-0, M-1, Colab C-3/C-4/C-5 (ONNX files ready) | **Blocks:** M-4

---

## Goal
Import all six segmentation ONNX models, run inference, quantify lesions,
generate overlay images, and emit the `lesions` block. All code in `src/segment/`.

---

## Features

### F1 — Load All Segmentation Nets (`loadSegmentationNets.m`)
```matlab
function nets = loadSegmentationNets()
    persistent cachedNets
    if isempty(cachedNets)
        disp('Loading segmentation networks...')
        modelFiles = {'vessel_unet','ma_unet','he_unet','ex_unet','nv_unet','od_detector'};
        for i = 1:numel(modelFiles)
            name = modelFiles{i};
            try
                cachedNets.(name) = importONNXNetwork( ...
                    ['models/' name '.onnx'], 'OutputLayerType', 'pixelclassification');
            catch
                cachedNets.(name) = importNetworkFromONNX(['models/' name '.onnx']);
            end
        end
        disp('All segmentation networks loaded.')
    end
    nets = cachedNets;
end
```

---

### F2 — Preprocess for Segmentation (`preprocessForSegmentation.m`)
U-Nets expect 512×512 single-channel (green) input.
```matlab
function dlImg = preprocessForSegmentation(img)
    green = img(:, :, 2);              % green channel from RGB
    green512 = imresize(green, [512 512]);
    green512 = im2single(green512);    % [0, 1]
    % dlarray format: H x W x C x B
    dlImg = dlarray(green512, 'SSC');
end
```

---

### F3 — Run Single Segmentation Model (`runSegModel.m`)
```matlab
function mask = runSegModel(net, dlImg, threshold)
    if nargin < 3; threshold = 0.5; end
    logits = predict(net, dlImg);
    probs  = sigmoid(logits);
    mask   = extractdata(probs) > threshold;
    mask   = squeeze(mask);           % remove batch/channel dims → H x W
end

function out = sigmoid(x)
    out = 1 ./ (1 + exp(-extractdata(x)));
    out = dlarray(out);
end
```

---

### F4 — Vessel Segmentation (`runVesselSegmentation.m`)
```matlab
function vesselMask = runVesselSegmentation(net, img)
    dlImg = preprocessForSegmentation(img);
    vesselMask = runSegModel(net, dlImg, 0.5);
    % Resize back to original image size
    vesselMask = imresize(vesselMask, [size(img,1) size(img,2)], 'nearest');
end
```

---

### F5 — Lesion Segmentation (`runLesionSegmentation.m`)
```matlab
function masks = runLesionSegmentation(nets, img)
    dlImg = preprocessForSegmentation(img);
    [H, W, ~] = size(img);

    masks.MA = imresize(runSegModel(nets.ma_unet, dlImg), [H W], 'nearest');
    masks.HE = imresize(runSegModel(nets.he_unet, dlImg), [H W], 'nearest');
    masks.EX = imresize(runSegModel(nets.ex_unet, dlImg), [H W], 'nearest');
    masks.NV = imresize(runSegModel(nets.nv_unet, dlImg), [H W], 'nearest');
end
```

---

### F6 — Optic Disc Localization (`runODDetector.m`)
```matlab
function [odCentroid, foveaEstimate, odMask] = runODDetector(net, img)
    dlImg  = preprocessForSegmentation(img);
    odMask = runSegModel(net, dlImg, 0.5);
    [H, W, ~] = size(img);
    odMask = imresize(odMask, [H W], 'nearest');

    props = regionprops(logical(odMask), 'Centroid', 'Area');
    if isempty(props)
        odCentroid    = [W/2, H/2];
        foveaEstimate = [W/2 - W*0.1, H/2];
        return
    end
    [~, idx]   = max([props.Area]);
    odCentroid = props(idx).Centroid;                      % [x, y]

    discRadius    = sqrt(props(idx).Area / pi);
    foveaEstimate = [odCentroid(1) - 2.5 * discRadius * 2, odCentroid(2)];
end
```

---

### F7 — Lesion Quantification (`quantifyLesions.m`)
```matlab
function counts = quantifyLesions(masks, fovMask)
    % MA count — connected components
    maCC = bwconncomp(masks.MA);
    counts.maCount = maCC.NumObjects;

    % HE count — connected components
    heCC = bwconncomp(masks.HE);
    counts.heCount = heCC.NumObjects;

    % EX area as % of retina FOV
    fovArea = sum(fovMask(:));
    counts.exudateAreaPct = (sum(masks.EX(:)) / fovArea) * 100;

    % NV — presence flag (any detected pixels)
    counts.nvPresent = any(masks.NV(:));
end
```

---

### F8 — Lesion Overlay Image (`generateLesionOverlay.m`)
Color-coded overlay: MA=red, HE=blue, EX=yellow, NV=magenta.
```matlab
function overlayImg = generateLesionOverlay(img, masks)
    overlayImg = im2double(img);

    alpha = 0.45;
    colors = struct('MA',[1 0 0], 'HE',[0 0 1], 'EX',[1 1 0], 'NV',[1 0 1]);
    fields = fieldnames(colors);

    for i = 1:numel(fields)
        f = fields{i};
        mask3 = repmat(masks.(f), [1 1 3]);
        color3 = reshape(colors.(f), 1, 1, 3);
        colorLayer = repmat(color3, [size(img,1) size(img,2) 1]);
        overlayImg = overlayImg .* (1 - alpha * mask3) + colorLayer .* (alpha * mask3);
    end
    overlayImg = im2uint8(overlayImg);
end
```

---

### F9 — Save Overlays & Build Lesions Block (`runSegmentationPipeline.m`)
```matlab
function [lesionsBlock, imagePaths] = runSegmentationPipeline(nets, img, patientId)
    outDir = fullfile('images', patientId);
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    % Run all segmentation models
    vesselMask           = runVesselSegmentation(nets.vessel_unet, img);
    masks                = runLesionSegmentation(nets, img);
    [odCentroid, ~, ~]   = runODDetector(nets.od_detector, img);

    % FOV mask (approximate — circle from image)
    fovMask = img(:,:,2) > 0.05;

    % Quantify
    counts = quantifyLesions(masks, fovMask);

    % Generate overlay images
    lesionOverlay = generateLesionOverlay(img, masks);
    vesselOverlay = uint8(vesselMask * 255);

    % Save
    lesionPath = fullfile(outDir, 'lesion_overlay.png');
    vesselPath = fullfile(outDir, 'vessel_map.png');
    imwrite(lesionOverlay, lesionPath);
    imwrite(vesselOverlay, vesselPath);

    % Build blocks
    lesionsBlock.maCount        = counts.maCount;
    lesionsBlock.heCount        = counts.heCount;
    lesionsBlock.exudateAreaPct = counts.exudateAreaPct;
    lesionsBlock.nvPresent      = counts.nvPresent;
    lesionsBlock.odCentroid     = odCentroid;

    imagePaths.lesionOverlay = lesionPath;
    imagePaths.vesselMap     = vesselPath;
end
```

---

## Done when
- [ ] All six ONNX models import without errors
- [ ] `runSegmentationPipeline` returns lesion counts + saved overlay images
- [ ] Lesion block fields match `data_contract.json` exactly
- [ ] Overlay images visually show correct color per lesion type on a test image
