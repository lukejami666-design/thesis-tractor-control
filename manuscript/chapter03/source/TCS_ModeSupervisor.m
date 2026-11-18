function [control_phase,blend_alpha,phase_changed,launch_enable,work_enable,protect_enable,work_enter_event,work_exit_event,work_param_invalid]=TCS_ModeSupervisor(vx,w,T_max,source_bad,slip_valid,reset,P)
%#codegen
% 中文注释永久保留：后续修改代码时不得删除注释，只能根据代码更新修改注释表述。
% 唯一阶段来源；速度 m/s、角速度 rad/s、能力 N·m；独立于旧 desired_stage/nspin。
persistent phase on_t off_t blend_t
if isempty(phase),phase=uint8(0);on_t=0;off_t=0;blend_t=0;end
old=phase;work_enter_event=false;work_exit_event=false;
work_param_invalid=~WorkSlip_validate_params(P);
bad=source_bad || ~isfinite(vx) || any(~isfinite(w)) || any(~isfinite(T_max)) || any(T_max<0) || work_param_invalid;
if reset>0.5
 phase=uint8(0);on_t=0;off_t=0;blend_t=0;
elseif bad
 phase=uint8(3);on_t=0;off_t=0;blend_t=0;
else
 if phase==uint8(3),phase=uint8(0);end
 if phase==uint8(0)
  enter=vx>=P.work_v_on && sum(double(slip_valid))>=P.work_min_valid_wheels;
  if enter,on_t=on_t+P.Ts;else,on_t=0;end
  if on_t>=P.work_on_hold,phase=uint8(1);blend_t=0;off_t=0;work_enter_event=true;end
 elseif phase==uint8(1)
  if vx<P.work_v_off,phase=uint8(0);on_t=0;blend_t=0;
  else,blend_t=min(blend_t+P.Ts,P.work_blend_time);if blend_t>=P.work_blend_time,phase=uint8(2);end,end
 elseif phase==uint8(2)
  if vx<P.work_v_off,off_t=off_t+P.Ts;else,off_t=0;end
  if off_t>=P.work_off_hold,phase=uint8(0);on_t=0;blend_t=0;end
 end
end
phase_changed=phase~=old;
work_exit_event=(old==uint8(1)||old==uint8(2)) && (phase==uint8(0)||phase==uint8(3));
blend_alpha=0;if phase==uint8(1),blend_alpha=blend_t/max(P.work_blend_time,P.Ts);elseif phase==uint8(2),blend_alpha=1;end
control_phase=phase;launch_enable=phase==uint8(0);work_enable=phase==uint8(1)||phase==uint8(2);protect_enable=phase==uint8(3);
end
