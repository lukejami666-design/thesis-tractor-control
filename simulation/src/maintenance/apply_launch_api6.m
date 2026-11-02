cfg = maintenance_context();
try
load_system('tractor_mu'); rt=sfroot; e=rt.find('-isa','Stateflow.EMChart'); front=[]; rear=[]; for k=1:numel(e), if contains(e(k).Path,'MATLAB Function4'), front=e(k); end; if contains(e(k).Path,'MATLAB Function5'), rear=e(k); end; end; fprintf('found %d %d\n',numel(front),numel(rear)); charts=rt.find('-isa','Stateflow.Chart','Name','launch_state'); chart=charts(1); fprintf('chart %d\n',numel(charts)); front.Script=fileread(fullfile(cfg.sourceRoot,'LaunchTCS_Motion_code.m')); fprintf('front ok\n'); rear.Script=fileread(fullfile(cfg.sourceRoot,'LaunchTCS_Torque_code.m')); fprintf('rear ok\n');
% delete old chart elements
for typ={'Stateflow.State','Stateflow.Transition','Stateflow.Junction','Stateflow.Data'}, objs=chart.find('-isa',typ{1}); if ~isempty(objs), delete(objs); end, end; chart.ActionLanguage='MATLAB'; chart.UserSpecifiedStateTransitionExecutionOrder=true;
inNames={'spin_on_raw','spin_clear_raw','no_move_raw','move_ok','speed_on_raw','speed_off_raw','consistency_ok','source_immediate_bad','enable','reset'}; outNames={'stage','spin_mask','speed_valid','no_move_confirmed','source_bad','nspin'};
for k=1:numel(inNames), d=Stateflow.Data(chart); d.Name=inNames{k}; d.Scope='Input'; d.Port=k; if k<=2, d.DataType='boolean'; d.Props.Array.Size='[4 1]'; else, d.DataType='boolean'; end, end
for k=1:numel(outNames), d=Stateflow.Data(chart); d.Name=outNames{k}; d.Scope='Output'; d.Port=k; if k==1,d.DataType='uint8'; elseif k==2,d.DataType='boolean'; d.Props.Array.Size='[4 1]'; elseif k==6,d.DataType='double'; else,d.DataType='boolean'; end, end
p=Stateflow.Data(chart); p.Name='P'; p.Scope='Parameter'; fprintf('data ok\n');
mon=Stateflow.State(chart); mon.Name='MONITOR'; mon.ExecutionOrder=1; mon.Decomposition='PARALLEL_AND'; mode=Stateflow.State(chart); mode.Name='MODE'; mode.ExecutionOrder=2; mode.Decomposition='EXCLUSIVE_OR';
for nm={'spin_on_t','spin_clear_t','no_move_t','speed_on_t','speed_off_t','cons_bad_t','desired_stage'}, d=Stateflow.Data(mon); d.Name=nm{1}; d.Scope='Local'; d.DataType='double'; end
mon.LabelString=fileread('monitor_label.txt');
names={'DISABLED','START_PROBE','NORMAL_LAUNCH','HEAVY_NO_MOVE','SINGLE_SPIN','MULTI_SPIN','WORK_PASS','PROTECT'}; nums=[255 0 1 2 3 4 5 6]; st=cell(1,8); for k=1:8, st{k}=Stateflow.State(mode); st{k}.Name=names{k}; st{k}.EntryAction=['stage=uint8(',num2str(nums(k)),');']; end; tr=Stateflow.Transition(mode); tr.Destination=st{1}; j=Stateflow.Junction(mode); for k=1:8, tr=Stateflow.Transition(mode); tr.Source=st{k}; tr.Destination=j; tr.LabelString=['[desired_stage ~= uint8(',num2str(nums(k)),')]']; tr=Stateflow.Transition(mode); tr.Source=j; tr.Destination=st{k}; tr.LabelString=['[desired_stage == uint8(',num2str(nums(k)),')]']; end; fprintf('states ok\n'); save_system('tractor_mu'); close_system('tractor_mu',0); exit;
catch ME, fid=fopen(fullfile(cfg.inspectDir, 'apply_err.txt'),'w'); fprintf(fid,'%s',getReport(ME,'extended','hyperlinks','off')); fclose(fid); exit(1); end




