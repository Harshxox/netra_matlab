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

    pid = record.patientId;
    outDir = fullfile(opts.saveDir, char(pid));
    if ~exist(outDir,'dir'); mkdir(outDir); end

    grade = 0;
    if isfield(record,'result') && isstruct(record.result) && isfield(record.result,'grade')
        grade = record.result.grade;
    end

    % ---- heatmap: real Grad-CAM if we have the net, else lesion evidence ---
    heatMethod = 'lesion-evidence';
    if ~isempty(opts.gradingNet)
        try
            [heatmap, heatMethod] = generateGradCAM(opts.gradingNet, processedImg, grade, opts.gradingInfo);
        catch e
            warning('runExplainPipeline:gradcam','Grad-CAM failed (%s) - using lesion evidence map.', e.message);
            heatmap = lesionEvidenceHeatmap(masks, size(processedImg,[1 2]));
        end
    else
        heatmap = lesionEvidenceHeatmap(masks, size(processedImg,[1 2]));
    end

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

    % keep the record's image block in sync for the report
    record.images.gradcam  = gradcamPath;
    record.images.evidence = evidencePath;

    % ---- PDF --------------------------------------------------------
    reportPath = '';
    if opts.makePdf
        reportPath = generateReport(record, struct('dir','reports','open',false));
    end
end
