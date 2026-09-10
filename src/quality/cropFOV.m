function [croppedImg, fovMask, bbox] = cropFOV(img)
%CROPFOV  Detect the circular retina (field of view) and crop the black border.
%
%   [croppedImg, fovMask, bbox] = cropFOV(img)
%
%   img         - RGB or grayscale fundus image (uint8 or double)
%   croppedImg  - img cropped to the retina's bounding box, then padded to a
%                 square (black padding) so a later imresize keeps aspect ratio
%   fovMask     - logical mask, same size as croppedImg, true inside the retina
%   bbox        - [x y w h] bounding box used, in original image coordinates
%
%   Method: the retina is much brighter than the black border. Threshold,
%   keep the largest blob, fill holes, take its bounding box.

    % --- work on a normalized single channel -----------------------------
    if size(img, 3) == 3
        gray = im2double(rgb2gray(img));
    else
        gray = im2double(img);
    end

    % --- threshold the black border -------------------------------------
    % ~4% of full scale is comfortably above sensor noise but below retina
    bw = gray > 0.04;
    bw = imfill(bw, 'holes');
    bw = bwareaopen(bw, round(0.01 * numel(bw)));   % drop specks < 1% of image

    props = regionprops(bw, 'BoundingBox', 'Area', 'Image');
    if isempty(props)
        % nothing found - return the image unchanged with a full mask
        croppedImg = img;
        fovMask    = true(size(gray));
        bbox       = [1 1 size(gray,2) size(gray,1)];
        return
    end

    % --- largest blob = the retina -------------------------------------
    [~, k] = max([props.Area]);
    bb = props(k).BoundingBox;                       % [x y w h], fractional
    x = max(1, floor(bb(1)));
    y = max(1, floor(bb(2)));
    w = min(size(gray,2) - x + 1, ceil(bb(3)));
    h = min(size(gray,1) - y + 1, ceil(bb(4)));
    bbox = [x y w h];

    cropped = img(y:y+h-1, x:x+w-1, :);
    maskCrop = bw(y:y+h-1, x:x+w-1);

    % --- pad to square so aspect ratio survives a later resize ----------
    side = max(h, w);
    padY = side - h;  padX = side - w;
    top = floor(padY/2);  bot = padY - top;
    lft = floor(padX/2);  rgt = padX - lft;

    croppedImg = padarray(cropped,  [top lft], 0, 'pre');
    croppedImg = padarray(croppedImg,[bot rgt], 0, 'post');

    fovMask = padarray(maskCrop,  [top lft], false, 'pre');
    fovMask = padarray(fovMask,   [bot rgt], false, 'post');
end
