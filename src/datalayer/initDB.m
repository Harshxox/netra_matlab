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
        db = migrate(s.db);
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
        string.empty(0,1), ...   % imageDir      (folder holding this screening's overlays)
        double.empty(0,1), ...   % maCount
        double.empty(0,1), ...   % heCount
        double.empty(0,1), ...   % exudateAreaPct
        logical.empty(0,1), ...  % nvPresent
        double.empty(0,1), ...   % focusScore
        'VariableNames', {'patientId','eye','date','grade','gradeLabel', ...
            'referable','confidence','qualityStatus','routing','reviewStatus', ...
            'finalGrade','reviewNotes','gradingMethod','reportPath', ...
            'imageDir','maCount','heCount','exudateAreaPct','nvPresent','focusScore'});

    save(dbPath, 'db');
    fprintf('Created new screening database: %s\n', dbPath);
end

% =====================================================================
function db = migrate(db)
%MIGRATE  Add columns introduced after a database was first created, so an
%         existing netra_db.mat keeps working instead of erroring on access.
    defaults = { ...
        'imageDir',       string(missing); ...
        'maCount',        NaN; ...
        'heCount',        NaN; ...
        'exudateAreaPct', NaN; ...
        'nvPresent',      false; ...
        'focusScore',     NaN };

    n = height(db);
    for k = 1:size(defaults,1)
        name = defaults{k,1};
        if ~ismember(name, db.Properties.VariableNames)
            val = defaults{k,2};
            if isstring(val)
                db.(name) = repmat(string(missing), n, 1);
            elseif islogical(val)
                db.(name) = false(n,1);
            else
                db.(name) = nan(n,1);
            end
        end
    end
end
