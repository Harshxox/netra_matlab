function [grade, probs, notes] = gradeFromRules(lesions)
%GRADEFROMRULES  Estimate DR grade 0-4 from lesion counts (ICDR-inspired).
%
%   [grade, probs, notes] = gradeFromRules(lesions)
%
%   lesions - struct from runSegmentationPipeline with fields:
%             maCount, heCount, exudateAreaPct, nvPresent, maByQuadrant
%
%   grade   - integer 0-4
%   probs   - 1x5 pseudo-probability vector (soft, for the confidence bar)
%   notes   - cellstr: the rule(s) that fired, for the "why this grade" panel
%
%   This is the International Clinical DR severity scale, simplified:
%     4 Proliferative : neovascularization present
%     3 Severe        : "4-2-1" - >20 hemorrhages in 4 quadrants, OR
%                       venous beading in 2, OR IRMA in 1  (we approximate
%                       with heavy hemorrhage/MA load across quadrants)
%     2 Moderate      : more than just microaneurysms - any hemorrhage or
%                       exudate, or many MAs
%     1 Mild          : microaneurysms only
%     0 No DR         : essentially nothing
%
%   NOTE: this is a transparent classical baseline. The trained ResNet-50
%   grader (dr_grader.onnx) replaces it when available - same output contract.

    % The classical detector has a false-positive floor (~5-8 MA, ~2-3 HE on a
    % healthy retina). Subtract it so grade 0/1 images are not over-referred.
    % Applied ONLY for the classical detector - trained-model / raw counts pass
    % through untouched (lesions.method ~= 'classical').
    rawMA = fieldOr(lesions,'maCount',0);
    rawHE = fieldOr(lesions,'heCount',0);

    isClassical = isfield(lesions,'method') && strcmpi(lesions.method,'classical');
    MA_FLOOR = 8*isClassical;   HE_FLOOR = 3*isClassical;
    ma = max(0, rawMA - MA_FLOOR);
    he = max(0, rawHE - HE_FLOOR);
    ex = fieldOr(lesions,'exudateAreaPct',0);
    HE_MOD = 1 + 2*isClassical;      % moderate: he_eff >= 1 (raw) or >= 3 (classical)
    MA_MOD = 15 + 2*isClassical;
    HE_SEV = 25 + 15*isClassical;    % severe:   he_eff >= 25 (raw) or >= 40 (classical)
    MA_SEV = 60 + 25*isClassical;
    nv = logical(fieldOr(lesions,'nvPresent',false));
    q  = fieldOr(lesions,'maByQuadrant',[0 0 0 0]);
    quadrantsWithManyMA = nnz(q >= 10);

    notes = {};

    if nv
        grade = 4;
        notes{end+1} = 'Neovascularization detected -> Proliferative DR';
    elseif (he >= HE_MOD && quadrantsWithManyMA >= 3) || he >= HE_SEV || ma >= MA_SEV
        grade = 3;
        notes{end+1} = sprintf('Heavy lesion load (MA=%d, HE=%d across %d quadrants) -> Severe', ...
                               rawMA, rawHE, quadrantsWithManyMA);
    elseif he >= HE_MOD || ex >= 0.6 || ma >= MA_MOD
        grade = 2;
        r = {};
        if he >= HE_MOD; r{end+1} = sprintf('%d hemorrhages', rawHE); end
        if ex >= 0.6;    r{end+1} = sprintf('exudates (%.2f%% area)', ex); end
        if ma >= MA_MOD; r{end+1} = sprintf('%d microaneurysms', rawMA); end
        notes{end+1} = ['More than microaneurysms alone: ' strjoin(r, ', ') ' -> Moderate'];
    elseif ma >= 1 || rawMA >= 3
        grade = 1;
        notes{end+1} = sprintf('%d microaneurysm(s), no significant hemorrhage -> Mild', rawMA);
    else
        grade = 0;
        notes{end+1} = 'No significant lesions detected -> No DR';
    end

    % --- soft probability vector centred on the grade -------------------
    d = abs((0:4) - grade);
    probs = exp(-1.1 * d);
    probs = probs / sum(probs);
end

function v = fieldOr(s, f, d)
    if isstruct(s) && isfield(s,f) && ~isempty(s.(f)); v = s.(f); else; v = d; end
end
