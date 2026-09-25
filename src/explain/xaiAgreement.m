function [agree, score, label] = xaiAgreement(heatmap, masks, fovMask)
%XAIAGREEMENT  Does the attention map focus on the detected lesions?
%
%   [agree, score, label] = xaiAgreement(heatmap, masks, fovMask)
%
%   A sanity check on the explanation: the fraction of attention "mass" that
%   falls on (or near) a detected lesion. If the model is looking at the same
%   things the lesion detector found, the explanation is trustworthy.
%
%   score  - 0..1, attention mass on lesion regions / total attention mass
%   agree  - true when score >= 0.5
%   label  - 'aligned' | 'partial' | 'weak'

    if nargin < 3 || isempty(fovMask); fovMask = heatmap > 0; end
    sz = size(heatmap);

    les = false(sz);
    for f = ["MA","HE","EX","NV"]
        if isfield(masks, f) && any(masks.(f)(:))
            les = les | imresize(masks.(f), sz, 'nearest');
        end
    end
    if ~any(les(:))
        agree = true; score = 1; label = 'no lesions - low attention expected';
        return
    end

    r = max(3, round(0.03 * max(sz)));
    lesNear = imdilate(les, strel('disk', r));

    h = heatmap; h(~logical(fovMask)) = 0;
    total = sum(h(:));
    if total <= 0
        agree = false; score = 0; label = 'weak'; return
    end
    score = sum(h(lesNear)) / total;

    agree = score >= 0.5;
    if     score >= 0.6; label = 'aligned';
    elseif score >= 0.35; label = 'partial';
    else;                 label = 'weak';
    end
end
