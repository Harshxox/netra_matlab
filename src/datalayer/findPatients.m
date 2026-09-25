function T = findPatients(query, dbPath)
%FINDPATIENTS  Search the registry by id / name / phone (case-insensitive substring).
%
%   T = findPatients()          % all patients
%   T = findPatients('ram')     % matches on id, name or phone

    if nargin < 2 || isempty(dbPath); dbPath = 'netra_patients.mat'; end
    db = initPatientDB(dbPath);

    if nargin >= 1 && ~isempty(query) && strlength(string(query)) > 0
        q = lower(string(query));
        hit = contains(lower(db.patientId), q) | ...
              contains(lower(db.name), q) | ...
              contains(lower(db.phone), q);
        db = db(hit, :);
    end
    T = sortrows(db, 'registeredOn', 'descend');
end
