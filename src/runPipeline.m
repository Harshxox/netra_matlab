function record = runPipeline(imagePath, patientId, eye, opts)
%RUNPIPELINE  Master entry point (M-8): one fundus image -> full screening record.
%
%   record = runPipeline(imagePath, patientId, eye)
%   record = runPipeline(imagePath, patientId, eye, opts)
%
%   imagePath - path to a fundus image
%   patientId - char/string
%   eye       - 'OD' | 'OS'
%   opts.save     - append to netra_db.mat (default true)
%   opts.makePdf  - generate the PDF report (default true)
%   opts.saveDir  - per-patient image folder base (default 'images')
%
%   Returns the data-contract struct (see docs/data_contract.json). On an
%   ungradable image it fills quality + routing='recapture' and returns early.
%
%   Order:  quality -> [exit if ungradable] -> segmentation -> grading
%           -> routing -> explainability -> history -> save

    if nargin < 3 || isempty(eye); eye = 'OD'; end
    if nargin < 4; opts = struct(); end
    if ~isfield(opts,'save');    opts.save    = true;  end
    if ~isfield(opts,'makePdf'); opts.makePdf = true;  end
    if ~isfield(opts,'saveDir'); opts.saveDir = 'images'; end

    t0 = tic;

    % ---- validate input ------------------------------------------
    imagePath = char(imagePath);
    if isempty(imagePath) || ~isfile(imagePath)
        error('runPipeline:noFile', 'Image file not found:\n  %s', imagePath);
    end
    try
        info = imfinfo(imagePath);          % also rejects non-image files
        assert(info(1).Width > 0 && info(1).Height > 0);
    catch
        error('runPipeline:notImage', ...
            'This file is not a readable image:\n  %s', imagePath);
    end
    if isempty(char(patientId))
        patientId = "PT-" + string(datetime('now','Format','yyyyMMdd-HHmmss'));
    end

    % ---- base record ------------------------------------------------
    record = emptyRecord();
    record.patientId = char(patientId);
    record.eye       = char(eye);
    record.date      = char(datetime('now','Format','yyyy-MM-dd_HH-mm'));
    record.images.originalRaw = imagePath;

    outDir = fullfile(opts.saveDir, record.patientId);
    if ~exist(outDir,'dir'); mkdir(outDir); end

    % save a display-sized copy of the TRUE original (no crop, no enhance)
    try
        rawImg = imread(imagePath);
        origPath = fullfile(outDir, 'original.png');
        imwrite(im2uint8(imresize(rawImg, [512 512])), origPath);
        record.images.original = origPath;
    catch
        record.images.original = char(imagePath);
    end

    % ---- M-1 quality + preprocess --------------------------------
    [proc, qBlock, routing, fovMask] = runQualityPipeline(imagePath);
    record.quality = qBlock;
    record.routing = routing;

    % the processed image (FOV-cropped, resized, enhanced if borderline)
    procPath = fullfile(outDir, 'processed.png');
    imwrite(im2uint8(proc), procPath);
    record.images.enhanced = procPath;

    if strcmp(routing, 'recapture')
        record.routing = 'recapture';
        if opts.save; saveScreening(record); end
        record.meta.elapsedSec = toc(t0);
        record.meta.note = 'Ungradable - recapture requested.';
        return
    end

    % ---- M-3 segmentation ---------------------------------------
    [lBlock, segPaths, masks] = runSegmentationPipeline(proc, record.patientId, fovMask, ...
                                    struct('saveDir', opts.saveDir));
    record.lesions = lBlock;
    record.images.lesionOverlay = segPaths.lesionOverlay;
    record.images.vesselMap     = segPaths.vesselMap;

    % ---- M-2 grading ------------------------------------------
    [gnet, ginfo] = loadGradingNet();
    record.result = runGradingPipeline(proc, lBlock, struct('forceRules', isempty(gnet)));

    % ---- routing ---------------------------------------------
    if record.result.referable
        record.routing = 'refer_specialist';
    else
        record.routing = 'routine_followup';
    end

    % ---- M-4 explainability + report -----------------------
    [ip, reportPath] = runExplainPipeline(proc, record, masks, struct( ...
        'saveDir', opts.saveDir, 'makePdf', opts.makePdf, ...
        'gradingNet', gnet, 'gradingInfo', ginfo));
    record.images.gradcam  = ip.gradcam;
    record.images.evidence = ip.evidence;
    record.images.reportPath = reportPath;
    record.meta.heatMethod = ip.heatMethod;

    % ---- M-5 history ---------------------------------------
    [hist, ~] = getHistory(record.patientId);
    record.history = hist;

    % ---- persist ------------------------------------------
    record.review = struct('status','pending','finalGrade',[], ...
                           'notes','','reviewerId','','timestamp','');
    if opts.save; saveScreening(record); end

    record.meta.elapsedSec = toc(t0);
end

% ====================================================================
function r = emptyRecord()
    r.schemaVersion = "1.0";
    r.patientId = ""; r.eye = "OD"; r.date = "";
    r.quality = struct('status','','focusScore',0,'illuminationScore',0,'fovRatio',0,'enhanced',false);
    r.result  = [];
    r.lesions = [];
    r.images  = struct('original','','enhanced','','gradcam','','lesionOverlay','', ...
                       'vesselMap','','evidence','','reportPath','');
    r.history = struct('priorGrades',[],'trend','');
    r.routing = 'routine_followup';
    r.review  = struct('status','pending','finalGrade',[],'notes','','reviewerId','','timestamp','');
    r.clinical = [];
    r.secondaryFindings = [];
    r.meta = struct();
end

function v = getdef(s,f,d)
    if isstruct(s) && isfield(s,f) && ~isempty(s.(f)); v = s.(f); else; v = d; end
end
