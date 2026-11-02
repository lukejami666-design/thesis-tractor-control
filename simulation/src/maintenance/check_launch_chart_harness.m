cfg = maintenance_context();

load_system('tractor_mu_compile_repaired_v2');
rt = sfroot;
c = rt.find('-isa','Stateflow.Chart','Name','launch_state');
new_system('launch_chart_check');
add_block(c.Path,'launch_chart_check/launch_state');
checkChart=rt.find('-isa','Stateflow.Chart','Path','launch_chart_check/launch_state');
assert(numel(checkChart.find('-isa','Stateflow.Data','Name','i'))==1);
em=rt.find('-isa','Stateflow.EMChart');
motion=[];
torque=[];
for n=1:numel(em)
    if contains(em(n).Path,'/MATLAB Function4') && contains(em(n).Path,'tractor_mu_compile_repaired_v2/')
        motion=em(n);
    end
    if contains(em(n).Path,'/MATLAB Function5') && contains(em(n).Path,'tractor_mu_compile_repaired_v2/')
        torque=em(n);
    end
end
assert(~isempty(motion) && ~isempty(torque));
add_block(motion.Path,'launch_chart_check/LaunchTCS_Motion');
add_block(torque.Path,'launch_chart_check/LaunchTCS_Torque');
assignin('base','P',launch_tcs_params());
for k=1:10
    name = sprintf('in%d',k);
    b = add_block('simulink/Sources/Constant',['launch_chart_check/',name]);
    if any(k==[1 6 8])
        set_param(b,'Value','zeros(4,1)');
    elseif k==9
        set_param(b,'Value','ones(4,1)');
    elseif k==7
        set_param(b,'Value','1');
    else
        set_param(b,'Value','0');
    end
    set_param(b,'Position',[30 35*k 65 35*k+20]);
    add_line('launch_chart_check',[name,'/1'],sprintf('LaunchTCS_Motion/%d',k));
end
for k=1:8
    add_line('launch_chart_check',sprintf('LaunchTCS_Motion/%d',k+2),sprintf('launch_state/%d',k));
end
for k=9:10
    name=sprintf('chart_in%d',k);
    b=add_block('simulink/Sources/Constant',['launch_chart_check/',name]);
    set_param(b,'Value',num2str(k==9));
    set_param(b,'Position',[220 35*k 255 35*k+20]);
    add_line('launch_chart_check',[name,'/1'],sprintf('launch_state/%d',k));
end
for k=1:6
    name=sprintf('out%d',k);
    b=add_block('simulink/Sinks/Terminator',['launch_chart_check/',name]);
    set_param(b,'Position',[380 45*k 400 45*k+20]);
    add_line('launch_chart_check',sprintf('launch_state/%d',k),[name,'/1']);
end
add_line('launch_chart_check','launch_state/1','LaunchTCS_Torque/1');
add_line('launch_chart_check','launch_state/2','LaunchTCS_Torque/2');
for k=3:5
    name=sprintf('torque_in%d',k);
    b=add_block('simulink/Sources/Constant',['launch_chart_check/',name]);
    if k<5, set_param(b,'Value','ones(4,1)'); else, set_param(b,'Value','0'); end
    set_param(b,'Position',[480 35*k 515 35*k+20]);
    add_line('launch_chart_check',[name,'/1'],sprintf('LaunchTCS_Torque/%d',k));
end
for k=1:4
    name=sprintf('torque_out%d',k);
    b=add_block('simulink/Sinks/Terminator',['launch_chart_check/',name]);
    set_param(b,'Position',[600 45*k 620 45*k+20]);
    add_line('launch_chart_check',sprintf('LaunchTCS_Torque/%d',k),[name,'/1']);
end
try
    set_param('launch_chart_check','SimulationCommand','update');
    fprintf('HARNESS_UPDATE_OK\n');
catch ME
    fprintf('HARNESS_ERROR\n%s\n',getReport(ME,'extended','hyperlinks','off'));
end
exit(0);
