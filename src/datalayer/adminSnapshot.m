function snap = adminSnapshot(patientDbPath, screenDbPath)
%ADMINSNAPSHOT  Everything the admin console needs, as a plain struct (jsonencode-ready).
%
%   snap = adminSnapshot()
%
%   snap.stats     - totals (patients, screenings, referrals, pending, today)
%   snap.grades    - 1x5 count of latest-grade per patient
%   snap.villages  - struct array {name, count, referrals}
%   snap.patients  - struct array, one per registered patient, with the
%                    latest screening summary joined in
%   snap.recent    - the last ~15 screenings across all patients

    if nargin < 1 || isempty(patientDbPath); patientDbPath = 'netra_patients.mat'; end
    if nargin < 2 || isempty(screenDbPath);  screenDbPath  = 'netra_db.mat';       end

    P = initPatientDB(patientDbPath);
    S = initDB(screenDbPath);

    n = height(P);
    labels = ["No DR","Mild","Moderate","Severe","Proliferative DR"];

    patients = struct('patientId',{},'name',{},'age',{},'sex',{},'village',{}, ...
        'phone',{},'registeredOn',{},'screenings',{},'lastGrade',{},'lastGradeLabel',{}, ...
        'lastDate',{},'lastRouting',{},'referable',{},'reviewStatus',{});

    latestGrade = nan(n,1);
    for i = 1:n
        pid = P.patientId(i);
        rows = S(S.patientId == pid, :);
        rows = sortrows(rows, 'date');

        patients(i).patientId    = char(pid);
        patients(i).name         = char(P.name(i));
        patients(i).age          = numOrEmpty(P.age(i));
        patients(i).sex          = char(P.sex(i));
        patients(i).village      = char(P.village(i));
        patients(i).phone        = char(P.phone(i));
        patients(i).registeredOn = char(string(P.registeredOn(i)));
        patients(i).screenings   = height(rows);

        if isempty(rows)
            patients(i).lastGrade = []; patients(i).lastGradeLabel = '';
            patients(i).lastDate = ''; patients(i).lastRouting = '';
            patients(i).referable = false; patients(i).reviewStatus = '';
        else
            last = rows(end,:);
            g = last.grade;
            patients(i).lastGrade      = numOrEmpty(g);
            if ~isnan(g); latestGrade(i) = g; patients(i).lastGradeLabel = char(labels(g+1));
            else; patients(i).lastGradeLabel = 'Ungradable'; end
            patients(i).lastDate     = char(string(last.date));
            patients(i).lastRouting  = char(last.routing);
            patients(i).referable    = logical(last.referable);
            patients(i).reviewStatus = char(last.reviewStatus);
        end
    end

    % --- aggregate stats ---------------------------------------------
    today = dateshift(datetime('now'),'start','day');
    snap.stats.totalPatients   = n;
    snap.stats.totalScreenings = height(S);
    snap.stats.referrals       = sum(S.referable == true);
    snap.stats.referralRate    = 100 * mean([S.referable; false]) ;   % guard empty
    if height(S) == 0; snap.stats.referralRate = 0; end
    snap.stats.pendingReview   = sum(S.reviewStatus == "pending");
    snap.stats.screenedToday   = sum(dateshift(S.date,'start','day') == today);
    snap.stats.registeredToday = sum(dateshift(P.registeredOn,'start','day') == today);

    gd = zeros(1,5);
    lv = latestGrade(~isnan(latestGrade));
    for k = 0:4; gd(k+1) = sum(lv == k); end
    snap.grades = gd;

    % --- villages ----------------------------------------------------
    vlist = unique(P.village);
    vlist(vlist == "" | ismissing(vlist)) = [];
    villages = struct('name',{},'patients',{},'referrals',{});
    for j = 1:numel(vlist)
        vp = P.patientId(P.village == vlist(j));
        vs = S(ismember(S.patientId, vp), :);
        villages(j).name      = char(vlist(j));
        villages(j).patients  = numel(vp);
        villages(j).referrals = sum(vs.referable == true);
    end
    snap.villages = villages;

    % --- recent screenings ----------------------------------------
    R = sortrows(S, 'date', 'descend');
    R = R(1:min(15, height(R)), :);
    recent = struct('patientId',{},'name',{},'date',{},'grade',{},'gradeLabel',{}, ...
        'routing',{},'reviewStatus',{});
    for i = 1:height(R)
        pn = P.name(P.patientId == R.patientId(i));
        recent(i).patientId    = char(R.patientId(i));
        recent(i).name         = char(firstOr(pn, ""));
        recent(i).date         = char(string(R.date(i)));
        recent(i).grade        = numOrEmpty(R.grade(i));
        recent(i).gradeLabel   = char(R.gradeLabel(i));
        recent(i).routing      = char(R.routing(i));
        recent(i).reviewStatus = char(R.reviewStatus(i));
    end
    snap.recent   = num2cell(recent);
    snap.patients = num2cell(patients);
    snap.villages = num2cell(snap.villages);
end

function v = numOrEmpty(x); if isnan(x); v = []; else; v = double(x); end; end
function v = firstOr(a, d); if isempty(a); v = d; else; v = a(1); end; end
