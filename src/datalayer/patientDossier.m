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
        'reviewNotes',{},'gradingMethod',{},'reportPath',{},'lesions',{},'images',{});
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

        sc(i).lesions = struct( ...
            'maCount',        numOrEmpty(colOr(r,'maCount',NaN)), ...
            'heCount',        numOrEmpty(colOr(r,'heCount',NaN)), ...
            'exudateAreaPct', numOrEmpty(colOr(r,'exudateAreaPct',NaN)), ...
            'nvPresent',      logical(colOr(r,'nvPresent',false)), ...
            'focusScore',     numOrEmpty(colOr(r,'focusScore',NaN)));

        sc(i).images = layerPaths(char(string(colOr(r,'imageDir',""))));
    end
    d.screenings = num2cell(sc);   % cell array -> always a JSON array
end

% =====================================================================
function im = layerPaths(dirPath)
%LAYERPATHS  Rebuild the overlay set from the screening's image folder.
%            Only files that actually exist are returned, so the UI never
%            renders a broken image.
    im = struct('original','','enhanced','','gradcam','', ...
                'lesionOverlay','','vesselMap','','evidence','');
    if isempty(dirPath) || strcmp(dirPath,'<missing>') || ~isfolder(dirPath); return; end

    files = struct( ...
        'original',      'original.png', ...
        'enhanced',      'processed.png', ...
        'gradcam',       'gradcam.png', ...
        'lesionOverlay', 'lesion_overlay.png', ...
        'vesselMap',     'vessel_map.png', ...
        'evidence',      'evidence.png');

    f = fieldnames(files);
    for k = 1:numel(f)
        p = fullfile(dirPath, files.(f{k}));
        if isfile(p); im.(f{k}) = p; end
    end
end

function v = colOr(row, name, dflt)
    if ismember(name, row.Properties.VariableNames)
        v = row.(name);
        if isstring(v) && ismissing(v); v = dflt; end
    else
        v = dflt;
    end
end

function v = numOrEmpty(x)
    if isempty(x) || (isnumeric(x) && isnan(x)); v = []; else; v = double(x); end
end
