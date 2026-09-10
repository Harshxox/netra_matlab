function debugSegment(names)
%DEBUGSEGMENT  Save a 2x3 montage (original / vessels / OD / MA+HE / EX / overlay)
%              for the named sample images, so tuning can be done by eye.
%
%   debugSegment                       % first 4 samples
%   debugSegment({'0111b949947e','009245722fa4'})
%
%   Montages go to  images/_debug/<name>_debug.png

    if nargin < 1 || isempty(names)
        f = dir('data/samples/*.png');
        names = arrayfun(@(x) erase(x.name,'.png'), f(1:min(4,numel(f))), 'uni', 0);
    end
    if ischar(names); names = {names}; end
    outDir = fullfile('images','_debug');
    if ~exist(outDir,'dir'); mkdir(outDir); end

    for k = 1:numel(names)
        nm = names{k};
        p  = fullfile('data','samples',[nm '.png']);
        [proc, ~, routing, fovMask] = runQualityPipeline(p);
        if strcmp(routing,'recapture'); fprintf('%s ungradable\n', nm); continue; end

        [odMask, odC, odR] = locateOpticDisc(proc, fovMask);
        vessel = segmentVessels(proc, fovMask);
        masks  = detectLesionsClassical(proc, fovMask, odMask, vessel);
        masks.vessel = vessel; masks.od = odMask;
        c = quantifyLesions(masks, fovMask);

        tiles = {
            proc,                                        sprintf('%s  original', nm)
            paint(proc, vessel, [0 1 1]),                sprintf('vessels  d=%.3f', nnz(vessel)/nnz(fovMask))
            paintCircle(proc, odC, odR),                 'optic disc'
            paint(paint(proc,masks.MA,[1 0 0]),masks.HE,[0 0.4 1]), sprintf('MA=%d  HE=%d', c.maCount, c.heCount)
            paint(proc, masks.EX, [1 0.9 0]),            sprintf('EX area=%.2f%%', c.exudateAreaPct)
            im2double(generateLesionOverlay(proc, masks, 0.55)), 'overlay'
        };

        fig = figure('Visible','off','Position',[100 100 1200 820]);
        t = tiledlayout(fig,2,3,'Padding','compact','TileSpacing','compact');
        for i = 1:6
            nexttile(t); imshow(tiles{i,1}); title(tiles{i,2},'Interpreter','none');
        end
        outPath = fullfile(outDir, [nm '_debug.png']);
        exportgraphics(fig, outPath, 'Resolution', 110);
        close(fig);
        fprintf('  %s  -> %s   (MA=%d HE=%d EX=%.2f%%)\n', nm, outPath, c.maCount, c.heCount, c.exudateAreaPct);
    end
end

function out = paint(base, mask, rgb)
    base = im2double(base);
    if size(base,3)==1; base = repmat(base,[1 1 3]); end
    m3 = repmat(imdilate(mask,strel('disk',1)),[1 1 3]);
    col = repmat(reshape(rgb,[1 1 3]), [size(base,1) size(base,2) 1]);
    out = base.*(1-0.6*m3) + col.*(0.6*m3);
end

function out = paintCircle(base, c, r)
    sz = [size(base,1) size(base,2)];
    [xx,yy] = meshgrid(1:sz(2),1:sz(1));
    ring = abs(sqrt((xx-c(1)).^2 + (yy-c(2)).^2) - r) < 2;
    out = paint(base, ring, [0 1 0]);
end
