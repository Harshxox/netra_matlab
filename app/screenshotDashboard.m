function outPng = screenshotDashboard(sampleName, outPng)
%SCREENSHOTDASHBOARD  Render the dashboard with a real payload and save a PNG.
%   For visual QA without clicking through the GUI.
%
%   screenshotDashboard('009245722fa4')

    if nargin < 1 || isempty(sampleName); sampleName = '009245722fa4'; end
    if nargin < 2 || isempty(outPng)
        outPng = fullfile('images','_debug',['dashboard_' sampleName '.png']);
    end
    if ~exist(fileparts(outPng),'dir'); mkdir(fileparts(outPng)); end

    warning('off','loadGradingNet:missing');
    warning('off','calibrateConfidence:noFile');

    appDir = fileparts(mfilename('fullpath'));
    rec = runPipeline(fullfile('data','samples',[sampleName '.png']), sampleName, 'OD');
    payload = buildDashboardPayload(rec);

    fig = uifigure('Position',[50 50 1180 780],'Color',[0.06 0.09 0.16], ...
                   'Visible','on');
    h = uihtml(fig,'Position',[1 1 1180 780], ...
        'HTMLSource', fullfile(appDir,'dashboard.html'), ...
        'Data', struct('boot',true));
    drawnow; pause(2);
    sendEventToHTMLSource(h, 'screening', payload);
    drawnow; pause(4);

    exportapp(fig, outPng);
    close(fig);
    fprintf('saved %s  (grade %d, %s)\n', outPng, ...
        rec.result.grade, rec.result.gradeLabel);
end
