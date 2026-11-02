function repair_launch_in_session
cfg = maintenance_context();
% Apply the compile repairs to the model already open in this MATLAB session.
% Run after setup_project and stopping the simulation.
modelFile=fullfile(cfg.modelRoot,'tractor_mu.slx');
load_system(modelFile);
mdl='tractor_mu';
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'), ...
    'Stop the simulation before applying this repair.');
rt=sfroot;
chartPath=[mdl '/驱动防滑模块/launch_state'];
c=rt.find('-isa','Stateflow.Chart','Path',chartPath);
assert(numel(c)==1,'Expected one launch_state Chart.');
c.ActionLanguage='MATLAB';
c.Decomposition='PARALLEL_AND';
c.ChartUpdate='DISCRETE';
c.SampleTime='0.001';
c.UserSpecifiedStateTransitionExecutionOrder=true;
for name={'no_move_raw','move_ok','speed_on_raw','speed_off_raw', ...
        'consistency_ok','source_immediate_bad','enable','reset'}
    d=c.find('-isa','Stateflow.Data','Name',name{1});
    assert(numel(d)==1,'Missing or duplicated Chart data.');
    d.Props.Array.Size='1';
    if any(strcmp(name{1},{'enable','reset'})), d.DataType='double'; end
end
d=c.find('-isa','Stateflow.Data','Name','i');
if isempty(d), d=Stateflow.Data(c); d.Name='i'; end
d.Scope='Local'; d.DataType='double'; d.Props.Array.Size='1';
p=c.find('-isa','Stateflow.Data','Name','P');
assert(numel(p)==1,'Expected Chart parameter P.');
p.Scope='Parameter';
mon=c.find('-isa','Stateflow.State','Name','MONITOR');
mode=c.find('-isa','Stateflow.State','Name','MODE');
disabled=c.find('-isa','Stateflow.State','Name','DISABLED');
assert(numel(mon)==1 && numel(mode)==1 && numel(disabled)==1);
mon.ExecutionOrder=1; mode.ExecutionOrder=2;
mode.Decomposition='EXCLUSIVE_OR';
assert(strcmp(disabled.Path,[chartPath '/MODE']), ...
    'DISABLED must be inside MODE. Repair the hierarchy before continuing.');
transitions=c.find('-isa','Stateflow.Transition');
hasDefault=false;
for k=1:numel(transitions)
    if isempty(transitions(k).Source)
        if strcmp(transitions(k).Path,[chartPath '/MODE']) && ...
                isequal(transitions(k).Destination,disabled)
            hasDefault=true;
        else
            delete(transitions(k));
        end
    end
end
if ~hasDefault
    t=Stateflow.Transition(mode);
    t.Destination=disabled;
    t.DestinationOClock=12;
    pos=disabled.Position;
    t.SourceEndPoint=[pos(1)+pos(3)/2 pos(2)-25];
end
rear=rt.find('-isa','Stateflow.EMChart','Path',[mdl '/驱动防滑模块/MATLAB Function5']);
assert(numel(rear)==1);
rear.Script=fileread(fullfile(fileparts(mfilename('fullpath')),'LaunchTCS_Torque_code.m'));
param=rear.find('-isa','Stateflow.Data','Name','P');
assert(numel(param)==1);
param.Scope='Parameter';
mw=get_param(mdl,'ModelWorkspace');
if ~mw.hasVariable('P'), mw.assignin('P',launch_tcs_params()); end
assert(abs(mw.evalin('P.Ts')-0.001)<eps,'P.Ts must equal 0.001.');
save_system(mdl,modelFile,'OverwriteIfChangedOnDisk',true);
fprintf('Launch TCS repairs applied to the open model and saved: %s\n',modelFile);
set_param(mdl,'SimulationCommand','update');
fprintf('Vehicle model update completed successfully.\n');
end
