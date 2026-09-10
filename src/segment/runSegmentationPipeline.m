function [lesionsBlock, imagePaths, masks] = runSegmentationPipeline(img, patientId, fovMask, opts)
%RUNSEGMENTATIONPIPELINE  Entry point for lesion/vessel analysis (M-3).
%
%   [lesionsBlock, imagePaths, masks] = runSegmentationPipeline(img, patientId, fovMask)
%   [...] = runSegmentationPipeline(img, patientId, fovMask, opts)
%
%   img         - RGB fundus, double [0,1], pipeline working size
%   patientId   - char/string, used for the output image folder
%   fovMask     - logical retina mask from runQualityPipeline
%   opts.useONNX - (default false) if true, use trained U-Nets instead of
%                  the classical detector (see runSegmentationONNX - stub)
%   opts.saveDir - (default 'images') base folder for overlays
%
%   OUTPUTS
%     lesionsBlock  struct matching the `lesions` block of data_contract.json
%                   (+ extra fields maByQuadrant, vesselDensity for the grader)
%     imagePaths    struct with .lesionOverlay and .vesselMap file paths
%     masks         struct of logical masks MA/HE/EX/NV/vessel/od  (for M-4)

    if nargin < 3; fovMask = []; end
    if nargin < 4; opts = struct(); end
    if ~isfield(opts,'useONNX');  opts.useONNX  = false; end
    if ~isfield(opts,'saveDir');  opts.saveDir  = 'images'; end

    if isempty(fovMask)
        fovMask = rgb2gray(img) > 0.04;
        fovMask = imfill(fovMask, 'holes');
    end
    fovMask = logical(fovMask);

    % --- landmarks + vessels -----------------------------------------
    [odMask, odCentroid, ~] = locateOpticDisc(img, fovMask);
    vesselMask = segmentVessels(img, fovMask);

    % --- lesions ------------------------------------------------------
    if opts.useONNX
        masks = runSegmentationONNX(img, fovMask);      % trained-model path (stub)
    else
        masks = detectLesionsClassical(img, fovMask, odMask, vesselMask);
    end
    masks.vessel = vesselMask;
    masks.od     = odMask;

    % --- quantify ---------------------------------------------------
    counts = quantifyLesions(masks, fovMask);

    % --- overlays + save ------------------------------------------
    outDir = fullfile(opts.saveDir, char(patientId));
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    lesionOverlay = generateLesionOverlay(img, masks, 0.55);
    vesselViz     = im2uint8(repmat(im2double(img(:,:,2)) .* 0.4, [1 1 3]));
    vv = vesselViz(:,:,1); vv(vesselMask) = 255; vesselViz(:,:,1) = vv;
    vv = vesselViz(:,:,2); vv(vesselMask) = 255; vesselViz(:,:,2) = vv;

    lesionPath = fullfile(outDir, 'lesion_overlay.png');
    vesselPath = fullfile(outDir, 'vessel_map.png');
    imwrite(lesionOverlay, lesionPath);
    imwrite(vesselViz, vesselPath);

    % --- data-contract block ------------------------------------
    lesionsBlock.maCount        = counts.maCount;
    lesionsBlock.heCount        = counts.heCount;
    lesionsBlock.exudateAreaPct = counts.exudateAreaPct;
    lesionsBlock.nvPresent      = logical(counts.nvPresent);
    lesionsBlock.odCentroid     = odCentroid(:)';           % [x y]
    % extras (not in JSON, used by the rules grader / UI)
    lesionsBlock.maByQuadrant   = counts.maByQuadrant;
    lesionsBlock.vesselDensity  = nnz(vesselMask) / max(nnz(fovMask),1);
    lesionsBlock.method         = ternary(opts.useONNX,'onnx','classical');

    imagePaths.lesionOverlay = lesionPath;
    imagePaths.vesselMap     = vesselPath;
end

function o = ternary(c,a,b); if c; o=a; else; o=b; end; end
