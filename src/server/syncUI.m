function syncUI(uiDir, webDir)
%SYNCUI  Rebuild web/ from the upstream UI in netra_ui/, re-applying the
%        MATLAB integration on top.
%
%   syncUI                       % netra_ui/ -> web/
%   syncUI('netra_ui','web')
%
%   Run this whenever the frontend teammate pushes:
%
%       >> cd netra_ui && !git pull
%       >> syncUI
%
%   WHY THIS EXISTS
%   netra_ui/ is a clone of the frontend repo (karthickkr2426/netra) that we
%   do not own. web/ is what actually ships. Keeping them as two hand-edited
%   copies guarantees drift, so web/ is treated as a BUILD OUTPUT:
%
%       web/  =  netra_ui/  +  the integration files below
%
%   Anything in KEEP is ours and survives the copy. Everything else in web/
%   is overwritten from netra_ui/, so never hand-edit those files - edit them
%   in netra_ui/ (or ask the frontend owner to), then re-run syncUI.
%
%   The function is idempotent: running it twice changes nothing.

    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    if nargin < 1 || isempty(uiDir);  uiDir  = fullfile(root,'netra_ui'); end
    if nargin < 2 || isempty(webDir); webDir = fullfile(root,'web');      end

    if ~exist(uiDir,'dir')
        error('syncUI:noUI','Upstream UI folder not found:\n  %s', uiDir);
    end
    if ~exist(webDir,'dir'); mkdir(webDir); end

    % Ours - never overwritten by the upstream copy.
    KEEP = {'js/config.js', 'js/api.js', 'js/netra-bridge.js', 'data', 'uploads'};

    % Upstream files we do not ship (we have our own at the repo root).
    SKIP = {'.git', '.gitignore', 'vercel.json', 'node_modules', 'README.md'};

    fprintf('syncUI  %s\n   ->   %s\n\n', uiDir, webDir);

    copied = copyTree(uiDir, webDir, '', SKIP, KEEP, 0);
    fprintf('\n  %d file(s) copied from upstream\n', copied);

    % ---- re-apply the integration ---------------------------------
    pages = {'index.html','login.html','dashboard.html','doctor-dashboard.html'};
    nPatched = 0;
    for k = 1:numel(pages)
        p = fullfile(webDir, pages{k});
        if isfile(p) && injectScripts(p)
            nPatched = nPatched + 1;
            fprintf('  wired  %s\n', pages{k});
        end
    end

    % ---- verify ours survived --------------------------------------
    fprintf('\n  integration files:\n');
    missing = {};
    for k = 1:numel(KEEP)
        p = fullfile(webDir, KEEP{k});
        present = isfile(p) || isfolder(p);
        fprintf('    [%s] %s\n', ternary(present,'ok','MISSING'), KEEP{k});
        if ~present && endsWith(KEEP{k},'.js'); missing{end+1} = KEEP{k}; end %#ok<AGROW>
    end

    fprintf('\nsyncUI  done - %d page(s) wired.\n', nPatched);
    if ~isempty(missing)
        warning('syncUI:missing', ...
            ['These integration files are missing from web/:\n  %s\n' ...
             'The site will load but cannot reach MATLAB.'], strjoin(missing, ', '));
    end
    if ~isfolder(fullfile(webDir,'data'))
        fprintf('  note: no web/data yet - run exportSnapshot to bake the offline fallback.\n');
    end
end

% =====================================================================
function n = copyTree(srcRoot, dstRoot, rel, SKIP, KEEP, n)
    items = dir(fullfile(srcRoot, rel));
    for k = 1:numel(items)
        it = items(k);
        if strcmp(it.name,'.') || strcmp(it.name,'..'); continue; end

        relPath = strtrim(fullfile(rel, it.name));
        posix   = strrep(relPath, '\', '/');

        if any(strcmpi(it.name, SKIP)) || any(strcmpi(posix, SKIP)); continue; end
        if any(strcmpi(posix, KEEP))
            fprintf('  keep   %s\n', posix); continue
        end

        src = fullfile(srcRoot, relPath);
        dst = fullfile(dstRoot, relPath);

        if it.isdir
            if ~exist(dst,'dir'); mkdir(dst); end
            n = copyTree(srcRoot, dstRoot, relPath, SKIP, KEEP, n);
        else
            copyfile(src, dst, 'f');
            n = n + 1;
        end
    end
end

% =====================================================================
function changed = injectScripts(htmlPath)
%INJECTSCRIPTS  Put config.js + api.js BEFORE the page's own scripts and
%               netra-bridge.js AFTER them. Idempotent.
    txt = fileread(htmlPath);
    if contains(txt, 'js/netra-bridge.js'); changed = false; return; end

    pre  = ['  <script src="js/config.js"></script>' newline ...
            '  <script src="js/api.js"></script>' newline];
    post = [newline '  <script src="js/netra-bridge.js"></script>'];

    % first of the page's own scripts -> insert pre before it
    firstTag = '';
    for cand = {'js/translations.js','js/app.js','js/workstation.js'}
        t = ['<script src="' cand{1} '"></script>'];
        if contains(txt, t); firstTag = t; break; end
    end
    if isempty(firstTag); changed = false; return; end
    txt = strrep(txt, firstTag, [strtrim(pre) newline '  ' firstTag]);

    % last of the page's own scripts -> insert post after it
    lastTag = '';
    for cand = {'js/app.js','js/workstation.js','js/translations.js'}
        t = ['<script src="' cand{1} '"></script>'];
        if contains(txt, t); lastTag = t; end
    end
    if isempty(lastTag); changed = false; return; end
    idx = strfind(txt, lastTag);
    idx = idx(end);
    cut = idx + numel(lastTag) - 1;
    txt = [txt(1:cut) post txt(cut+1:end)];

    fid = fopen(htmlPath,'w');
    fwrite(fid, unicode2native(txt,'UTF-8'), 'uint8');
    fclose(fid);
    changed = true;
end

function s = ternary(c, a, b)
    if c; s = a; else; s = b; end
end
