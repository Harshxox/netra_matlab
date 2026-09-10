function enhanced = enhanceImage(img, fovMask)
%ENHANCEIMAGE  Contrast + illumination normalization for borderline images.
%
%   enhanced = enhanceImage(img, fovMask)
%
%   Applies, on the green channel:
%     1. CLAHE (adaptive histogram equalization) for local contrast
%     2. background subtraction (large morphological opening) to flatten
%        uneven illumination
%     3. a light Gaussian to suppress the noise CLAHE amplifies
%   then rebuilds an RGB image with the enhanced green channel.
%
%   enhanced is double in [0,1], same size as img.

    img = im2double(img);
    green = extractGreenChannel(img);

    if nargin < 2 || isempty(fovMask)
        fovMask = green > 0.04;
    end
    fovMask = logical(fovMask);

    % 1. CLAHE ---------------------------------------------------------------
    g = adapthisteq(green, 'ClipLimit', 0.01, 'NumTiles', [8 8]);

    % 2. flatten illumination: estimate background with a big opening -------
    bg = imopen(g, strel('disk', 30));
    g  = g - bg + mean(bg(fovMask));
    g  = mat2gray(g);

    % 3. denoise ----------------------------------------------------------
    g = imgaussfilt(g, 0.5);

    % keep the black border black
    g(~fovMask) = 0;

    % --- rebuild RGB ---------------------------------------------------
    if size(img, 3) == 3
        enhanced = img;
        enhanced(:, :, 2) = g;
    else
        enhanced = g;
    end
    enhanced = min(1, max(0, enhanced));
end
