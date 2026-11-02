cfg = maintenance_context();
load_system('tractor_mu');
rt=sfroot;
% Find target objects without relying on non-ASCII paths.
fc=rt.find('-isa','Stateflow.EMChart','Name','true');
for k=1:numel(fc), if contains(fc(k).Path,'MATLAB Function4'), front=fc(k); end, end
rc=rt.find('-isa','Stateflow.EMChart','Name','LaunchTCS_Torque'); rear=rc(1);
charts=rt.find('-isa','Stateflow.Chart','Name','launch_state'); chart=charts(1);
front.Script=fileread(fullfile(cfg.sourceRoot,'LaunchTCS_Motion_code.m')); front.Inputs='w,vx,vy,ax,r,delta,speed_src_valid,T_actual,T_max,reset'; front.Outputs='v_ref,dv,spin_on_raw,spin_clear_raw,no_move_raw,move_ok,speed_on_raw,speed_off_raw,consistency_ok,source_immediate_bad,drive_active,diag_motion'; front.SampleTime='P.Ts';
rear.Script=fileread(fullfile(cfg.sourceRoot,'LaunchTCS_Torque_code.m')); rear.Inputs='stage,spin_mask,T_base,T_max,reset'; rear.Outputs='T_pref,T_lim_out,T_cmd,diag_torque'; rear.SampleTime='P.Ts';
% Rebuild chart.
for typ={'Stateflow.State','Stateflow.Transition','Stateflow.Junction','Stateflow.Data'}
  objs=chart.find('-isa',typ{1}); if ~isempty(objs), delete(objs); end
end
chart.ActionLanguage='MATLAB'; chart.SampleTime='P.Ts'; chart.UserSpecifiedStateTransitionExecutionOrder=true;
% Inputs and outputs.
inNames={'spin_on_raw','spin_clear_raw','no_move_raw','move_ok','speed_on_raw','speed_off_raw','consistency_ok','source_immediate_bad','enable','reset'};
outNames={'stage','spin_mask','speed_valid','no_move_confirmed','source_bad','nspin'};
for k=1:numel(inNames)
 d=Stateflow.Data(chart); d.Name=inNames{k}; d.Scope='Input'; d.DataType='boolean'; d.Port=k; if k<=2, d.Props.Array.Size=[4 1]; end
end
for k=1:numel(outNames)
 d=Stateflow.Data(chart); d.Name=outNames{k}; d.Scope='Output'; d.Port=k;
 if strcmp(outNames{k},'stage'), d.DataType='uint8'; elseif strcmp(outNames{k},'spin_mask'), d.DataType='boolean'; d.Props.Array.Size=[4 1]; elseif strcmp(outNames{k},'nspin'), d.DataType='double'; else, d.DataType='boolean'; end
