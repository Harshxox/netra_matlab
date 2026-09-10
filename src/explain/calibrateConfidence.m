function [probs, T] = calibrateConfidence(logits)
%CALIBRATECONFIDENCE  Temperature-scale raw logits into calibrated probabilities.
%
%   [probs, T] = calibrateConfidence(logits)
%
%   logits - 1xK raw network output (grading model)
%   probs  - 1xK calibrated softmax probabilities
%   T      - the temperature used
%
%   T comes from models/temperature.mat (field `temperature`), produced by the
%   Colab team on the validation set. If the file is missing, T = 1 (a plain
%   softmax) and a one-time warning is issued. Only meaningful for the ONNX
%   grading path - the rules grader has no logits.

    persistent Tcached
    if isempty(Tcached)
        p = fullfile('models','temperature.mat');
        if isfile(p)
            d = load(p);
            if isfield(d,'temperature'); Tcached = double(d.temperature);
            else; Tcached = 1; end
        else
            Tcached = 1;
            warning('calibrateConfidence:noFile', ...
                'models/temperature.mat not found - using T=1 (uncalibrated).');
        end
    end
    T = Tcached;

    z = logits(:).' / T;
    z = z - max(z);
    probs = exp(z) / sum(exp(z));
end
