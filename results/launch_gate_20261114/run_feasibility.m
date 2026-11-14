function run_feasibility(archiveDir,vehicleDataDir)
% Read-only diagnostic branches; no change to candidate J control or vehicle data.
if nargin<1,archiveDir=fileparts(mfilename('fullpath'));end
if nargin<2,vehicleDataDir=pwd;end
oldPwd=pwd;oldPath=path;oldP=evalin('base','P');oldTh=evalin('base','gate_throttle');
cleanup=onCleanup(@()restore(oldPwd,oldP,oldTh,oldPath));
addpath(fullfile(archiveDir,'src'));cd(vehicleDataDir);
s=load(fullfile(archiveDir,'data','r2_J_rise24.mat'),'runData');P=s.runData.P;
ov=load(fullfile(archiveDir,'data','selected_gate_parameter_overrides.mat'));
fn=fieldnames(ov);for j=1:numel(fn),assert(isequaln(P.(fn{j}),ov.(fn{j})));end
save(fullfile(archiveDir,'data','candidate_J_full_parameters.mat'),'P','-v7');
model='launch_gate_diag';
if bdIsLoaded(model),close_system(model,0);end
copyfile(fullfile(archiveDir,'models','launch_gate_exp.slx'),fullfile(archiveDir,'models',[model '.slx']),'f');
load_system(fullfile(archiveDir,'models',[model '.slx']));
% Direct solver export: index map comes from Run_all.par EXPORT order.
record(model,'5750',1,'solver_export_raw');
alloc=[model '/四轮转矩分配/基线垂直载荷分配'];ap=get_param(alloc,'PortHandles');
for j=1:4,record_source(get_param(alloc,'Parent'),ap.Outport(j),sprintf('distribution_raw_%d',j));end
motion=Simulink.ID.getFullName([model ':5662']);ph=get_param(motion,'PortHandles');
for j=[1 6]
 ln=get_param(ph.Inport(j),'Line');src=get_param(ln,'SrcPortHandle');
 names={'omega_raw_radps','','','','','delta_raw_rad'};record_source(get_param(motion,'Parent'),src,names{j});
end
set_param(model,'LoggingFileName',fullfile(archiveDir,'diagnostic_dataset.mat'));
save_system(model);
sf=sfroot;c=sf.find('-isa','Stateflow.Chart','Path',[model '/驱动防滑模块/launch_state']);
f=fopen(fullfile(archiveDir,'src','launch_state_actual.txt'),'w','n','UTF-8');
states=c.find('-isa','Stateflow.State');for j=1:numel(states),fprintf(f,'STATE %s\n%s\n\n',states(j).Name,states(j).LabelString);end
tr=c.find('-isa','Stateflow.Transition');for j=1:numel(tr),fprintf(f,'TRANSITION %s\n',tr(j).LabelString);end;fclose(f);
charts=sf.find('-isa','Stateflow.EMChart');
for j=1:numel(charts)
 if startsWith(charts(j).Path,[model '/']) && contains(charts(j).Script,'LaunchTCS_Motion')
  f=fopen(fullfile(archiveDir,'src','LaunchTCS_Motion.m'),'w','n','UTF-8');fprintf(f,'%s',charts(j).Script);fclose(f);
 end
