function reportPath = generateReport(record, opts)
%GENERATEREPORT  Designed, doctor-friendly one/two-page PDF screening report.
%
%   reportPath = generateReport(record)
%   reportPath = generateReport(record, opts)   % .dir (default 'reports'), .open
%
%   Built with mlreportgen.dom for full colour/layout control:
%     - teal header band with patient identifiers
%     - a large colour-coded verdict banner (REFER / ROUTINE / RECAPTURE)
%     - grade + calibrated confidence, with a bar
%     - the evidence image (heatmap + lesion outlines)
%     - a findings table with colour-coded status cells
%     - plain-language "what this means" + "next step" for the patient
%     - prototype disclaimer footer

    import mlreportgen.dom.*

    if nargin < 2; opts = struct(); end
    if ~isfield(opts,'dir');  opts.dir  = 'reports'; end
    if ~isfield(opts,'open'); opts.open = false;     end
    if ~exist(opts.dir,'dir'); mkdir(opts.dir); end

    C = palette();

    pid   = gv(record,'patientId','UNKNOWN');
    eye   = gv(record,'eye','OD');
    dstr  = gv(record,'date', char(datetime('now','Format','yyyy-MM-dd HH:mm')));
    qual  = '';
    if isfield(record,'quality') && isstruct(record.quality); qual = gv(record.quality,'status',''); end

    fname = matlab.lang.makeValidName(sprintf('%s_%s', pid, dstr));
    d = Document(fullfile(opts.dir, fname), 'pdf');
    open(d);
    d.CurrentPageLayout.PageMargins.Top    = '0.35in';
    d.CurrentPageLayout.PageMargins.Bottom = '0.3in';
    d.CurrentPageLayout.PageMargins.Left   = '0.55in';
    d.CurrentPageLayout.PageMargins.Right  = '0.55in';

    % ---------------- header band -----------------------------------
    hdr = Table(); hdr.Width = '100%'; hdr.Border = 'none';
    hr = TableRow();
    left = TableEntry();
    t1 = Paragraph('NETRA'); t1.Style = {Bold, FontSize('16pt'), Color('white')};
    t2 = Paragraph('Diabetic Retinopathy Screening Report');
    t2.Style = {FontSize('9pt'), Color('#CFF5F0')};
    append(left, t1); append(left, t2);
    left.Style = {BackgroundColor(C.teal), InnerMargin('12pt','12pt','10pt','10pt')};
    right = TableEntry();
    for kv = { {'Patient', char(pid)}, {'Eye', char(eye)}, {'Date', char(dstr)}, {'Image quality', char(qual)} }
        pr = Paragraph(sprintf('%s:  %s', kv{1}{1}, kv{1}{2}));
        pr.Style = {FontSize('9pt'), Color('white'), HAlign('right')};
        append(right, pr);
    end
    right.Style = {BackgroundColor(C.teal), InnerMargin('12pt','12pt','10pt','10pt')};
    append(hr, left); append(hr, right);
    append(hdr, hr);
    append(d, hdr);
    append(d, vspace('5pt'));

    routing = gv(record,'routing','');
    graded  = isfield(record,'result') && isstruct(record.result) && isfield(record.result,'grade');

    % ---------------- ungradable short-circuit ---------------------
    if strcmpi(routing,'recapture') || ~graded
        append(d, banner('IMAGE UNGRADABLE', 'Please recapture the fundus photograph', C.amber));
        if isfield(record,'quality') && isfield(record.quality,'reasons') && ~isempty(record.quality.reasons)
            append(d, softBox('Why', strjoin(cellstr(string(record.quality.reasons)), '  ·  '), C));
        end
        append(d, disclaimer(C));
        close(d);
        reportPath = d.OutputPath;
        if opts.open && ispc; try; winopen(reportPath); catch; end; end %#ok<TRYNC>
        return
    end

    R = record.result;
    grade = R.grade;  glabel = gv(R,'gradeLabel','');
    refer = logical(gv(R,'referable',false));
    conf  = gv(R,'confidence',0);
    method = gv(R,'method','');

    % ---------------- verdict banner -----------------------------
    if refer
        append(d, banner('REFER TO SPECIALIST', ...
            'Arrange an ophthalmology review for this patient', C.rose));
    else
        append(d, banner('ROUTINE FOLLOW-UP', ...
            'No urgent referral - re-screen at the next annual visit', C.green));
    end
    append(d, vspace('5pt'));

    % ---------------- grade + confidence + image row ------------
    row = Table(); row.Width = '100%'; row.Border = 'none';
    tr = TableRow();

    gc = TableEntry();
    gc.Style = {Width('52%'), VAlign('top'), InnerMargin('0','14pt','0','0')};
    gp = Paragraph(sprintf('DR Grade %d', grade));
    gp.Style = {Bold, FontSize('22pt'), Color(C.ink)};
    gl = Paragraph(glabel);
    gl.Style = {FontSize('12pt'), Color(C.ink2)};
    append(gc, gp); append(gc, gl);
    append(gc, vspace('10pt'));
    cl = Paragraph(sprintf('Calibrated confidence:  %.0f%%', 100*conf));
    cl.Style = {Bold, FontSize('10pt'), Color(C.ink)};
    append(gc, cl);
    append(gc, confBar(conf, C));
    if ~isempty(method)
        mp = Paragraph(sprintf('Grading method: %s', ternary(strcmpi(method,'onnx'), ...
            'ResNet-50 deep-learning classifier', 'classical computer-vision baseline')));
        mp.Style = {FontSize('8pt'), Color(C.ink3), OuterMargin('0','4pt','0','0')};
        append(gc, mp);
    end
    % explainability checks
    ex = gv(record,'explain',struct());
    cal = gv(R,'calibration',struct());
    parts = {};
    if isstruct(ex) && isfield(ex,'heatMethod') && ~isempty(ex.heatMethod)
        parts{end+1} = sprintf('Attention: %s', methodName(ex.heatMethod));
    end
    if isstruct(ex) && isfield(ex,'xaiLabel') && ~isempty(ex.xaiLabel)
        parts{end+1} = sprintf('attention-lesion agreement %s', ex.xaiLabel);
    end
    if isstruct(cal) && isfield(cal,'available') && cal.available
        if isfield(cal,'ece') && ~isnan(cal.ece)
            parts{end+1} = sprintf('confidence calibrated (ECE %.0f%%, n=%d)', 100*cal.ece, cal.n);
        else
            parts{end+1} = 'confidence calibrated';
        end
    end
    if ~isempty(parts)
        xp = Paragraph(['Explainability: ' strjoin(parts, '  ·  ')]);
        xp.Style = {FontSize('8pt'), Color(C.ink3), OuterMargin('0','4pt','0','0')};
        append(gc, xp);
    end

    ic = TableEntry(); ic.Style = {Width('48%'), VAlign('top')};
    evi = ''; if isfield(record,'images'); evi = gv(record.images,'evidence',''); end
    if isempty(evi) || ~isfile(evi)
        if isfield(record,'images'); evi = gv(record.images,'lesionOverlay',''); end
    end
    if ~isempty(evi) && isfile(evi)
        im = Image(evi); im.Width = '2.5in'; im.Height = '2.5in';
        append(ic, im);
        cap = Paragraph('Evidence view - attention heatmap with lesion outlines');
        cap.Style = {FontSize('8pt'), Color(C.ink3), HAlign('center')};
        append(ic, cap);
    end
    append(tr, gc); append(tr, ic);
    append(row, tr);
    append(d, row);
    append(d, vspace('6pt'));

    % ---------------- findings table ---------------------------
    L = struct(); if isfield(record,'lesions') && isstruct(record.lesions); L = record.lesions; end
    append(d, sectionTitle('Lesion findings', C));
    ft = Table();
    ft.Width = '100%';
    ft.Style = {Border('solid', C.line, '1px'), ColSep('solid', C.line, '1px'), RowSep('solid', C.line, '1px')};
    append(ft, findHeader(C));
    append(ft, findRow('Microaneurysms', '0 - 5', numstr(gv(L,'maCount',0)), '> 15', ...
        statusOf(gv(L,'maCount',0), 6, 15), C));
    append(ft, findRow('Hemorrhages', '0', numstr(gv(L,'heCount',0)), '1 or more', ...
        statusOf(gv(L,'heCount',0), 1, 6), C));
    append(ft, findRow('Exudate area', '0%', sprintf('%.2f%%', gv(L,'exudateAreaPct',0)), '> 0.6%', ...
        statusOf(gv(L,'exudateAreaPct',0), 0.1, 0.6), C));
    nvp = logical(gv(L,'nvPresent',false));
    append(ft, findRow('Neovascularization', 'Absent', ternary(nvp,'Present','Absent'), 'Present', ...
        ternary(nvp,'high','normal'), C));
    append(d, ft);
    append(d, vspace('6pt'));

    % ---------------- why this grade --------------------------
    notes = gv(R,'notes',{});
    if ~isempty(notes)
        append(d, softBox('Why this grade', strjoin(cellstr(string(notes)), char(10)), C));
    end

    % ---------------- patient guidance -----------------------
    [meaning, nextStep] = guidance(grade, refer);
    g2 = Table(); g2.Width = '100%'; g2.Border = 'none';
    g2r = TableRow();
    e1 = TableEntry(); e1.Style = {Width('50%'), InnerMargin('0','8pt','0','0'), VAlign('top')};
    append(e1, guideCard('What this means', meaning, C.tealSoft, C));
    e2 = TableEntry(); e2.Style = {Width('50%'), InnerMargin('8pt','0','0','0'), VAlign('top')};
    append(e2, guideCard('Recommended next step', nextStep, C.blueSoft, C));
    append(g2r, e1); append(g2r, e2);
    append(g2, g2r);
    append(d, g2);

    % ---------------- history --------------------------------
    if isfield(record,'history') && isfield(record.history,'trend') && ~isempty(record.history.trend)
        append(d, vspace('5pt'));
        hp = Paragraph(sprintf('Patient history:  %s', record.history.trend));
        hp.Style = {FontSize('9pt'), Color(C.ink2), Italic};
        append(d, hp);
    end

    append(d, disclaimer(C));
    close(d);
    reportPath = d.OutputPath;
    if opts.open && ispc; try; winopen(reportPath); catch; end; end %#ok<TRYNC>
