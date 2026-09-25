function [imagePaths, reportPath] = runExplainPipeline(processedImg, record, masks, opts)
%RUNEXPLAINPIPELINE  Entry point for M-4: heatmap + evidence view + PDF report.
%
%   [imagePaths, reportPath] = runExplainPipeline(processedImg, record, masks)
%   [...] = runExplainPipeline(processedImg, record, masks, opts)
%
%   processedImg - RGB fundus, double [0,1]
%   record       - data-contract struct (needs .patientId, .result, .lesions, .images)
%   masks        - struct of lesion masks from runSegmentationPipeline
%   opts.gradingNet, opts.gradingInfo - pass these to use real Grad-CAM
%   opts.saveDir  - image folder base (default 'images')
%   opts.makePdf  - generate the PDF (default true)
%
%   Writes gradcam.png + evidence.png under images/<patientId>/ and (optionally)
%   a PDF under reports/. Returns their paths.

    if nargin < 4; opts = struct(); end
    if ~isfield(opts,'saveDir'); opts.saveDir = 'images'; end
    if ~isfield(opts,'makePdf'); opts.makePdf = true;     end
    if ~isfield(opts,'gradingNet');  opts.gradingNet  = []; end
    if ~isfield(opts,'gradingInfo'); opts.gradingInfo = struct('inputSize',[224 224 3]); end
    if ~isfield(opts,'lesionsBlock'); opts.lesionsBlock = struct(); end
    if ~isfield(opts,'fovMask'); opts.fovMask = []; end

    pid = record.patientId;
    outDir = fullfile(opts.saveDir, char(pid));
    if ~exist(outDir,'dir'); mkdir(outDir); end

    grade = 0;
    if isfield(record,'result') && isstruct(record.result) && isfield(record.result,'grade')
        grade = record.result.grade;
    end

    sz = size(processedImg,[1 2]);
    fov = opts.fovMask; if isempty(fov); fov = processedImg(:,:,2) > 0.05; end

    % ---- attention map ---------------------------------------------
    %   trained CNN present -> Grad-CAM
    %   otherwise            -> occlusion-sensitivity on the classical grader
    %                           (decisionInfluenceMap), a model-agnostic analogue
    heatMethod = 'occlusion-sensitivity';
    if ~isempty(opts.gradingNet)
        try
            [heatmap, heatMethod] = generateGradCAM(opts.gradingNet, processedImg, grade, opts.gradingInfo);
        catch e
            warning('runExplainPipeline:gradcam','Grad-CAM failed (%s) - using occlusion sensitivity.', e.message);
            heatmap = safeInfluence(masks, opts.lesionsBlock, fov, sz);
        end
    else
        heatmap = safeInfluence(masks, opts.lesionsBlock, fov, sz);
    end

    % ---- explanation sanity check: attention vs detected lesions ----
    [xaiOK, xaiScore, xaiLabel] = xaiAgreement(heatmap, masks, fov);
    explain = struct('heatMethod', heatMethod, ...
                     'xaiAgreement', xaiOK, 'xaiScore', xaiScore, 'xaiLabel', xaiLabel);

    % ---- write images -------------------------------------------------
    gradcamImg  = overlayHeatmap(processedImg, heatmap, 0.45);
    evidenceImg = buildEvidenceView(processedImg, heatmap, masks);

    gradcamPath  = fullfile(outDir, 'gradcam.png');
    evidencePath = fullfile(outDir, 'evidence.png');
    imwrite(gradcamImg,  gradcamPath);
    imwrite(evidenceImg, evidencePath);

    imagePaths.gradcam     = gradcamPath;
    imagePaths.evidence    = evidencePath;
    imagePaths.heatMethod  = heatMethod;
    imagePaths.explain     = explain;

    % keep the record's image block in sync for the report
    record.images.gradcam  = gradcamPath;
    record.images.evidence = evidencePath;
    record.explain         = explain;

    % ---- PDF --------------------------------------------------------
    reportPath = '';
    if opts.makePdf
        reportPath = generateReport(record, struct('dir','reports','open',false));
    end
end

% --------------------------------------------------------------------
function h = safeInfluence(masks, lesionsBlock, fov, sz)
    try
        h = decisionInfluenceMap(masks, lesionsBlock, fov, 12);
        if ~any(h(:) > 0)
            h = lesionEvidenceHeatmap(masks, sz);   % nothing swings the grade
        end
    catch
        h = lesionEvidenceHeatmap(masks, sz);
    end
end
