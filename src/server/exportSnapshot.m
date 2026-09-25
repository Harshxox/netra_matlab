function exportSnapshot(nCases)
%EXPORTSNAPSHOT  Bake REAL pipeline output into web/data/ for offline hosting.
%
%   exportSnapshot        % 6 demo cases
%   exportSnapshot(10)
%
%   Runs the actual MATLAB pipeline over sample fundus images, copies every
%   overlay PNG into web/data/images/, and writes web/data/snapshot.json.
%
%   The deployed site loads this whenever the MATLAB backend is unreachable,
%   so a judge opening the public URL with your laptop off still sees genuine
%   pipeline output - clearly labelled "cached" by the UI - instead of a dead
%   page or invented numbers.
%
%   Re-run this whenever the pipeline changes, then commit web/data/.

    if nargin < 1 || isempty(nCases); nCases = 6; end

    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    cd(root);
    addpath(genpath(fullfile(root,'src')));
    addpath(fullfile(root,'app'));

    outDir = fullfile(root,'web','data');
    imgDir = fullfile(outDir,'images');
    if ~exist(imgDir,'dir'); mkdir(imgDir); end

    fprintf('Snapshot  seeding demo patients...\n');
    try; seedDemoPatients(); catch ME; fprintf(2,'  %s\n', ME.message); end

    samples = dir(fullfile(root,'data','samples','*.png'));
    if isempty(samples)
        error('exportSnapshot:noSamples','No images in data/samples/.');
    end
    nCases = min(nCases, numel(samples));

    P = findPatients();
    records = {};

    fprintf('Snapshot  running the pipeline on %d images...\n', nCases);
    for k = 1:nCases
        imgPath = fullfile(samples(k).folder, samples(k).name);

        if height(P) >= k
            pid = char(P.patientId(k));
        else
            pid = sprintf('PT-SNAP-%03d', k);
        end

        fprintf('  [%d/%d] %s -> %s\n', k, nCases, samples(k).name, pid);
        try
            rec = runPipeline(imgPath, pid, 'OD', struct( ...
                    'save', true, 'makePdf', true, ...
                    'saveDir', fullfile(root,'images')));
        catch ME
            fprintf(2,'      skipped: %s\n', ME.message);
            continue
        end

        rec = localiseImages(rec, imgDir, root, k);
        records{end+1} = rec; %#ok<AGROW>
    end

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
    if isfield(d,'screenings')
        for k = 1:numel(d.screenings)
            if isfield(d.screenings(k),'reportPath')
                d.screenings(k).reportPath = '';
            end
        end
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