end

% ====================================================================
function C = palette()
    C.teal='#0D9488'; C.rose='#E11D48'; C.green='#16A34A'; C.amber='#D97706';
    C.ink='#111827'; C.ink2='#4B5563'; C.ink3='#9CA3AF'; C.line='#E5E7EB';
    C.normalBg='#DCFCE7'; C.normalInk='#15803D';
    C.elevBg='#FEF3C7';   C.elevInk='#B45309';
    C.highBg='#FEE2E2';   C.highInk='#B91C1C';
    C.tealSoft='#ECFDF5'; C.blueSoft='#EFF6FF'; C.softGrey='#F9FAFB';
end

function b = banner(title, sub, color)
    import mlreportgen.dom.*
    b = Table(); b.Width='100%'; b.Border='none';
    r = TableRow(); e = TableEntry();
    p1 = Paragraph(title); p1.Style = {Bold, FontSize('17pt'), Color('white'), HAlign('center')};
    p2 = Paragraph(sub);   p2.Style = {FontSize('9.5pt'), Color('white'), HAlign('center')};
    append(e, p1); append(e, p2);
    e.Style = {BackgroundColor(color), InnerMargin('12pt','12pt','12pt','12pt')};
    append(r, e); append(b, r);
end

function t = sectionTitle(txt, C)
    import mlreportgen.dom.*
    t = Paragraph(upper(txt));
    t.Style = {Bold, FontSize('9pt'), Color(C.ink3), OuterMargin('0','0','0','5pt')};
