function runData=run_gate_trial(label,case_id,strategy,P)
taskdir=fileparts(mfilename('fullpath'));model='launch_gate_exp';
loadid=str2double(case_id(2));loads=[0 0 0;10000 1000 2800;12000 1200 3360];v=loads(loadid+1,:);
set_param([model '/Implement_Load'],'D0',num2str(v(1)),'B',num2str(v(2)),'C',num2str(v(3)),'LoadMode','1','LoadStart','0','UseDistance','0','StartDistance','0','RampTime','0.4','DMax','80000');
if endsWith(case_id,'U05'),th=[0 .5;1 .5;5 .5];elseif endsWith(case_id,'U08'),th=[0 .8;1 .8;5 .8];else,th=[0 0;1 .8;5 .8];end
assignin('base','gate_throttle',th);assignin('base','P',P);rng(1,'twister');
sw=strcmp(strategy,'baseline');set_param([model '/2'],'CurrentSetting',num2str(sw));
set_param(model,'FastRestart','off','LoadInitialState','off','StopTime','5','FixedStep','0.001');
diary off;diary(fullfile(taskdir,[label '.log']));diary on;lastwarn('');
fprintf('RUN %s %s %s\n',label,case_id,datestr(now,31));started=tic;out=sim(model);elapsed=toc(started);
t=out.tout;data=struct('tout',t);logs=find_system(model,'LookUnderMasks','all','BlockType','ToWorkspace');names=unique(cellfun(@(b)get_param(b,'VariableName'),logs,'UniformOutput',false));
for j=1:numel(names)
 if ~ismember(names{j},out.who),continue;end
 a=out.get(names{j});if isa(a,'timeseries'),a=a.Data;end
 if (isnumeric(a)||islogical(a))&&~isempty(a)
  if size(a,1)~=numel(t)&&mod(numel(a),numel(t))==0,a=reshape(a,[],numel(t))';end
  data.(names{j})=a;
 end
end
data.lambda_raw=data.lamda_raw;data.lambda_filtered=[data.lambda_filtered_1 data.lambda_filtered_2 data.lambda_filtered_3 data.lambda_filtered_4];
data.vx_filtered=data.diag_motion(:,1);data.wheel_speed=data.v_wheel;data.T_max=data.T_max_current;
data.jerk=[NaN;diff(data.ax)/.001];data.D_unlimited=data.Implement_D_unlimited;
assert(numel(t)==5001&&max(abs(diff(t)-.001))<1e-10);
for key={'vx_raw','ax','T_actual','T_max','dv','lambda_raw','T0','Implement_D'},assert(all(isfinite(data.(key{1})(:))),key{1});end
assert(min(data.T_actual(:))>=0);assert(max(data.T_actual(:)-data.T_max(:))<1e-6);
assert(max(abs(data.Implement_Fx_actual+data.Implement_D))<1e-6);
if sw,assert(max(abs(data.T_pre_cap(:)-data.T_base(:)))<1e-5);end
[wm,wi]=lastwarn;
runData=struct('label',label,'case_id',case_id,'strategy',strategy,'P',P,'data',data,'ManualSwitch2_CurrentSetting',sw,'load_parameters',v,'throttle_parameters',th,'elapsed',elapsed,'run_time',datestr(now,31),'model_path',get_param(model,'FileName'),'parameter_source',which('launch_tcs_params'),'warnings',struct('last_message',wm,'last_identifier',wi,'full_log',[label '.log']));
save(fullfile(taskdir,[label '.mat']),'runData','-v7');
fprintf('DONE %s elapsed %.2f\n',label,elapsed);
end
