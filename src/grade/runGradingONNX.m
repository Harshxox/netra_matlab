function [grade, probs, logits] = runGradingONNX(net, img, info)
%RUNGRADINGONNX  Forward pass of the imported ResNet-50 DR grader.
%
%   [grade, probs, logits] = runGradingONNX(net, img, info)
%
%   net    - dlnetwork from loadGradingNet
%   img    - RGB fundus, double [0,1]
%   info   - struct from loadGradingNet (.inputSize)
%   grade  - 0-4 (argmax)
%   probs  - 1x5 softmax probabilities
%   logits - 1x5 raw network output
%
%   IMPORTANT: this assumes the ONNX model outputs RAW LOGITS for 5 classes
%   in order [0 1 2 3 4]. If Colab exports a model that already ends in a
%   Softmax layer, set APPLY_SOFTMAX = false below (double softmax flattens
%   the confidence). Confirm with the Colab team.

    APPLY_SOFTMAX = true;

    if nargin < 3 || isempty(info); info.inputSize = [224 224 3]; end

    dlx = preprocessForGrader(img, info.inputSize);
    y   = predict(net, dlx);
    y   = double(extractdata(gather(y)));
    logits = y(:).';                       % row vector

    if numel(logits) ~= 5
        error('runGradingONNX:badOutput', ...
            'Grader returned %d values, expected 5. Check the ONNX model.', numel(logits));
    end

    if APPLY_SOFTMAX
        z = logits - max(logits);
        probs = exp(z) / sum(exp(z));
    else
        probs = logits / sum(logits);
    end

    [~, k] = max(probs);
    grade  = k - 1;
end
