cfg = maintenance_context();
try
load_system('tractor_mu');
rt=sfroot; fprintf('A\n');
fc=rt.find('-isa','Stateflow.EMChart','Name','true'); fprintf('fc %d\n',numel(fc)); front=[]; for k=1:numel(fc), if contains(fc(k).Path,'MATLAB Function4'), front=fc(k); end, end; fprintf('front %d\n',numel(front));
rc=rt.find('-isa','Stateflow.EMChart','Name','LaunchTCS_Torque'); fprintf('rc %d\n',numel(rc)); rear=rc(1); charts=rt.find('-isa','Stateflow.Chart','Name','launch_state'); fprintf('charts %d\n',numel(charts)); chart=charts(1);
front.Script=fileread(fullfile(cfg.sourceRoot,'LaunchTCS_Motion_code.m')); fprintf('script front\n'); front.Inputs='w,vx,vy,ax,r,delta,speed_src_valid,T_actual,T_max,reset'; front.Outputs='v_ref,dv,spin_on_raw,spin_clear_raw,no_move_raw,move_ok,speed_on_raw,speed_off_raw,consistency_ok,source_immediate_bad,drive_active,diag_motion'; fprintf('ports front\n');
rear.Script=fileread(fullfile(cfg.sourceRoot,'LaunchTCS_Torque_code.m')); fprintf('script rear\n'); rear.Inputs='stage,spin_mask,T_base,T_max,reset'; rear.Outputs='T_pref,T_lim_out,T_cmd,diag_torque'; fprintf('ports rear\n');
chart.ActionLanguage='MATLAB'; fprintf('chart action\n');
close_system('tractor_mu',0); exit;
catch ME
fid=fopen(fullfile(cfg.inspectDir, 'err.txt'),'w'); fprintf(fid,'%s\n',getReport(ME,'extended','hyperlinks','off')); fclose(fid); exit(1);
end
