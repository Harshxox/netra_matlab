# Phase M-6 — Simulink Telemedicine Model

**Track:** MATLAB | **Owner:** B5 | **Day:** 3–6
**Depends on:** M-0 | **Parallel with:** M-5

---

## Goal
Model the end-to-end telemedicine screening workflow in Simulink using SimEvents.
Output: how many reviewers a district needs, where throughput bottlenecks,
and how bandwidth affects queue times for 100,000 patients/year.

---

## Features

### F1 — Model Setup
```
File: simulink/netra_telemedicine.slx
Open: Simulink → New → Blank Model → save as netra_telemedicine.slx
Add SimEvents library (Simulink Library Browser → SimEvents)
```

---

### F2 — Patient Arrival Source
Block: `Entity Generator` (SimEvents)
```
Period: 315 seconds
  (= 365 days × 24h × 3600s / 100,000 patients = 315 sec/patient)
Entity type: Patient
Attribute: severity (randomly assigned 0-4, weighted by APTOS distribution)
```
Add a `MATLAB Function` block to assign severity:
```matlab
function severity = assignSeverity()
    % APTOS distribution: ~49% grade0, 27% grade1, 13% grade2, 6% grade3, 5% grade4
    r = rand();
    if r < 0.49;    severity = 0;
    elseif r < 0.76; severity = 1;
    elseif r < 0.89; severity = 2;
    elseif r < 0.95; severity = 3;
    else;            severity = 4;
    end
end
```

---

### F3 — Bandwidth Queue
Block: `Entity Queue` (SimEvents) → FIFO
```
Capacity: Inf (or set to bandwidth limit)
```
Add `Entity Server` block for upload delay:
```
Service time = imageSize / bandwidth
imageSize = 2 MB (typical fundus image after compression)
bandwidth = Workspace variable: bw_mbps (2, 10, or 50)
Service time formula: (2 * 8) / (bw_mbps * 1e6) seconds = 8/bw_mbps µs
(near-instant for 10+ Mbps — bottleneck is usually review, not upload)
```

---

### F4 — AI Processing Server
Block: `Entity Server` (SimEvents)
```
Number of servers: 1 (or match available hardware)
Service time: 30 seconds (estimated pipeline processing time per image)
Service time distribution: Normal(30, 5) seconds
```

---

### F5 — Ophthalmologist Review Queue + Server
Block: `Entity Queue` → Priority Queue (sort by severity attribute)
```
Sorting attribute: severity (descending — grade 4 reviewed first)
```
Block: `Entity Server`
```
Number of servers: Workspace variable: num_reviewers (sweep 1 → 10)
Service time: Normal(60, 15) seconds (avg 1 minute per case, some faster)
```

---

### F6 — Metrics Dashboard Blocks
Add `Simulink Dashboard` blocks:
- `Scope`: queue length over time (review queue)
- `Display`: current queue wait time (95th percentile)
- `Display`: reviewer utilization %
- `Display`: total throughput (cases/day)

Use `Statistics` blocks from SimEvents to compute:
```
Average wait time in review queue
Server utilization for ophthalmologist servers
```

---

### F7 — Parameter Sweep Script (`simulink/runSimulation.m`)
```matlab
function results = runSimulation(bw_mbps_list, reviewer_count_list)
    model = 'netra_telemedicine';
    load_system(model);

    results = struct();
    r = 1;
    for bw = bw_mbps_list
        for nRev = reviewer_count_list
            set_param([model '/BandwidthServer'], 'ServiceTime', num2str(8/bw));
            set_param([model '/ReviewServer'], 'NumberOfServers', num2str(nRev));

            simOut = sim(model, 'StopTime', '31536000'); % 1 year in seconds
            results(r).bw         = bw;
            results(r).reviewers  = nRev;
            results(r).avgWait    = simOut.avgWaitTime;
            results(r).utilization = simOut.reviewerUtil;
            results(r).throughput  = simOut.casesPerDay;
            r = r + 1;
        end
    end

    % Find minimum reviewers where wait < 24h (86400 seconds)
    acceptable = results([results.avgWait] < 86400);
    [~, idx] = min([acceptable.reviewers]);
    fprintf('Minimum reviewers for <24h wait: %d\n', acceptable(idx).reviewers);
end

% Run scenarios
results = runSimulation([2, 10, 50], 1:10);
```

---

### F8 — Key Output for PPT Deck
After simulation, extract these numbers for the presentation:
```matlab
% Example outputs to include in the deck
fprintf('=== Simulink Results ===\n')
fprintf('District: 100,000 patients/year\n')
fprintf('Low bandwidth (2 Mbps): wait time = XX hours\n')
fprintf('High bandwidth (50 Mbps): wait time = XX minutes\n')
fprintf('Optimal reviewer count: X reviewers → <24h wait\n')
fprintf('Bottleneck: review queue (not upload, not AI processing)\n')
```

---

## Done when
- [ ] Simulink model runs for 1 year (31.5M seconds) without errors
- [ ] Queue wait time and reviewer utilization are logged
- [ ] Sweep of 1–10 reviewers completed for all 3 bandwidth scenarios
- [ ] Minimum reviewer count for < 24h wait identified
- [ ] Key numbers extracted and ready for PPT slide
