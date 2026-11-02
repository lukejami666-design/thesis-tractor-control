function verify_launch_repair
cfg = maintenance_context();

fid=fopen('launch_repair_verification.txt','w','n','UTF-8');
cleanup=onCleanup(@()fclose(fid));
try
    load_system('tractor_mu_repair_20261030');
    rt=sfroot;
    charts=rt.find('-isa','Stateflow.EMChart');
    front=[]; rear=[];
    for k=1:numel(charts)
        if endsWith(charts(k).Path,'/MATLAB Function4'), front=charts(k); end
        if endsWith(charts(k).Path,'/MATLAB Function5'), rear=charts(k); end
    end
    chart=rt.find('-isa','Stateflow.Chart','Name','launch_state');
    assert(numel(chart)==1 && ~isempty(front) && ~isempty(rear));
    new_system('launch_repair_check');
    add_block(front.Path,'launch_repair_check/Motion');
    add_block(chart.Path,'launch_repair_check/Mode');
    add_block(rear.Path,'launch_repair_check/Torque');
    mw=get_param('tractor_mu_repair_20261030','ModelWorkspace');
    checkMw=get_param('launch_repair_check','ModelWorkspace');
    checkMw.assignin('P',mw.evalin('P'));
    fprintf('THREE_BLOCKS_COPIED\n');
    values={'zeros(4,1)','0','0','0','0','zeros(4,1)','1', ...
        '','2000*ones(4,1)','0'};
    for k=[1:7 9:10]
        name=sprintf('input%d',k);
        add_block('simulink/Sources/Constant',['launch_repair_check/' name],'Value',values{k});
        add_line('launch_repair_check',[name '/1'],sprintf('Motion/%d',k));
    end
    add_block('simulink/Sources/Constant','launch_repair_check/enable','Value','1');
    add_block('simulink/Sources/Constant','launch_repair_check/T_base','Value','1000*ones(4,1)');
    for k=1:8
        add_line('launch_repair_check',sprintf('Motion/%d',k+2),sprintf('Mode/%d',k));
    end
    add_line('launch_repair_check','enable/1','Mode/9');
    add_line('launch_repair_check','input10/1','Mode/10');
    add_line('launch_repair_check','Mode/1','Torque/1');
    add_line('launch_repair_check','Mode/2','Torque/2');
    add_line('launch_repair_check','T_base/1','Torque/3');
    add_line('launch_repair_check','input9/1','Torque/4');
    add_line('launch_repair_check','input10/1','Torque/5');
    add_block('simulink/Discrete/Unit Delay','launch_repair_check/feedback', ...
        'SampleTime','0.001','InitialCondition','zeros(4,1)');
    add_line('launch_repair_check','Torque/3','feedback/1');
    add_line('launch_repair_check','feedback/1','Motion/8');
    set_param('launch_repair_check','SolverType','Fixed-step', ...
        'Solver','FixedStepDiscrete','FixedStep','0.001');
    set_param('launch_repair_check','SimulationCommand','update');
    fprintf('THREE_BLOCKS_UPDATE_OK\n');
    fprintf(fid,'THREE_BLOCKS_UPDATE_OK\n');
    sim('launch_repair_check','StopTime','0.01');
    fprintf('FEEDBACK_SIMULATION_OK\n');
    fprintf(fid,'FEEDBACK_SIMULATION_OK\n');
catch ME
    fprintf(fid,'%s\n',getReport(ME,'extended','hyperlinks','off'));
    fprintf('VERIFICATION_FAILED %s\n',ME.identifier);
end
if bdIsLoaded('launch_repair_check'), close_system('launch_repair_check',0); end
if bdIsLoaded('tractor_mu_repair_20261030'), close_system('tractor_mu_repair_20261030',0); end
fprintf('VERIFICATION_DONE\n');
end
