function seedDemoPatients()
%SEEDDEMOPATIENTS  Populate the registry + screenings with a demo cohort.
%   For the demo / video only. Wipes netra_patients.mat and netra_db.mat first.

    warning('off','all');
    for f = {'netra_patients.mat','netra_db.mat'}
        if isfile(f{1}); delete(f{1}); end
    end

    people = {
        'Ramesh Kumar',   58,'M','9876500001','Rampur PHC',   12,'hypertension'
        'Sita Devi',      63,'F','9876500002','Rampur PHC',   18,''
        'Mohan Lal',      49,'M','9876500003','Bela PHC',      7,''
        'Lakshmi Bai',    55,'F','9876500004','Bela PHC',     14,'on insulin'
        'Arun Prasad',    44,'M','9876500005','Chandanpur PHC',5,''
        'Kamala Nair',    67,'F','9876500006','Chandanpur PHC',22,'prior laser'
        'Vijay Singh',    52,'M','9876500007','Rampur PHC',    9,''
        'Farida Begum',   60,'F','9876500008','Bela PHC',     16,''
    };

    s = dir('data/samples/*.png');
    assert(~isempty(s), 'no sample images');

    for i = 1:size(people,1)
        [pid,~] = registerPatient(struct('name',people{i,1},'age',people{i,2}, ...
            'sex',people{i,3},'phone',people{i,4},'village',people{i,5}, ...
            'diabetesYears',people{i,6},'notes',people{i,7},'registeredBy','PHC Health Worker'));

        img = fullfile(s(mod(i-1, numel(s))+1).folder, s(mod(i-1, numel(s))+1).name);
        try
            rec = runPipeline(img, pid, 'OD');
            fprintf('  %-16s %s -> grade %d (%s)\n', people{i,1}, pid, rec.result.grade, rec.result.gradeLabel);
            if mod(i,2) == 0
                saveReviewDecision(pid, 'OD', rec.result.grade, 'Agree with AI', 'Dr. Reviewer');
            end
        catch e
            fprintf(2, '  %s failed: %s\n', people{i,1}, e.message);
        end
    end

    snap = adminSnapshot();
    fprintf('\nSeeded: %d patients, %d screenings, %.0f%% referral rate, %d pending review\n', ...
        snap.stats.totalPatients, snap.stats.totalScreenings, snap.stats.referralRate, snap.stats.pendingReview);
end