end
p=Stateflow.Data(chart); p.Name='P'; p.Scope='Parameter';
% top-level parallel states
mon=Stateflow.State(chart); mon.Name='MONITOR'; mon.LabelString='MONITOR'; mon.ExecutionOrder=1; mon.Decomposition='PARALLEL_AND';
mode=Stateflow.State(chart); mode.Name='MODE'; mode.LabelString='MODE'; mode.ExecutionOrder=2; mode.Decomposition='OR_STATE';
% monitor local data
locals={'spin_on_t','spin_clear_t','no_move_t','speed_on_t','speed_off_t','cons_bad_t'};
for k=1:numel(locals), d=Stateflow.Data(mon); d.Name=locals{k}; d.Scope='Local'; d.DataType='double'; if k<=2, d.Props.Array.Size=[4 1]; end, end
d=Stateflow.Data(mon); d.Name='desired_stage'; d.Scope='Local'; d.DataType='uint8';
% monitor state action
mon.EntryAction=['spin_on_t=zeros(4,1); spin_clear_t=zeros(4,1); spin_mask=false(4,1); nspin=0; no_move_t=0; no_move_confirmed=false; speed_on_t=0; speed_off_t=0; speed_valid=false; cons_bad_t=0; source_bad=false; desired_stage=uint8(255);'];
mon.DuringAction=['if enable<=0.5 || reset>0.5\n spin_on_t=zeros(4,1); spin_clear_t=zeros(4,1); spin_mask=false(4,1); nspin=0; no_move_t=0; no_move_confirmed=false; speed_on_t=0; speed_off_t=0; speed_valid=false; cons_bad_t=0; source_bad=false; if enable<=0.5, desired_stage=uint8(255); else, desired_stage=uint8(0); end\nelse\n for i=1:4\n  if spin_on_raw(i), spin_on_t(i)=min(P.t_spin_on,spin_on_t(i)+P.Ts); spin_clear_t(i)=0; else, spin_on_t(i)=max(0,spin_on_t(i)-P.Ts); if spin_clear_raw(i), spin_clear_t(i)=min(P.t_spin_clear,spin_clear_t(i)+P.Ts); else, spin_clear_t(i)=0; end, end\n  if spin_on_t(i)>=P.t_spin_on, spin_mask(i)=true; end\n  if spin_clear_t(i)>=P.t_spin_clear, spin_mask(i)=false; end\n end\n nspin=sum(double(spin_mask));\n if no_move_raw, no_move_t=min(P.t_no_move,no_move_t+P.Ts); elseif move_ok, no_move_t=0; else, no_move_t=max(0,no_move_t-P.Ts); end\n no_move_confirmed=no_move_t>=P.t_no_move;\n if consistency_ok, cons_bad_t=max(0,cons_bad_t-P.Ts); else, cons_bad_t=min(P.t_cons_bad,cons_bad_t+P.Ts); end\n source_bad=source_immediate_bad || cons_bad_t>=P.t_cons_bad;\n if ~speed_valid, if speed_on_raw && nspin<=1 && ~source_bad, speed_on_t=min(P.t_speed_on,speed_on_t+P.Ts); else, speed_on_t=0; end; if speed_on_t>=P.t_speed_on, speed_valid=true; speed_off_t=0; end; else, if speed_off_raw || nspin>=2 || source_bad, speed_off_t=min(P.t_speed_off,speed_off_t+P.Ts); else, speed_off_t=0; end; if speed_off_t>=P.t_speed_off, speed_valid=false; speed_on_t=0; end; end\n if source_bad, desired_stage=uint8(6); elseif nspin>=2, desired_stage=uint8(4); elseif nspin==1, desired_stage=uint8(3); elseif speed_valid, desired_stage=uint8(5); elseif no_move_confirmed, desired_stage=uint8(2); elseif move_ok, desired_stage=uint8(1); else, desired_stage=uint8(0); end\nend'];
% MODE states
names={'DISABLED','START_PROBE','NORMAL_LAUNCH','HEAVY_NO_MOVE','SINGLE_SPIN','MULTI_SPIN','WORK_PASS','PROTECT'}; nums=[255 0 1 2 3 4 5 6]; states=cell(1,8);
for k=1:8, states{k}=Stateflow.State(mode); states{k}.Name=names{k}; states{k}.LabelString=[names{k},'\nentry: stage=uint8(',num2str(nums(k)),');']; states{k}.EntryAction=['stage=uint8(',num2str(nums(k)),');']; end
% Default transition to DISABLED
tr=Stateflow.Transition(mode); tr.Destination=states{1};
% Junction and transitions
j=Stateflow.Junction(mode);
for k=1:8
 tr=Stateflow.Transition(mode); tr.Source=states{k}; tr.Destination=j; tr.LabelString=['[desired_stage ~= uint8(',num2str(nums(k)),')]'];
 tr=Stateflow.Transition(mode); tr.Source=j; tr.Destination=states{k}; tr.LabelString=['[desired_stage == uint8(',num2str(nums(k)),')]'];
end
% ensure chart update discrete and save
save_system('tractor_mu'); close_system('tractor_mu',0); exit;
