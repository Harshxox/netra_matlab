function outPng = screenshotDashboard(sampleName, outPng, viewName)
%SCREENSHOTDASHBOARD  Render a dashboard view with real data and save a PNG.
%
%   screenshotDashboard                              % default sample, screening view
%   screenshotDashboard('009245722fa4','out.png')
%   screenshotDashboard([], 'login.png', 'login')    % view: 'login'|'register'|'screening'|'admin'
%
%   Drives the login/session flow so views render as a real user would see them.

    if nargin < 1 || isempty(sampleName); sampleName = '009245722fa4'; end
    if nargin < 2 || isempty(outPng); outPng = fullfile('images','_debug',['dash_' sampleName '.png']); end
    if nargin < 3 || isempty(viewName); viewName = 'screening'; end
    if ~exist(fileparts(outPng),'dir'); mkdir(fileparts(outPng)); end
    warning('off','all');

    appDir = fileparts(mfilename('fullpath'));
    fig = uifigure('Position',[40 40 1280 820],'Color',[0.93 0.94 0.96],'Visible','on');
    h = uihtml(fig,'Position',[1 1 1280 820], ...
        'HTMLSource', buildAppHtml(), 'Data', struct('boot',true));
    drawnow; pause(2.2);

    if strcmp(viewName,'login')
        exportapp(fig, outPng); close(fig); fprintf('saved %s (login)\n', outPng); return
    end

    isAdmin = strcmp(viewName,'admin');
    sendEventToHTMLSource(h,'session', struct('ok',true, ...
        'role', ternary(isAdmin,'admin','operator'), ...
        'name', ternary(isAdmin,'District Health Officer','PHC Health Worker')));
    drawnow; pause(1.2);

    if isAdmin
        snap = adminSnapshot();
        sendEventToHTMLSource(h,'adminData', snap);
        drawnow; pause(2);
        P = initPatientDB();
        if ~isempty(P) && isvalid(h)
            try
                dossier = patientDossier(char(P.patientId(2)));
                sendEventToHTMLSource(h,'patientDetail', dossier);
            catch me
                fprintf(2,'dossier skipped: %s\n', me.message);
            end
        end
        drawnow; pause(1.5);
        exportapp(fig, outPng); close(fig); fprintf('saved %s (admin)\n', outPng); return
    end

    if strcmp(viewName,'register')
        T = findPatients('');
        if ~isempty(T)
            sendEventToHTMLSource(h,'patientResults', struct('rows', {tableRows(T)}));
        end
        drawnow; pause(1);
        exportapp(fig, outPng); close(fig); fprintf('saved %s (register)\n', outPng); return
    end

    prof = struct('patientId','PT-DEMO-0001','name','Ramesh Kumar','age',58, ...
        'sex','M','phone','9876543210','village','Rampur PHC','diabetesYears',12);
    sendEventToHTMLSource(h,'patientReady', struct('patient',prof,'isNew',false));
    drawnow; pause(1);

    rec = runPipeline(fullfile('data','samples',[sampleName '.png']), sampleName, 'OD');
    rec.patient = prof;
    sendEventToHTMLSource(h, 'screening', buildDashboardPayload(rec));
    drawnow; pause(4.5);

    exportapp(fig, outPng); close(fig);
    fprintf('saved %s  (grade %d, %s)\n', outPng, rec.result.grade, rec.result.gradeLabel);
end

function o = ternary(c,a,b); if c; o=a; else; o=b; end; end
function arr = tableRows(T)
    s = table2struct(T); arr = {};
    for i = 1:numel(s)
        for f = fieldnames(s)'
            x = s(i).(f{1});
            if isdatetime(x); s(i).(f{1}) = char(string(x));
            elseif isstring(x); s(i).(f{1}) = char(x);
            elseif isnumeric(x) && isnan(x); s(i).(f{1}) = [];
            end
        end
        arr{end+1} = s(i); %#ok<AGROW>
    end
end
