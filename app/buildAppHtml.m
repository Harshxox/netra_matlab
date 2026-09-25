function htmlPath = buildAppHtml()
%BUILDAPPHTML  Inline dashboard.css + dashboard.js into a single fresh HTML file.
%
%   htmlPath = buildAppHtml()
%
%   uihtml / the embedded Chromium caches linked <link> and <script> files by
%   URL and does NOT reliably reload them when the source changes. This bundles
%   the three source files into one self-contained HTML written to a uniquely
%   named temp file, so every launch loads a URL the cache has never seen.
%
%   Edit app/dashboard.{html,css,js} as normal - this just packages them.

    appDir = fileparts(mfilename('fullpath'));
    html = fileread(fullfile(appDir, 'dashboard.html'));
    css  = fileread(fullfile(appDir, 'dashboard.css'));
    js   = fileread(fullfile(appDir, 'dashboard.js'));

    % strrep (not regexprep) so $ and \ in the CSS/JS are treated literally
    html = strrep(html, '<link rel="stylesheet" href="dashboard.css">', ...
                  ['<style>' newline css newline '</style>']);
    html = strrep(html, '<script src="dashboard.js"></script>', ...
                  ['<script>' newline js newline '</script>']);

    outDir = fullfile(tempdir, 'netra_app');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    % clean up bundles from previous runs
    old = dir(fullfile(outDir, 'netra_*.html'));
    for k = 1:numel(old)
        try; delete(fullfile(old(k).folder, old(k).name)); catch; end %#ok<TRYNC>
    end

    htmlPath = fullfile(outDir, sprintf('netra_%s.html', ...
        datestr(now, 'yyyymmdd_HHMMSSFFF')));
    fid = fopen(htmlPath, 'w', 'n', 'UTF-8');
    fwrite(fid, html, 'char');
    fclose(fid);
end
