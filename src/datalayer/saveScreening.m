function saveScreening(record, dbPath)
%SAVESCREENING  Append one completed screening to the database and persist it.
%
%   saveScreening(record)
%   saveScreening(record, 'netra_db.mat')
%
%   record - the data-contract struct after the pipeline has run.
%            Ungradable records (no result) are still logged, with grade = NaN.

    if nargin < 2 || isempty(dbPath); dbPath = 'netra_db.mat'; end
    db = initDB(dbPath);

    hasResult = isfield(record,'result') && isstruct(record.result) && isfield(record.result,'grade');

    grade      = NaN;  glabel = "";  refer = false;  conf = NaN;  method = "";
    if hasResult
        grade  = record.result.grade;
        glabel = string(gv(record.result,'gradeLabel',''));
        refer  = logical(gv(record.result,'referable',false));
        conf   = gv(record.result,'confidence',NaN);
        method = string(gv(record.result,'method',''));
    end

    q = "";
    if isfield(record,'quality') && isfield(record.quality,'status')
        q = string(record.quality.status);
    end

    dt = datetime('now');
    if isfield(record,'date') && ~isempty(record.date)
        try; dt = datetime(record.date, 'InputFormat','yyyy-MM-dd_HH-mm'); catch; end
    end

    imgs = getfield_safe(record,'images');
    les  = getfield_safe(record,'lesions');
    qual = getfield_safe(record,'quality');

    % Folder that holds this screening's overlays, derived from any one of
    % them. Lets the dossier rebuild every layer path without storing six
    % columns - and still no image blobs in the database.
    imgDir = "";
    for f = ["evidence","gradcam","lesionOverlay","original","enhanced"]
        p = char(string(gv(imgs, char(f), '')));
        if ~isempty(p); imgDir = string(fileparts(p)); break; end
    end

    newRow = table( ...
        string(record.patientId), string(gv(record,'eye','OD')), dt, ...
        grade, glabel, refer, conf, q, string(gv(record,'routing','')), ...
        "pending", NaN, "", method, string(gv(imgs,'reportPath','')), ...
        imgDir, ...
        double(gv(les,'maCount',NaN)), ...
        double(gv(les,'heCount',NaN)), ...
        double(gv(les,'exudateAreaPct',NaN)), ...
        logical(gv(les,'nvPresent',false)), ...
        double(gv(qual,'focusScore',NaN)), ...
        'VariableNames', db.Properties.VariableNames);

    db = [db; newRow];
    save(dbPath, 'db');
end

function v = gv(s,f,d)
    if isstruct(s) && isfield(s,f) && ~isempty(s.(f)); v = s.(f); else; v = d; end
end
function s = getfield_safe(r,f)
    if isfield(r,f) && isstruct(r.(f)); s = r.(f); else; s = struct(); end
end
