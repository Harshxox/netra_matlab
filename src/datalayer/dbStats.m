function stats = dbStats(dbPath)
%DBSTATS  Aggregate numbers for the district view / PPT (from the .mat table).
%
%   stats = dbStats()

    if nargin < 1 || isempty(dbPath); dbPath = 'netra_db.mat'; end
    db = initDB(dbPath);

    n = height(db);
    stats.totalScreened = n;
    if n == 0
        stats.referralRate = 0; stats.pendingReview = 0;
        stats.screenedToday = 0; stats.gradeDistribution = zeros(1,5);
        return
    end

    stats.referralRate     = 100 * mean(db.referable);
    stats.pendingReview    = sum(db.reviewStatus == "pending");
    stats.screenedToday    = sum(dateshift(db.date,'start','day') == dateshift(datetime('now'),'start','day'));
    g = db.grade(~isnan(db.grade));
    stats.gradeDistribution = histcounts(g, -0.5:1:4.5) / max(numel(g),1) * 100;
end
