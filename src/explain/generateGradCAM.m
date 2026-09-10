function [heatmap, methodUsed] = generateGradCAM(net, img, grade, info)
%GENERATEGRADCAM  Attention heatmap for the ResNet-50 grader (with fallbacks).
%
%   [heatmap, methodUsed] = generateGradCAM(net, img, grade, info)
%
%   net   - dlnetwork from loadGradingNet
%   img   - RGB fundus, double [0,1]
%   grade - predicted class 0-4
%   info  - struct from loadGradingNet (.inputSize)
%
%   heatmap    - double [0,1], resized to img size
%   methodUsed - 'gradcam' | 'occlusion' - which technique actually ran
%
%   Tries gradCAM (auto layer detection). If that fails on the imported ONNX
%   network - common - it falls back to occlusionSensitivity, which needs no
%   layer names. The caller handles the no-net case separately
%   (lesionEvidenceHeatmap).

    if nargin < 4 || isempty(info); info.inputSize = [224 224 3]; end
    hw = info.inputSize(1:2);

    x224 = imresize(im2double(img), hw);
    if size(x224,3) == 1; x224 = repmat(x224,[1 1 3]); end
    mu = reshape([0.485 0.456 0.406],[1 1 3]);
    sd = reshape([0.229 0.224 0.225],[1 1 3]);
    dlx = dlarray(single((x224 - mu)./sd), 'SSCB');

    cls = grade + 1;                 % 1-indexed class

    methodUsed = 'gradcam';
    try
        map = gradCAM(net, dlx, cls);
    catch
        try
            % specify the last conv-like feature layer explicitly
            fl = lastFeatureLayer(net);
            map = gradCAM(net, dlx, cls, 'FeatureLayer', fl);
        catch
            methodUsed = 'occlusion';
            map = occlusionSensitivity(net, dlx, cls, ...
                'MaskSize', round(hw(1)/8), 'Stride', round(hw(1)/16));
        end
    end

    map = extractdata(gather(map));
    map = double(map);
    map = mat2gray(map);
    heatmap = imresize(map, [size(img,1) size(img,2)]);
    heatmap = max(0, min(1, heatmap));
end

% ----------------------------------------------------------------------
function name = lastFeatureLayer(net)
    name = '';
    for i = numel(net.Layers):-1:1
        L = net.Layers(i);
        if isa(L,'nnet.cnn.layer.Convolution2DLayer') || ...
           contains(class(L),'Conv','IgnoreCase',true) || ...
           contains(class(L),'Relu','IgnoreCase',true)
            name = L.Name; return
        end
    end
    if isempty(name); name = net.Layers(max(1,end-3)).Name; end
end
