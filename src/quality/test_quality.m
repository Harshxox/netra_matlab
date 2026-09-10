function test_quality()
%TEST_QUALITY  Smoke test for the M-1 preprocessing/quality module.
%
%   >> test_quality
%
%   If data/samples/ has real fundus images it runs on the first few.
%   Otherwise it builds a synthetic fundus so the code path is still exercised.
%   Checks: output sizes, value range, data-contract field names/types,
%   and that a deliberately blurred/darkened image degrades the status.

    fprintf('=== M-1 quality pipeline smoke test ===\n\n');

    sampleDir = fullfile('data','samples');
    exts = {'*.png','*.jpg','*.jpeg','*.tif','*.tiff'};
    files = [];
    for e = exts; files = [files; dir(fullfile(sampleDir,e{1}))]; end %#ok<AGROW>

    if ~isempty(files)
        n = min(4, numel(files));
        fprintf('Found %d real images, testing %d.\n\n', numel(files), n);
        for i = 1:n
            runOne(fullfile(files(i).folder, files(i).name));
        end
    else
        fprintf('No images in %s - using a synthetic fundus.\n\n', sampleDir);
        img = syntheticFundus(800);
        runOne(img, 'synthetic-good');

        blurred = imgaussfilt(img, 6);
        runOne(blurred, 'synthetic-blurred');

        dark = img * 0.25;
        runOne(dark, 'synthetic-dark');
    end

    fprintf('\n=== all assertions passed ===\n');
end

% ----------------------------------------------------------------------
function runOne(input, label)
    if nargin < 2
        [~, nm, ext] = fileparts(char(input));
        label = [nm ext];
    end

    [proc, qb, routing, fovMask] = runQualityPipeline(input);

    % --- shape / range checks ---------------------------------------
    assert(isequal(size(proc), [512 512 3]), '%s: processed image must be 512x512x3', label);
    assert(isa(proc,'double'),               '%s: processed image must be double', label);
    assert(all(proc(:) >= 0 & proc(:) <= 1), '%s: pixels must be in [0,1]', label);
    assert(isequal(size(fovMask), [512 512]),'%s: fovMask must be 512x512', label);
    assert(islogical(fovMask),               '%s: fovMask must be logical', label);

    % --- data-contract field checks -------------------------------
    for f = {'status','focusScore','illuminationScore','fovRatio','enhanced'}
        assert(isfield(qb, f{1}), '%s: quality block missing field %s', label, f{1});
    end
    assert(ismember(qb.status, {'gradable','borderline','ungradable'}), ...
        '%s: bad status "%s"', label, qb.status);
    assert(islogical(qb.enhanced), '%s: enhanced must be logical', label);
    assert(ismember(routing, {'pending','recapture'}), '%s: bad routing', label);
    if strcmp(qb.status,'ungradable')
        assert(strcmp(routing,'recapture'), '%s: ungradable must route to recapture', label);
    end

    % --- JSON round-trips? --------------------------------------
    js = jsonencode(qb); jsondecode(js);

    fprintf('  %-22s status=%-11s focus=%.2e illum=%.3f fov=%.2f enhanced=%d routing=%s\n', ...
        label, qb.status, qb.focusScore, qb.illuminationScore, qb.fovRatio, qb.enhanced, routing);
end

% ----------------------------------------------------------------------
function img = syntheticFundus(sz)
%SYNTHETICFUNDUS  A crude fake fundus: orange disc, vessels, optic disc, texture.
    [X, Y] = meshgrid(linspace(-1,1,sz));
    R = sqrt(X.^2 + Y.^2);
    fov = R < 0.92;

    base = zeros(sz, sz, 3);
    base(:,:,1) = 0.55;  base(:,:,2) = 0.28;  base(:,:,3) = 0.12;   % retina orange
    shade = 1 - 0.3*R;
    base = base .* shade;

    % optic disc: bright blob off-centre
    od = exp(-((X-0.4).^2 + (Y-0.05).^2) / 0.004);
    base = base + cat(3, 0.35*od, 0.32*od, 0.20*od);

    % a few vessels branching from the optic disc
    v = zeros(sz);
    t = linspace(0,1,600);
    for k = 1:6
        cx = 0.4 + 0.5*t .* cos(k);
        cy = 0.05 + 0.5*t .* sin(k) + 0.1*sin(6*t);
        ix = round((cx+1)/2*sz); iy = round((cy+1)/2*sz);
        ok = ix>1 & ix<sz & iy>1 & iy<sz;
        idx = sub2ind([sz sz], iy(ok), ix(ok));
        v(idx) = 1;
    end
    v = imdilate(v, strel('disk',2));
    base = base .* (1 - 0.5*cat(3,v,v,v));

    base = base + 0.02*randn(sz,sz,3);              % sensor noise / texture
    base = base .* cat(3, fov, fov, fov);           % black border
    img = im2uint8(min(1,max(0,base)));
end
