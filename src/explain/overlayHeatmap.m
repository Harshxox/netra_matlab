function out = overlayHeatmap(img, heatmap, alpha, lowClip)
%OVERLAYHEATMAP  Alpha-blend a [0,1] heatmap onto an image, only where it matters.
%
%   out = overlayHeatmap(img, heatmap, alpha, lowClip)
%
%   img     - RGB, double [0,1] or uint8
%   heatmap - double [0,1], same H×W as img (resized if not)
%   alpha   - peak blend strength, default 0.55
%   lowClip - heatmap values below this contribute NO overlay, so a healthy
%             (or unaffected) retina stays fully visible. Default 0.22.
%   out     - uint8 RGB
%
%   Colormap runs transparent -> yellow -> orange -> red (a "hot" ramp), which
%   reads as clinical severity better than jet's blue-green low end.

    if nargin < 3 || isempty(alpha);   alpha   = 0.55; end
    if nargin < 4 || isempty(lowClip); lowClip = 0.22; end

    base = im2double(img);
    if size(base,3) == 1; base = repmat(base,[1 1 3]); end
    if ~isequal(size(heatmap), size(base,[1 2]))
        heatmap = imresize(heatmap, size(base,[1 2]));
    end
    heatmap = max(0, min(1, heatmap));

    % rescale so [lowClip,1] -> [0,1]; everything below lowClip -> 0
    h = max(0, (heatmap - lowClip) / (1 - lowClip));

    % hot-style colormap: black(0) -> red -> orange -> yellow -> white
    cmap = hot(256);
    idx  = max(1, min(256, round(h * 255) + 1));
    rgbHeat = reshape(cmap(idx(:), :), [size(h) 3]);

    a = repmat(alpha * h, [1 1 3]);       % zero alpha where h==0
    out = base .* (1 - a) + rgbHeat .* a;
    out = im2uint8(max(0, min(1, out)));
end
