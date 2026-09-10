function modelPath = buildTelemedicineModel()
%BUILDTELEMEDICINEMODEL  Programmatically build simulink/netra_telemedicine.slx
%
%   >> buildTelemedicineModel
%
%   A SimEvents discrete-event model of the Netra telemedicine workflow:
%
%     Entity Generator ->  Upload Server  ->  AI Queue  ->  AI Server
%       (Poisson arrivals)  (bandwidth)                     (~30 s)
%       -> Review Queue -> Ophthalmologist Review (N servers, ~180 s) -> Sink
%
%   Model workspace variables (edit in the .slx or via set_param):
%       num_reviewers   number of ophthalmologist servers   (default 3)
%       upload_time     seconds to upload one image         (default 1.6)
%       ai_time         AI pipeline service time, seconds    (default 30)
%       review_time     review service time, seconds         (default 180)
%       mean_arrival    mean seconds between patient arrivals (default 315)
%
%   Rigorous stochastic results live in queueSim.m / runSimulation.m; this
%   .slx is the SimEvents visual + a live queue-length scope.

    model = 'netra_telemedicine';
    modelPath = fullfile(fileparts(mfilename('fullpath')), [model '.slx']);

    if bdIsLoaded(model); close_system(model, 0); end
    if isfile(modelPath); delete(modelPath); end

    load_system('sldelib');
    new_system(model);          % build without opening a GUI window

    add = @(src, name, pos) add_block(src, [model '/' name], 'Position', pos);

    % ---- blocks ---------------------------------------------------------
    gen = add('sldelib/Entity Generator', 'Patient Arrivals',        [ 40  60 110 110]);
    up  = add('sldelib/Entity Server',    'Image Upload',            [190  60 270 110]);
    aq  = add('sldelib/Entity Queue',     'AI Queue',                [340  60 410 110]);
    ai  = add('sldelib/Entity Server',    'AI Pipeline',             [470  60 550 110]);
    rq  = add('sldelib/Entity Queue',     'Review Queue',            [620  60 700 110]);
    rev = add('sldelib/Entity Server',    'Ophthalmologist Review',  [760  60 860 110]);
    snk = add('sldelib/Entity Terminator','Completed Cases',         [930  60 1000 110]);

    % ---- arrivals: one patient every mean_arrival seconds ------------
    set_param(gen, 'GenerationMethod', 'Time-based', ...
                   'TimeSource', 'Dialog', ...
                   'Period', 'mean_arrival', ...
                   'EntityType', 'Anonymous');

    % ---- servers (constant service times; stochastic detail is in queueSim.m)
    set_param(up,  'ServiceTimeSource', 'Dialog', 'ServiceTimeValue', 'upload_time', 'Capacity', '1');
    set_param(ai,  'ServiceTimeSource', 'Dialog', 'ServiceTimeValue', 'ai_time',     'Capacity', '1');
    set_param(rev, 'ServiceTimeSource', 'Dialog', 'ServiceTimeValue', 'review_time', ...
                   'Capacity', 'num_reviewers');

    % ---- queues unbounded FIFO -----------------------------------
    set_param(aq, 'Capacity', 'inf', 'QueueType', 'FIFO');
    set_param(rq, 'Capacity', 'inf', 'QueueType', 'FIFO');

    % ---- enable statistic ports BEFORE wiring (they insert as port 1,
    %      pushing the entity port to the end) --------------------------
    set_param(rq,  'NumberEntitiesInBlock', 'on');
    set_param(rev, 'Utilization', 'on');

    % which outport is the entity, which is the stat?
    rqEnt  = entityOutPort(rq);   rqStat  = statOutPort(rq);
    revEnt = entityOutPort(rev);  revStat = statOutPort(rev);

    % ---- wire the entity path -------------------------------------
    conn(model, 'Patient Arrivals/1', 'Image Upload/1');
    conn(model, 'Image Upload/1',     'AI Queue/1');
    conn(model, 'AI Queue/1',         'AI Pipeline/1');
    conn(model, 'AI Pipeline/1',      'Review Queue/1');
    addByHandle(model, rqEnt,  [model '/Ophthalmologist Review'], 1);
    addByHandle(model, revEnt, [model '/Completed Cases'], 1);

    % ---- scopes on the statistic ports --------------------------
    scopeQ = add_block('simulink/Sinks/Scope', [model '/Review Queue Length'], ...
                       'Position', [620 210 700 270]);
    scopeU = add_block('simulink/Sinks/Scope', [model '/Reviewer Utilization'], ...
                       'Position', [790 210 870 270]);
    add_line(model, rqStat,  get_param(scopeQ,'PortHandles').Inport(1), 'autorouting','on');
    add_line(model, revStat, get_param(scopeU,'PortHandles').Inport(1), 'autorouting','on');

    % ---- model workspace defaults --------------------------
    mw = get_param(model, 'ModelWorkspace');
    assignin(mw, 'num_reviewers', 3);
    assignin(mw, 'upload_time',   1.6);
    assignin(mw, 'ai_time',       30);
    assignin(mw, 'review_time',   180);
    assignin(mw, 'mean_arrival',  315);

    % ---- solver / stop time -------------------------------
    set_param(model, 'StopTime', '2592000', ...        % 30 days in seconds
                     'SolverType', 'Variable-step', ...
                     'SaveOutput', 'on', 'SaveFormat', 'Dataset');

    Simulink.BlockDiagram.arrangeSystem(model);
    save_system(model, modelPath);
    close_system(model, 0);     % release the file so the IDE can open it
    fprintf('Saved %s\n', modelPath);
end

% ====================================================================
function tf = bdIsLoaded(name)
    tf = any(strcmp(find_system('type','block_diagram'), name));
end

function conn(model, a, b)
    add_line(model, a, b, 'autorouting', 'on');
end

function h = entityOutPort(blk)
    ph = get_param(blk, 'PortHandles');
    h = firstOfType(ph.Outport, true);
end

function h = statOutPort(blk)
    ph = get_param(blk, 'PortHandles');
    h = firstOfType(ph.Outport, false);
end

function h = firstOfType(ports, wantEntity)
    h = ports(1);
    for i = 1:numel(ports)
        isEnt = any(strcmpi(get_param(ports(i),'PortType'), {'entity','message'}));
        if isEnt == wantEntity; h = ports(i); return; end
    end
    % PortType may just say 'outport' for both - fall back to position:
    % the statistic port is inserted first, entity port is last.
    if wantEntity; h = ports(end); else; h = ports(1); end
end

function addByHandle(model, srcHandle, dstBlk, dstPortNum)
    dp = get_param(dstBlk, 'PortHandles');
    add_line(model, srcHandle, dp.Inport(dstPortNum), 'autorouting', 'on');
end

