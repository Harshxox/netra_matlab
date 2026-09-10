function test_segment()
%TEST_SEGMENT  Run classical segmentation on every sample image, save overlays.
%
%   >> test_segment
%
%   Writes lesion_overlay.png + vessel_map.png per image under
%   images/<name>/ and prints the lesion counts. Open a few overlays and
%   sanity-check: red dots on dark spots, yellow on bright deposits, vessels
%   traced, optic disc not flagged as exudate.

    fprintf('=== M-3 classical segmentation test ===\n\n');
    files = dir('data/samples/*.png');
    assert(~isempty(files), 'No images in data/samples');

    fprintf('%-24s %5s %5s %8s %6s   %s\n','file','MA','HE','EX area%','vessel','overlay');
    fprintf('%s\n', repmat('-',1,78));

    for i = 1:numel(files)
        p = fullfile(files(i).folder, files(i).name);
        [~, nm] = fileparts(files(i).name);

        [proc, qb, routing, fovMask] = runQualityPipeline(p);
        if strcmp(routing,'recapture')
            fprintf('%-24s  (ungradable - skipped)\n', files(i).name);
            continue
        end

        [lb, paths, masks] = runSegmentationPipeline(proc, nm, fovMask);

        % --- assertions ------------------------------------------
        for f = {'maCount','heCount','exudateAreaPct','nvPresent','odCentroid'}
            assert(isfield(lb, f{1}), 'lesions block missing %s', f{1});
        end
        assert(isequal(size(masks.MA), size(proc,[1 2])), 'MA mask wrong size');
        assert(islogical(masks.EX), 'EX mask must be logical');
        assert(isfile(paths.lesionOverlay), 'overlay not saved');
        jsondecode(jsonencode(rmfield(lb,'maByQuadrant')));   % JSON round-trip

        fprintf('%-24s %5d %5d %8.2f %6.3f   %s\n', ...
            files(i).name, lb.maCount, lb.heCount, lb.exudateAreaPct, ...
            lb.vesselDensity, paths.lesionOverlay);
    end

    fprintf('\n=== all assertions passed - now EYEBALL the overlays in images/ ===\n');
end
