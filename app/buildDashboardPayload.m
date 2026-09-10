function payload = buildDashboardPayload(record)
%BUILDDASHBOARDPAYLOAD  Turn a pipeline record into the struct the dashboard JS
%                       expects, with images embedded as base64 data URIs.
%
%   payload = buildDashboardPayload(record)
%
%   uihtml serves files from the HTML's own folder only, and the overlays live
%   under images/<patientId>/. Embedding them as data URIs sidesteps all path
%   issues - the dashboard is fully self-contained in one message.

    payload = record;

    layerFields = struct( ...
        'evidence',      tryget(record.images,'evidence'), ...
        'gradcam',       tryget(record.images,'gradcam'), ...
        'lesionOverlay', tryget(record.images,'lesionOverlay'), ...
        'vesselMap',     tryget(record.images,'vesselMap'), ...
        'enhanced',      tryget(record.images,'enhanced'), ...
        'original',      tryget(record.images,'original'));

    layers = struct();
    for f = fieldnames(layerFields)'
        p = layerFields.(f{1});
        if ~isempty(p) && isfile(p)
            layers.(f{1}) = fileToDataURI(p);
        end
    end
    payload.layers = layers;

    % make sure quality.reasons is a cell array of char (jsonencode friendly)
    if isfield(payload,'quality') && isfield(payload.quality,'reasons')
        payload.quality.reasons = cellstr(string(payload.quality.reasons));
    end
end

% ----------------------------------------------------------------------
function uri = fileToDataURI(path)
    fid = fopen(path, 'rb');
    bytes = fread(fid, Inf, '*uint8');
    fclose(fid);
    b64 = matlab.net.base64encode(bytes);
    [~,~,ext] = fileparts(path);
    mime = 'image/png';
    if any(strcmpi(ext, {'.jpg','.jpeg'})); mime = 'image/jpeg'; end
    uri = ['data:' mime ';base64,' b64];
end

function v = tryget(s, f)
    if isstruct(s) && isfield(s,f); v = s.(f); else; v = ''; end
end
