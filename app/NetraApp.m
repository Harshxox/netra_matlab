function NetraApp(port)
%NETRAAPP  Launch Netra: starts the MATLAB backend and opens the web UI.
%
%   NetraApp          % serves on 8090 and opens the browser
%   NetraApp(9000)    % any free port
%
%   One MATLAB process serves BOTH the netra_ui frontend and the REST API on
%   the same port, so there is no CORS setup, no second server, and no Python
%   dependency. Your browser becomes the app window.
%
%     http://localhost:<port>/          -> the netra_ui site (web/)
%     http://localhost:<port>/api/...   -> the MATLAB pipeline
%
%   Sign in with (see src/datalayer/checkAuth.m):
%     admin  / netra2026    district health officer console
%     phc    / phc2026      PHC operator - register + screen
%     doctor / doctor2026   operator
%
%   Press Ctrl-C in this window to stop the server.
%
%   Want the old single-window MATLAB UI instead?  >> NetraAppNative
%   Pulling UI changes from the frontend repo?     >> syncUI

    if nargin < 1 || isempty(port); port = 8090; end

    appDir  = fileparts(mfilename('fullpath'));
    rootDir = fileparts(appDir);
    cd(rootDir);
    addpath(genpath(fullfile(rootDir,'src')));
    addpath(appDir);

    webDir = fullfile(rootDir,'web');
    if ~isfile(fullfile(webDir,'index.html'))
        error('NetraApp:noWeb', ...
            ['web/index.html is missing.\n' ...
             'Run  syncUI  to build web/ from netra_ui/.']);
    end

    if ~isfile(fullfile(webDir,'data','snapshot.json'))
        fprintf(2, ['  note: no web/data/snapshot.json yet.\n' ...
                    '        Run  exportSnapshot  so the site still works when\n' ...
                    '        this server is not running.\n\n']);
    end

    url = sprintf('http://localhost:%d', port);

    fprintf('\n  Netra\n');
    fprintf('  ─────────────────────────────────────────────\n');
    fprintf('  UI   %s\n', url);
    fprintf('  API  %s/api\n', url);
    fprintf('  Stop Ctrl-C in this window\n');
    fprintf('  ─────────────────────────────────────────────\n\n');

    % netraServer opens the browser itself, the moment the socket is bound
    % and before it starts accepting. Don't poll the port from a timer here:
    % the accept loop owns this thread, so a timer racing the bind deadlocks.
    netraServer(port, @() openBrowser(url));   % blocks until Ctrl-C
end

% =====================================================================
function openBrowser(url)
    fprintf('  opening %s\n\n', url);
    try
        web(url, '-browser');        % default system browser
    catch
        try
            web(url);                % fall back to MATLAB's own browser
        catch
            fprintf(2,'  Could not open a browser - go to %s manually.\n', url);
        end
    end
end
