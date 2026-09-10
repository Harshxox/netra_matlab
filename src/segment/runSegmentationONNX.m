function masks = runSegmentationONNX(img, fovMask) %#ok<INUSD>
%RUNSEGMENTATIONONNX  Trained U-Net lesion segmentation - STUB.
%
%   Fill this in ONLY if the Colab team delivers:
%     models/ma_unet.onnx  he_unet.onnx  ex_unet.onnx  nv_unet.onnx  vessel_unet.onnx
%
%   Contract: return the same struct as detectLesionsClassical:
%     masks.MA, masks.HE, masks.EX, masks.NV  (logical, size of img(:,:,1))
%
%   Skeleton (see docs/matlab_guide.md and phase_m3.md, with the fixes noted):
%     persistent nets
%     if isempty(nets)
%         nets.ma = importNetworkFromONNX('models/ma_unet.onnx');
%         ... etc ...
%     end
%     green = im2single(imresize(img(:,:,2), [512 512]));
%     dlx   = dlarray(green, 'SSCB');                    % batch is implicit/last
%     pr    = extractdata(predict(nets.ma, dlx));
%     maskS = 1./(1+exp(-pr)) > 0.5;                     % if the net outputs logits
%     masks.MA = imresize(maskS, [size(img,1) size(img,2)], 'nearest');

    error('runSegmentationONNX:notImplemented', ...
        ['ONNX segmentation not wired up yet. Use the classical path ' ...
         '(opts.useONNX = false) until the U-Net ONNX files arrive.']);
end
