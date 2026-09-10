function db = initDB(dbPath)
%INITDB  Load the screening database (a table in a .mat file), or create it.
%
%   db = initDB()
%   db = initDB('netra_db.mat')
%
%   Columns match the flat fields the dashboard + history need. Image blobs
%   are NEVER stored - only file paths. One row per completed screening.

    if nargin < 1 || isempty(dbPath); dbPath = 'netra_db.mat'; end

    if isfile(dbPath)
        s = load(dbPath, 'db');
        db = s.db;
        return
    end

    db = table( ...
        string.empty(0,1), ...   % patientId
        string.empty(0,1), ...   % eye  (OD/OS)
        datetime.empty(0,1), ... % date
        double.empty(0,1), ...   % grade
        string.empty(0,1), ...   % gradeLabel
        logical.empty(0,1), ...  % referable
        double.empty(0,1), ...   % confidence
        string.empty(0,1), ...   % qualityStatus
        string.empty(0,1), ...   % routing
        string.empty(0,1), ...   % reviewStatus  (pending/reviewed)
        double.empty(0,1), ...   % finalGrade
        string.empty(0,1), ...   % reviewNotes
        string.empty(0,1), ...   % gradingMethod (onnx/rules)
        string.empty(0,1), ...   % reportPath
        'VariableNames', {'patientId','eye','date','grade','gradeLabel', ...
            'referable','confidence','qualityStatus','routing','reviewStatus', ...
            'finalGrade','reviewNotes','gradingMethod','reportPath'});

    save(dbPath, 'db');
    fprintf('Created new screening database: %s\n', dbPath);
end
