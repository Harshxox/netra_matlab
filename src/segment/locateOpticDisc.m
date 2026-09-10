function [odMask, odCentroid, odRadius] = locateOpticDisc(img, fovMask)
%LOCATEOPTICDISC  Find the optic disc: the bright, roughly circular region
%                 where the vessels converge.
%
%   [odMask, odCentroid, odRadius] = locateOpticDisc(img, fovMask)
%
%   img        - RGB fundus, double [0,1], pipeline working size
%   fovMask    - logical retina mask (same size)
%   odMask     - logical mask of the estimated optic disc
%   odCentroid - [x y] centre, in pixels
%   odRadius   - estimated disc radius, in pixels
%
%   Method (classical, no training): the OD is the brightest sizable blob.
%   Work on the red+green average (OD is bright in both), blur heavily to
%   merge vessels, take the brightest region, keep the largest component.

    if nargin < 2 || isempty(fovMask)
        fovMask = rgb2gray(img) > 0.04;
    end
    fovMask = logical(fovMask);

    r = im2double(img(:,:,1));
    g = im2double(img(:,:,2));
    bright = (r + g) / 2;
    bright(~fovMask) = 0;

    % smooth away vessels so the disc becomes one blob
    sm = imgaussfilt(bright, round(0.02 * min(size(g))) + 1);
    sm(~imerode(fovMask, strel('disk', round(0.03*min(size(g)))+1))) = 0;

    % brightest ~2% of interior pixels
    vals = sm(sm > 0);
    if isempty(vals)
        odMask = false(size(g)); odCentroid = [size(g,2) size(g,1)]/2; odRadius = 0.1*min(size(g));
        return
    end
    thr = prctile(vals, 98);
    bw  = sm >= thr;
    bw  = imclose(bw, strel('disk', round(0.02*min(size(g)))+1));
    bw  = imfill(bw, 'holes');

    cc = bwconncomp(bw);
    if cc.NumObjects == 0
        odMask = false(size(g)); odCentroid = [size(g,2) size(g,1)]/2; odRadius = 0.1*min(size(g));
        return
    end
    numPix = cellfun(@numel, cc.PixelIdxList);
    [~, k] = max(numPix);
    odMask = false(size(g));
    odMask(cc.PixelIdxList{k}) = true;

    p = regionprops(odMask, 'Centroid', 'Area', 'MajorAxisLength');
    odCentroid = p(1).Centroid;
    odRadius   = max(p(1).MajorAxisLength/2, sqrt(p(1).Area/pi));

    % regularize to a disc of that radius (cleaner for display + exclusion)
    [xx, yy] = meshgrid(1:size(g,2), 1:size(g,1));
    odMask = (xx - odCentroid(1)).^2 + (yy - odCentroid(2)).^2 <= (1.1*odRadius)^2;
    odMask = odMask & fovMask;
end
