function kappa = quadraticWeightedKappa(actual, predicted, minR, maxR)
%QUADRATICWEIGHTEDKAPPA  QWK between two integer ratings (the APTOS metric).
%
%   kappa = quadraticWeightedKappa(actual, predicted)
%   kappa = quadraticWeightedKappa(actual, predicted, 0, 4)
%
%   actual, predicted - vectors of integer grades
%   Returns a value in [-1, 1]; 1 = perfect, 0 = random, <0 = worse than random.
%   Penalizes disagreements by the SQUARE of their distance (grade 0 vs 4 is
%   16x worse than 0 vs 1) - the right metric for ordinal DR grades.

    actual = actual(:); predicted = predicted(:);
    if nargin < 3 || isempty(minR); minR = min([actual; predicted]); end
    if nargin < 4 || isempty(maxR); maxR = max([actual; predicted]); end

    R = maxR - minR + 1;
    a = actual - minR + 1;
    p = predicted - minR + 1;

    O = zeros(R);                                  % observed agreement matrix
    for i = 1:numel(a)
        O(a(i), p(i)) = O(a(i), p(i)) + 1;
    end

    w = (repmat((1:R)',1,R) - repmat(1:R,R,1)).^2 / (R-1)^2;   % quadratic weights

    actHist = sum(O,2);  predHist = sum(O,1);
    E = actHist * predHist / sum(O(:));            % expected by chance

    num = sum(w(:) .* O(:));
    den = sum(w(:) .* E(:));
    if den == 0
        kappa = 1;
    else
        kappa = 1 - num/den;
    end
end
