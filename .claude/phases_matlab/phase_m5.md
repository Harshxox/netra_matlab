# Phase M-5 — Data Layer & Patient History

**Track:** MATLAB | **Owner:** B4 | **Day:** 4–5
**Depends on:** M-0 | **Blocks:** M-7, M-8 | **Parallel with:** M-6

---

## Goal
Build the persistence layer — save every screening to a `.mat` table, look up
patient history, and build the trend string. All code in `src/datalayer/`.

---

## Features

### F1 — DB Init (`initDB.m`)
Load on startup. Create empty table if first run.
```matlab
function db = initDB()
    dbPath = 'netra_db.mat';
    if isfile(dbPath)
        data = load(dbPath, 'db');
        db   = data.db;
    else
        db = table( ...
            string.empty(0,1), ...   % patientId
            string.empty(0,1), ...   % eye
            datetime.empty(0,1), ... % date
            double.empty(0,1), ...   % grade
            string.empty(0,1), ...   % gradeLabel
            logical.empty(0,1), ...  % referable
            double.empty(0,1), ...   % confidence
            string.empty(0,1), ...   % qualityStatus
            string.empty(0,1), ...   % routing
            string.empty(0,1), ...   % reviewStatus
            double.empty(0,1), ...   % finalGrade
            string.empty(0,1), ...   % reportPath
            'VariableNames', { ...
                'patientId','eye','date','grade','gradeLabel', ...
                'referable','confidence','qualityStatus','routing', ...
                'reviewStatus','finalGrade','reportPath'} ...
        );
        save(dbPath, 'db');
        disp('New database created: netra_db.mat')
    end
end
```

---

### F2 — Save Screening (`saveScreening.m`)
```matlab
function saveScreening(record)
    persistent db
    if isempty(db); db = initDB(); end

    newRow = table( ...
        string(record.patientId), ...
        string(record.eye), ...
        datetime('now'), ...
        record.result.grade, ...
        string(record.result.gradeLabel), ...
        record.result.referable, ...
        record.result.confidence, ...
        string(record.quality.status), ...
        string(record.routing), ...
        string('pending'), ...
        NaN, ...
        string(''), ...
        'VariableNames', { ...
            'patientId','eye','date','grade','gradeLabel', ...
            'referable','confidence','qualityStatus','routing', ...
            'reviewStatus','finalGrade','reportPath'} ...
    );

    db = [db; newRow];
    save('netra_db.mat', 'db');
end
```

---

### F3 — Get Patient History (`getHistory.m`)
```matlab
function [history, records] = getHistory(patientId)
    persistent db
    if isempty(db); db = initDB(); end

    records = db(strcmp(db.patientId, patientId), :);
    records = sortrows(records, 'date');    % oldest first

    if isempty(records)
        history.priorGrades = [];
        history.trend       = 'First screening';
        return
    end

    history.priorGrades = records.grade';

    % Build trend string
    labels = {'No DR','Mild','Moderate','Severe','Proliferative DR'};
    gradeStrs = labels(records.grade + 1);

    if height(records) == 1
        history.trend = gradeStrs{1};
    else
        history.trend = strjoin(gradeStrs, ' → ');
        % Add time span
        span = records.date(end) - records.date(1);
        months = round(days(span) / 30);
        if months > 0
            history.trend = [history.trend sprintf(' over %d months', months)];
        end
    end
end
```

---

### F4 — Update Review Decision (`saveReviewDecision.m`)
Called from the dashboard when ophthalmologist clicks Agree or Override.
```matlab
function saveReviewDecision(patientId, eyeSide, finalGrade, notes, reviewerId)
    persistent db
    if isempty(db); db = initDB(); end

    % Find the most recent pending record for this patient+eye
    idx = find( ...
        strcmp(db.patientId, patientId) & ...
        strcmp(db.eye, eyeSide) & ...
        strcmp(db.reviewStatus, 'pending'), 1, 'last');

    if isempty(idx)
        warning('No pending record found for patient %s', patientId);
        return
    end

    db.reviewStatus(idx) = "reviewed";
    db.finalGrade(idx)   = finalGrade;
    save('netra_db.mat', 'db');
end
```

---

### F5 — Quick Stats (`dbStats.m`)
Used by the optional district dashboard (O-4).
```matlab
function stats = dbStats()
    persistent db
    if isempty(db); db = initDB(); end

    stats.totalScreened      = height(db);
    stats.referralRate       = mean(db.referable) * 100;
    stats.pendingReview      = sum(strcmp(db.reviewStatus, 'pending'));
    stats.screenedToday      = sum(dateshift(db.date,'start','day') == dateshift(datetime('now'),'start','day'));
    stats.gradeDistribution  = histcounts(db.grade, 0:5) / max(height(db), 1) * 100;
end
```

---

## Done when
- [ ] `saveScreening(record)` appends correctly and persists across MATLAB sessions
- [ ] `getHistory('PT-001')` returns prior grades + trend string for a known patient
- [ ] `saveReviewDecision` updates the record status to `'reviewed'`
- [ ] Empty DB case handled (first screening for a new patient)
- [ ] DB schema matches `data_contract.json` fields
