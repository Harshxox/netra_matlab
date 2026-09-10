function scores = qualityScore(img, fovMask)
%QUALITYSCORE  Three interpretable image-quality measures for a fundus image.
%
%   scores = qualityScore(img, fovMask)
%
%   img      - RGB or grayscale fundus image, any type
%   fovMask  - (optional) logical retina mask. If omitted it is estimated.
%
%   scores.focusScore         variance of the Laplacian of the green channel.
%                             Higher = sharper. Blurry images score low.
%   scores.illuminationScore  mean green intensity INSIDE the retina (0-1).
%                             Too low = underexposed, too high = washed out.
%   scores.fovRatio           retina area / total image area (0-1).
%                             Low = retina only partly in frame.
%
%   All measures are computed on the green channel normalized to [0,1] so the
%   thresholds in classifyQuality are comparable across images/cameras.

    green = extractGreenChannel(img);            % double [0,1]

    if nargin < 2 || isempty(fovMask)
        fovMask = green > 0.04;
        fovMask = imfill(fovMask, 'holes');
        fovMask = bwareaopen(fovMask, round(0.01 * numel(fovMask)));
    end
    fovMask = logical(fovMask);
    if ~any(fovMask(:))
        fovMask = true(size(green));
    end

    % The retina's circular rim is a hard black->bright edge. Its Laplacian
    % is huge and swamps the actual in-focus/out-of-focus signal, so we
    % sample focus and illumination from an ERODED interior mask only.
    r = max(3, round(0.05 * min(size(green))));
    inner = imerode(fovMask, strel('disk', r));
    if ~any(inner(:)); inner = fovMask; end

    % --- focus: variance of the Laplacian, mildly contrast-normalized ---
    lap = imfilter(green, fspecial('laplacian', 0.2), 'replicate');
    lapVals = lap(inner);
    mu = mean(green(inner));
    % floor mu so a DARK image can't inflate its focus score (a real blur on a
    % dark image would otherwise look sharp after dividing by a tiny mu^2)
    scores.focusScore = var(lapVals) / max(mu, 0.25)^2;

    % --- illumination: mean brightness of the retina interior -----------
    scores.illuminationScore = mu;

    % --- field of view coverage (uses the FULL mask) -------------------
    scores.fovRatio = nnz(fovMask) / numel(fovMask);
end
