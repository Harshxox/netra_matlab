function stats = queueSim(arrivalsPerDay, nReviewers, aiSecMean, revSecMean, days, bwMbps, opts)
%QUEUESIM  Discrete-event simulation of the Netra telemedicine workflow.
%
%   stats = queueSim(arrivalsPerDay, nReviewers, aiSecMean, revSecMean, days, bwMbps, opts)
%
%   Plain-MATLAB substitute for the SimEvents model (M-6). Path:
%     patient arrives -> image upload (bandwidth) -> AI pipeline (1 server)
%     -> ophthalmologist review (nReviewers, working a daily window) -> done
%
%   Defaults: queueSim(274, 3, 30, 180, 30, 10)
%     274/day ~ 100,000 patients/year per district
%     AI 30 s/case ; review 180 s/case (3 min incl. report sign-off)
%
%   opts.reviewHoursPerDay  reviewer working window, default 6 (e.g. 10:00-16:00)
%   opts.clinicHoursPerDay  arrivals spread over this window, default 9 (08:00-17:00)
%
%   stats.meanWaitHrs / .p95WaitHrs  - wait between AI-done and review-start
%   stats.throughputPerDay / .reviewerUtil / .uploadWaitHrs

    if nargin < 1 || isempty(arrivalsPerDay); arrivalsPerDay = 274;  end
    if nargin < 2 || isempty(nReviewers);     nReviewers     = 3;    end
    if nargin < 3 || isempty(aiSecMean);      aiSecMean      = 30;   end
    if nargin < 4 || isempty(revSecMean);     revSecMean     = 180;  end
    if nargin < 5 || isempty(days);           days           = 30;   end
    if nargin < 6 || isempty(bwMbps);         bwMbps         = 10;   end
    if nargin < 7; opts = struct(); end
    if ~isfield(opts,'reviewHoursPerDay'); opts.reviewHoursPerDay = 6; end
    if ~isfield(opts,'clinicHoursPerDay'); opts.clinicHoursPerDay = 9; end

    rng(42);
    T = days * 86400;

    % --- arrivals: Poisson, but only during clinic hours (08:00 onward) ---
    clinicStart = 8*3600;
    clinicLen   = opts.clinicHoursPerDay * 3600;
    perDay = poissrnd(arrivalsPerDay, [days 1]);
    arr = [];
    for d = 0:days-1
        k = perDay(d+1);
        arr = [arr; d*86400 + clinicStart + sort(rand(k,1))*clinicLen]; %#ok<AGROW>
    end
    arr = sort(arr(arr < T));
    n = numel(arr);

    imageMB   = 2.0;
    uploadSec = imageMB * 8 / max(bwMbps, 0.1);

    % --- reviewer working window: 10:00 .. 10:00+reviewHours each day -----
    revStartOfDay = 10*3600;
    revLen        = opts.reviewHoursPerDay * 3600;

    uploadFree = 0;
    aiFree     = 0;
    revFree    = zeros(nReviewers,1);

    aiDone   = zeros(n,1);
    revStart = zeros(n,1);
    revDone  = zeros(n,1);
    upWait   = zeros(n,1);

    for i = 1:n
        prevUp = uploadFree;
        uploadFree = max(uploadFree, arr(i)) + uploadSec;
        upWait(i)  = max(0, prevUp - arr(i));

        aiFree = max(aiFree, uploadFree) + max(1, normrnd(aiSecMean, aiSecMean/6));
        aiDone(i) = aiFree;

        [free, s] = min(revFree);
        t0 = max(aiDone(i), free);
        t0 = nextWorkingInstant(t0, revStartOfDay, revLen);   % wait for the window
        revStart(i) = t0;
        revDone(i)  = t0 + max(1, normrnd(revSecMean, revSecMean/4));
        revFree(s)  = revDone(i);
    end

    wait = revStart - aiDone;

    stats.arrivalsPerDay   = arrivalsPerDay;
    stats.nReviewers       = nReviewers;
    stats.bwMbps           = bwMbps;
    stats.completed        = n;
    stats.meanWaitHrs      = mean(wait) / 3600;
    stats.p95WaitHrs       = prctile(wait, 95) / 3600;
    stats.maxWaitHrs       = max(wait) / 3600;
    stats.uploadWaitHrs    = mean(upWait) / 3600;
    stats.throughputPerDay = n / days;
    stats.reviewerUtil     = min(1, sum(revDone - revStart) / (nReviewers * days * revLen));
    stats.overloaded       = stats.p95WaitHrs > 24;
end

% --------------------------------------------------------------------
function t = nextWorkingInstant(t, startOfDay, len)
%   Push t forward to the next moment inside a [startOfDay, startOfDay+len]
%   window (same clock every day).
    day   = floor(t / 86400);
    tod   = t - day*86400;
    if tod < startOfDay
        t = day*86400 + startOfDay;
    elseif tod >= startOfDay + len
        t = (day+1)*86400 + startOfDay;
    end
end
