function [status, ctype, payload] = netraRoute(method, path, query, body, root)
%NETRAROUTE  Maps HTTP requests onto the existing Netra MATLAB functions.
%
%   Called by netraServer. Returns an HTTP status, a content type and a
%   uint8 payload. Every handler here is a thin wrapper - the real work
%   stays in src/<module>.

    status = 200;
    ctype  = 'application/json';

    switch true

        % ---- liveness ------------------------------------------------
        case strcmp(path,'/api/health')
            payload = ok(struct('service','netra-matlab', ...
                                'version', matlabRelease().Release, ...
                                'time', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'))));

        % ---- auth ----------------------------------------------------
        case strcmp(path,'/api/login') && strcmp(method,'POST')
            d = jsondecode(body);
            [good, role, who] = checkAuth(getf(d,'user',''), getf(d,'pass',''));
            if good
                payload = ok(struct('role',role,'name',who));
            else
                status  = 401;
                payload = fail('Invalid username or password');
            end

        % ---- patients ------------------------------------------------
        case strcmp(path,'/api/patients') && strcmp(method,'GET')
            q = qparam(query,'q');
            T = findPatients(q);
            payload = ok(struct('patients', {tableToStructArray(T)}));

        case strcmp(path,'/api/patients') && strcmp(method,'POST')
            d = jsondecode(body);
            profile = struct( ...
                'patientId',     getf(d,'patientId',''), ...
                'name',          getf(d,'name',''), ...
                'age',           num(getf(d,'age',NaN)), ...
                'sex',           getf(d,'sex',''), ...
                'phone',         getf(d,'phone',''), ...
                'village',       getf(d,'village',''), ...
                'diabetesYears', num(getf(d,'diabetesYears',NaN)), ...
                'registeredBy',  getf(d,'registeredBy','web'));
            [pid, rec] = registerPatient(profile);
            payload = ok(struct('patientId',char(pid),'patient',rec));

        case startsWith(path,'/api/patients/') && strcmp(method,'GET')
            pid = path(numel('/api/patients/')+1:end);
            d = patientDossier(urldecode(pid));
            if isempty(d.profile)
                status = 404; payload = fail('Patient not found');
            else
                d = webifyDossier(d, root);
                payload = ok(struct('dossier',d));
            end

        % ---- screening (the pipeline) --------------------------------
        case strcmp(path,'/api/screen') && strcmp(method,'POST')
            d = jsondecode(body);
            [status, payload] = doScreen(d, root);

        % ---- review --------------------------------------------------
        case strcmp(path,'/api/review') && strcmp(method,'POST')
            d = jsondecode(body);
            fg = getf(d,'finalGrade',[]);
            if ischar(fg) || isstring(fg); fg = str2double(fg); end
            good = saveReviewDecision( ...
                getf(d,'patientId',''), getf(d,'eye','OD'), fg, ...
                getf(d,'notes',''),     getf(d,'reviewerId','web-reviewer'));
            payload = ok(struct('saved', logical(good)));

        % ---- admin ---------------------------------------------------
        case strcmp(path,'/api/admin/snapshot') && strcmp(method,'GET')
            payload = ok(struct('snapshot', adminSnapshot()));

        % ---- file passthrough (overlay PNGs, report PDFs) -------------
        case strcmp(path,'/api/file') && strcmp(method,'GET')
            [status, ctype, payload] = serveFile(qparam(query,'p'), root);

        % ---- everything else: the static site in web/ -----------------
        otherwise
            if strcmp(method,'GET')
                [status, ctype, payload] = serveStatic(path, root);
            else
                status  = 404;
                payload = fail(sprintf('No route for %s %s', method, path));
            end
    end
end

% =====================================================================
function [status, ctype, payload] = serveStatic(path, root)
%SERVESTATIC  Serves web/ so the UI and the API share one origin (no CORS,
%             one port, no separate static server needed).
    rel = path;
    if isempty(rel) || strcmp(rel,'/'); rel = '/index.html'; end
    rel = strrep(rel, '/', filesep);
    if startsWith(rel, filesep); rel = rel(2:end); end

    candidate = fullfile(root, 'web', rel);
    if ~isfile(candidate) && ~endsWith(lower(rel), '.html')
        alt = fullfile(root, 'web', [rel '.html']);      % vercel cleanUrls parity
        if isfile(alt); candidate = alt; end
    end

    [status, ctype, payload] = serveFile( ...
        strrep(erase(candidate, [root filesep]), filesep, '/'), root);
end

% =====================================================================
function [status, payload] = doScreen(d, root)
%DOSCREEN  base64 image -> temp file -> runPipeline -> web-safe record.

    b64 = getf(d,'imageBase64','');
    if isempty(b64)
        status = 400; payload = fail('imageBase64 is required'); return
    end
    comma = strfind(b64, ',');                    % strip data: URI prefix
    if ~isempty(comma) && comma(1) < 200
        b64 = b64(comma(1)+1:end);
    end

    fname = getf(d,'filename','upload.png');
    [~,~,ext] = fileparts(char(fname));
    if isempty(ext); ext = '.png'; end

    upDir = fullfile(root,'web','uploads');
    if ~exist(upDir,'dir'); mkdir(upDir); end
    tmp = fullfile(upDir, sprintf('up_%s%s', ...
            char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')), ext));

    bytes = matlab.net.base64decode(b64);
    fid = fopen(tmp,'w'); fwrite(fid, bytes, 'uint8'); fclose(fid);

    patientId = getf(d,'patientId','');
    eye       = getf(d,'eye','OD');

    record = runPipeline(tmp, patientId, eye, ...
                struct('save',true,'makePdf',true,'saveDir',fullfile(root,'images')));

    status  = 200;
    payload = ok(struct('record', webifyRecord(record, root)));
end

% =====================================================================
function r = webifyRecord(r, root)
%WEBIFYRECORD  Rewrites absolute image paths into /api/file URLs the
%              browser can actually load.
    if isfield(r,'images') && isstruct(r.images)
        f = fieldnames(r.images);
        for k = 1:numel(f)
            r.images.(f{k}) = toUrl(r.images.(f{k}), root);
        end
    end
end

function d = webifyDossier(d, root)
    if isfield(d,'screenings') && ~isempty(d.screenings)
        for k = 1:numel(d.screenings)
            if isfield(d.screenings(k),'reportPath')
                d.screenings(k).reportPath = toUrl(d.screenings(k).reportPath, root);
            end
        end
    end
end

function u = toUrl(p, root)
    p = char(string(p));
    if isempty(p); u = ''; return; end
    rel = p;
    if startsWith(lower(p), lower(root))
        rel = p(numel(root)+2:end);
    end
    rel = strrep(rel, '\', '/');
    u = ['/api/file?p=' urlencode(rel)];
end

% =====================================================================
function [status, ctype, payload] = serveFile(relPath, root)
    status = 200; ctype = 'application/octet-stream'; payload = uint8([]);

    relPath = urldecode(char(relPath));
    relPath = strrep(relPath, '\', '/');

    % path traversal guard - resolve and confirm it stays under root
    full = fullfile(root, relPath);
    fullReal = char(java.io.File(full).getCanonicalPath());
    rootReal = char(java.io.File(root).getCanonicalPath());
    if ~startsWith(lower(fullReal), lower(rootReal)) || ~isfile(fullReal)
        status = 404; ctype = 'application/json';
        payload = fail('File not found'); return
    end

    [~,~,ext] = fileparts(fullReal);
    types = struct( ...
        'x_html','text/html; charset=utf-8', 'x_css','text/css; charset=utf-8', ...
        'x_js','application/javascript; charset=utf-8', ...
        'x_json','application/json', 'x_svg','image/svg+xml', ...
        'x_png','image/png', 'x_jpg','image/jpeg', 'x_jpeg','image/jpeg', ...
        'x_gif','image/gif', 'x_webp','image/webp', 'x_ico','image/x-icon', ...
        'x_woff','font/woff', 'x_woff2','font/woff2', 'x_ttf','font/ttf', ...
        'x_pdf','application/pdf', 'x_txt','text/plain; charset=utf-8');
    key = ['x_' lower(strrep(ext,'.',''))];
    if isfield(types, key); ctype = types.(key); end

    fid = fopen(fullReal,'r');
    payload = fread(fid, inf, '*uint8')';
    fclose(fid);
end

% =====================================================================
function p = ok(s)
    s.ok = true;
    p = unicode2native(jsonencode(s), 'UTF-8');
end

function p = fail(msg)
    p = unicode2native(jsonencode(struct('ok',false,'error',char(msg))), 'UTF-8');
end

function v = getf(s, f, d)
    if isstruct(s) && isfield(s,f) && ~isempty(s.(f)); v = s.(f); else; v = d; end
    if isstring(v) || ischar(v); v = char(v); end
end

function v = num(x)
    if ischar(x) || isstring(x); v = str2double(x); else; v = double(x); end
    if isempty(v); v = NaN; end
end

function v = qparam(query, key)
    v = '';
    if isempty(query); return; end
    pairs = strsplit(char(query), '&');
    for k = 1:numel(pairs)
        kv = strsplit(pairs{k}, '=');
        if numel(kv) == 2 && strcmp(kv{1}, key)
            v = urldecode(kv{2}); return
        end
    end
end

function s = tableToStructArray(T)
    if isempty(T) || height(T) == 0; s = {}; return; end
    s = table2struct(T);
    for k = 1:numel(s)
        f = fieldnames(s(k));
        for j = 1:numel(f)
            val = s(k).(f{j});
            if isstring(val) || iscategorical(val); s(k).(f{j}) = char(string(val)); end
            if isdatetime(val); s(k).(f{j}) = char(string(val,'yyyy-MM-dd')); end
            if isnumeric(val) && isscalar(val) && isnan(val); s(k).(f{j}) = -1; end
        end
    end
    s = num2cell(s);
end
