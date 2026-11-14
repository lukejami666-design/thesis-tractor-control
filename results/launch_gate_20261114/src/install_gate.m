function install_gate(model,taskdir)
sf=sfroot;ch=sf.find('-isa','Stateflow.EMChart');torque=[];motion=[];
for j=1:numel(ch)
 if ~startsWith(ch(j).Path,[model '/']),continue;end
 if contains(ch(j).Script,'LaunchTCS_Torque'),torque=ch(j);end
 if contains(ch(j).Script,'LaunchTCS_Motion'),motion=ch(j);end
end
assert(~isempty(torque)&&~isempty(motion));
c=sf.find('-isa','Stateflow.Chart','Path',[get_param(torque.Path,'Parent') '/launch_state']);assert(numel(c)==1);
states=c.find('-isa','Stateflow.State','Name','MONITOR');assert(numel(states)==1);
mon=fileread(fullfile(taskdir,'MONITOR_gate.txt'));
mon=strrep(mon,char(13),'');
% Set the three Stateflow action fields separately.  This avoids the parser
% treating the state name/action header as an executable action when the
% label is assigned through the API.
parts=regexp(mon,'^(?<name>[^\n]*)\nentry:\n(?<entry>.*?)\nduring:\n(?<during>.*)$','names','once');
if isempty(parts), error('Invalid MONITOR_gate.txt format'); end
% Existing Stateflow versions expose entry/during as read-only API fields;
% assigning the complete label preserves the established chart syntax.
states.LabelString=mon;
newdata(c,'dv_warning','Input',11,'double','[4 1]');
newdata(c,'fast_warning','Input',12,'boolean','[4 1]');
newdata(c,'prewarn','Output',7,'boolean','[4 1]');
newdata(c,'warn_age','Output',8,'double','[4 1]');
for name={'warn_on_t','warn_clear_t','warn_early_t'},newdata(c,name{1},'Local',0,'double','[4 1]');end
newdata(c,'warn_armed','Local',0,'boolean','[4 1]');
torque.Script=fileread(fullfile(taskdir,'LaunchTCS_Torque_gate.m'));
% Existing chart data keep their established port ordering.  New signals are
% created explicitly because EMChart does not auto-create data from the
% MATLAB function signature.
for name={'dv_ctrl','fast_worsening'},
 d=torque.find('-isa','Stateflow.Data','Name',name{1});
 if isempty(d), error('Missing existing Torque data %s',name{1}); end
 d.Props.Array.Size='[4 1]';
end
newchartdata(torque,'source_bad','Input',12,'boolean','[1 1]');
newchartdata(torque,'prewarn','Input',8,'boolean','[4 1]');
newchartdata(torque,'warn_age','Input',9,'double','[4 1]');
newchartdata(torque,'T_actual_prev','Input',10,'double','[4 1]');
newchartdata(torque,'vx_raw','Input',11,'double','[1 1]');
newchartdata(torque,'gate_diag','Output',13,'double','[72 1]');
par=get_param(torque.Path,'Parent');mp=get_param(motion.Path,'PortHandles');tp=get_param(torque.Path,'PortHandles');cp=get_param(c.Path,'PortHandles');
assert(numel(tp.Inport)==12 && numel(tp.Outport)==13);
add_line(par,mp.Outport(13),cp.Inport(11),'autorouting','on');
add_line(par,mp.Outport(15),cp.Inport(12),'autorouting','on');
add_line(par,cp.Outport(7),tp.Inport(8),'autorouting','on');
add_line(par,cp.Outport(8),tp.Inport(9),'autorouting','on');
actualLine=get_param(mp.Inport(8),'Line');actualSource=get_param(actualLine,'SrcPortHandle');
add_line(par,actualSource,tp.Inport(10),'autorouting','on');
speedLine=get_param(mp.Inport(2),'Line');speedSource=get_param(speedLine,'SrcPortHandle');
add_line(par,speedSource,tp.Inport(11),'autorouting','on');
add_line(par,cp.Outport(5),tp.Inport(12),'autorouting','on');
record(par,cp.Outport(7),'prewarn');record(par,cp.Outport(8),'warn_age');record(par,tp.Outport(13),'gate_diag');
% Only new P structures may initialize this model; full candidate P is preserved.
init=get_param(model,'InitFcn');
set_param(model,'InitFcn',[init newline 'if ~exist(''P'',''var'') || ~isfield(P,''gate_version''), P=gate_params(launch_tcs_params()); end']);
P=gate_params(launch_tcs_params());assignin('base','P',P);
save_system(model,fullfile(taskdir,[model '.slx']));
end
function newdata(c,name,scope,port,dtype,dims)
d=c.find('-isa','Stateflow.Data','Name',name);if isempty(d),d=Stateflow.Data(c);d.Name=name;end
d.Scope=scope;d.DataType=dtype;d.Props.Array.Size=dims;if port>0,d.Port=port;end
end
function newchartdata(ch,name,scope,port,dtype,dims)
d=ch.find('-isa','Stateflow.Data','Name',name);
if isempty(d),d=Stateflow.Data(ch);d.Name=name;end
d.Scope=scope;d.DataType=dtype;d.Props.Array.Size=dims;d.Port=port;
end
function record(par,src,name)
b=[par '/Gate_Record_' name];add_block('simulink/Sinks/To Workspace',b,'VariableName',name,'SaveFormat','Array','SampleTime','0.001','MaxDataPoints','inf');p=get_param(b,'PortHandles');add_line(par,src,p.Inport(1),'autorouting','on');
end
