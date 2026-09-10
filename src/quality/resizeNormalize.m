function imgOut = resizeNormalize(img, targetSize)
%RESIZENORMALIZE  Resize to targetSize and return double in [0,1].
%
%   imgOut = resizeNormalize(img, targetSize)
%
%   targetSize - [H W], e.g. [512 512] for the pipeline working image,
%                [224 224] for the classifier.
%
%   Note: this only scales to [0,1]. Model-specific normalization
%   (ImageNet mean/std) happens in the grading/segmentation modules.

    if nargin < 2 || isempty(targetSize)
        targetSize = [512 512];
    end
    imgOut = imresize(img, targetSize);
    imgOut = im2double(imgOut);
    imgOut = min(1, max(0, imgOut));   % guard against imresize ringing past [0,1]
end
