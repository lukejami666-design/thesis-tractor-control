cfg = maintenance_context();

load_system('tractor_mu');
anti=Simulink.ID.getHandle('tractor_mu:1787');
new_system('launch_subsystem_check');
add_block(getfullname(anti),'launch_subsystem_check/drive_antislip');
assignin('base','P',launch_tcs_params());
for k=1:11
    name=sprintf('input_%d',k);
    b=add_block('simulink/Sources/Constant',['launch_subsystem_check/',name]);
    if k==11, value='ones(4,1)'; else, value='0'; end
    set_param(b,'Value',value,'Position',[30 40*k 65 40*k+20]);
    add_line('launch_subsystem_check',[name,'/1'],sprintf('drive_antislip/%d',k));
end
for k=1:7
    name=sprintf('output_%d',k);
    b=add_block('simulink/Sinks/Terminator',['launch_subsystem_check/',name]);
    set_param(b,'Position',[600 50*k 620 50*k+20]);
    add_line('launch_subsystem_check',sprintf('drive_antislip/%d',k),[name,'/1']);
end
try
    set_param('launch_subsystem_check','SimulationCommand','update');
    fprintf('SUBSYSTEM_UPDATE_OK\n');
catch ME
    fprintf('SUBSYSTEM_ERROR\n%s\n',getReport(ME,'extended','hyperlinks','off'));
end
exit(0);
