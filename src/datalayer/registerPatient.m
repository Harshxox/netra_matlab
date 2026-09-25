function [patientId, record] = registerPatient(profile, dbPath)
%REGISTERPATIENT  Add (or update) a patient in the registry.
%
%   [patientId, record] = registerPatient(profile)
%   [...] = registerPatient(profile, 'netra_patients.mat')
%
%   profile - struct with any of: patientId, name, age, sex, phone, village,
%             diabetesYears, notes, registeredBy
%             If patientId is blank a new one is generated (PT-YYYYMMDD-####).
%             If patientId already exists, that row is updated in place.
%
%   Returns the resolved patientId and the full stored row as a struct.

    if nargin < 2 || isempty(dbPath); dbPath = 'netra_patients.mat'; end
    db = initPatientDB(dbPath);

    g = @(f,d) getdef(profile, f, d);
    pid = strtrim(string(g('patientId','')));

    if pid == "" || ismissing(pid)
        n = height(db) + 1;
        pid = "PT-" + string(datetime('now','Format','yyyyMMdd')) + "-" + sprintf('%04d', n);
        while any(db.patientId == pid)
            n = n + 1;
            pid = "PT-" + string(datetime('now','Format','yyyyMMdd')) + "-" + sprintf('%04d', n);
        end
    end

    row = table( pid, ...
        string(g('name','')), double(g('age',NaN)), string(g('sex','')), ...
        string(g('phone','')), string(g('village','')), ...
        double(g('diabetesYears',NaN)), string(g('notes','')), ...
        datetime('now'), string(g('registeredBy','')), ...
        'VariableNames', db.Properties.VariableNames);

    idx = find(db.patientId == pid, 1);
    if isempty(idx)
        db = [db; row];
    else
        row.registeredOn = db.registeredOn(idx);   % keep original registration time
        db(idx, :) = row;
    end

    save(dbPath, 'db');
    patientId = char(pid);
    record = table2struct(db(db.patientId == pid, :));
end

function v = getdef(s, f, d)
    if isstruct(s) && isfield(s,f) && ~isempty(s.(f)) && ~(ischar(s.(f)) && isempty(strtrim(s.(f))))
        v = s.(f);
    else
        v = d;
    end
end
