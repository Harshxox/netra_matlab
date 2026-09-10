function counts = quantifyLesions(masks, fovMask)
%QUANTIFYLESIONS  Turn lesion masks into the numbers the grader/UI need.
%
%   counts = quantifyLesions(masks, fovMask)
%
%   counts.maCount         number of microaneurysm blobs
%   counts.heCount         number of hemorrhage blobs
%   counts.exudateAreaPct  exudate pixels as % of the retina area
%   counts.nvPresent       logical - any neovascularization pixels
%   counts.maByQuadrant    1x4 count [supN supT infT infN] style split
%                          (used by the 4-2-1 severe-DR rule)

    fovArea = max(nnz(fovMask), 1);

    maCC = bwconncomp(masks.MA);
    heCC = bwconncomp(masks.HE);
    counts.maCount = maCC.NumObjects;
    counts.heCount = heCC.NumObjects;

    counts.exudateAreaPct = 100 * nnz(masks.EX) / fovArea;
    counts.nvPresent = any(masks.NV(:));

    % --- microaneurysms per quadrant (about the image centre) ----------
    sz = size(masks.MA);
    cx = sz(2)/2; cy = sz(1)/2;
    q = zeros(1,4);
    if maCC.NumObjects > 0
        p = regionprops(maCC, 'Centroid');
        for i = 1:numel(p)
            x = p(i).Centroid(1) - cx;
            y = p(i).Centroid(2) - cy;
            if     x>=0 && y<0;  q(1) = q(1)+1;   % upper-right
            elseif x<0  && y<0;  q(2) = q(2)+1;   % upper-left
            elseif x<0  && y>=0; q(3) = q(3)+1;   % lower-left
            else                 q(4) = q(4)+1;   % lower-right
            end
        end
    end
    counts.maByQuadrant = q;
end
