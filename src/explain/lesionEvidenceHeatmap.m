function heatmap = lesionEvidenceHeatmap(masks, sz)
%LESIONEVIDENCEHEATMAP  Smooth "where is the evidence" map from lesion masks.
%
%   heatmap = lesionEvidenceHeatmap(masks, sz)
%
%   masks - struct with logical fields MA/HE/EX/NV (any subset)
%   sz    - [H W] output size (defaults to the mask size)
%   heatmap - double [0,1], high where clinically significant lesions cluster
%
%   This is the explainability visual for the RULES grader (no CNN). Each
%   lesion type is weighted by how much it drives DR severity, the points are
%   spread with a Gaussian, and the result is normalized. It reads like a
%   Grad-CAM but is fully transparent: it literally shows the lesions the
%   grade is based on.

    if nargin < 2 || isempty(sz)
        f = fieldnames(masks);
        sz = size(masks.(f{1}));
    end

    weights = struct('MA',0.5, 'HE',1.0, 'EX',0.7, 'NV',1.5);
    acc = zeros(sz);
    for f = fieldnames(weights)'
        name = f{1};
        if isfield(masks, name) && any(masks.(name)(:))
            m = imresize(double(masks.(name)), sz) > 0.5;
            acc = acc + weights.(name) * double(m);
        end
    end

    if ~any(acc(:))
        heatmap = zeros(sz);
        return
    end

    sigma = 0.03 * max(sz);
    heatmap = imgaussfilt(acc, sigma);

    % Percentile normalization + gamma so a heavily-diseased retina still
    % shows WHERE the worst concentrations are, instead of saturating solid red.
    hi = prctile(heatmap(heatmap > 0), 96);
    if hi <= 0; hi = max(heatmap(:)); end
    heatmap = min(1, heatmap / hi);
    heatmap = heatmap .^ 1.6;
end
