function block = buildResultBlock(grade, probs, referable, method, notes)
%BUILDRESULTBLOCK  Assemble the `result` block of the data contract.
%
%   block = buildResultBlock(grade, probs, referable, method, notes)
%
%   Field names/types must match docs/data_contract.json:
%     grade             int 0-4
%     gradeLabel        char
%     referable         logical
%     confidence        double 0-1
%     classProbabilities 1x5 double
%   Extras (not in JSON, used by UI/PDF): method, notes

    if nargin < 4; method = 'unknown'; end
    if nargin < 5; notes = {}; end

    probs = probs(:).';
    if numel(probs) < 5; probs(end+1:5) = 0; end
    probs = probs / max(sum(probs), eps);

    block.grade              = double(max(0, min(4, round(grade))));
    block.gradeLabel         = gradeLabel(block.grade);
    block.referable          = logical(referable);
    block.confidence         = double(max(probs));
    block.classProbabilities = probs;
    block.method             = char(method);     % 'onnx' | 'rules'
    block.notes              = notes;
end
