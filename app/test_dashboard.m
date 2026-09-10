function test_dashboard()
%TEST_DASHBOARD  Headless check of the M-7 data path (payload + JSON + URIs).
%                The GUI itself must be launched with NetraApp.
%
%   >> test_dashboard

    fprintf('=== M-7 dashboard payload test ===\n\n');
    warning('off','loadGradingNet:missing');
    warning('off','calibrateConfidence:noFile');

    files = dir('data/samples/*.png');
    assert(~isempty(files), 'no sample images');

    % gradable case
    [~, pid] = fileparts(files(3).name);
    rec = runPipeline(fullfile(files(3).folder, files(3).name), pid, 'OD');
    p = buildDashboardPayload(rec);

    assert(isfield(p,'layers'), 'payload missing layers');
    need = {'evidence','gradcam','lesionOverlay','vesselMap','enhanced'};
    for k = need
        assert(isfield(p.layers, k{1}), 'layer %s missing', k{1});
        assert(startsWith(p.layers.(k{1}), 'data:image/'), 'layer %s not a data URI', k{1});
    end

    js = jsonencode(p);
    d  = jsondecode(js);
    assert(isfield(d,'result') && isfield(d,'lesions'), 'JSON missing blocks');
    assert(d.result.grade == rec.result.grade, 'grade mismatch after JSON round-trip');

    fprintf('  gradable : %s  grade %d  payload %.0f KB  layers=%d\n', ...
        pid, rec.result.grade, numel(js)/1024, numel(fieldnames(p.layers)));

    % ungradable case
    bad = fullfile(tempdir,'ung.png');
    b = im2double(imread(fullfile(files(1).folder,files(1).name)));
    imwrite(im2uint8(imgaussfilt(b,14)*0.3), bad);
    rec2 = runPipeline(bad, 'PT-UNG', 'OS');
    p2 = buildDashboardPayload(rec2);
    js2 = jsonencode(p2);  jsondecode(js2);
    assert(strcmp(rec2.routing,'recapture'), 'ungradable path');
    fprintf('  ungradable: routing=%s  payload %.0f KB\n', rec2.routing, numel(js2)/1024);

    % HTML/CSS/JS files present
    for f = {'dashboard.html','dashboard.css','dashboard.js'}
        assert(isfile(fullfile('app', f{1})), 'missing app/%s', f{1});
    end

    fprintf('\n=== payload path OK - now run  NetraApp  to see the UI ===\n');
end
