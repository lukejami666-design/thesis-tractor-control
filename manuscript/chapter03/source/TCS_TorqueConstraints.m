function [T_cmd,cap_active,total_demand_active,rise_slew_active,fall_slew_active,slew_override,demand_unmet,protect_active,projection_lambda,T_total_req,total_demand_source,T_safe] = TCS_TorqueConstraints(T_pref,T_req_raw,T_base,T_max,T_launch_safe,T_prev,phase,source_bad,reset,P)
%#codegen
% 中文注释永久保留：后续修改代码时不得删除注释，只能根据代码更新修改注释表述。
% 唯一最终变化率/能力/总需求约束层。轮端 N·m，变化率 N·m/s，FL FR RL RR。
% T_req_raw 的物理语义是顶层输入 T0 的原始总扭矩需求预算（标量 N·m）。
% 真实 T0 有效时直接进入总需求约束；T_base 仅用于四轮分配参考，不能替代 T0。
% total_demand_source: 0=T0_VALID，2=T0_INVALID_PROTECT。历史 BASE_SUM_FALLBACK 不再作为正常来源。
T_total_req=T_req_raw;total_demand_source=uint8(0);
if ~isfinite(T_req_raw)||T_req_raw<0
    T_total_req=0;
    total_demand_source=uint8(2);
end
if ~isfinite(T_total_req)||T_total_req<0
    T_total_req=0;
    total_demand_source=uint8(2);
end
T_total_req=max(T_total_req,0);T_cmd=zeros(4,1);cap_active=false(4,1);rise_slew_active=false(4,1);fall_slew_active=false(4,1);
protect_active=source_bad || total_demand_source==uint8(2) || uint8(phase)==uint8(3) || ~WorkSlip_validate_params(P) || ...
 any(~isfinite(T_pref)) || any(~isfinite(T_max)) || any(T_max<0) || any(~isfinite(T_prev)) || any(~isfinite(T_base));
T_safe=max(T_max,0);L=zeros(4,1);U=zeros(4,1);pref=zeros(4,1);slew_override=false;
for i=1:4
 cap=max(T_max(i),0);if ~isfinite(cap),cap=0;end
 T_safe(i)=cap;
 if uint8(phase)==uint8(0),T_safe(i)=min(cap,max(T_launch_safe(i),0));end
 if protect_active||reset>0.5,T_safe(i)=0;end
 prev=max(T_prev(i),0);if ~isfinite(prev),prev=0;end
 L(i)=max(0,prev-P.work_fall_rate(i)*P.Ts);U(i)=min(T_safe(i),prev+P.work_rise_rate(i)*P.Ts);
 if L(i)>U(i),L(i)=U(i);slew_override=true;end
 pref(i)=T_pref(i);if ~isfinite(pref(i)),pref(i)=0;end
end
if sum(L)>T_total_req,L=zeros(4,1);slew_override=true;end
% 对原偏好作加权投影，WORK 不以逐轮基础分配为硬上限。
T_cmd=min(max(pref,L),U);projection_lambda=0;total_demand_active=sum(T_cmd)>T_total_req+1e-8;
if total_demand_active
 lo=0;hi=max(max((pref-L).*P.work_proj_weight),1);
 for j=1:60
  mid=(lo+hi)/2;x=min(max(pref-mid./P.work_proj_weight,L),U);
  if sum(x)>T_total_req,lo=mid;else,hi=mid;end
 end
 projection_lambda=hi;T_cmd=min(max(pref-hi./P.work_proj_weight,L),U);
end
for i=1:4
 cap_active(i)=pref(i)>T_max(i)+1e-7 && T_cmd(i)>=T_max(i)-1e-7;
 rise_slew_active(i)=pref(i)>U(i)+1e-7 && U(i)<T_safe(i)-1e-7;
 fall_slew_active(i)=pref(i)<L(i)-1e-7 && L(i)>0;
end
demand_unmet=sum(T_cmd)<T_total_req-1e-6;
end
