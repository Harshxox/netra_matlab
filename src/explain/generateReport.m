function reportPath = generateReport(record, opts)
%GENERATEREPORT  One-page annotated PDF screening report (MATLAB Report Generator).
%
%   reportPath = generateReport(record)
%   reportPath = generateReport(record, opts)
%
%   record    - the data-contract struct after the pipeline has run
%   opts.dir  - output folder (default 'reports')
%   opts.open - open the PDF when done (default false)
%
%   Contents: patient/quality header, grade + referable verdict (large, colour),
%   confidence, evidence image, lesion overlay, lesion counts table, routing,
%   "why this grade" notes, and the prototype disclaimer.

    import mlreportgen.report.*
    import mlreportgen.dom.*

    if nargin < 2; opts = struct(); end
    if ~isfield(opts,'dir');  opts.dir  = 'reports'; end
    if ~isfield(opts,'open'); opts.open = false;     end
    if ~exist(opts.dir,'dir'); mkdir(opts.dir); end

    pid   = getfielddef(record,'patientId','UNKNOWN');
    dstr  = getfielddef(record,'date', char(datetime('now','Format','yyyy-MM-dd_HH-mm')));
    fname = matlab.lang.makeValidName(sprintf('%s_%s', pid, dstr));
    rpt   = Report(fullfile(opts.dir, fname), 'pdf');

    % ---- title ------------------------------------------------------
    tp = TitlePage('Title','Netra - DR Screening Report', ...
                   'Subtitle', sprintf('Patient %s', pid));
    tp.Author = 'AI screening prototype - SIH 2026';
    tp.PubDate = dstr;
    add(rpt, tp);

    ch = Chapter('Title','Screening Result');

    eye = getfielddef(record,'eye','-');
    qs  = '-';
    if isfield(record,'quality') && isstruct(record.quality)
        qs = getfielddef(record.quality,'status','-');
    end
    add(ch, Paragraph(sprintf('Date: %s      Eye: %s      Image quality: %s', dstr, eye, qs)));

    % ---- ungradable short-circuit --------------------------------
    routing = getfielddef(record,'routing','');
    if strcmpi(routing,'recapture') || ~isfield(record,'result') || isempty(record.result)
        w = Paragraph('IMAGE UNGRADABLE - please recapture');
        w.Bold = true; w.FontSize = '18pt'; w.Color = '#D97706';
        add(ch, w);
        if isfield(record,'quality') && isfield(record.quality,'reasons')
            add(ch, Paragraph(['Reasons: ' strjoin(cellstr(record.quality.reasons), '; ')]));
        end
        addDisclaimer(ch);
        add(rpt, ch); close(rpt); reportPath = rpt.OutputPath;
        if opts.open && ispc; try; winopen(reportPath); catch; end; end
        return
    end

    R = record.result;
    grade = getfielddef(R,'grade',0);
    glab  = getfielddef(R,'gradeLabel','');
    refer = logical(getfielddef(R,'referable',false));
    conf  = getfielddef(R,'confidence',0);

    % ---- verdict (large, coloured) -------------------------------
    v = Paragraph(sprintf('DR Grade %d  -  %s', grade, glab));
    v.Bold = true; v.FontSize = '20pt';
    add(ch, v);

    verdictText = ternary(refer, 'REFER TO SPECIALIST', 'ROUTINE FOLLOW-UP');
    r = Paragraph(sprintf('%s      Confidence: %.0f%%', verdictText, 100*conf));
    r.Bold = true; r.FontSize = '14pt';
    r.Color = ternary(refer, '#DC2626', '#16A34A');
    add(ch, r);

    method = getfielddef(R,'method','');
    if ~isempty(method)
        m = Paragraph(sprintf('Grading method: %s', upper(method)));
        m.FontSize = '8pt'; m.Color = '#64748B';
        add(ch, m);
    end

    % ---- images ------------------------------------------------
    imgs = getfielddef(record,'images',struct());
    evi  = getfielddef(imgs,'evidence','');
    les  = getfielddef(imgs,'lesionOverlay','');
    if isfile(evi)
        add(ch, Paragraph('Evidence view (attention heatmap + lesion outlines):'));
        fi = FormalImage(evi); fi.ScaleToFit = true; add(ch, fi);
    end
    if isfile(les)
        add(ch, Paragraph('Lesion overlay  (red = microaneurysm, blue = hemorrhage, yellow = exudate):'));
        fi = FormalImage(les); fi.ScaleToFit = true; add(ch, fi);
    end

    % ---- lesion counts table (2-D cell array!) -----------------
    L = getfielddef(record,'lesions',struct());
    data = {
        'Finding', 'Value';
        'Microaneurysms',       num2str(getfielddef(L,'maCount',0));
        'Hemorrhages',          num2str(getfielddef(L,'heCount',0));
        'Exudate area',         sprintf('%.2f%%', getfielddef(L,'exudateAreaPct',0));
        'Neovascularization',   ternary(logical(getfielddef(L,'nvPresent',false)),'Present','Not detected')
    };
    tbl = Table(data);
    tbl.Border = 'solid'; tbl.RowSep = 'solid'; tbl.ColSep = 'solid';
    tbl.TableEntriesInnerMargin = '2pt';
    add(ch, tbl);

    % ---- why this grade + history ----------------------------
    notes = getfielddef(R,'notes',{});
    if ~isempty(notes)
        add(ch, Paragraph('Why this grade:'));
        ul = UnorderedList(cellstr(notes));
        add(ch, ul);
    end
    if isfield(record,'history') && isfield(record.history,'trend') && ~isempty(record.history.trend)
        add(ch, Paragraph(sprintf('Patient history: %s', record.history.trend)));
    end

    add(ch, Paragraph(sprintf('Recommendation: %s', prettyRouting(routing))));

    addDisclaimer(ch);
    add(rpt, ch);
    close(rpt);
    reportPath = rpt.OutputPath;
    if opts.open && ispc; try; winopen(reportPath); catch; end; end
end

% ====================================================================
function addDisclaimer(ch)
    import mlreportgen.dom.*
    d = Paragraph(['This report is produced by a hackathon prototype and is NOT a ' ...
        'certified medical device. All findings must be reviewed and confirmed by a ' ...
        'qualified ophthalmologist. SIH 2026 - PS 26038.']);
    d.Italic = true; d.FontSize = '8pt'; d.Color = '#64748B';
    add(ch, d);
end

function out = ternary(c,a,b); if c; out = a; else; out = b; end; end

function v = getfielddef(s, f, d)
    if isstruct(s) && isfield(s,f) && ~isempty(s.(f)); v = s.(f); else; v = d; end
end

function s = prettyRouting(r)
    switch lower(char(r))
        case 'refer_specialist', s = 'Refer to ophthalmologist';
        case 'routine_followup', s = 'Routine follow-up (annual screening)';
        case 'recapture',        s = 'Recapture image';
        otherwise,               s = char(r);
    end
end
