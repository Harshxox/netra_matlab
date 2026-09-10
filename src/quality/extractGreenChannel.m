function green = extractGreenChannel(img)
%EXTRACTGREENCHANNEL  Return the green channel as double in [0,1].
%
%   green = extractGreenChannel(img)
%
%   The green channel has the best contrast between retinal lesions and the
%   background, so almost every downstream step works on it. Handles RGB or
%   already-single-channel input, uint8 or double.

    if size(img, 3) == 3
        green = img(:, :, 2);
    else
        green = img;
    end
    green = im2double(green);   % uint8 0-255 -> double 0-1 ; double passes through
end
