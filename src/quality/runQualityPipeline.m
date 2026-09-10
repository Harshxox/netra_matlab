function [processedImg, qualityBlock, routing, fovMask] = runQualityPipeline(imageInput, thr)
%RUNQUALITYPIPELINE  Entry point for M-1: raw fundus image -> clean image + quality block.
%
%   [processedImg, qualityBlock, routing, fovMask] = runQualityPipeline(imagePath)
%   [...] = runQualityPipeline(imgMatrix)        % also accepts an image array
%   [...] = runQualityPipeline(..., thr)         % custom quality thresholds
%
%   OUTPUTS
%     processedImg  512x512x3 double in [0,1]. FOV-cropped, resized, and
%                   CLAHE-enhanced if the image was borderline.
%     qualityBlock  struct matching the `quality` block of data_contract.json
%     routing       'recapture'  if ungradable  ->  caller should stop here
%                   'pending'    otherwise      ->  continue to grading/segmentation
%     fovMask       512x512 logical retina mask (needed by M-3 for area %)
%
%   Pipeline:  load -> cropFOV -> resize 512 -> score -> classify
%              -> (enhance if borderline) -> build block -> decide routing

    if nargin < 2; thr = []; end

    % --- load ---------------------------------------------------------
    if ischar(imageInput) || isstring(imageInput)
        img = imread(char(imageInput));
    else
        img = imageInput;
    end
    if size(img,3) == 1
        img = repmat(img, [1 1 3]);      % keep everything 3-channel downstream
    end

    % --- crop to the retina ----------------------------------------
    [img, fovMask] = cropFOV(img);

    % --- standard working size -----------------------------------
    img     = resizeNormalize(img, [512 512]);
    fovMask = imresize(fovMask, [512 512], 'nearest');

    % --- quality assessment (on the un-enhanced image) ------------
    scores = qualityScore(img, fovMask);
    [status, reasons] = classifyQuality(scores, thr);

    % --- enhance borderline images -------------------------------
    wasEnhanced = false;
    if strcmp(status, 'borderline')
        img = enhanceImage(img, fovMask);
        wasEnhanced = true;
    end

    % --- outputs ------------------------------------------------
    qualityBlock = buildQualityBlock(scores, status, wasEnhanced);
    qualityBlock.reasons = reasons;         % extra: not in JSON, handy for UI/PDF

    if strcmp(status, 'ungradable')
        routing = 'recapture';
    else
        routing = 'pending';
    end

    processedImg = img;
end
