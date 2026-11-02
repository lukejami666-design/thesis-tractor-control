function verify_cosimulation(cfg)
%VERIFY_COSIMULATION Short run using a local copy; do not save the model.
assert(~bdIsLoaded('tractor_mu'), 'Close tractor_mu before verification.');
assert(isfile(cfg.simfile), 'Configure cfg.simfile first.');
outputDir = fullfile(cfg.outputRoot, 'cosimulation');
if ~isfolder(outputDir), mkdir(outputDir); end
text = fileread(cfg.simfile);
% Keep the input database macro; redirect generated run output locally.
prefix = fullfile(outputDir, 'smoke');
text = regexprep(text, '(?m)^SET_MACRO \$\(OUTPUT_PATH\)\$[^\r\n]*', ...
    ['SET_MACRO $(OUTPUT_PATH)$ ' strrep(outputDir, '\', '/')]);
text = regexprep(text, '(?m)^SET_MACRO \$\(OUTPUT_FILE_PREFIX\)\$[^\r\n]*', ...
    ['SET_MACRO $(OUTPUT_FILE_PREFIX)$ ' strrep(prefix, '\', '/')]);
text = regexprep(text, '(?m)^GUI_REFRESH_V[^\r\n]*\r?\n', '');
assert(contains(text, ['SET_MACRO $(OUTPUT_FILE_PREFIX)$ ' strrep(prefix,'\','/')]));
localSim = fullfile(outputDir, 'simfile.sim');
fid = fopen(localSim, 'w');
assert(fid ~= -1, 'Cannot create local simulation configuration.');
fwrite(fid, text); fclose(fid);
previous = pwd;
restore = onCleanup(@() cd(previous));
cd(outputDir);
load_system(fullfile(cfg.modelRoot, 'tractor_mu.slx'));
modelCleanup = onCleanup(@() close_system('tractor_mu', 0));
set_param('tractor_mu/TruckSim S-Function', 'SIMFILE', localSim);
sim('tractor_mu', 'StopTime', '0.01', 'ReturnWorkspaceOutputs', 'on');
fprintf('COSIM_10MS_OK\n');
end
