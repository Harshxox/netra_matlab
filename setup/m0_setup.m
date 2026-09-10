function m0_setup()
% M0_SETUP  Create the Netra folder layout and a MATLAB Project, add code to path.
%
% Run this ONCE from the repo root (the folder that contains this "setup" folder):
%   >> cd  <path-to>\netra
%   >> setup\m0_setup
%
% Safe to re-run: it only makes folders that don't already exist.

    root = pwd;
    fprintf('Setting up Netra project in:\n  %s\n\n', root);

    % ---- 1. Folder layout (matches docs/tech_stack.md section 7) ----------
    folders = [ ...
        "data", ...
        "src/quality", "src/grade", "src/segment", "src/explain", "src/datalayer", ...
        "models", ...
        "app", "app/poc", ...
        "simulink", ...
        "images", "reports", "docs", "colab", ...
        "setup" ];

    for i = 1:numel(folders)
        p = fullfile(root, folders(i));
        if ~exist(p, 'dir')
            mkdir(p);
            fprintf('  created  %s\n', folders(i));
        else
            fprintf('  exists   %s\n', folders(i));
        end
    end

    % ---- 2. Put a .gitkeep in the empty runtime folders so git tracks them
    for f = ["images" "reports" "models" "data"]
        keep = fullfile(root, f, ".gitkeep");
        if ~isfile(keep); fclose(fopen(keep, 'w')); end
    end

    % ---- 3. Add all source code to the MATLAB path -----------------------
    addpath(genpath(fullfile(root, "src")));
    addpath(fullfile(root, "app", "poc"));
    addpath(fullfile(root, "setup"));
    savepath;   % remove this line if you don't want it saved between sessions
    fprintf('\n  src/ added to MATLAB path.\n');

    % ---- 4. Create a MATLAB Project if one doesn't exist ----------------
    prjFiles = dir(fullfile(root, "*.prj"));
    if isempty(prjFiles)
        try
            proj = matlab.project.createProject("Name", "Netra", "Folder", root);
            fprintf('\n  MATLAB Project created: %s\n', proj.Name);
        catch e
            fprintf(2, '\n  Could not auto-create Project (%s).\n', e.message);
            fprintf('  Do it manually: Home > New > Project > From Folder > pick this folder.\n');
        end
    else
        fprintf('\n  MATLAB Project already exists: %s\n', prjFiles(1).name);
    end

    fprintf('\nDONE. Next:\n');
    fprintf('  1. setup\\m0_check_toolboxes\n');
    fprintf('  2. setup\\m0_onnx_test\n');
    fprintf('  3. run  app\\poc\\poc_test\n');
end
