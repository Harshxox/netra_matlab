function [heatmap, hotspots] = decisionInfluenceMap(masks, lesionsBlock, fovMask, gridN)
%DECISIONINFLUENCEMAP  Model-agnostic occlusion-sensitivity attention map for the
%                      classical grader (a Grad-CAM analogue that needs no CNN).
%
%   [heatmap, hotspots] = decisionInfluenceMap(masks, lesionsBlock, fovMask, gridN)
%
%   Grids the retina into gridN x gridN cells. For each cell it removes every
%   lesion pixel inside that cell, re-quantifies the lesions and re-grades with
%   gradeFromRules, and records how much the referable-risk P(grade>=2) drops.
%   High drop = that region is driving the referral decision.
%
%   heatmap  - double [0,1], same size as fovMask, smoothed influence map
%   hotspots - logical mask of the highest-influence regions
%
%   ~gridN^2 rule evaluations (milliseconds) - no image re-processing.

    if nargin < 4 || isempty(gridN); gridN = 12; end
    sz = size(fovMask);
    fovMask = logical(fovMask);

    baseCounts = quantifyLesions(masks, fovMask);
    [~, baseProbs] = gradeFromRules(mergeCounts(lesionsBlock, baseCounts));
    baseRef = sum(baseProbs(3:5));

    infl = zeros(gridN);
    ys = round(linspace(1, sz(1)+1, gridN+1));
    xs = round(linspace(1, sz(2)+1, gridN+1));

    for gy = 1:gridN
        for gx = 1:gridN
            r = ys(gy):ys(gy+1)-1;  c = xs(gx):xs(gx+1)-1;
            if ~any(fovMask(r, c), 'all'); continue; end

            m = maskOut(masks, r, c);
            cnt = quantifyLesions(m, fovMask);
            [~, p] = gradeFromRules(mergeCounts(lesionsBlock, cnt));
            infl(gy, gx) = max(0, baseRef - sum(p(3:5)));   % drop in referable risk
        end
    end

    if max(infl(:)) > 0
        infl = infl / max(infl(:));
    end

    heatmap = imresize(infl, sz, 'bilinear');
    heatmap = imgaussfilt(heatmap, 0.035 * max(sz));
    heatmap(~fovMask) = 0;
    if max(heatmap(:)) > 0; heatmap = heatmap / max(heatmap(:)); end

    hotspots = heatmap > 0.55;
end

% ----------------------------------------------------------------------
function m = maskOut(masks, r, c)
    m = masks;
    for f = ["MA","HE","EX","NV"]
        if isfield(m, f)
            k = m.(f); k(r, c) = false; m.(f) = k;
        end
    end
end

function b = mergeCounts(lesionsBlock, counts)
    b = lesionsBlock;
    b.maCount        = counts.maCount;
    b.heCount        = counts.heCount;
    b.exudateAreaPct = counts.exudateAreaPct;
    b.nvPresent      = counts.nvPresent;
    if isfield(counts,'maByQuadrant'); b.maByQuadrant = counts.maByQuadrant; end
end
