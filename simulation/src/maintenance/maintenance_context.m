function cfg = maintenance_context()
%MAINTENANCE_CONTEXT Explicit setup for historical repair tools.
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root, 'scripts'));
cfg = setup_project();
addpath(cfg.archiveDir);
cd(cfg.maintenanceRoot);
warning('thesis:HistoricalRepair', ...
    'Historical repair tool: may edit/save models or exit MATLAB. Review before use.');
end
