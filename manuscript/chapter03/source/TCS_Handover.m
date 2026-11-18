function [T_pref_blend,handover_fallback,T_launch_anchor]=TCS_Handover(control_phase,blend_alpha,T_launch_pref,T_pref_work,T_base,smc_valid,T_applied_cmd_prev,reset,P)
%#codegen
% 中文注释永久保留：后续修改代码时不得删除注释，只能根据代码更新修改注释表述。
% 唯一扭矩偏好选择器，单位 N·m；BLEND 入口锁存上一拍真正下发的起步命令。
persistent anchor previous_phase
if isempty(anchor),anchor=zeros(4,1);previous_phase=uint8(0);end
if reset>0.5,anchor=max(T_applied_cmd_prev,0);previous_phase=uint8(0);end
phase=uint8(control_phase);
if phase==uint8(1)&&previous_phase~=uint8(1),anchor=max(T_applied_cmd_prev,0);end
T_pref_blend=zeros(4,1);handover_fallback=false(4,1);
for i=1:4
 work=max(T_base(i),0);
 if smc_valid(i),work=max(T_pref_work(i),0);else,handover_fallback(i)=phase==uint8(1)||phase==uint8(2);end
 if phase==uint8(0),T_pref_blend(i)=max(T_launch_pref(i),0);
 elseif phase==uint8(1),a=min(max(blend_alpha,0),1);T_pref_blend(i)=(1-a)*anchor(i)+a*work;
 elseif phase==uint8(2),T_pref_blend(i)=work;
 end
end
T_launch_anchor=anchor;previous_phase=phase;
end
