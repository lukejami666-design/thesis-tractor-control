function diagnose_launch_model
% Compile the saved vehicle model with a sensor stub in memory only.
addpath(fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'scripts'));
cfg = setup_project();
assert(~bdIsLoaded('tractor_mu'), 'Close tractor_mu before this diagnostic; existing edits must be preserved.');
fid=fopen(fullfile(cfg.inspectDir,'launch_model_diagnostic.txt'),'w','n','UTF-8');
assert(fid ~= -1, 'Cannot open diagnostic log.');
cleanup=onCleanup(@()fclose(fid));
try
    load_system('tractor_mu');
    fprintf('MODEL_LOADED\n');
    truck='tractor_mu/TruckSim S-Function';
    ph=get_param(truck,'PortHandles');
    inLine=get_param(ph.Inport(1),'Line');
    outLine=get_param(ph.Outport(1),'Line');
    src=get_param(inLine,'SrcPortHandle');
    dst=get_param(outLine,'DstPortHandle');
    pos=get_param(truck,'Position');
    delete_line(inLine);
    delete_line(outLine);
    delete_block(truck);
    add_block('built-in/Subsystem',truck,'Position',pos);
    add_block('simulink/Ports & Subsystems/In1',[truck '/torque']);
    add_block('simulink/Sinks/Terminator',[truck '/term']);
    add_block('simulink/Sources/Constant',[truck '/sensors'],'Value','zeros(34,1)');
    add_block('simulink/Ports & Subsystems/Out1',[truck '/measurements']);
    add_line(truck,'torque/1','term/1');
    add_line(truck,'sensors/1','measurements/1');
    ph=get_param(truck,'PortHandles');
    add_line('tractor_mu',src,ph.Inport(1));
    for k=1:numel(dst), add_line('tractor_mu',ph.Outport(1),dst(k)); end
    fprintf('SENSOR_STUB_READY\n');
    set_param('tractor_mu','SimulationCommand','update');
    fprintf(fid,'MODEL_UPDATE_OK\n');
    fprintf('MODEL_UPDATE_OK\n');
catch ME
    report=getReport(ME,'extended','hyperlinks','off');
    fprintf(fid,'%s\n',report);
    fprintf('MODEL_UPDATE_FAILED: %s\n',ME.identifier);
    if bdIsLoaded('tractor_mu'), close_system('tractor_mu',0); end
    rethrow(ME);
end
% Discard only this batch process's diagnostic copy.
close_system('tractor_mu',0);
fprintf('DIAGNOSTIC_DONE\n');
end
