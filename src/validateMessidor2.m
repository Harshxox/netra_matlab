function M = validateMessidor2(imgDir, labelsCsv, opts)
%VALIDATEMESSIDOR2  External validation of the pipeline on Messidor-2.
%
%   M = validateMessidor2                 % data/messidor2/images + data/messidor2/labels.csv
%   M = validateMessidor2(imgDir, labelsCsv)
%   M = validateMessidor2(imgDir, labelsCsv, opts)
%
%   Messidor-2 is a held-out dataset the models are NEVER trained on - this is
%   the "does it generalise" test the PS asks for. Runs the FULL runPipeline on
%   each image, then reports referable-DR sensitivity/specificity and QWK.
%
%   opts.limit        run only the first N gradable images (default Inf).
%                     Use ~150-250 for a quick check - the full set is ~1748
%                     images and the classical pipeline is ~5 s each.
%   opts.referGrade   grade at/above which a case is "referable" (default 2)
%   opts.outFile      save a results .mat + a summary .txt (default 'reports/messidor2_validation')
%   opts.useParallel  parfor over images if Parallel Computing Toolbox present (default true)
%
%   Handles the common Messidor-2 CSV layouts:
%     - {id_code, diagnosis}                        (Kaggle APTOS-style mirror)
%     - {image_id, adjudicated_dr_grade, ...}       (Google adjudicated labels)
%     - {Image name, Retinopathy grade, ...}        (original ADCIS release, 0-3)

    if nargin < 1 || isempty(imgDir);   imgDir   = fullfile('data','messidor2','images'); end
    if nargin < 2 || isempty(labelsCsv);labelsCsv= fullfile('data','messidor2','labels.csv'); end
    if nargin < 3; opts = struct(); end
    if ~isfield(opts,'limit');       opts.limit = Inf; end
    if ~isfield(opts,'referGrade');  opts.referGrade = 2; end
    if ~isfield(opts,'outFile');     opts.outFile = fullfile('reports','messidor2_validation'); end
    if ~isfield(opts,'useParallel'); opts.useParallel = license('test','Distrib_Computing_Toolbox')==1; end

    assert(isfolder(imgDir),  'Image folder not found: %s', imgDir);
    assert(isfile(labelsCsv), 'Labels CSV not found: %s',  labelsCsv);

    [names, grades, gradable] = readMessidorLabels(labelsCsv);
    keep = gradable & ~isnan(grades);
    names = names(keep); grades = grades(keep);

    % resolve each name to a real file (extensions vary: .jpg .JPG .png .tif)
    paths = strings(size(names)); ok = false(size(names));
    for i = 1:numel(names)
        p = resolveImage(imgDir, names(i));
        if p ~= ""; paths(i) = p; ok(i) = true; end
    end
    names = names(ok); grades = grades(ok); paths = paths(ok);

    n = min(numel(paths), opts.limit);
    paths = paths(1:n); grades = grades(1:n); names = names(1:n);
    fprintf('Messidor-2: %d labelled + resolved images (running %d)\n', numel(ok), n);

    predGrade = nan(n,1);
    predRefer = false(n,1);
    t0 = tic;

    runOne = @(k) predictOne(paths(k));
    if opts.useParallel && n > 20
        parfor k = 1:n
            [predGrade(k), predRefer(k)] = runOne(k);
        end
    else
        for k = 1:n
            [predGrade(k), predRefer(k)] = runOne(k);
            if mod(k,25)==0; fprintf('  %d/%d  (%.0fs)\n', k, n, toc(t0)); end
        end
    end

    valid = ~isnan(predGrade);
    tg = grades(valid);  pg = predGrade(valid);
    trueRefer = tg >= opts.referGrade;
    pr = predRefer(valid);

    TP = sum(trueRefer & pr);  TN = sum(~trueRefer & ~pr);
    FP = sum(~trueRefer & pr); FN = sum(trueRefer & ~pr);

    M.n            = numel(tg);
    M.excluded     = n - numel(tg);          % ungradable by our quality check
    M.sensitivity  = TP / max(TP+FN,1);
    M.specificity  = TN / max(TN+FP,1);
    M.ppv          = TP / max(TP+FP,1);
    M.npv          = TN / max(TN+FN,1);
    M.qwk          = quadraticWeightedKappa(round(tg), round(pg), 0, 4);
    M.exactAcc     = mean(round(tg)==round(pg));
    M.within1Acc   = mean(abs(round(tg)-round(pg))<=1);
    M.confusion    = confMat(round(tg), round(pg));
    M.elapsedMin   = toc(t0)/60;
    M.referGrade   = opts.referGrade;

    printSummary(M);
    saveResults(M, opts.outFile, names(valid), tg, pg);
