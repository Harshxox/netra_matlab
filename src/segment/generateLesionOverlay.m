function overlay = generateLesionOverlay(img, masks, alpha)
%GENERATELESIONOVERLAY  Colour-code lesion masks on top of the fundus image.
%
%   overlay = generateLesionOverlay(img, masks, alpha)
%
%   MA = red, HE = blue, EX = yellow, NV = magenta.
%   img    - RGB fundus, double [0,1] or uint8
%   masks  - struct with logical fields MA/HE/EX/NV
%   alpha  - blend strength (default 0.5)
%   overlay- uint8 RGB image
%
%   Small lesions are dilated slightly so they are visible at a glance.

    if nargin < 3 || isempty(alpha); alpha = 0.5; end
    base = im2double(img);
    if size(base,3) == 1; base = repmat(base,[1 1 3]); end

    colors = struct('MA',[1 0 0], 'HE',[0 0.35 1], 'EX',[1 0.9 0], 'NV',[1 0 1]);
    grow   = struct('MA',1,       'HE',1,          'EX',0,         'NV',1);

    for f = fieldnames(colors)'
        name = f{1};
        if ~isfield(masks, name) || ~any(masks.(name)(:)); continue; end
        m = masks.(name);
        if grow.(name) > 0
            m = imdilate(m, strel('disk', grow.(name)));
        end
        m3 = repmat(m, [1 1 3]);
        col = reshape(colors.(name), [1 1 3]);
        colLayer = repmat(col, [size(base,1) size(base,2) 1]);
        base = base .* (1 - alpha*m3) + colLayer .* (alpha*m3);
    end

    overlay = im2uint8(min(1, max(0, base)));
end
