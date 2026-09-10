function M = evalGrading(sampleDir, labelsCsv)
%EVALGRADING  Run the full pipeline on every labelled sample and score it.
%
%   M = evalGrading                                   % data/samples + data/train.csv
%   M = evalGrading('data/samples','data/train.csv')
%
%   Prints per-image predicted vs true grade, the confusion matrix, exact +
%   within-1 accuracy, QWK, and referable-DR (grade>=2) sensitivity/specificity.
%   Returns a struct with all the numbers (for the PPT metrics slide).

    if nargin < 1 || isempty(sampleDir); sampleDir = fullfile('data','samples'); end
    if nargin < 2 || isempty(labelsCsv); labelsCsv = fullfile('data','train.csv'); end

    L = readtable(labelsCsv, 'TextType','string');
    % accept {id_code,diagnosis} (APTOS) or {image,grade}
    idCol = L.Properties.VariableNames{1};
    grCol = L.Properties.VariableNames{2};
    key   = string(L.(idCol));
    val   = double(L.(grCol));

    files = dir(fullfile(sampleDir,'*.png'));
    trueG = []; predG = []; names = strings(0);

    warning('off','loadGradingNet:missing');
    fprintf('%-22s %5s %5s %6s %6s   %s\n','image','true','pred','MA','HE','note');
    fprintf('%s\n', repmat('-',1,90));

    for i = 1:numel(files)
        [~, nm] = fileparts(files(i).name);
        j = find(key == string(nm), 1);
        if isempty(j); continue; end                 % unlabelled - skip
        tg = val(j);

        p = fullfile(files(i).folder, files(i).name);
        [proc, ~, routing, fov] = runQualityPipeline(p);
        if strcmp(routing,'recapture')
            fprintf('%-22s %5d   ungradable (skipped)\n', nm, tg); continue
        end
        [lb, ~, ~] = runSegmentationPipeline(proc, nm, fov);
        r = runGradingPipeline(proc, lb);

        trueG(end+1) = tg;        %#ok<AGROW>
        predG(end+1) = r.grade;   %#ok<AGROW>
        names(end+1) = nm;        %#ok<AGROW>

        flag = ''; if abs(tg - r.grade) >= 2; flag = '  <-- off by >=2'; end
        fprintf('%-22s %5d %5d %6d %6d   %s%s\n', nm, tg, r.grade, ...
            lb.maCount, lb.heCount, r.method, flag);
    end

    n = numel(trueG);
    assert(n > 0, 'No labelled images found - check that sample names match id_code in the CSV.');

    trueG = trueG(:); predG = predG(:);
    exact   = mean(trueG == predG);
    within1 = mean(abs(trueG - predG) <= 1);
    qwk     = quadraticWeightedKappa(trueG, predG, 0, 4);

    refT = trueG >= 2;  refP = predG >= 2;
    TP = sum(refT & refP);  TN = sum(~refT & ~refP);
    FP = sum(~refT & refP); FN = sum(refT & ~refP);
    sens = TP / max(TP+FN, 1);
    spec = TN / max(TN+FP, 1);

    fprintf('\n=== confusion matrix (rows=true 0-4, cols=pred 0-4) ===\n');
    C = zeros(5);
    for i = 1:n; C(trueG(i)+1, predG(i)+1) = C(trueG(i)+1, predG(i)+1) + 1; end
    disp(C);

    fprintf('n = %d labelled images\n', n);
    fprintf('Exact accuracy   : %.1f%%\n', 100*exact);
    fprintf('Within-1 accuracy: %.1f%%\n', 100*within1);
    fprintf('QWK              : %.3f\n', qwk);
    fprintf('Referable DR (grade>=2):  sensitivity %.1f%%   specificity %.1f%%\n', 100*sens, 100*spec);
    fprintf('  (targets: sensitivity > 90%%, specificity > 85%%)\n');

    M = struct('n',n,'exact',exact,'within1',within1,'qwk',qwk, ...
               'sensitivity',sens,'specificity',spec,'confusion',C, ...
               'trueG',trueG,'predG',predG,'names',{names});
end
