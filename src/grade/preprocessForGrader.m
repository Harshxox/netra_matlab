function dlx = preprocessForGrader(img, inputSize)
%PREPROCESSFORGRADER  Prepare a fundus image for the ResNet-50 ONNX grader.
%
%   dlx = preprocessForGrader(img)
%   dlx = preprocessForGrader(img, [224 224 3])
%
%   img  - RGB fundus, double [0,1] (output of runQualityPipeline)
%   dlx  - dlarray, format 'SSCB' (height, width, channel, batch)
%
%   Steps: resize -> ImageNet mean/std normalization -> single -> dlarray.
%   Batch is implicit/last in MATLAB - do NOT reshape to add it.

    if nargin < 2 || isempty(inputSize); inputSize = [224 224 3]; end
    hw = inputSize(1:2);

    x = imresize(im2double(img), hw);
    if size(x,3) == 1; x = repmat(x, [1 1 3]); end

    mu = reshape([0.485 0.456 0.406], [1 1 3]);
    sd = reshape([0.229 0.224 0.225], [1 1 3]);
    x  = (x - mu) ./ sd;

    dlx = dlarray(single(x), 'SSCB');
end
