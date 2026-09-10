function poc_test()
% POC_TEST  Day-1 non-negotiable: prove the uihtml <-> MATLAB two-way bridge.
%
%   >> cd  <path-to>\netra
%   >> app\poc\poc_test
%
% EXPECTED: a window opens with a "Ping MATLAB" button. Click it.
%   - The grey box should change to "Hello from MATLAB - 3 pings so far".
%   - The Command Window should print each event received.
%
% If the button does nothing / no Command Window output:
%   the bridge is broken -> the whole dashboard (M-7) is at risk. Flag it,
%   and fall back to plain App Designer widgets (uibutton/uiimage/uilabel).
%
% NOTE: this is the CORRECT uihtml API. The pseudo-code in phase_m0.md that
% uses window.postMessage / CustomEvent('mlEvent') does NOT work with uihtml.

    htmlFile = fullfile(fileparts(mfilename('fullpath')), 'poc.html');
    if ~isfile(htmlFile)
        error('poc.html not found next to poc_test.m');
    end

    fig = uifigure('Name', 'Netra uihtml PoC', 'Position', [200 200 640 460]);

    h = uihtml(fig, ...
        'Position', [10 10 620 440], ...
        'HTMLSource', htmlFile, ...
        'Data', struct('startedAt', string(datetime('now'))));

    % Callback fired whenever the HTML calls sendEventToMATLAB(...)
    h.HTMLEventReceivedFcn = @onHtmlEvent;

    % Keep a counter on the component so the callback can see it
    h.UserData = struct('pingCount', 0);

    fprintf('PoC window open. Click the "Ping MATLAB" button.\n');

    function onHtmlEvent(src, event)
        fprintf('  <- HTML event: "%s"  data: %s\n', ...
            event.HTMLEventName, jsonencode(event.HTMLEventData));

        switch event.HTMLEventName
            case 'ping'
                src.UserData.pingCount = src.UserData.pingCount + 1;
                msg = sprintf('Hello from MATLAB - %d ping(s) so far', ...
                              src.UserData.pingCount);
                % MATLAB -> HTML
                sendEventToHTMLSource(src, 'pong', struct('msg', msg));
                fprintf('  -> sent "pong": %s\n', msg);
        end
    end
end
