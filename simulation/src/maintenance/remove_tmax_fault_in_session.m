function remove_tmax_fault_in_session
cfg = maintenance_context();
% Remove the Tmax source-fault branch from the current loaded model.
% Other pending edits in the current model are preserved when saving.
folder = cfg.modelRoot;
mdl = 'tractor_mu';
load_system(fullfile(folder, [mdl '.slx']));
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'), ...
    'Stop the simulation before applying this change.');
assert(strcmpi(get_param(mdl,'FileName'),fullfile(folder,[mdl '.slx'])), ...
    'The loaded tractor_mu is not the intended model file.');

rt = sfroot;
charts = rt.find('-isa','Stateflow.EMChart');
target = [];
for k = 1:numel(charts)
    if strcmp(charts(k).Path, [mdl '/驱动防滑模块/MATLAB Function4'])
        target = charts(k);
    end
end
assert(numel(target)==1,'Expected exactly one LaunchTCS Motion function.');
before = target.Script;
after = regexprep(before,'\(~cap_ok\)\s*\|\|\s*','');
after = regexprep(after,'cap_ok\s*=\s*true;\s*','');
after = regexprep(after,'[ \t]*if\s+~cap_valid,\s*cap_ok\s*=\s*false;\s*end\r?\n','');
after = regexprep(after,'[ \t]*if isnan\(T_max\(i\)\)\|\|isinf\(T_max\(i\)\)\|\|T_max\(i\)<P.TcapFloor\(i\), cap_ok=false; end\r?\n','');
assert(~contains(after,'cap_ok'),'Unexpected cap_ok reference; no change applied.');
assert(contains(after,'source_immediate_bad') && contains(after,'actual_ok') ...
    && contains(after,'P.applied_active_frac'), 'Unexpected function contents.');

stamp = datestr(now,'yyyymmdd_HHMMSS');
copyfile(fullfile(folder,[mdl '.slx']), ...
    fullfile(cfg.archiveDir,['tractor_mu.before_tmax_fault_session_' stamp '.slx']));
backup = fullfile(cfg.archiveDir,['LaunchTCS_Motion.loaded_before_tmax_fault_' stamp '.txt']);
fid = fopen(backup,'w','n','UTF-8');
assert(fid~=-1,'Cannot write function backup.');
fwrite(fid,before,'char'); fclose(fid);

target.Script = after;
save_system(mdl);
fid = fopen(fullfile(cfg.sourceRoot,'LaunchTCS_Motion_code.m'),'w','n','UTF-8');
assert(fid~=-1,'Cannot synchronize function source.');
fwrite(fid,after,'char'); fclose(fid);
assert(~contains(target.Script,'cap_ok'));
fprintf('TMAX_FAULT_REMOVED_AND_TRACTOR_MU_SAVED\n');
end
