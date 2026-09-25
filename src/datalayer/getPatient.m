function p = getPatient(patientId, dbPath)
%GETPATIENT  Return one patient's profile as a struct, or [] if not found.
%
%   p = getPatient('PT-20260910-0001')

    if nargin < 2 || isempty(dbPath); dbPath = 'netra_patients.mat'; end
    db = initPatientDB(dbPath);
    row = db(db.patientId == string(patientId), :);
    if isempty(row); p = []; return; end
    p = table2struct(row(1,:));
    if isnan(p.age);           p.age = -1;           end   % -1 = unknown (JSON-safe)
    if isnan(p.diabetesYears); p.diabetesYears = -1; end
    p.patientId     = char(p.patientId);
    p.name          = char(p.name);
    p.sex           = char(p.sex);
    p.phone         = char(p.phone);
    p.village       = char(p.village);
    p.notes         = char(p.notes);
    p.registeredBy  = char(p.registeredBy);
    try
        p.registeredOn = char(string(row.registeredOn(1), 'dd MMM yyyy'));
    catch
        p.registeredOn = char(string(p.registeredOn));
    end
end
