function rebuild_launch_chart
cfg = maintenance_context();
load_system('tractor_mu');
rt = sfroot;
c = rt.find('-isa','Stateflow.Chart','Name','launch_state');
chartPath = c.Path;
tr = rt.find('-isa','Stateflow.Transition');
for k = numel(tr):-1:1
    if startsWith(tr(k).Path,chartPath), delete(tr(k)); end
end
st = rt.find('-isa','Stateflow.State');
for k = numel(st):-1:1
    if startsWith(st(k).Path,chartPath), delete(st(k)); end
end
jn = rt.find('-isa','Stateflow.Junction');
for k = numel(jn):-1:1
    if startsWith(jn(k).Path,chartPath), delete(jn(k)); end
end
st = rt.find('-isa','Stateflow.State');
for k = 1:numel(st)
    assert(~startsWith(st(k).Path,chartPath),'Old chart state remains');
end

c.Decomposition = 'PARALLEL_AND';
c.SampleTime = '0.001';
c.UserSpecifiedStateTransitionExecutionOrder = true;
mon = Stateflow.State(c);
mon.Position = [40 40 520 760];
mon.LabelString = fileread('monitor_label.txt');
mon.ExecutionOrder = 1;
mode = Stateflow.State(c);
mode.Position = [600 40 950 760];
mode.LabelString = 'MODE';
mode.ExecutionOrder = 2;
mode.Decomposition = 'EXCLUSIVE_OR';
names = {'DISABLED','START_PROBE','NORMAL_LAUNCH','HEAVY_NO_MOVE', ...
    'SINGLE_SPIN','MULTI_SPIN','WORK_PASS','PROTECT'};
codes = [255 0 1 2 3 4 5 6];
states = cell(1,8);
for k = 1:8
    states{k} = Stateflow.State(mode);
    states{k}.Position = [50+400*mod(k-1,2),60+150*floor((k-1)/2),260,90];
    states{k}.LabelString = sprintf('%s\nentry: stage = uint8(%d);',names{k},codes(k));
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
