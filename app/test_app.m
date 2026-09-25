function test_app()
%TEST_APP  Headless test of the auth + patient-registry + admin data layer.
%          (The GUI itself is launched with NetraApp.)

    fprintf('=== app data-layer test ===\n\n');
    warning('off','all');

    % fresh DBs
    for f = {'netra_patients.mat','netra_db.mat'}
        if isfile(f{1}); delete(f{1}); end
    end

    % --- auth ------------------------------------------------------
    assert( checkAuth('admin','netra2026'),        'admin login should pass');
    [ok,role] = checkAuth('phc','phc2026');
    assert(ok && strcmp(role,'operator'),          'phc login should be operator');
    assert(~checkAuth('admin','wrong'),            'bad password should fail');
    fprintf('  auth: admin + operator + reject OK\n');

    % --- register + retrieve ------------------------------------
    [pid1,~] = registerPatient(struct('name','Ramesh Kumar','age',58,'sex','M', ...
        'phone','9876543210','village','Rampur PHC','diabetesYears',12,'registeredBy','PHC Health Worker'));
    assert(startsWith(pid1,'PT-'), 'auto id should be generated');
    p = getPatient(pid1);
    assert(strcmp(p.name,'Ramesh Kumar') && p.age == 58, 'profile round-trip');
    fprintf('  registered %s (%s, %dy)\n', pid1, p.name, p.age);

    [pid2,~] = registerPatient(struct('name','Sita Devi','age',63,'sex','F','village','Rampur PHC'));
    registerPatient(struct('name','Mohan Lal','age',49,'sex','M','village','Bela PHC'));

    % update in place
    registerPatient(struct('patientId',pid1,'name','Ramesh Kumar','age',59,'notes','hypertension'));
    assert(getPatient(pid1).age == 59, 'update in place');
    assert(height(initPatientDB()) == 3, 'still 3 patients after update');
    fprintf('  update-in-place OK, 3 patients total\n');

    % --- search --------------------------------------------------
    T = findPatients('sita');
    assert(height(T) == 1 && T.name(1) == "Sita Devi", 'search by name');
    T = findPatients(pid1);
    assert(height(T) == 1, 'search by id');
    fprintf('  search by name / id OK\n');

    % --- link a screening --------------------------------------
    s = dir('data/samples/*.png');
    rec = runPipeline(fullfile(s(1).folder,s(1).name), pid1, 'OD', struct('makePdf',false));
    assert(~isempty(rec.result), 'screening ran');
    [~,recs] = getHistory(pid1);
    assert(height(recs) >= 1, 'screening linked to patient');
    fprintf('  screening linked: %s -> grade %d\n', pid1, rec.result.grade);

    % --- admin snapshot ---------------------------------------
    snap = adminSnapshot();
    assert(snap.stats.totalPatients == 3, 'snapshot patient count');
    assert(numel(snap.patients) == 3, 'snapshot patient array');
    assert(snap.stats.totalScreenings >= 1, 'snapshot screening count');
    js = jsonencode(snap); jsondecode(js);            % must serialize
    fprintf('  adminSnapshot: %d patients, %d screenings, %.0f%% referral, JSON %dKB\n', ...
        snap.stats.totalPatients, snap.stats.totalScreenings, snap.stats.referralRate, round(numel(js)/1024));

    % --- dossier ---------------------------------------------
    d = patientDossier(pid1);
    assert(strcmp(d.profile.name,'Ramesh Kumar'), 'dossier profile');
    assert(numel(d.screenings) >= 1, 'dossier screenings');
    jsondecode(jsonencode(d));
    fprintf('  patientDossier: %d screening(s), trend "%s"\n', numel(d.screenings), d.history.trend);

    % --- dashboard payload carries patient -------------------
    rec.patient = getPatient(pid1);
    pl = buildDashboardPayload(rec);
    assert(isfield(pl,'patient') && strcmp(pl.patient.name,'Ramesh Kumar'), 'payload has patient');
    jsondecode(jsonencode(pl));
    fprintf('  dashboard payload carries patient context OK\n');

    fprintf('\n=== all app data-layer assertions passed ===\n');
end
