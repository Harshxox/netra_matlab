function [history, records] = getHistory(patientId, dbPath)
%GETHISTORY  Prior screenings for a patient + a human-readable trend string.
%
%   [history, records] = getHistory('PT-001')
%
%   history.priorGrades - row vector of prior grades, oldest first
%   history.trend       - e.g. "No DR -> Mild -> Moderate over 8 months"
%                         or "First screening" when there is no prior record
%   records             - the matching table rows, sorted by date

    if nargin < 2 || isempty(dbPath); dbPath = 'netra_db.mat'; end
    db = initDB(dbPath);

    records = db(db.patientId == string(patientId), :);
    records = sortrows(records, 'date');

    if isempty(records)
        history.priorGrades = [];
        history.trend = 'First screening';
        return
    end

    g = records.grade(:).';
    g = g(~isnan(g));
    history.priorGrades = g;

    labels = {'No DR','Mild','Moderate','Severe','Proliferative DR'};
    if isempty(g)
        history.trend = 'Prior visit(s) ungradable';
        return
    end
    if numel(g) == 1
        history.trend = labels{g(1)+1};
        return
    end

    seq = labels(g + 1);
    trend = strjoin(seq, ' -> ');
    span  = records.date(end) - records.date(1);
    months = round(days(span) / 30);
    if months >= 1
        trend = sprintf('%s over %d month(s)', trend, months);
    end
    history.trend = trend;
end
