function out = buildEvidenceView(img, heatmap, masks)
%BUILDEVIDENCEVIEW  Heatmap + lesion markers on the fundus - the one image an
%                   ophthalmologist checks to agree/override in <30s.
%
%   out = buildEvidenceView(img, heatmap, masks)
%
%   Stays legible whether there are 3 lesions or 300:
%     - microaneurysms  -> small filled dots (they can number in the hundreds)
%     - hemorrhages      -> thin outlines
%     - exudates         -> thin outlines
%   Heatmap is kept subtle so the fundus detail shows through.

    out = overlayHeatmap(img, heatmap, 0.30, 0.28);
    [H, W, ~] = size(out);
    scale = min(H, W) / 512;

    % --- microaneurysms: dots at centroids -----------------------------
    if isfield(masks,'MA') && any(masks.MA(:))
        cc = bwconncomp(masks.MA);
        ctr = regionprops(cc,'Centroid');
        dot = false(H, W);
        for k = 1:numel(ctr)
            x = round(ctr(k).Centroid(1)); y = round(ctr(k).Centroid(2));
            if x>1 && x<W && y>1 && y<H; dot(y, x) = true; end
        end
        dot = imdilate(dot, strel('disk', max(1, round(2*scale))));
        out = stamp(out, dot, [255 45 45]);
    end

    % --- hemorrhages + exudates: thin outlines -----------------------
    for spec = {{'HE',[60 130 255]}, {'EX',[255 220 0]}}
        name = spec{1}{1}; col = spec{1}{2};
        if isfield(masks,name) && any(masks.(name)(:))
            edge = bwperim(masks.(name));
            out = stamp(out, edge, col);
        end
    end
end

% ----------------------------------------------------------------------
function im = stamp(im, mask, rgb)
    for c = 1:3
        ch = im(:,:,c);
        ch(mask) = rgb(c);
        im(:,:,c) = ch;
    end
end
