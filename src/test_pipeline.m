function test_pipeline()
%TEST_PIPELINE  End-to-end smoke test for the master runPipeline (M-8).

    fprintf('=== M-8 end-to-end pipeline test ===\n\n');
    warning('off','loadGradingNet:missing');
    warning('off','calibrateConfidence:noFile');

    % start from a clean DB (it is gitignored + rebuilt on demand)
    if isfile('netra_db.mat'); delete('netra_db.mat'); end

    files = dir('data/samples/*.png');
    assert(~isempty(files), 'no sample images');

    % --- 1. gradable image, full run --------------------------------
    p = fullfile(files(1).folder, files(1).name);
    [~, pid] = fileparts(files(1).name);
    rec = runPipeline(p, pid, 'OD');

    assert(~isempty(rec.result), 'result block empty on gradable image');
    assert(rec.result.grade >= 0 && rec.result.grade <= 4, 'grade out of range');
    assert(isfile(rec.images.gradcam),      'gradcam not saved');
    assert(isfile(rec.images.lesionOverlay),'lesion overlay not saved');
    assert(isfile(rec.images.evidence),     'evidence not saved');
    assert(isfile(rec.images.reportPath),   'PDF not saved');
    assert(ismember(rec.routing, {'refer_specialist','routine_followup'}), 'bad routing');
    assert(strcmp(rec.review.status,'pending'), 'review status must be pending');

    js = jsonencode(rec);           % must serialize for the dashboard
    d  = jsondecode(js);
    assert(isfield(d,'result') && isfield(d,'lesions') && isfield(d,'images'), 'JSON missing blocks');

    fprintf('  %-20s grade %d (%s)  referable=%d  %.1fs  heat=%s\n', ...
        pid, rec.result.grade, rec.result.gradeLabel, rec.result.referable, ...
        rec.meta.elapsedSec, rec.meta.heatMethod);

    % --- 2. ungradable image, early exit ---------------------------
    blurPath = fullfile(tempdir,'blur.png');
    bad = im2double(imread(p));
    bad = imgaussfilt(bad, 14) * 0.35;          % very blurry AND dark
    imwrite(im2uint8(bad), blurPath);
    rec2 = runPipeline(blurPath, 'PT-BAD', 'OS');
    assert(strcmp(rec2.routing,'recapture'), 'ungradable must route to recapture');
    assert(isempty(rec2.result), 'ungradable must have empty result');
    fprintf('  %-20s routing=%s (early exit OK)\n', 'PT-BAD', rec2.routing);

    % --- 3. history across two visits (temp DB) -------------------
    runPipeline(p, 'PT-HIST', 'OD', struct('save',true,'makePdf',false));
    runPipeline(fullfile(files(2).folder,files(2).name), 'PT-HIST', 'OD', struct('save',true,'makePdf',false));
    [h,~] = getHistory('PT-HIST');
    assert(numel(h.priorGrades) >= 2, 'history should have >= 2 records');
    fprintf('  PT-HIST trend: "%s"\n', h.trend);

    % --- 4. review decision -------------------------------------
    ok = saveReviewDecision('PT-HIST','OD', 2, 'Agree', 'reviewer_01');
    assert(ok, 'review decision should succeed');
    st = dbStats();
    fprintf('  dbStats: %d screened, %.0f%% referral rate, %d pending\n', ...
        st.totalScreened, st.referralRate, st.pendingReview);

    fprintf('\n=== all assertions passed ===\n');
end
