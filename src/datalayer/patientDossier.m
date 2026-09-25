function d = patientDossier(patientId, patientDbPath, screenDbPath)
%PATIENTDOSSIER  Full record for one patient (profile + every screening).
%
%   d = patientDossier('PT-20260910-0001')
%
%   d.profile     - the registry row (struct)
%   d.history     - trend string + prior grades (from getHistory)
%   d.screenings  - struct array, newest first, one per screening with
%                   grade / verdict / confidence / lesion summary / report path

    if nargin < 2 || isempty(patientDbPath); patientDbPath = 'netra_patients.mat'; end
    if nargin < 3 || isempty(screenDbPath);  screenDbPath  = 'netra_db.mat';       end

    d.profile = getPatient(patientId, patientDbPath);
    [d.history, ~] = getHistory(patientId, screenDbPath);

    S = initDB(screenDbPath);
    rows = S(S.patientId == string(patientId), :);
    rows = sortrows(rows, 'date', 'descend');

    sc = struct('date',{},'grade',{},'gradeLabel',{},'referable',{},'confidence',{}, ...
        'qualityStatus',{},'routing',{},'reviewStatus',{},'finalGrade',{}, ...
        'reviewNotes',{},'gradingMethod',{},'reportPath',{});
    for i = 1:height(rows)
        r = rows(i,:);
        sc(i).date          = char(string(r.date));
        sc(i).grade         = numOrEmpty(r.grade);
        sc(i).gradeLabel    = char(r.gradeLabel);
        sc(i).referable     = logical(r.referable);
        sc(i).confidence    = numOrEmpty(r.confidence);
        sc(i).qualityStatus = char(r.qualityStatus);
        sc(i).routing       = char(r.routing);
        sc(i).reviewStatus  = char(r.reviewStatus);
        sc(i).finalGrade    = numOrEmpty(r.finalGrade);
        sc(i).reviewNotes   = char(r.reviewNotes);
        sc(i).gradingMethod = char(r.gradingMethod);
        sc(i).reportPath    = char(r.reportPath);
    end
    d.screenings = num2cell(sc);   % cell array -> always a JSON array
end

function v = numOrEmpty(x); if isnan(x); v = []; else; v = double(x); end; end
