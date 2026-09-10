function ok = saveReviewDecision(patientId, eyeSide, finalGrade, notes, reviewerId, dbPath)
%SAVEREVIEWDECISION  Record the ophthalmologist's Agree/Override on the latest
%                    pending screening for a patient+eye.
%
%   ok = saveReviewDecision('PT-001','OD', 2, 'Agree with AI', 'reviewer_01')
%
%   Finds the most recent row with reviewStatus == "pending" for that
%   patient+eye, sets it to "reviewed", stores finalGrade + notes. Returns
%   false (with a warning) if there is no pending row.

    if nargin < 6 || isempty(dbPath); dbPath = 'netra_db.mat'; end
    if nargin < 5; reviewerId = ""; end
    if nargin < 4; notes = ""; end
    db = initDB(dbPath);

    idx = find(db.patientId == string(patientId) & ...
               db.eye       == string(eyeSide)  & ...
               db.reviewStatus == "pending", 1, 'last');

    if isempty(idx)
        warning('saveReviewDecision:noPending', ...
            'No pending screening for %s / %s.', patientId, eyeSide);
        ok = false; return
    end

    db.reviewStatus(idx) = "reviewed";
    db.finalGrade(idx)   = finalGrade;
    db.reviewNotes(idx)  = string(notes) + " [" + string(reviewerId) + "]";
    save(dbPath, 'db');
    ok = true;
end
