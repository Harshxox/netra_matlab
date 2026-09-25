function NetraAppNative()
%NETRAAPPNATIVE  Netra - MATLAB-native UI (uihtml), no browser needed.
%
%   The original single-window app. NetraApp now launches the netra_ui
%   web frontend instead; this is kept as an offline fallback.
%
%   Netra - retinal DR screening (login -> register/screen -> admin console).
%
%   >> cd  <repo root>\netra
%   >> addpath(genpath('src')); addpath('app')
%   >> NetraAppNative
%
%   CREDENTIALS (prototype - see src/datalayer/checkAuth.m):
%     admin  / netra2026   -> District Health Officer console (all patients + data)
%     phc    / phc2026     -> PHC operator: register a patient, run a screening
%     doctor / doctor2026  -> operator
%
%   Flow:  Login -> (operator) find or register patient -> screening dashboard
%                -> (admin)    console: patient list, drill-down, live stats
%   Data:  netra_patients.mat (profiles) + netra_db.mat (screenings), linked by id.

    S.appDir  = fileparts(mfilename('fullpath'));
    S.rootDir = fileparts(S.appDir);
    cd(S.rootDir);
    addpath(genpath(fullfile(S.rootDir,'src')));

    S.session       = [];    % struct('role','operator'|'admin', 'name', ...)
    S.currentPatient = [];   % profile struct
    S.currentRecord  = [];   % last screening record
    S.eye            = 'OD';

    fig = uifigure('Name','Netra - Retinal Screening', ...
                   'Position',[60 60 1280 820], 'Color',[0.93 0.94 0.96]);
    g = uigridlayout(fig,[1 1],'Padding',0,'BackgroundColor',[0.93 0.94 0.96]);

    S.html = uihtml(g, ...
        'HTMLSource', buildAppHtml(), ...   % fresh self-contained bundle (no CSS/JS cache)
        'HTMLEventReceivedFcn', @onEvent, ...
        'Data', struct('booted', true));

    guidata(fig, S);

    % warm caches so the first screening is fast (non-blocking-ish)
    warmup();

    % ================================================================
    function warmup()
        try
            initPatientDB(); initDB(); loadGradingNet();
            w = dir(fullfile(S.rootDir,'data','samples','*.png'));
            if ~isempty(w)
                runPipeline(fullfile(w(1).folder,w(1).name), 'PT-WARMUP', 'OD', ...
                            struct('save',false,'makePdf',false));
            end
        catch
        end
    end

    % ================================================================
    function onEvent(src, ev)
        S = guidata(fig);
        name = ev.HTMLEventName;
        d = struct(); try; d = ev.HTMLEventData; catch; end

        switch name

            % ---------- auth --------------------------------------
            case 'login'
                [ok, role, who] = checkAuth(getf(d,'user',''), getf(d,'pass',''));
                if ok
                    S.session = struct('role',role,'name',who);
                    guidata(fig, S);
                    sendEventToHTMLSource(S.html,'session', ...
                        struct('ok',true,'role',role,'name',who));
                    if strcmp(role,'admin'); pushAdmin(); end
                else
                    sendEventToHTMLSource(S.html,'session', ...
                        struct('ok',false,'msg','Invalid username or password'));
                end

            case 'logout'
                S.session = []; S.currentPatient = []; S.currentRecord = [];
                guidata(fig, S);
                sendEventToHTMLSource(S.html,'loggedOut',struct());

            % ---------- patient registry -------------------------
            case 'searchPatients'
                T = findPatients(getf(d,'q',''));
                sendEventToHTMLSource(S.html,'patientResults', ...
                    struct('rows', {tableToStructArray(T)}));

            case 'registerPatient'
                prof = d;
                if isfield(S.session,'name'); prof.registeredBy = S.session.name; end
                [pid, rec] = registerPatient(prof);
                S.currentPatient = getPatient(pid);
                guidata(fig, S);
                sendEventToHTMLSource(S.html,'patientReady', ...
                    struct('patient', S.currentPatient, 'isNew', true));

            case 'selectPatient'
                p = getPatient(getf(d,'patientId',''));
                if isempty(p)
                    sendEventToHTMLSource(S.html,'status',struct('msg','Patient not found'));
                    return
                end
                S.currentPatient = p;
                guidata(fig, S);
                [hist,~] = getHistory(p.patientId);
                sendEventToHTMLSource(S.html,'patientReady', ...
                    struct('patient', p, 'isNew', false, 'history', hist));

            % ---------- screening -------------------------------
            case 'requestOpen'
                if isempty(S.currentPatient)
                    sendEventToHTMLSource(S.html,'status',struct('msg','Select a patient first'));
                    return
                end
                [f,p] = uigetfile({'*.png;*.jpg;*.jpeg;*.tif;*.tiff','Fundus images'}, ...
                                  'Select a fundus image', fullfile(S.rootDir,'data','samples'));
                if isequal(f,0); return; end
                imgPath = fullfile(p,f);

                sendEventToHTMLSource(S.html,'busy',struct('on',true, ...
                    'text','Quality check - segmentation - grading - explainability'));
                drawnow;
                try
                    rec = runPipeline(imgPath, S.currentPatient.patientId, S.eye);
                catch e
                    sendEventToHTMLSource(S.html,'busy',struct('on',false));
                    uialert(fig, e.message, 'Pipeline error');
                    return
                end
                rec.patient = S.currentPatient;
                S.currentRecord = rec;
                guidata(fig, S);
                sendEventToHTMLSource(S.html,'screening', buildDashboardPayload(rec));

            case 'reviewDecision'
                if isempty(S.currentRecord); return; end
                ok = saveReviewDecision(S.currentRecord.patientId, S.currentRecord.eye, ...
                        getf(d,'finalGrade',NaN), getf(d,'notes',''), ...
                        sessName());
                msg = tern(ok, sprintf('Decision saved (%s, grade %d)', ...
                        getf(d,'type','agree'), getf(d,'finalGrade',NaN)), ...
                        'No pending screening to update');
                sendEventToHTMLSource(S.html,'status',struct('msg',msg));

            case 'generateReport'
                if isempty(S.currentRecord); return; end
                rp = '';
                if isfield(S.currentRecord,'images'); rp = getf(S.currentRecord.images,'reportPath',''); end
                if isempty(rp) || ~isfile(rp)
                    rp = generateReport(S.currentRecord, struct('dir','reports'));
                end
                openFile(rp);
                sendEventToHTMLSource(S.html,'status',struct('msg','Report opened'));

            case 'eyeChanged'
                S.eye = getf(d,'eye','OD'); guidata(fig, S);

            % ---------- admin console ---------------------------
            case 'requestAdminData'
                pushAdmin();

            case 'requestPatientDetail'
                dossier = patientDossier(getf(d,'patientId',''));
                sendEventToHTMLSource(S.html,'patientDetail', dossier);

            case 'openReportPath'
                openFile(getf(d,'path',''));
        end
    end

    % ================================================================
    function pushAdmin()
        S = guidata(fig);
        try
            snap = adminSnapshot();
        catch e
            sendEventToHTMLSource(S.html,'status',struct('msg',['Admin load failed: ' e.message]));
            return
        end
        sendEventToHTMLSource(S.html,'adminData', snap);
    end

    function n = sessName()
        S = guidata(fig);
        if isstruct(S.session) && isfield(S.session,'name'); n = S.session.name; else; n = 'operator'; end
    end
end

% --------------------------------------------------------------------
function v = getf(s, f, d)
    if isstruct(s) && isfield(s,f) && ~isempty(s.(f)); v = s.(f); else; v = d; end
end
function o = tern(c,a,b); if c; o=a; else; o=b; end; end
function openFile(p)
    if isempty(p) || ~isfile(p); return; end
    try
        if ispc; winopen(p); elseif ismac; system(['open "' p '"']); else; system(['xdg-open "' p '"']); end
    catch
    end
end
function arr = tableToStructArray(T)
    if isempty(T); arr = {}; return; end
    s = table2struct(T);
    for i = 1:numel(s)
        f = fieldnames(s);
        for k = 1:numel(f)
            v = s(i).(f{k});
            if isdatetime(v); s(i).(f{k}) = char(string(v));
            elseif isstring(v); s(i).(f{k}) = char(v);
            elseif isnumeric(v) && isnan(v); s(i).(f{k}) = [];
            end
        end
    end
    arr = num2cell(s);
end
