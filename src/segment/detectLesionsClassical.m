function masks = detectLesionsClassical(img, fovMask, odMask, vesselMask, params)
%DETECTLESIONSCLASSICAL  Find DR lesions with morphology only (no trained model).
%
%   masks = detectLesionsClassical(img, fovMask, odMask, vesselMask, params)
%
%   Uses a FIXED absolute local-contrast threshold so a healthy retina reads
%   near-zero. Conservative by design (high precision, lower recall) - a clean,
%   credible overlay matters more for the demo than catching every faint spot.
%   The trained U-Nets (runSegmentationONNX) replace this when available.
%
%   params (optional):
%     .darkContrast   default 0.052  darker-than-local for a dark lesion ([0,1])
%     .brightContrast default 0.085  brighter-than-local for an exudate
%     .maxMA_area     default 30     MA vs HE size split (px @ 512)
%
%   Returns logical masks the size of img(:,:,1): masks.MA/.HE/.EX/.NV

    sz = [size(img,1) size(img,2)];
    if nargin < 2 || isempty(fovMask);    fovMask = rgb2gray(img) > 0.04; end
    if nargin < 3 || isempty(odMask);     odMask = false(sz);             end
    if nargin < 4 || isempty(vesselMask); vesselMask = false(sz);         end
    if nargin < 5; params = struct(); end
    p.darkContrast = 0.060; p.brightContrast = 0.085; p.maxMA_area = 30;
    for f = fieldnames(params)'; p.(f{1}) = params.(f{1}); end

    fovMask = logical(fovMask);
    scale = min(sz) / 512;
    interior  = imerode(fovMask, strel('disk', round(14*scale)));
    vesselDil = imdilate(vesselMask, strel('disk', round(6*scale)));
    odDil     = imdilate(odMask,     strel('disk', round(14*scale)));

    g = im2double(img(:,:,2));
    g = imgaussfilt(g, max(0.6, 0.6*scale));           % noise only, keep lesions

    bgDark   = imclose(g, strel('disk', round(12*scale)));   % fills dark spots
    bgBright = imopen(g,  strel('disk', round(12*scale)));    % removes bright spots
    darkDiff   = bgDark - g;
    brightDiff = g - bgBright;

    % ================= DARK LESIONS (MA + HE) =========================
    darkBW = (darkDiff > p.darkContrast) & interior & ~vesselDil;
    darkBW = bwareaopen(darkBW, round(4*scale^2));
    darkBW = imopen(darkBW, strel('disk', 1));

    cc = bwconncomp(darkBW);
    st = regionprops(cc, 'Area','Solidity','Eccentricity','MajorAxisLength','MinorAxisLength');
    maKeep = false(cc.NumObjects,1);
    heKeep = false(cc.NumObjects,1);
    for i = 1:cc.NumObjects
        a  = st(i).Area;
        ar = st(i).MajorAxisLength / max(st(i).MinorAxisLength,1);
        round_ = st(i).Solidity > 0.88 && st(i).Eccentricity < 0.75 && ar < 2.2;
        blobby = st(i).Solidity > 0.60 && ar < 3.0;
        if     a >= 4*scale^2 && a <= p.maxMA_area*scale^2 && round_
            maKeep(i) = true;
        elseif a > p.maxMA_area*scale^2 && a <= 2200*scale^2 && blobby
            heKeep(i) = true;
        end
    end
    masks.MA = compMask(cc, maKeep, sz);
    masks.HE = compMask(cc, heKeep, sz);

    % ================= BRIGHT LESIONS (EX) ============================
    exBW = (brightDiff > p.brightContrast) & interior & ~vesselDil & ~odDil;
    exBW = bwareaopen(exBW, round(6*scale^2));
    exBW = imopen(exBW, strel('disk', 1));

    ccE = bwconncomp(exBW);
    stE = regionprops(ccE, 'Area','MajorAxisLength','MinorAxisLength');
    keepE = false(ccE.NumObjects,1);
    for i = 1:ccE.NumObjects
        ar = stE(i).MajorAxisLength / max(stE(i).MinorAxisLength,1);
        keepE(i) = ar < 3.0 && stE(i).Area < 4000*scale^2;
    end
    masks.EX = compMask(ccE, keepE, sz);

    % ================= NV - not feasible classically ==================
    masks.NV = false(sz);
end

% ----------------------------------------------------------------------
function m = compMask(cc, keep, sz)
    m = false(sz);
    for i = find(keep)'
        m(cc.PixelIdxList{i}) = true;
    end
end
