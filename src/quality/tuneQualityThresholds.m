function T = tuneQualityThresholds(folder)
%TUNEQUALITYTHRESHOLDS  Print quality scores for every image in a folder.
%
%   tuneQualityThresholds('data/samples')
%
%   Use this to calibrate classifyQuality. Run it on a folder that mixes
%   clearly-good and clearly-bad images. Look at where focusScore /
%   illuminationScore / fovRatio separate the two groups, then edit the
%   defaults in classifyQuality.m (or pass a `thr` struct at call time).
%
%   Returns a table so you can sort/plot: T = tuneQualityThresholds(...)

    exts = {'*.png','*.jpg','*.jpeg','*.tif','*.tiff','*.bmp'};
    files = [];
    for e = exts
        files = [files; dir(fullfile(folder, e{1}))]; %#ok<AGROW>
    end
    if isempty(files)
        error('No images found in %s', folder);
    end

    name = strings(numel(files),1);
    focus = zeros(numel(files),1);
    illum = zeros(numel(files),1);
    fov   = zeros(numel(files),1);
    status = strings(numel(files),1);

    fprintf('%-28s %12s %12s %10s   %s\n', 'file','focus','illum','fovRatio','status');
    fprintf('%s\n', repmat('-',1,80));
    for i = 1:numel(files)
        p = fullfile(files(i).folder, files(i).name);
        try
            [~, qb] = runQualityPipeline(p);
        catch err
            fprintf('%-28s  ERROR: %s\n', files(i).name, err.message);
            continue
        end
        name(i)   = files(i).name;
        focus(i)  = qb.focusScore;
        illum(i)  = qb.illuminationScore;
        fov(i)    = qb.fovRatio;
        status(i) = qb.status;
        fprintf('%-28s %12.3e %12.4f %10.3f   %s\n', ...
            files(i).name, focus(i), illum(i), fov(i), qb.status);
    end

    T = table(name, focus, illum, fov, status);
end
