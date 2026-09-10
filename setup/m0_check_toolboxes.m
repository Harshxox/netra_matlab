function m0_check_toolboxes()
% M0_CHECK_TOOLBOXES  Verify every toolbox the Netra MATLAB track needs.
%
%   >> setup\m0_check_toolboxes
%
% Green = you have it. Red = install it before the phase that needs it.

    fprintf('\nMATLAB version: %s\n\n', version);

    % name shown to you | license feature name | which phase needs it | required?
    checks = {
        'Image Processing Toolbox'              'Image_Toolbox'            'M-1, M-3, M-4'  true
        'Deep Learning Toolbox'                 'Neural_Network_Toolbox'   'M-2, M-3, M-4'  true
        'Computer Vision Toolbox'               'Video_and_Image_Blockset' 'M-1, M-3'       true
        'Statistics and Machine Learning'       'Statistics_Toolbox'       'M-8 metrics'    true
        'MATLAB Report Generator'               'MATLAB_Report_Gen'        'M-4 PDF'        true
        'Simulink'                              'Simulink'                 'M-6 (optional)' false
        'SimEvents'                             'SimEvents'                'M-6 (optional)' false
        'Parallel Computing Toolbox'            'Distrib_Computing_Toolbox' 'GPU (optional)' false
        'Medical Imaging Toolbox'               'Medical_Imaging_Toolbox'  'DICOM (optional)' false
    };

    nMissingRequired = 0;
    for i = 1:size(checks,1)
        name  = checks{i,1};
        feat  = checks{i,2};
        phase = checks{i,3};
        req   = checks{i,4};

        ok = license('test', feat) == 1;
        if ok
            status = 'OK   ';
        elseif req
            status = 'MISS*';
            nMissingRequired = nMissingRequired + 1;
        else
            status = 'miss ';
        end
        fprintf('  [%s] %-34s  (%s)\n', status, name, phase);
    end

    % --- Support packages (separate from toolboxes: license test won't see them) ---
    hasOnnx = ~isempty(which('importNetworkFromONNX')) || ~isempty(which('importONNXNetwork'));
    if ~hasOnnx
        nMissingRequired = nMissingRequired + 1;
    end
    fprintf('  [%s] %-34s  (M-2, M-3 - REQUIRED - install from Add-On Explorer)\n', ...
        ternary(hasOnnx,'OK   ','MISS*'), 'ONNX Converter support package');

    hasResnet = ~isempty(which('resnet50'));
    fprintf('  [%s] %-34s  (M-2 fallback if ONNX fails)\n', ...
        ternary(hasResnet,'OK   ','miss '), 'ResNet-50 support package');

    fprintf('\n');
    if nMissingRequired == 0
        fprintf('All REQUIRED toolboxes present. Proceed to m0_onnx_test.\n');
    else
        fprintf(2, '%d required toolbox(es) missing (marked MISS*). ', nMissingRequired);
        fprintf(2, 'Install via Home > Add-Ons > Get Add-Ons.\n');
    end
end

function out = ternary(c,a,b)
    if c; out = a; else; out = b; end
end
