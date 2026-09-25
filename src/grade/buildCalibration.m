function cal = buildCalibration(sampleDir, labelsCsv, outFile)
%BUILDCALIBRATION  Fit a confidence-calibration curve for the classical grader.
%
%   cal = buildCalibration                          % data/samples + data/train.csv
%   cal = buildCalibration(sampleDir, labelsCsv, outFile)
%
%   Runs the pipeline on every labelled image, takes the raw referable-risk
%   P(grade>=2), and fits Platt scaling  p_cal = sigmoid(A*logit(p_raw)+B)
%   against whether the case was truly referable. Saves A, B and the expected
%   calibration error (ECE) before/after to  models/calibration.mat.
%
%   This makes the "confidence" shown in the app an actual reliability estimate
%   (an ophthalmologist can trust "80% confident" to mean ~80% correct),
%   calibrated on held-out labelled data - the PS calls for "calibrated
%   confidence scores".

    if nargin < 1 || isempty(sampleDir); sampleDir = fullfile('data','samples'); end
    if nargin < 2 || isempty(labelsCsv); labelsCsv = fullfile('data','train.csv'); end
    if nargin < 3 || isempty(outFile);   outFile   = fullfile('models','calibration.mat'); end

    L = readtable(labelsCsv, 'TextType','string');
    key = string(L.(L.Properties.VariableNames{1}));
    val = double(L.(L.Properties.VariableNames{2}));

    files = dir(fullfile(sampleDir, '*.png'));
    pRaw = []; yRef = [];
    warning('off','loadGradingNet:missing');
    warning('off','loadGradingNet:importFailed');

    fprintf('Collecting predictions for calibration...\n');
    for i = 1:numel(files)
        [~, nm] = fileparts(files(i).name);
        j = find(key == string(nm), 1);
        if isempty(j); continue; end

        try
            rec = runPipeline(fullfile(files(i).folder, files(i).name), nm, 'OD', ...
                              struct('save',false,'makePdf',false));
        catch
            continue
        end
        if isempty(rec.result); continue; end
        p = rec.result.classProbabilities;
        pRaw(end+1) = sum(p(3:5));            %#ok<AGROW>  raw P(referable)
        yRef(end+1) = double(val(j) >= 2);    %#ok<AGROW>
    end

    n = numel(pRaw);
    assert(n >= 10, 'Only %d labelled predictions - need more for calibration.', n);
    pRaw = min(max(pRaw(:), 1e-4), 1-1e-4);
    yRef = yRef(:);

    % --- Platt fit: minimise negative log-likelihood ------------------
    z = log(pRaw ./ (1 - pRaw));
    nll = @(ab) -sum( yRef.*log(sig(ab(1)*z+ab(2)) + 1e-9) + ...
                     (1-yRef).*log(1 - sig(ab(1)*z+ab(2)) + 1e-9) );
    ab = fminsearch(nll, [1 0], optimset('Display','off','MaxFunEvals',2000));

    pCal = sig(ab(1)*z + ab(2));

    cal.method   = 'platt';
    cal.A        = ab(1);
    cal.B        = ab(2);
    cal.n        = n;
    cal.date     = char(datetime('now'));
    cal.eceRaw   = ece(pRaw, yRef);
    cal.eceCal   = ece(pCal, yRef);
    cal.brierRaw = mean((pRaw - yRef).^2);
    cal.brierCal = mean((pCal - yRef).^2);

    if ~exist(fileparts(outFile),'dir'); mkdir(fileparts(outFile)); end
    save(outFile, '-struct', 'cal');

    fprintf('\nCalibration fitted on %d labelled cases (Platt A=%.2f B=%.2f)\n', n, cal.A, cal.B);
    fprintf('  Expected Calibration Error : %.3f  ->  %.3f\n', cal.eceRaw, cal.eceCal);
    fprintf('  Brier score                : %.3f  ->  %.3f\n', cal.brierRaw, cal.brierCal);
    fprintf('  Saved %s\n', outFile);
end

% ----------------------------------------------------------------------
function s = sig(x); s = 1 ./ (1 + exp(-x)); end

function e = ece(p, y, nbins)
    if nargin < 3; nbins = 8; end
    edges = linspace(0, 1, nbins+1);
    e = 0; N = numel(p);
    for b = 1:nbins
        in = p > edges(b) & p <= edges(b+1);
        if b == 1; in = in | (p == 0); end
        if ~any(in); continue; end
        e = e + (sum(in)/N) * abs(mean(y(in)) - mean(p(in)));
    end
end
