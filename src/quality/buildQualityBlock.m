function block = buildQualityBlock(scores, status, wasEnhanced)
%BUILDQUALITYBLOCK  Assemble the `quality` block of the data contract.
%
%   block = buildQualityBlock(scores, status, wasEnhanced)
%
%   Field names and types must match docs/data_contract.json exactly:
%     status            char   'gradable' | 'borderline' | 'ungradable'
%     focusScore        double
%     illuminationScore double
%     fovRatio          double
%     enhanced          logical

    block.status            = char(status);
    block.focusScore        = double(scores.focusScore);
    block.illuminationScore = double(scores.illuminationScore);
    block.fovRatio          = double(scores.fovRatio);
    block.enhanced          = logical(wasEnhanced);
end
