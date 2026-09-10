function [referable, pReferable, thr] = isReferable(probs, grade)
%ISREFERABLE  Decide referable DR (grade >= 2) from the probability vector.
%
%   [referable, pReferable, thr] = isReferable(probs, grade)
%
%   probs - 1x5 probabilities for grades 0..4
%   grade - (optional) the argmax grade, used as a fallback
%
%   Uses models/referable_threshold.txt (a single float from Colab C-2) if
%   present, else a default of 0.5. P(referable) = P(grade>=2) = sum(probs(3:5)).

    persistent cachedThr
    if isempty(cachedThr)
        p = fullfile('models','referable_threshold.txt');
        if isfile(p)
            fid = fopen(p,'r'); cachedThr = fscanf(fid,'%f',1); fclose(fid);
        else
            cachedThr = 0.5;
        end
    end
    thr = cachedThr;

    probs = probs(:).';
    if numel(probs) >= 5
        pReferable = sum(probs(3:5));
    elseif nargin >= 2
        pReferable = double(grade >= 2);
    else
        pReferable = 0;
    end

    referable = pReferable >= thr;
end
