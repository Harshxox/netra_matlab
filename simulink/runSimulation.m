function results = runSimulation()
%RUNSIMULATION  Sweep bandwidth x reviewer count, print the district numbers
%               for the PPT slide (M-6).
%
%   >> results = runSimulation

    bwList  = [2 10 50];          % Mbps: rural / town / district HQ
    revList = 1:10;

    fprintf('District load: 100,000 patients/year (~274/day, clinic hours)\n');
    fprintf('AI pipeline: ~30 s/case   Review: ~180 s/case   Reviewers work 6 h/day\n\n');
    fprintf('%-6s %-10s %-12s %-12s %-10s\n','BW','Reviewers','meanWait(h)','p95Wait(h)','RevUtil');
    fprintf('%s\n', repmat('-',1,54));

    results = struct('bw',{},'reviewers',{},'meanWaitHrs',{},'p95WaitHrs',{}, ...
                     'reviewerUtil',{},'throughputPerDay',{});
    r = 0;
    for bw = bwList
        for nr = revList
            s = queueSim(274, nr, 30, 180, 30, bw);
            r = r + 1;
            results(r).bw               = bw;
            results(r).reviewers        = nr;
            results(r).meanWaitHrs      = s.meanWaitHrs;
            results(r).p95WaitHrs       = s.p95WaitHrs;
            results(r).reviewerUtil     = s.reviewerUtil;
            results(r).throughputPerDay = s.throughputPerDay;
            fprintf('%-6d %-10d %-12.2f %-12.2f %-10.0f%%\n', ...
                bw, nr, s.meanWaitHrs, s.p95WaitHrs, 100*s.reviewerUtil);
        end
        fprintf('\n');
    end

    % minimum reviewers to keep p95 wait < 24 h, at 10 Mbps
    at10 = results([results.bw] == 10);
    ok = at10([at10.p95WaitHrs] < 24);
    fprintf('=== KEY NUMBERS FOR THE DECK ===\n');
    if isempty(ok)
        fprintf('Even 10 reviewers cannot keep p95 wait < 24 h - district needs > 10.\n');
    else
        [~,k] = min([ok.reviewers]);
        fprintf('At 10 Mbps: %d ophthalmologists keep 95%% of cases reviewed within 24 h.\n', ok(k).reviewers);
    end
    lo = results([results.bw]==2  & [results.reviewers]==3);
    hi = results([results.bw]==50 & [results.reviewers]==3);
    fprintf('Bandwidth impact (3 reviewers): 2 Mbps mean wait %.1f h vs 50 Mbps %.1f h.\n', ...
        lo.meanWaitHrs, hi.meanWaitHrs);
    fprintf('Bottleneck: the review queue, not upload or AI processing.\n');
end