end
trial('diag_gate_L2_U08','tcs');trial('diag_baseline_L2_U08','baseline');
close_system(model,0);
    function trial(label,strategy)
        set_param([model '/Implement_Load'],'D0','12000','B','1200','C','3360','LoadMode','1','LoadStart','0','UseDistance','0','StartDistance','0','RampTime','0.4','DMax','80000');
        th=[0 .8;1 .8;5 .8];assignin('base','gate_throttle',th);assignin('base','P',P);rng(1,'twister');
        sw=strcmp(strategy,'baseline');set_param([model '/2'],'CurrentSetting',num2str(sw));
        set_param(model,'FastRestart','off','LoadInitialState','off','StopTime','5','FixedStep','0.001','ReturnWorkspaceOutputs','on');
        diary off;diary(fullfile(archiveDir,[label '_warnings.txt']));diary on;lastwarn('');
        out=sim(model);t=out.tout;data=struct('tout',t);logs=find_system(model,'LookUnderMasks','all','BlockType','ToWorkspace');
        names=unique(cellfun(@(b)get_param(b,'VariableName'),logs,'UniformOutput',false));
        for k=1:numel(names)
            if ~ismember(names{k},out.who),continue;end
            a=out.get(names{k});if isa(a,'timeseries'),a=a.Data;end
            if (isnumeric(a)||islogical(a))&&~isempty(a)
                if size(a,1)~=numel(t)&&mod(numel(a),numel(t))==0,a=reshape(a,[],numel(t))';end
                data.(names{k})=a;
            end
        end
        data.lambda_raw=data.lamda_raw;data.lambda_filtered=[data.lambda_filtered_1 data.lambda_filtered_2 data.lambda_filtered_3 data.lambda_filtered_4];
        data.vx_filtered=data.diag_motion(:,1);data.wheel_speed=data.v_wheel;data.T_max=data.T_max_current;
        raw=data.solver_export_raw;assert(size(raw,2)==34);
        data.Fx=raw(:,[26 27 28 29]);data.Fy=raw(:,[31 32 33 34]);data.Fz=raw(:,[12 14 13 15]);
        data.steer_deg=[raw(:,2:3) zeros(numel(t),2)];
        data.Fx_forward_planar=data.Fx.*cosd(data.steer_deg)-data.Fy.*sind(data.steer_deg);
        data.Romega_raw=data.omega_raw_radps.*P.R';
        data.T_distribution_unclipped=[data.distribution_raw_1 data.distribution_raw_2 data.distribution_raw_3 data.distribution_raw_4];
        data.jerk=[NaN;diff(data.ax)/.001];
        actualP=evalin('base','P');assert(isequaln(actualP,P),'Candidate parameters changed during init/sim');
        assert(numel(t)==5001&&max(abs(diff(t)-.001))<1e-10);
        for key={'vx_raw','ax','T_actual','T_max','dv','lambda_raw','T0','Implement_D','Fx','Fy','Fz','omega_raw_radps'},assert(all(isfinite(data.(key{1})(:))),key{1});end
        assert(min(data.T_actual(:))>=0&&max(data.T_actual(:)-data.T_max(:))<1e-6);
        [wm,wi]=lastwarn;
        runData=struct('label',label,'case_id','L2_U08','strategy',strategy,'P',actualP,'data',data,'ManualSwitch2_CurrentSetting',sw,'load_parameters',[12000 1200 3360],'throttle_parameters',th,'run_time',datestr(now,31),'model_path',get_param(model,'FileName'),'parameter_source',which('launch_tcs_params'),'warnings',struct('last_message',wm,'last_identifier',wi,'full_log',[label '_warnings.txt']));
        save(fullfile(archiveDir,'data',[label '.mat']),'runData','-v7');diary off;
    end
end
function record(model,sid,idx,name)
b=Simulink.ID.getFullName([model ':' sid]);ph=get_param(b,'PortHandles');record_source(get_param(b,'Parent'),ph.Outport(idx),name);
end
function record_source(par,src,name)
b=[par '/Diagnostic_Record_' name];add_block('simulink/Sinks/To Workspace',b,'VariableName',name,'SaveFormat','Array','SampleTime','0.001','MaxDataPoints','inf');ph=get_param(b,'PortHandles');add_line(par,src,ph.Inport(1),'autorouting','on');
end
function restore(oldPwd,oldP,oldTh,oldPath)
diary off;assignin('base','P',oldP);assignin('base','gate_throttle',oldTh);cd(oldPwd);path(oldPath);
end
