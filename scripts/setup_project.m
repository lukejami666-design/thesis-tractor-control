function cfg = setup_project()
%SETUP_PROJECT Configure project paths without opening or changing models.
root = fileparts(fileparts(mfilename('fullpath')));
cfg.root = root;
cfg.simulationRoot = fullfile(root, 'simulation');
cfg.modelRoot = fullfile(cfg.simulationRoot, 'models');
cfg.sourceRoot = fullfile(cfg.simulationRoot, 'src');
cfg.maintenanceRoot = fullfile(cfg.sourceRoot, 'maintenance');
cfg.configRoot = fullfile(cfg.simulationRoot, 'config');
cfg.archiveDir = fullfile(cfg.simulationRoot, 'archive');
cfg.outputRoot = fullfile(root, 'results', 'generated');
cfg.runRoot = fullfile(cfg.outputRoot, 'run');
cfg.inspectDir = fullfile(cfg.outputRoot, 'inspection');
cfg.truckSimRoot = getenv('TRUCKSIM_ROOT');
cfg.simfile = ''; % Export a complete TruckSim run locally, then configure this.
cfg.matlabVersion = 'R2022b';
cfg.fixedStep = 0.001;
localFile = fullfile(cfg.configRoot, 'local_paths.m');
if isfile(localFile), run(localFile); end
addpath(fullfile(root, 'scripts'), cfg.modelRoot, cfg.sourceRoot, ...
    cfg.configRoot, fullfile(cfg.simulationRoot, 'analysis'));
for folder = {cfg.outputRoot, cfg.runRoot, cfg.inspectDir, cfg.archiveDir}
    if ~isfolder(folder{1}), mkdir(folder{1}); end
end
if ~isempty(cfg.truckSimRoot)
    solverRoot = fullfile(cfg.truckSimRoot, 'Programs', 'solvers', 'Matlab84+');
    if isfolder(solverRoot), addpath(solverRoot);
    else, warning('thesis:TruckSimPath', 'TruckSim solver folder not found: %s', solverRoot);
    end
end
if exist('Simulink.fileGenControl', 'file') || ~isempty(ver('simulink'))
    cacheRoot = fullfile(cfg.outputRoot, 'cache');
    codeRoot = fullfile(cfg.outputRoot, 'codegen');
    Simulink.fileGenControl('set', 'CacheFolder', cacheRoot, ...
        'CodeGenFolder', codeRoot, 'createDir', true);
end
% These scripts/functions define existing parameters only; Total_T3D is manual.
assignin('base', 'P', launch_tcs_params());
run(fullfile(cfg.sourceRoot, 'value_parameter.m'));
for name = {'k_f','k_r','w_1','w_2','w_3'}
    assignin('base', name{1}, eval(name{1}));
end
fprintf('Project ready (%s), model: %s\n', version('-release'), ...
    fullfile(cfg.modelRoot, 'tractor_mu.slx'));
end