end

% ====================================================================
function [g, r] = predictOne(p)
    g = NaN; r = false;
    try
        rec = runPipeline(char(p), 'MESSIDOR', 'OD', ...
                          struct('save',false,'makePdf',false));
        if ~isempty(rec.result)
            g = rec.result.grade;
            r = logical(rec.result.referable);
        end
    catch
    end
end

function [names, grades, gradable] = readMessidorLabels(csv)
    T = readtable(csv, 'TextType','string', 'VariableNamingRule','preserve');
    v = string(T.Properties.VariableNames);
    lc = lower(v);

    nameCol = pick(lc, ["image_id","id_code","image name","image","filename","imagename"]);
    gradeCol = pick(lc, ["adjudicated_dr_grade","diagnosis","retinopathy grade", ...
                         "dr_grade","grade","dr_level"]);
    assert(nameCol>0 && gradeCol>0, ...
        'Could not find name/grade columns in %s. Columns: %s', csv, strjoin(v,', '));

    names  = string(T.(v(nameCol)));
    grades = double(T.(v(gradeCol)));

    gcol = pick(lc, ["adjudicated_gradable","gradable","adjudicable"]);
    if gcol>0
        gradable = logical(double(T.(v(gcol))));
    else
        gradable = true(size(names));
    end
end

function idx = pick(cols, candidates)
    idx = 0;
    for c = candidates
        f = find(cols == c, 1);
        if ~isempty(f); idx = f; return; end
    end
end

function p = resolveImage(dirPath, name)
    p = "";
    name = string(name);
    [~, base, ext] = fileparts(name);
    tries = string.empty;
    if ext ~= ""; tries(end+1) = name; end
    for e = [".jpg",".JPG",".jpeg",".png",".PNG",".tif",".tiff",".bmp"]
        tries(end+1) = base + e; %#ok<AGROW>
    end
    for t = tries
        cand = fullfile(dirPath, t);
        if isfile(cand); p = string(cand); return; end
    end
end

function C = confMat(t, p)
    C = zeros(5);
    for i = 1:numel(t)
        a = min(max(t(i),0),4)+1;  b = min(max(p(i),0),4)+1;
        C(a,b) = C(a,b)+1;
    end
end

function printSummary(M)
    fprintf('\n=== Messidor-2 external validation ===\n');
    fprintf('n = %d  (excluded ungradable: %d)   runtime %.1f min\n', M.n, M.excluded, M.elapsedMin);
    fprintf('Referable DR (grade >= %d):\n', M.referGrade);
    fprintf('  Sensitivity : %.3f   (target > 0.90)\n', M.sensitivity);
    fprintf('  Specificity : %.3f   (target > 0.85)\n', M.specificity);
    fprintf('  PPV / NPV   : %.3f / %.3f\n', M.ppv, M.npv);
    fprintf('Grading: QWK %.3f  | exact %.1f%%  | within-1 %.1f%%\n', ...
        M.qwk, 100*M.exactAcc, 100*M.within1Acc);
    fprintf('Confusion (rows=true 0-4, cols=pred):\n'); disp(M.confusion);
end

function saveResults(M, outFile, names, tg, pg)
    d = fileparts(outFile); if ~isempty(d) && ~isfolder(d); mkdir(d); end
    save([outFile '.mat'], 'M', 'names', 'tg', 'pg');
    fid = fopen([outFile '.txt'], 'w');
    fprintf(fid, 'Messidor-2 external validation\n');
    fprintf(fid, 'n=%d excluded=%d\n', M.n, M.excluded);
    fprintf(fid, 'Referable (>=%d): sensitivity %.3f  specificity %.3f  PPV %.3f  NPV %.3f\n', ...
        M.referGrade, M.sensitivity, M.specificity, M.ppv, M.npv);
    fprintf(fid, 'QWK %.3f  exact %.3f  within1 %.3f\n', M.qwk, M.exactAcc, M.within1Acc);
    fclose(fid);
    fprintf('Saved %s.mat / .txt\n', outFile);
end
