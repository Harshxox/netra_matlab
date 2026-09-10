function [status, reasons] = classifyQuality(scores, thr)
%CLASSIFYQUALITY  Map quality scores to 'gradable' / 'borderline' / 'ungradable'.
%
%   [status, reasons] = classifyQuality(scores)
%   [status, reasons] = classifyQuality(scores, thr)   % custom thresholds
%
%   scores   - struct from qualityScore()
%   thr      - (optional) struct overriding any of the default thresholds
%   status   - 'gradable' | 'borderline' | 'ungradable'
%   reasons  - cellstr explaining borderline/ungradable calls (for the UI/PDF)
%
%   IMPORTANT: the default thresholds below are STARTING GUESSES for the green
%   channel scaled to [0,1]. Tune them once you have real images:
%       >> tuneQualityThresholds('data/samples')
%   and move each cut to where good and bad images actually separate.

    % Tuned 2026-09-09 on 12 real APTOS images + degraded variants.
    % Real images: focus 3.1e-3..1.9e-2, illum 0.24..0.37, fovRatio 0.74..0.79.
    % blur sigma>=4 -> focus ~0 ; blur sigma 2 -> ~4e-4 ; dark 0.3x -> illum 0.11.
    d.FOCUS_GOOD  = 1.5e-3;  % >= this  -> sharp enough to grade
    d.FOCUS_MIN   = 2.0e-4;  % <  this  -> too blurry, ungradable
    d.ILLUM_LOW   = 0.15;    % mean green below this -> borderline (too dark)
    d.ILLUM_HIGH  = 0.70;    % mean green above this -> borderline (bright)
    d.ILLUM_FAIL_LO = 0.08;  % below this -> ungradable
    d.ILLUM_FAIL_HI = 0.85;  % above this -> ungradable
    d.FOV_MIN     = 0.55;    % retina must fill at least this fraction of frame

    if nargin >= 2 && ~isempty(thr)
        for f = fieldnames(thr)'
            d.(f{1}) = thr.(f{1});
        end
    end

    reasons = {};

    focusHardFail = scores.focusScore < d.FOCUS_MIN;
    focusSoft     = scores.focusScore < d.FOCUS_GOOD;
    illumHardFail = scores.illuminationScore < d.ILLUM_FAIL_LO || ...
                    scores.illuminationScore > d.ILLUM_FAIL_HI;
    illumBad      = scores.illuminationScore < d.ILLUM_LOW || ...
                    scores.illuminationScore > d.ILLUM_HIGH;
    fovBad        = scores.fovRatio < d.FOV_MIN;

    if focusHardFail;         reasons{end+1} = 'Image too blurry';            end
    if scores.illuminationScore < d.ILLUM_LOW
        reasons{end+1} = 'Image too dark';
    elseif scores.illuminationScore > d.ILLUM_HIGH
        reasons{end+1} = 'Image over-exposed';
    end
    if fovBad;                reasons{end+1} = 'Retina not fully in frame';   end

    if focusHardFail || fovBad || illumHardFail
        status = 'ungradable';
    elseif focusSoft || illumBad
        status = 'borderline';
        if isempty(reasons); reasons{end+1} = 'Marginal sharpness/illumination'; end
    else
        status = 'gradable';
    end
end
