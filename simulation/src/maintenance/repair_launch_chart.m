function repair_launch_chart
cfg = maintenance_context();
load_system('tractor_mu');
rt = sfroot;
c = rt.find('-isa','Stateflow.Chart','Name','launch_state');
objects = c.find('-isa','Stateflow.Transition');
if ~isempty(objects), delete(objects); end
objects = c.find('-isa','Stateflow.Junction');
if ~isempty(objects), delete(objects); end
objects = c.find('-isa','Stateflow.State');
if ~isempty(objects), delete(objects); end

c.Decomposition = 'PARALLEL_AND';
c.SampleTime = '0.001';
c.UserSpecifiedStateTransitionExecutionOrder = true;
mon = Stateflow.State(c);
mon.Name = 'MONITOR';
mon.Position = [40 40 520 760];
mon.ExecutionOrder = 1;
mon.LabelString = fileread('monitor_label.txt');
mode = Stateflow.State(c);
mode.Name = 'MODE';
mode.Position = [600 40 950 760];
mode.ExecutionOrder = 2;
mode.Decomposition = 'EXCLUSIVE_OR';

names = {'DISABLED','START_PROBE','NORMAL_LAUNCH','HEAVY_NO_MOVE', ...
    'SINGLE_SPIN','MULTI_SPIN','WORK_PASS','PROTECT'};
codes = [255 0 1 2 3 4 5 6];
states = cell(1,8);
for k = 1:8
    states{k} = Stateflow.State(mode);
    states{k}.LabelString = sprintf('%s\nentry: stage = uint8(%d);',names{k},codes(k));
    col = mod(k-1,2);
    row = floor((k-1)/2);
    states{k}.Position = [650+420*col,100+155*row,280,100];
end
j = Stateflow.Junction(mode);
tr = Stateflow.Transition(mode);
tr.Destination = states{1};
for k = 1:8
    tr = Stateflow.Transition(mode);
    tr.Source = states{k};
    tr.Destination = j;
    tr.LabelString = sprintf('[desired_stage ~= uint8(%d)]',codes(k));
    tr = Stateflow.Transition(mode);
    tr.Source = j;
    tr.Destination = states{k};
    tr.LabelString = sprintf('[desired_stage == uint8(%d)]',codes(k));
end
save_system('tractor_mu');
close_system('tractor_mu',0);
end
