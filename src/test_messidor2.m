function test_messidor2()
%TEST_MESSIDOR2  Verify validateMessidor2 wiring using a tiny synthetic set
%                built from the APTOS samples (no real Messidor-2 needed).

    fprintf('=== validateMessidor2 wiring test ===\n\n');
    warning('off','all');

    tmp = fullfile(tempdir,'messidor2_fake');
    imgd = fullfile(tmp,'images');
    if isfolder(tmp); rmdir(tmp,'s'); end
    mkdir(imgd);

    % borrow 6 APTOS images, give them Messidor-style names + grades
    src = dir('data/samples/*.png');
    L = readtable('data/train.csv','TextType','string');
    rows = strings(0); grades = [];
    for i = 1:min(6,numel(src))
        [~,b] = fileparts(src(i).name);
        j = find(L.id_code == string(b), 1);
        if isempty(j); continue; end
        newName = sprintf('IM%04d.jpg', i);
        copyfile(fullfile(src(i).folder,src(i).name), fullfile(imgd,newName));
        rows(end+1) = newName;          %#ok<AGROW>
        grades(end+1) = L.diagnosis(j); %#ok<AGROW>
    end

    % write a Google-adjudicated-style CSV
    csv = fullfile(tmp,'labels.csv');
    T = table(rows(:), grades(:), ones(numel(rows),1), ...
        'VariableNames', {'image_id','adjudicated_dr_grade','adjudicated_gradable'});
    writetable(T, csv);

    M = validateMessidor2(imgd, csv, struct('useParallel',false,'outFile',fullfile(tempdir,'m2test')));

    assert(M.n >= 3, 'expected at least 3 scored images');
    assert(M.sensitivity >= 0 && M.sensitivity <= 1, 'sensitivity out of range');
    assert(isfinite(M.qwk), 'QWK not finite');
    assert(isfile(fullfile(tempdir,'m2test.txt')), 'summary txt not written');

    fprintf('\n=== wiring OK (sens=%.2f spec=%.2f qwk=%.2f on %d fake images) ===\n', ...
        M.sensitivity, M.specificity, M.qwk, M.n);
end
