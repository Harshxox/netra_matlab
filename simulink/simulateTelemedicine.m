function out = simulateTelemedicine(numReviewers, days)
%SIMULATETELEMEDICINE  Run the SimEvents model netra_telemedicine.slx.
%
%   out = simulateTelemedicine(numReviewers, days)
%
%   Builds the model if it doesn't exist, sets num_reviewers, runs for `days`
%   simulated days, and returns the SimulationOutput.
%
%   NOTE: this .slx uses CONSTANT service times - it is the visual/architecture
%   artefact. For the rigorous stochastic sweep (Poisson arrivals, normal
%   service, the "district needs 3 ophthalmologists" number), use
%   runSimulation.m / queueSim.m.

    if nargin < 1 || isempty(numReviewers); numReviewers = 3; end
    if nargin < 2 || isempty(days);         days = 7;         end

    here  = fileparts(mfilename('fullpath'));
    model = 'netra_telemedicine';
    slx   = fullfile(here, [model '.slx']);
    if ~isfile(slx)
        buildTelemedicineModel();
    end

    load_system(slx);
    mw = get_param(model, 'ModelWorkspace');
    assignin(mw, 'num_reviewers', numReviewers);

    stopSec = days * 86400;
    t0 = tic;
    out = sim(model, 'StopTime', num2str(stopSec));
    fprintf('SimEvents run OK: %d reviewers, %d simulated days (wall %.1fs).\n', ...
        numReviewers, days, toc(t0));
    fprintf('For queue-wait / utilization numbers use  runSimulation  (queueSim.m).\n');

    close_system(model, 0);
end
