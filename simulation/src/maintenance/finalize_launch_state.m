function finalize_launch_state
cfg = maintenance_context();
load_system('tractor_mu');
rt = sfroot;
em = rt.find('-isa','Stateflow.EMChart');
for k = 1:numel(em)
    if contains(em(k).Path,'/MATLAB Function4') || contains(em(k).Path,'/MATLAB Function5')
        params = em(k).find('-isa','Stateflow.Data','Name','P');
        if isempty(params)
            params = Stateflow.Data(em(k));
            params.Name = 'P';
        end
        params.Scope = 'Parameter';
        em(k).SampleTime = '0.001';
        if contains(em(k).Path,'/MATLAB Function4')
            vectorNames = {'w','delta','T_actual','T_max','v_ref','dv', ...
                'spin_on_raw','spin_clear_raw','diag_motion'};
            booleanNames = {'spin_on_raw','spin_clear_raw','no_move_raw','move_ok', ...
                'speed_on_raw','speed_off_raw','consistency_ok','source_immediate_bad','drive_active'};
        else
            vectorNames = {'spin_mask','T_base','T_max','T_pref','T_lim_out','T_cmd','diag_torque'};
            booleanNames = {'spin_mask'};
        end
        for n = vectorNames
            d = em(k).find('-isa','Stateflow.Data','Name',n{1});
            d.Props.Array.Size = '[4 1]';
        end
        for n = booleanNames
            d = em(k).find('-isa','Stateflow.Data','Name',n{1});
            d.DataType = 'boolean';
        end
        if contains(em(k).Path,'/MATLAB Function5')
            d = em(k).find('-isa','Stateflow.Data','Name','stage');
            d.DataType = 'uint8';
        end
    end
end

c = rt.find('-isa','Stateflow.Chart','Name','launch_state');
c.Decomposition = 'PARALLEL_AND';
c.SampleTime = '0.001';
c.UserSpecifiedStateTransitionExecutionOrder = true;
states = c.find('-isa','Stateflow.State');
for k = 1:numel(states)
    s = states(k);
    switch s.Name
        case 'MONITOR'
            mon = s;
        case 'MODE'
            mode = s;
    end
end
mon.ExecutionOrder = 1;
mode.ExecutionOrder = 2;
mon.Decomposition = 'EXCLUSIVE_OR';
mon.Position = [40 40 520 760];
mode.Position = [600 40 900 760];

locals = mon.find('-isa','Stateflow.Data');
for k = 1:numel(locals)
    d = locals(k);
    chartData = Stateflow.Data(c);
    chartData.Name = d.Name;
    chartData.Scope = 'Local';
    if strcmp(d.Name,'spin_on_t') || strcmp(d.Name,'spin_clear_t')
        chartData.Props.Array.Size = '[4 1]';
    elseif strcmp(d.Name,'desired_stage')
        chartData.DataType = 'uint8';
    end
    delete(d);
end

names = {'DISABLED','START_PROBE','NORMAL_LAUNCH','HEAVY_NO_MOVE', ...
    'SINGLE_SPIN','MULTI_SPIN','WORK_PASS','PROTECT'};
codes = [255 0 1 2 3 4 5 6];
children = mode.find('-isa','Stateflow.State');
for k = 1:numel(children)
    s = children(k);
    for j = 1:8
        if startsWith(s.Name,names{j})
            s.LabelString = sprintf('%s\nentry: stage = uint8(%d);',names{j},codes(j));
            col = mod(j-1,2);
            row = floor((j-1)/2);
            s.Position = [650+400*col,100+155*row,260,100];
            break;
        end
    end
end
mw = get_param('tractor_mu','ModelWorkspace');
mw.assignin('P',launch_tcs_params());
save_system('tractor_mu');
close_system('tractor_mu',0);
end
