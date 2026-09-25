function db = initPatientDB(dbPath)
%INITPATIENTDB  Load the patient registry (a table in a .mat file), or create it.
%
%   db = initPatientDB()
%   db = initPatientDB('netra_patients.mat')
%
%   One row per registered patient. Screening results live separately in
%   netra_db.mat, linked by patientId. Image blobs are never stored.

    if nargin < 1 || isempty(dbPath); dbPath = 'netra_patients.mat'; end

    if isfile(dbPath)
        s = load(dbPath, 'db');
        db = s.db;
        return
    end

    db = table( ...
        string.empty(0,1), ...   % patientId
        string.empty(0,1), ...   % name
        double.empty(0,1), ...   % age
        string.empty(0,1), ...   % sex  (M/F/Other)
        string.empty(0,1), ...   % phone
        string.empty(0,1), ...   % village / PHC
        double.empty(0,1), ...   % diabetesYears
        string.empty(0,1), ...   % notes
        datetime.empty(0,1), ... % registeredOn
        string.empty(0,1), ...   % registeredBy
        'VariableNames', {'patientId','name','age','sex','phone','village', ...
            'diabetesYears','notes','registeredOn','registeredBy'});

    save(dbPath, 'db');
    fprintf('Created patient registry: %s\n', dbPath);
end
