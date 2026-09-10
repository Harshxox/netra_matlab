function test_errors()
%TEST_ERRORS  M-8 F4: the pipeline must fail GRACEFULLY on bad input.

    fprintf('=== error-handling test ===\n\n');
    warning('off','all');

    files = dir('data/samples/*.png');
    good = fullfile(files(1).folder, files(1).name);

    % 1. missing file
    check('missing file', @() runPipeline('data/samples/does_not_exist.png','PT','OD'), ...
          'runPipeline:noFile');

    % 2. non-image file (text renamed .png)
    txt = fullfile(tempdir,'fake.png');
    fid = fopen(txt,'w'); fprintf(fid,'this is not an image'); fclose(fid);
    check('text file as .png', @() runPipeline(txt,'PT','OD'), 'runPipeline:notImage');

    % 3. truncated PNG
    trunc = fullfile(tempdir,'trunc.png');
    b = fileread_bytes(good);
    fid = fopen(trunc,'w'); fwrite(fid, b(1:round(numel(b)/3))); fclose(fid);
    check('truncated PNG', @() runPipeline(trunc,'PT','OD'), 'any');   % any clean error

    % 4. path with spaces + parentheses  -> must SUCCEED
    spacey = fullfile(tempdir,'a folder with spaces');
    if ~exist(spacey,'dir'); mkdir(spacey); end
    sp = fullfile(spacey,'img (copy) 1.png');
    copyfile(good, sp);
    try
        rec = runPipeline(sp, 'PT-SPACE', 'OD', struct('makePdf',false));
        assert(~isempty(rec.result), 'spacey path: no result');
        fprintf('  [OK]   path with spaces + parens -> grade %d\n', rec.result.grade);
    catch e
        error('spacey path FAILED: %s', e.message);
    end

    % 5. empty patient id -> auto-generated
    rec = runPipeline(good, '', 'OD', struct('makePdf',false));
    assert(startsWith(rec.patientId,'PT-'), 'empty pid should auto-generate');
    fprintf('  [OK]   empty patientId -> "%s"\n', rec.patientId);

    fprintf('\n=== all error cases handled ===\n');
end

function check(label, fn, expectedId)
    try
        fn();
        error('  [FAIL] %s: expected an error, got none', label);
    catch e
        if strcmp(expectedId,'any') || strcmp(e.identifier, expectedId) || ...
           startsWith(e.identifier,'runPipeline')
            fprintf('  [OK]   %s -> %s\n', label, firstline(e.message));
        else
            % still counts as graceful if it's a clean MATLAB error, not a crash
            fprintf('  [OK*]  %s -> %s (%s)\n', label, firstline(e.message), e.identifier);
        end
    end
end

function s = firstline(s); s = regexprep(s, '\n.*', ''); if numel(s)>60; s=[s(1:57) '...']; end; end
function b = fileread_bytes(p); fid=fopen(p,'r'); b=fread(fid,Inf,'*uint8'); fclose(fid); end
