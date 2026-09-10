function test_explain()
%TEST_EXPLAIN  Smoke test for M-4: heatmap, evidence view, PDF report.
%
%   >> test_explain
%
%   Runs quality -> segment -> grade -> explain on the first 3 sample images
%   and one synthetic ungradable case. Checks images + PDF are produced.

    fprintf('=== M-4 explainability smoke test ===\n\n');
    warning('off','loadGradingNet:missing');
    warning('off','calibrateConfidence:noFile');

    files = dir('data/samples/*.png');
    assert(~isempty(files), 'no sample images');

    for i = 1:min(3, numel(files))
        [~, pid] = fileparts(files(i).name);
        p = fullfile(files(i).folder, files(i).name);

        [proc, qb, routing, fov] = runQualityPipeline(p);
        record = baseRecord(pid, proc, qb, routing);
        if strcmp(routing,'recapture'); continue; end

        [lb, segPaths, masks] = runSegmentationPipeline(proc, pid, fov);
        record.lesions = lb;
        record.images.lesionOverlay = segPaths.lesionOverlay;
        record.images.vesselMap     = segPaths.vesselMap;

        record.result = runGradingPipeline(proc, lb);
        if record.result.referable
            record.routing = 'refer_specialist';
        else
            record.routing = 'routine_followup';
        end

        [ip, rp] = runExplainPipeline(proc, record, masks);

        assert(isfile(ip.gradcam),  '%s: gradcam.png not written', pid);
        assert(isfile(ip.evidence), '%s: evidence.png not written', pid);
        assert(isfile(rp),          '%s: PDF not written', pid);
        gc = imread(ip.gradcam);
        assert(size(gc,3) == 3 && isa(gc,'uint8'), 'gradcam must be uint8 RGB');

        fprintf('  %-22s grade %d (%s)  heat=%s  PDF=%s\n', ...
            pid, record.result.grade, record.result.gradeLabel, ip.heatMethod, rp);
    end

    % --- ungradable path ------------------------------------------
    fprintf('\n  ungradable path:\n');
    blur = imgaussfilt(im2double(imread(fullfile(files(1).folder,files(1).name))), 9);
    [proc, qb, routing, ~] = runQualityPipeline(blur);
    rec = baseRecord('PT-UNGRADABLE', proc, qb, routing);
    rp = generateReport(rec, struct('dir','reports'));
    assert(isfile(rp), 'ungradable PDF not written');
    fprintf('    routing=%s  PDF=%s\n', routing, rp);

    fprintf('\n=== all assertions passed - open a PDF in reports/ to eyeball ===\n');
end

% ----------------------------------------------------------------------
function r = baseRecord(pid, ~, qb, routing)
    r.patientId = pid;
    r.eye  = 'OD';
    r.date = char(datetime('now','Format','yyyy-MM-dd_HH-mm'));
    r.quality = qb;
    r.routing = routing;
    r.images  = struct('original','','enhanced','','gradcam','', ...
                       'lesionOverlay','','vesselMap','','evidence','');
    r.history = struct('priorGrades',[],'trend','');
    r.result  = [];
    r.lesions = [];
end
