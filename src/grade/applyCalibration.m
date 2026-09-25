function [pRefCal, conf, info] = applyCalibration(pRefRaw)
%APPLYCALIBRATION  Map a raw referable-risk to a calibrated one + a confidence.
%
%   [pRefCal, conf, info] = applyCalibration(pRefRaw)
%
%   pRefRaw  - raw P(grade >= 2) from the grader
%   pRefCal  - calibrated P(grade >= 2)  (Platt / temperature, from models/calibration.mat)
%   conf     - calibrated confidence in the referable / not-referable decision
%              = max(pRefCal, 1 - pRefCal)
%   info     - struct: .available, .method, .ece (post-calibration), .n
%
%   Falls back to identity (pRefCal = pRefRaw) with info.available = false when
%   models/calibration.mat is missing - run buildCalibration to create it.

    persistent cal
    if isempty(cal)
        p = fullfile('models','calibration.mat');
        if isfile(p)
            cal = load(p);
        else
            cal = struct('available', false);
        end
    end

    pRefRaw = min(max(pRefRaw, 1e-4), 1 - 1e-4);

    if isfield(cal,'A')
        z = log(pRefRaw / (1 - pRefRaw));
        pRefCal = 1 / (1 + exp(-(cal.A * z + cal.B)));
        info = struct('available', true, 'method', cal.method, ...
                      'ece', cal.eceCal, 'n', cal.n);
    elseif isfield(cal,'temperature')
        z = log(pRefRaw / (1 - pRefRaw)) / cal.temperature;
        pRefCal = 1 / (1 + exp(-z));
        info = struct('available', true, 'method', 'temperature', 'ece', NaN, 'n', NaN);
    else
        pRefCal = pRefRaw;
        info = struct('available', false, 'method', 'none', 'ece', NaN, 'n', NaN);
    end

    conf = max(pRefCal, 1 - pRefCal);
end
