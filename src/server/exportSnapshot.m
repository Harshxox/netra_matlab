function exportSnapshot(~)
%EXPORTSNAPSHOT  Bake REAL pipeline output into web/data/ for offline hosting.
%
%   exportSnapshot
%
%   Re-seeds the demo cohort (every patient screened once, each on a
%   different fundus image), copies every overlay PNG into web/data/images/,
%   and writes web/data/snapshot.json.
%
%   NOTE: this WIPES netra_patients.mat and netra_db.mat and rebuilds them.
%
%   The deployed site loads this whenever the MATLAB backend is unreachable,
%   so a judge opening the public URL with your laptop off still sees genuine
%   pipeline output - clearly labelled "cached" by the UI - instead of a dead
%   page or invented numbers.
%
%   Re-run this whenever the pipeline changes, then commit web/data/.

    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    cd(root);
    addpath(genpath(fullfile(root,'src')));
    addpath(fullfile(root,'app'));

    outDir = fullfile(root,'web','data');
    imgDir = fullfile(outDir,'images');
    if ~exist(imgDir,'dir'); mkdir(imgDir); end

    % seedDemoPatients screens every patient once, each with a different
    % sample image, and hands back the full records - so there is no second
    % pipeline pass here and every patient owns a distinct retina.
    fprintf('Snapshot  seeding demo cohort (one screening each)...\n');
    raw = {};
    try
        raw = seedDemoPatients();
    catch ME
        fprintf(2,'  %s\n', ME.message);
    end

    records = {};
    for k = 1:numel(raw)
        records{end+1} = localiseImages(raw{k}, imgDir, root, k); %#ok<AGROW>
    end
    fprintf('Snapshot  captured %d screening record(s).\n', numel(records));

    % ---- dossiers for every patient we touched ----------------------
    dossiers = struct();
    P = findPatients();
    for k = 1:height(P)
        pid = char(P.patientId(k));
        try
            d = patientDossier(pid);
            d = stripPaths(d);
            dossiers.(matlab.lang.makeValidName(pid)) = d;
        catch
        end
    end

    % ---- assemble ---------------------------------------------------
    snap = struct();
    snap.generatedAt = char(datetime('now','Format','yyyy-MM-dd HH:mm'));
    snap.note        = ['Real MATLAB pipeline output, pre-computed. ' ...
                        'Live screening requires the netraServer backend.'];
    snap.records     = records;
    snap.patients    = num2cell(patientsAsStructs(P));
    snap.dossiers    = dossiers;
    snap.snapshot    = adminSnapshot();
    snap.users = { ...
        struct('user','admin', 'pass','netra2026', 'role','admin',    'name','District Health Officer'), ...
        struct('user','phc',   'pass','phc2026',   'role','operator', 'name','PHC Health Worker'), ...
        struct('user','doctor','pass','doctor2026','role','operator', 'name','Screening Operator') };

    jsonPath = fullfile(outDir,'snapshot.json');
    fid = fopen(jsonPath,'w');
    fwrite(fid, unicode2native(jsonencode(snap),'UTF-8'), 'uint8');
    fclose(fid);

    fprintf('\nSnapshot  wrote %s\n', jsonPath);
    fprintf('          %d screening records, %d patients\n', numel(records), height(P));
    fprintf('          images in %s\n', imgDir);
    fprintf('          commit web/data/ and redeploy.\n');
end

% =====================================================================
function rec = localiseImages(rec, imgDir, root, idx) %#ok<INUSD>
%LOCALISEIMAGES  Copy each overlay into web/data/images and rewrite the
%                path to something the static site can load directly.
    if ~isfield(rec,'images') || ~isstruct(rec.images); return; end
    f = fieldnames(rec.images);
    for j = 1:numel(f)
        src = char(string(rec.images.(f{j})));
        if isempty(src) || ~isfile(src)
            rec.images.(f{j}) = ''; continue
        end
        [~,~,ext] = fileparts(src);
        safeId = matlab.lang.makeValidName(char(string(rec.patientId)));
        name = sprintf('%s_%s%s', safeId, f{j}, ext);
        try
            copyfile(src, fullfile(imgDir, name));
            rec.images.(f{j}) = ['data/images/' name];   % relative to web/
        catch
            rec.images.(f{j}) = '';
        end
    end
end

function d = stripPaths(d)
%STRIPPATHS  Blank machine-local paths in the offline dossier. Every patient
%            has a full record in snapshot.records, so the UI falls back to
%            that for overlays instead of pointing at this machine's disk.
    if ~isfield(d,'screenings'); return; end
    for k = 1:numel(d.screenings)
        s = d.screenings{k};
        if isfield(s,'reportPath'); s.reportPath = ''; end
        if isfield(s,'images') && isstruct(s.images)
            f = fieldnames(s.images);
            for j = 1:numel(f); s.images.(f{j}) = ''; end
        end
        d.screenings{k} = s;
    end
end

function s = patientsAsStructs(T)
    if isempty(T) || height(T) == 0; s = struct([]); return; end
    s = table2struct(T);
    for k = 1:numel(s)
        f = fieldnames(s(k));
        for j = 1:numel(f)
            v = s(k).(f{j});
            if isstring(v) || iscategorical(v); s(k).(f{j}) = char(string(v)); end
            if isdatetime(v); s(k).(f{j}) = char(string(v,'yyyy-MM-dd')); end
            if isnumeric(v) && isscalar(v) && isnan(v); s(k).(f{j}) = -1; end
        end
    end
end
