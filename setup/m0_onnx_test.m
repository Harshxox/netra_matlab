function m0_onnx_test(onnxPath)
% M0_ONNX_TEST  Day-1 non-negotiable: prove MATLAB can import + run an ONNX model.
%
%   >> setup\m0_onnx_test                       % looks for models\test.onnx
%   >> setup\m0_onnx_test('models\resnet50-v1-7.onnx')
%
% WHERE TO GET A TEST MODEL (do this before running):
%   Download a real classifier ONNX so the test is meaningful, e.g.
%   ResNet-50 opset-11 from the ONNX Model Zoo:
%     https://github.com/onnx/models  ->  vision/classification/resnet
%   Save it as  models\test.onnx  (or pass the path as an argument).
%
% If this FAILS: screenshot the error, post it to the team, and tell the
% Colab team to export with  opset_version=11  and standard ops only.

    if nargin < 1 || isempty(onnxPath)
        onnxPath = fullfile('models', 'test.onnx');
    end

    if ~isfile(onnxPath)
        error('m0_onnx_test:noFile', ...
            ['No ONNX file at "%s".\n' ...
             'Download a real ResNet-50 opset-11 model from the ONNX Model Zoo\n' ...
             'and save it there, or pass a path: m0_onnx_test(''path\\to\\model.onnx'')'], ...
            onnxPath);
    end

    % --- The ONNX import functions live in a FREE support package --------
    if isempty(which('importNetworkFromONNX')) && isempty(which('importONNXNetwork'))
        error('m0_onnx_test:noConverter', ...
            ['ONNX import functions are not available. Install the free support package:\n' ...
             '  Home tab > Add-Ons > Get Add-Ons > search "ONNX"\n' ...
             '  > install "Deep Learning Toolbox Converter for ONNX Model Format"\n' ...
             '  (sign in with your MathWorks trial account; ~1 min)\n' ...
             'Then run  setup\\m0_onnx_test  again.']);
    end

    fprintf('Importing: %s\n', onnxPath);

    net = [];
    % --- Try the modern API first (R2023b+), returns a dlnetwork ----------
    try
        net = importNetworkFromONNX(onnxPath);
        fprintf('  importNetworkFromONNX: OK  (class: %s)\n', class(net));
    catch e1
        fprintf(2, '  importNetworkFromONNX failed: %s\n', e1.message);
        % --- Fall back to the older API ----------------------------------
        try
            net = importONNXNetwork(onnxPath, 'OutputLayerType', 'classification');
            fprintf('  importONNXNetwork: OK  (class: %s)\n', class(net));
        catch e2
            fprintf(2, '  importONNXNetwork also failed: %s\n', e2.message);
            error('m0_onnx_test:importFailed', ...
                'Both ONNX import APIs failed. This BLOCKS M-2 and M-3 - flag immediately.');
        end
    end

    % --- Check for placeholder layers (unsupported ops) -------------------
    ph = [];
    try
        ph = findPlaceholderLayers(net);
    catch
        % dlnetwork path: scan layer classes for "PlaceholderLayer"
        try
            isPH = arrayfun(@(L) contains(class(L),'Placeholder','IgnoreCase',true), net.Layers);
            ph = net.Layers(isPH);
        catch
        end
    end
    if ~isempty(ph)
        fprintf(2, '\n  WARNING: %d placeholder layer(s) - the model has ops MATLAB does not support.\n', numel(ph));
        fprintf(2, '  The network will NOT run until these are replaced. Tell Colab to simplify the export.\n');
        for k = 1:numel(ph)
            fprintf(2, '    - %s\n', ph(k).Name);
        end
    else
        fprintf('  No placeholder layers - all ops supported.\n');
    end

    % --- Try a forward pass with a random 224x224x3 image ---------------
    try
        x = dlarray(rand(224,224,3,1,'single'), 'SSCB');
        y = predict(net, x);
        y = extractdata(gather(y));
        fprintf('  Forward pass OK. Output size: [%s]\n', num2str(size(y)));
        fprintf('  (If output length is 1000 this is an ImageNet model - expected for the test.)\n');
    catch e
        fprintf(2, '  Forward pass failed: %s\n', e.message);
        fprintf(2, '  Import worked but inference did not - check input size / dlarray format.\n');
    end

    fprintf('\n  Open the network viewer to inspect layers (needed later for Grad-CAM):\n');
    fprintf('    >> analyzeNetwork(net)\n');
    fprintf('\nONNX import test PASSED. M-2 / M-3 are unblocked.\n');
end
