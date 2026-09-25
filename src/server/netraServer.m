function netraServer(port, onReady)
%NETRASERVER  MATLAB-native REST API in front of the Netra pipeline.
%
%   netraServer          % listens on 8090
%   netraServer(9000)    % any free port
%   netraServer(9000, @() web('http://localhost:9000','-browser'))
%
%   onReady (optional) runs once, on this thread, immediately after the
%   socket is bound and before the accept loop starts. NetraApp uses it to
%   open the browser. Doing it here - rather than polling the port from a
%   timer - is what guarantees the server is actually listening first.
%
%   Pure MATLAB + the JVM that ships with it (java.net.ServerSocket) - no
%   extra toolbox, no Python, no Node. The runtime pipeline stays MATLAB.
%
%   Ctrl-C in the Command Window stops it.
%
%   Endpoints (all JSON in / JSON out, CORS open):
%     POST /api/login                {user,pass}
%     GET  /api/patients?q=          search
%     POST /api/patients             {name,age,sex,phone,village,diabetesYears}
%     GET  /api/patients/<id>        dossier
%     POST /api/screen               {patientId,eye,imageBase64,filename}
%     POST /api/review               {patientId,eye,finalGrade,notes,reviewerId}
%     GET  /api/admin/snapshot       district console payload
%     GET  /api/health               liveness probe (used by the web fallback)
%     GET  /api/file?p=<path>        serves an overlay PNG / report PDF

    if nargin < 1 || isempty(port);    port = 8090;  end
    if nargin < 2;                     onReady = []; end

    root = fileparts(fileparts(mfilename('fullpath')));   % <repo>/src -> <repo>
    root = fileparts(root);
    cd(root);
    addpath(genpath(fullfile(root,'src')));
    addpath(fullfile(root,'app'));

    fprintf('Netra API  warming caches...\n');
    try
        initPatientDB(); initDB(); loadGradingNet();
    catch ME
        fprintf(2,'  warmup: %s\n', ME.message);
    end

    try
        server = java.net.ServerSocket(port);
    catch ME
        if contains(ME.message, 'Address already in use')
            error('netraServer:portBusy', ...
                ['Port %d is already in use.\n\n' ...
                 'Most likely an earlier Netra server is still running.\n' ...
                 'Either:\n' ...
                 '  - use another port:   NetraApp(%d)\n' ...
                 '  - or close the old one. To find it:\n' ...
                 '        netstat -ano | findstr :%d\n' ...
                 '        taskkill /PID <pid> /F'], port, port + 1, port);
        end
        rethrow(ME);
    end
    server.setReuseAddress(true);
    cleanup = onCleanup(@() server.close());   %#ok<NASGU>

    fprintf('Netra API  listening on http://localhost:%d\n', port);
    fprintf('           repo root: %s\n', root);
    fprintf('           Ctrl-C to stop.\n\n');

    % The socket is bound and listening now, so anything that wants to
    % connect (e.g. opening the browser) is safe to run at this point.
    if ~isempty(onReady)
        try
            onReady();
        catch ME
            fprintf(2,'  [onReady] %s\n', ME.message);
        end
    end

    while true
        sock = [];
        try
            sock = server.accept();
            sock.setSoTimeout(30000);
            handleConnection(sock, root);
        catch ME
            if ~isempty(ME.identifier) && contains(ME.identifier,'ServerSocket')
                rethrow(ME);
            end
            fprintf(2,'  [conn] %s\n', ME.message);
        end
        if ~isempty(sock)
            try; sock.close(); catch; end
        end
    end
end