end

function box = softBox(title, body, C)
    import mlreportgen.dom.*
    box = Table(); box.Width='100%'; box.Border='none';
    r = TableRow(); e = TableEntry();
    tt = Paragraph(upper(title)); tt.Style = {Bold, FontSize('8.5pt'), Color(C.ink3)};
    append(e, tt);
    for ln = strsplit(string(body), newline)'
        bp = Paragraph(char(ln)); bp.Style = {FontSize('9.5pt'), Color(C.ink2)};
        append(e, bp);
    end
    e.Style = {BackgroundColor(C.softGrey), InnerMargin('10pt','10pt','10pt','10pt'), ...
               Border('solid', C.line, '1px')};
    append(r, e); append(box, r);
    box.Style = {OuterMargin('0','0','0','8pt')};
end

function card = guideCard(title, body, bg, C)
    import mlreportgen.dom.*
    card = Table(); card.Width='100%'; card.Border='none';
    r = TableRow(); e = TableEntry();
    tt = Paragraph(upper(title)); tt.Style = {Bold, FontSize('8.5pt'), Color(C.ink)};
    bp = Paragraph(char(body));   bp.Style = {FontSize('9.5pt'), Color(C.ink2)};
    append(e, tt); append(e, bp);
    e.Style = {BackgroundColor(bg), InnerMargin('10pt','10pt','10pt','10pt'), Border('solid', C.line, '1px')};
    append(r, e); append(card, r);
end

function bar = confBar(conf, C)
    import mlreportgen.dom.*
    pct = max(2, round(100*conf));
    bar = Table(); bar.Width='100%'; bar.Border='none';
    bar.Style = {OuterMargin('0','4pt','0','0')};
    r = TableRow();
    fill = TableEntry();
    fill.Style = {Width(sprintf('%d%%', pct)), BackgroundColor(C.teal), InnerMargin('0','0','3pt','3pt')};
    append(fill, Paragraph(' '));
    rest = TableEntry();
    rest.Style = {Width(sprintf('%d%%', 100-pct)), BackgroundColor(C.line), InnerMargin('0','0','3pt','3pt')};
    append(rest, Paragraph(' '));
    append(r, fill); append(r, rest);
    append(bar, r);
