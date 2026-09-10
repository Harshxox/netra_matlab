function resultBlock = runGradingPipeline(processedImg, lesionsBlock, opts)
%RUNGRADINGPIPELINE  Entry point for M-2: image (+ lesion counts) -> result block.
%
%   resultBlock = runGradingPipeline(processedImg, lesionsBlock)
%   resultBlock = runGradingPipeline(processedImg, lesionsBlock, opts)
%
%   processedImg  - RGB fundus, double [0,1], from runQualityPipeline
%   lesionsBlock  - struct from runSegmentationPipeline (for the rules grader)
%   opts.forceRules - (default false) ignore the ONNX model even if present
%
%   Strategy: use dr_grader.onnx if it is available and imports; otherwise
%   fall back to gradeFromRules(lesionsBlock). Both return the same contract.

    if nargin < 2; lesionsBlock = struct('maCount',0,'heCount',0, ...
                                         'exudateAreaPct',0,'nvPresent',false); end
    if nargin < 3; opts = struct(); end
    if ~isfield(opts,'forceRules'); opts.forceRules = false; end

    [net, info] = deal([], struct('available',false));
    if ~opts.forceRules
        [net, info] = loadGradingNet();
    end

    if info.available && ~isempty(net)
        try
            [grade, probs] = runGradingONNX(net, processedImg, info);
            [referable, ~] = isReferable(probs, grade);
            resultBlock = buildResultBlock(grade, probs, referable, 'onnx', ...
                {sprintf('ResNet-50 grader: P(grade %d)=%.0f%%', grade, 100*max(probs))});
            return
        catch e
            warning('runGradingPipeline:onnxFailed', ...
                'ONNX grader failed (%s) - falling back to rules.', e.message);
        end
    end

    % --- rules-based fallback ---------------------------------------
    [grade, probs, notes] = gradeFromRules(lesionsBlock);
    [referable, ~] = isReferable(probs, grade);
    resultBlock = buildResultBlock(grade, probs, referable, 'rules', notes);
end
