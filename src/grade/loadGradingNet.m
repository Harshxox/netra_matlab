function [net, info] = loadGradingNet(modelPath)
%LOADGRADINGNET  Import dr_grader.onnx once and cache it (persistent).
%
%   [net, info] = loadGradingNet()
%   [net, info] = loadGradingNet('models/dr_grader.onnx')
%
%   net  - dlnetwork, or [] if the file is not present yet
%   info - struct: .available (logical), .path, .message, .inputSize
%
%   Never throws for a missing file - the pipeline falls back to the rules
%   grader. It only warns once. A genuine import error IS surfaced.

    persistent cachedNet cachedInfo
    if nargin < 1 || isempty(modelPath)
        modelPath = fullfile('models','dr_grader.onnx');
    end

    if ~isempty(cachedInfo) && strcmp(cachedInfo.path, modelPath)
        net = cachedNet; info = cachedInfo; return
    end

    info = struct('available',false,'path',modelPath,'message','','inputSize',[224 224 3]);

    if ~isfile(modelPath)
        info.message = sprintf('%s not found - using the rules-based grader.', modelPath);
        warning('loadGradingNet:missing', '%s', info.message);
        cachedNet = []; cachedInfo = info; net = [];
        return
    end

    try
        n = importNetworkFromONNX(modelPath);
    catch e1
        try
            n = importONNXNetwork(modelPath, 'OutputLayerType', 'classification');
        catch e2
            error('loadGradingNet:importFailed', ...
                'dr_grader.onnx exists but will not import:\n  %s\n  %s', ...
                e1.message, e2.message);
        end
    end

    % try to read the expected input HxW from the network
    try
        s = n.Layers(1).InputSize;
        if numel(s) >= 2 && all(s(1:2) > 0); info.inputSize = s; end
    catch
    end

    info.available = true;
    info.message   = 'dr_grader.onnx loaded.';
    fprintf('%s (input %s)\n', info.message, mat2str(info.inputSize));

    cachedNet = n; cachedInfo = info; net = n;
end