% =====================================================================
function handleConnection(sock, root)
    in = java.io.BufferedInputStream(sock.getInputStream());

    % ---- request line + headers (small, byte-at-a-time is fine) ------
    head = readUntilBlankLine(in);
    if isempty(head); return; end
    lines = strsplit(head, sprintf('\r\n'));
    parts = strsplit(strtrim(lines{1}), ' ');
    if numel(parts) < 2; return; end
    method = upper(parts{1});
    target = parts{2};

    hdrs = containers.Map('KeyType','char','ValueType','char');
    for k = 2:numel(lines)
        idx = strfind(lines{k}, ':');
        if isempty(idx); continue; end
        key = lower(strtrim(lines{k}(1:idx(1)-1)));     % raw, e.g. content-length
        hdrs(key) = strtrim(lines{k}(idx(1)+1:end));
    end

    % ---- body -------------------------------------------------------
    nBody = 0;
    if hdrs.isKey('content-length'); nBody = str2double(hdrs('content-length')); end
    if isnan(nBody); nBody = 0; end
    body = '';
    if nBody > 0
        body = readExactly(in, nBody);
    end

    % ---- split path / query ----------------------------------------
    qIdx = strfind(target,'?');
    if isempty(qIdx)
        path = target; query = '';
    else
        path = target(1:qIdx(1)-1); query = target(qIdx(1)+1:end);
    end

    out = sock.getOutputStream();

    % ---- CORS preflight --------------------------------------------
    if strcmp(method,'OPTIONS')
        writeResponse(out, 204, 'text/plain', uint8([]));
        return
    end

    fprintf('  %-4s %s\n', method, path);

    try
        [status, ctype, payload] = netraRoute(method, path, query, body, root);
    catch ME
        fprintf(2,'  [route] %s\n', getReport(ME,'basic'));
        status  = 500;
        ctype   = 'application/json';
        payload = unicode2native(jsonencode(struct( ...
                    'ok', false, 'error', ME.message)), 'UTF-8');
    end

    writeResponse(out, status, ctype, payload);
end

% =====================================================================
function s = readUntilBlankLine(in)
%READUNTILBLANKLINE  Reads bytes until CRLFCRLF. Headers only, so small.
    buf = uint8(zeros(1,8192));
    n = 0;
    while true
        b = in.read();
        if b < 0; break; end
        n = n + 1;
        buf(n) = uint8(b);
        if n >= 4 && all(buf(n-3:n) == uint8([13 10 13 10])); break; end
        if n >= numel(buf); break; end
    end
    s = char(buf(1:max(n-4,0)));
end

% =====================================================================
function s = readExactly(in, n)
%READEXACTLY  Reads exactly n bytes of body.
%
%   Uses Apache Commons IO (on MATLAB's static Java classpath) because it
%   RETURNS a byte[] - passing a MATLAB-side array into in.read() would only
%   fill a copy, since MATLAB copies Java arrays across the boundary.
%   Falls back to a byte loop if commons-io ever goes missing.
    try
        raw = org.apache.commons.io.IOUtils.toByteArray(in, int64(n));
        s = char(typecast(int8(raw(:)'), 'uint8'));   % byte[] arrives as a column
        return
    catch
    end

    buf = uint8(zeros(1, n));
    got = 0;
    while got < n
        b = in.read();
        if b < 0; break; end
        got = got + 1;
        buf(got) = uint8(b);
    end
    s = char(buf(1:got));
end

% =====================================================================
function writeResponse(out, status, ctype, payload)
    reasons = containers.Map( ...
        {200,204,400,401,404,500}, ...
        {'OK','No Content','Bad Request','Unauthorized','Not Found','Internal Server Error'});
    if reasons.isKey(status); reason = reasons(status); else; reason = 'OK'; end

    hdr = sprintf([ ...
        'HTTP/1.1 %d %s\r\n' ...
        'Content-Type: %s\r\n' ...
        'Content-Length: %d\r\n' ...
        'Access-Control-Allow-Origin: *\r\n' ...
        'Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n' ...
        'Access-Control-Allow-Headers: Content-Type, ngrok-skip-browser-warning\r\n' ...
        'Cache-Control: no-store\r\n' ...
        'Connection: close\r\n\r\n'], ...
        status, reason, ctype, numel(payload));

    out.write(typecast(unicode2native(hdr,'UTF-8'),'int8'));
    if ~isempty(payload)
        out.write(typecast(uint8(payload(:)'),'int8'));
    end
    out.flush();
end
