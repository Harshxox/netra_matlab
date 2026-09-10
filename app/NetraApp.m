function NetraApp()
%NETRAAPP  Netra DR-screening desktop app (uifigure + uihtml, no App Designer).
%
%   >> cd  <repo root>\netra
%   >> addpath(genpath('src')); addpath('app')
%   >> NetraApp
%
%   Top strip: patient ID, eye, "Open fundus image".
%   Below: the HTML dashboard. Open an image -> the pipeline runs -> the
%   dashboard fills in. Agree / Override write to netra_db.mat. Open PDF opens
%   the generated report.

    S.appDir  = fileparts(mfilename('fullpath'));
    S.rootDir = fileparts(S.appDir);
    cd(S.rootDir);
    addpath(genpath(fullfile(S.rootDir,'src')));

    S.record = [];

    fig = uifigure('Name','Netra - DR Screening','Position',[80 80 1180 780], ...
                   'Color',[0.06 0.09 0.16]);
    g = uigridlayout(fig,[2 1],'RowHeight',{44,'1x'},'Padding',2,'RowSpacing',2, ...
                     'BackgroundColor',[0.06 0.09 0.16]);

    % ---- top strip ------------------------------------------------
    strip = uigridlayout(g,[1 6],'ColumnWidth',{90,150,70,'1x',150,150}, ...
        'Padding',[8 6 8 6],'ColumnSpacing',8,'BackgroundColor',[0.12 0.16 0.24]);

    uilabel(strip,'Text','Patient ID','FontColor',[.7 .75 .82]);
    S.pid = uieditfield(strip,'text','Value',char("PT-" + string(datetime('now','Format','HHmmss'))));
    S.eye = uidropdown(strip,'Items',{'OD','OS'},'Value','OD');
    uilabel(strip,'Text','');
    S.openBtn = uibutton(strip,'Text','Open fundus image...','ButtonPushedFcn',@onOpen);
    S.status  = uilabel(strip,'Text','','FontColor',[0.3 0.8 0.55]);

    % ---- dashboard ----------------------------------------------
    S.html = uihtml(g, ...
        'HTMLSource', fullfile(S.appDir,'dashboard.html'), ...
        'HTMLEventReceivedFcn', @onHtmlEvent, ...
        'Data', struct('ready',true));

    guidata(fig, S);

    % ---- warm up caches + JIT so the first real demo image is fast ----
    S.status.Text = 'Warming up...';
    S.openBtn.Enable = 'off';
    drawnow;
    try
        warmDir = fullfile(S.rootDir,'data','samples');
        w = dir(fullfile(warmDir,'*.png'));
        loadGradingNet();
        if ~isempty(w)
            runPipeline(fullfile(w(1).folder,w(1).name), 'PT-WARMUP', 'OD', ...
                        struct('save',false,'makePdf',false));
        end
    catch
    end
    S.status.Text = 'Ready - open a fundus image';
    S.openBtn.Enable = 'on';
    drawnow;

    % ================================================================
    function onOpen(~,~)
        S = guidata(fig);
        [f,p] = uigetfile({'*.png;*.jpg;*.jpeg;*.tif;*.tiff','Fundus images'}, ...
                          'Select a fundus image', fullfile(S.rootDir,'data','samples'));
        if isequal(f,0); return; end
        imgPath = fullfile(p,f);

        S.status.Text = 'Running pipeline...';
        S.openBtn.Enable = 'off'; drawnow;

        try
            rec = runPipeline(imgPath, S.pid.Value, S.eye.Value);
        catch e
            S.status.Text = 'Pipeline error';
            uialert(fig, e.message, 'Pipeline error');
            S.openBtn.Enable = 'on';
            return
        end

        S.record = rec;
        guidata(fig, S);

        payload = buildDashboardPayload(rec);
        sendEventToHTMLSource(S.html, 'screening', payload);

        if strcmp(rec.routing,'recapture')
            S.status.Text = 'Ungradable - recapture';
        else
            S.status.Text = sprintf('Grade %d (%s) - %.1fs', ...
                rec.result.grade, rec.result.gradeLabel, rec.meta.elapsedSec);
        end
        S.openBtn.Enable = 'on';
    end

    % ================================================================
    function onHtmlEvent(~, ev)
        S = guidata(fig);
        rec = S.record;
        switch ev.HTMLEventName

            case 'reviewDecision'
                if isempty(rec); return; end
                d = ev.HTMLEventData;
                ok = saveReviewDecision(rec.patientId, rec.eye, d.finalGrade, ...
                        getdef(d,'notes',''), 'reviewer_01');
                msg = tern(ok, sprintf('Saved: %s, final grade %d', d.type, d.finalGrade), ...
                               'No pending record to update');
                sendEventToHTMLSource(S.html,'status',struct('msg',msg));
                S.status.Text = msg;

            case 'generateReport'
                if isempty(rec); return; end
                rp = getdef(rec.images,'reportPath','');
                if isempty(rp) || ~isfile(rp)
                    rp = generateReport(rec, struct('dir','reports'));
                end
                if ispc; try; winopen(rp); catch; end; end
                sendEventToHTMLSource(S.html,'status',struct('msg','PDF opened'));

            case 'eyeChanged'
                S.eye.Value = ev.HTMLEventData.eye;
                guidata(fig, S);
        end
    end
end

% --------------------------------------------------------------------
function v = getdef(s,f,d)
    if isstruct(s) && isfield(s,f) && ~isempty(s.(f)); v = s.(f); else; v = d; end
end
function o = tern(c,a,b); if c; o=a; else; o=b; end; end
