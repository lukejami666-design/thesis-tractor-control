% Run in a fresh MATLAB batch process; never save the main model.
addpath(fileparts(mfilename('fullpath')));
cfg = setup_project();
diary(fullfile(cfg.outputRoot, 'matlab-validation.txt'));
diaryCleanup = onCleanup(@() diary('off'));
fprintf('MATLAB_RELEASE=%s\n', version('-release'));
assert(strcmp(['R' version('-release')], cfg.matlabVersion));
assert(evalin('base','P.Ts') == cfg.fixedStep);
assert(isfolder(cfg.modelRoot) && isfolder(cfg.sourceRoot));
fprintf('SETUP_OK\n');
models = {'tractor_mu','tractor_mu2018','noslip_softsoil','launch_chart_check_valid'};
for k = 1:numel(models)
    name = models{k};
    load_system(fullfile(cfg.modelRoot, [name '.slx']));
    fprintf('MODEL_LOAD_OK=%s\n', name);
    if strcmp(name, 'tractor_mu')
        assert(abs(str2double(get_param(name,'FixedStep')) - cfg.fixedStep) < eps);
        blocks = find_system(name, 'LookUnderMasks','all', 'BlockType','S-Function');
        for j = 1:numel(blocks)
            fprintf('S_FUNCTION=%s; PARAMETERS=%s\n', blocks{j}, get_param(blocks{j},'Parameters'));
        end
    end
    close_system(name, 0);
end
report = analyze_launch_run(fullfile(cfg.simulationRoot, 'data', 'sample', 'stage6_workspace.mat'));
assert(~isempty(which('diagnose_launch_model')), 'Sample analysis removed the project source path.');
assert(~isempty(report.data.t), 'Sample has no usable time vector.');
fprintf('SAMPLE_ANALYSIS_OK; STATUS=%s\n', report.status);
fprintf('MISSING_SIGNALS=%s\n', strjoin(report.missingSignals, ','));
try
    diagnose_launch_model();
    fprintf('STUB_UPDATE_OK\n');
catch ME
    fprintf('STUB_UPDATE_FAILED=%s\n%s\n', ME.identifier, ME.message);
end
if isempty(cfg.simfile) || ~isfile(cfg.simfile)
    fprintf('COSIM_BLOCKED=No complete TruckSim run export (simfile.sim) configured.\n');
else
    try
        verify_cosimulation(cfg);
    catch ME
        fprintf('COSIM_FAILED=%s\n%s\n', ME.identifier, getReport(ME,'extended','hyperlinks','off'));
    end
end
fprintf('VERIFICATION_DONE\n');