end

function row = findHeader(C)
    import mlreportgen.dom.*
    row = TableRow();
    for h = {'Indicator','Normal','Detected','Threshold','Status'}
        e = TableEntry(); p = Paragraph(h{1});
        p.Style = {Bold, FontSize('8pt'), Color(C.ink3)};
        append(e, p);
        e.Style = {BackgroundColor(C.softGrey), InnerMargin('7pt','7pt','5pt','5pt')};
        append(row, e);
    end
end

function row = findRow(ind, lo, res, hi, status, C)
    import mlreportgen.dom.*
    switch status
        case 'high';     bg = C.highBg;   ink = C.highInk;   lbl = 'High';
        case 'elevated'; bg = C.elevBg;   ink = C.elevInk;   lbl = 'Elevated';
        otherwise;       bg = C.normalBg; ink = C.normalInk; lbl = 'Normal';
    end
    row = TableRow();
    cells = {ind, lo, res, hi};
    styles = {{Bold}, {}, {Bold}, {}};
    for k = 1:4
        e = TableEntry(); p = Paragraph(cells{k});
        p.Style = [{FontSize('9pt'), Color(C.ink2)}, styles{k}];
        append(e, p); e.Style = {InnerMargin('7pt','7pt','5pt','5pt')};
        append(row, e);
    end
    se = TableEntry();
    sp = Paragraph(lbl); sp.Style = {Bold, FontSize('8pt'), Color(ink), HAlign('center')};
    append(se, sp);
    se.Style = {BackgroundColor(bg), InnerMargin('7pt','7pt','5pt','5pt')};
    append(row, se);
end

function d = disclaimer(C)
    import mlreportgen.dom.*
    d = Table(); d.Width='100%'; d.Border='none'; d.Style = {OuterMargin('0','7pt','0','0')};
    r = TableRow(); e = TableEntry();
    p = Paragraph(['This report is produced by a hackathon prototype (SIH 2026, PS 26038) and is ' ...
        'NOT a certified medical device. All findings must be reviewed and confirmed by a ' ...
        'qualified ophthalmologist before any clinical decision.']);
    p.Style = {Italic, FontSize('7.5pt'), Color(C.ink3)};
    append(e, p);
    e.Style = {BackgroundColor(C.softGrey), InnerMargin('8pt','8pt','7pt','7pt')};
    append(r, e); append(d, r);
end

function s = vspace(h)
    import mlreportgen.dom.*
    s = Paragraph(' '); s.Style = {FontSize('1pt'), OuterMargin('0','0','0',h)};
end

% ---- small helpers ----
function [meaning, nextStep] = guidance(grade, refer)
    switch grade
        case 0
            meaning = 'The retina shows no signs of diabetic eye disease.';
        case 1
            meaning = 'A few early microaneurysms are present - the mildest stage of diabetic retinopathy.';
        case 2
            meaning = 'Moderate diabetic retinopathy: more than microaneurysms alone, with some bleeding or deposits.';
        case 3
            meaning = 'Severe (non-proliferative) diabetic retinopathy - a high risk of progression to sight-threatening disease.';
        otherwise
            meaning = 'Proliferative diabetic retinopathy: abnormal new blood vessels are growing. This is the most advanced stage.';
    end
    if refer
        nextStep = 'Refer to an ophthalmologist. Keep blood sugar and blood pressure well controlled in the meantime.';
    else
        nextStep = 'Continue annual eye screening. Maintain good control of blood sugar, blood pressure and cholesterol.';
    end
end

function v = gv(s, f, dflt)
    if isstruct(s) && isfield(s,f) && ~isempty(s.(f)); v = s.(f); else; v = dflt; end
end
function o = ternary(c,a,b); if c; o = a; else; o = b; end; end
function s = numstr(x); s = num2str(x); end
function m = methodName(h)
    switch lower(char(h))
        case 'gradcam';               m = 'Grad-CAM';
        case {'occlusion','occlusion-sensitivity'}; m = 'occlusion sensitivity';
        otherwise;                    m = 'lesion-evidence map';
    end
end
function st = statusOf(v, warnAt, highAt)
    v = double(v);
    if v >= highAt; st = 'high'; elseif v >= warnAt; st = 'elevated'; else; st = 'normal'; end
end
