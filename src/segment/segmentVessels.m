function vesselMask = segmentVessels(img, fovMask)
%SEGMENTVESSELS  Binary blood-vessel mask via multiscale vesselness + cleanup.
%
%   vesselMask = segmentVessels(img, fovMask)
%
%   Vessels are dark elongated structures on the green channel. We enhance
%   contrast, run a Frangi-style vesselness filter at several widths, then
%   threshold and clean up. No training needed. The mask is intentionally a
%   little generous so downstream code can subtract vessels reliably.

    if nargin < 2 || isempty(fovMask)
        fovMask = rgb2gray(img) > 0.04;
    end
    fovMask = logical(fovMask);
    sz = [size(img,1) size(img,2)];
    scale = min(sz) / 512;

    g = im2double(img(:,:,2));

    % background-flatten so big illumination gradients don't fool the filter
    bg = imopen(g, strel('disk', round(40*scale)));
    gf = g - bg;
    gf = mat2gray(gf);
    gf = adapthisteq(gf, 'ClipLimit', 0.01, 'NumTiles',[8 8]);

    % vesselness at a range of widths (thin capillaries -> major arcades)
    widths = max(1, round([1 2 3 4 6 8] * scale));
    V = fibermetric(gf, unique(widths), 'ObjectPolarity','dark', ...
                    'StructureSensitivity', 0.5*std(gf(fovMask)));
    V = mat2gray(V);

    vesselMask = imbinarize(V, max(0.08, graythresh(V(fovMask))*0.6));
    vesselMask = bwareaopen(vesselMask, round(60*scale^2));
    vesselMask = imclose(vesselMask, strel('disk', 1));

    % keep only structures connected into the vessel tree (drop blobs)
    vesselMask = bwpropfilt(vesselMask, 'Eccentricity', [0.6 1]);

    vesselMask = vesselMask & imerode(fovMask, strel('disk', round(4*scale)));
end
