function test_quality_degrade(imgPath)
%TEST_QUALITY_DEGRADE  Check that deliberately degraded images are downgraded.
%
%   test_quality_degrade                       % uses first image in data/samples
%   test_quality_degrade('data/samples/x.png')
%
%   Takes one good image and applies blur / darkening / brightening / a
%   partial-frame crop, then prints the scores + status for each. Use this to
%   confirm classifyQuality's thresholds actually reject bad input.

    if nargin < 1 || isempty(imgPath)
        f = dir('data/samples/*.png');
        assert(~isempty(f), 'No images in data/samples');
        imgPath = fullfile(f(1).folder, f(1).name);
    end
    img = im2double(imread(imgPath));

    cases = { ...
        'original',  img; ...
        'blur s2',   imgaussfilt(img, 2); ...
        'blur s4',   imgaussfilt(img, 4); ...
        'blur s8',   imgaussfilt(img, 8); ...
        'dark 0.3x', img * 0.30; ...
        'dark 0.5x', img * 0.50; ...
        'bright 2x', min(1, img * 2.0); ...
        'half-frame',halfFrame(img) };

    fprintf('%-12s %12s %10s %9s   %s\n','case','focus','illum','fov','status');
    fprintf('%s\n', repmat('-',1,66));
    for i = 1:size(cases,1)
        [~, qb] = runQualityPipeline(cases{i,2});
        fprintf('%-12s %12.4f %10.3f %9.3f   %s\n', ...
            cases{i,1}, qb.focusScore, qb.illuminationScore, qb.fovRatio, qb.status);
    end
end

function im = halfFrame(im)
    im(:, 1:round(size(im,2)*0.6), :) = 0;   % blank out 60% of the width
end
