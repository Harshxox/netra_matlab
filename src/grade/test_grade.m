function test_grade()
%TEST_GRADE  Smoke test for M-2 grading (rules path + ONNX path if present).
%
%   >> test_grade

    fprintf('=== M-2 grading smoke test ===\n\n');

    % --- 1. rules grader on synthetic lesion counts --------------------
    cases = {
        struct('maCount',0,  'heCount',0, 'exudateAreaPct',0,   'nvPresent',false,'maByQuadrant',[0 0 0 0]), 0
        struct('maCount',3,  'heCount',0, 'exudateAreaPct',0,   'nvPresent',false,'maByQuadrant',[1 1 1 0]), 1
        struct('maCount',18, 'heCount',2, 'exudateAreaPct',0.5, 'nvPresent',false,'maByQuadrant',[6 5 4 3]), 2
        struct('maCount',80, 'heCount',35,'exudateAreaPct',1.2, 'nvPresent',false,'maByQuadrant',[20 18 15 12]), 3
        struct('maCount',40, 'heCount',10,'exudateAreaPct',0.3, 'nvPresent',true, 'maByQuadrant',[10 10 10 5]), 4
    };
    for i = 1:size(cases,1)
        [g, p, notes] = gradeFromRules(cases{i,1});
        r = runGradingPipeline([], cases{i,1}, struct('forceRules',true));
        assert(g == cases{i,2}, 'rules case %d: got grade %d, expected %d', i, g, cases{i,2});
        assert(abs(sum(p) - 1) < 1e-9, 'probs must sum to 1');
        assert(numel(r.classProbabilities) == 5, 'need 5 class probs');
        assert(islogical(r.referable), 'referable must be logical');
        jsondecode(jsonencode(rmfield(r,'notes')));
        fprintf('  counts->grade %d (%s)  conf=%.0f%%  referable=%d  | %s\n', ...
            r.grade, r.gradeLabel, 100*r.confidence, r.referable, notes{1});
    end

    % --- 2. full quality -> segment -> grade on a real image ----------
    fprintf('\n  end-to-end on real images (rules path):\n');
    files = dir('data/samples/*.png');
    for i = 1:min(4, numel(files))
        p = fullfile(files(i).folder, files(i).name);
        [proc, ~, routing, fov] = runQualityPipeline(p);
        if strcmp(routing,'recapture'); continue; end
        [lb, ~, ~] = runSegmentationPipeline(proc, 'TEST', fov);
        r = runGradingPipeline(proc, lb);
        fprintf('    %-22s MA=%3d HE=%3d -> grade %d (%s)  referable=%d  [%s]\n', ...
            files(i).name, lb.maCount, lb.heCount, r.grade, r.gradeLabel, r.referable, r.method);
    end

    % --- 3. ONNX path, only if the model file exists -----------------
    if isfile(fullfile('models','dr_grader.onnx'))
        fprintf('\n  dr_grader.onnx present - testing ONNX path:\n');
        [proc,~,~,~] = runQualityPipeline(fullfile(files(1).folder, files(1).name));
        r = runGradingPipeline(proc, struct(), struct('forceRules',false));
        fprintf('    grade %d (%s) conf=%.0f%% method=%s\n', ...
            r.grade, r.gradeLabel, 100*r.confidence, r.method);
        assert(strcmp(r.method,'onnx'), 'expected ONNX path to be used');
    else
        fprintf('\n  (dr_grader.onnx not present - ONNX path not tested)\n');
    end

    fprintf('\n=== all assertions passed ===\n');
end
