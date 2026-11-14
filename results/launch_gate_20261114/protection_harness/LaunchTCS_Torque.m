function [T_pref,T_lim_out,T_cmd,diag_torque,T_pref_open,I_dv_out,cap_out,T_target,T_slip_lim,slip_ratio_out,slip_recovering,cut_f_out,gate_diag] = ...
 LaunchTCS_Torque(stage,spin_mask,dv_ctrl,T_base,T_max,reset,fast_worsening,prewarn,warn_age,T_actual_prev,vx_raw,source_bad,P)
%#codegen
% Stateflow owns warning/confirmed events. This block only shapes actuator bounds.
% No P/I/fast-P correction and no cut_f persistent state exists.
persistent initialized envelope bound bound_target anchor previous_warning previous_spin previous_cmd multi_bound multi_anchor multi_previous exit_timer handed_off
if isempty(initialized)
 initialized=true;envelope=zeros(4,1);bound=ones(4,1)*1e12;bound_target=ones(4,1)*1e12;anchor=zeros(4,1);
 previous_warning=false(4,1);previous_spin=false(4,1);previous_cmd=zeros(4,1);
 multi_bound=1e12;multi_anchor=0;multi_previous=false;exit_timer=0;handed_off=false;
end
cap=zeros(4,1);base=zeros(4,1);applied=zeros(4,1);rated=max(P.TcapDefault,1);
input_bad=source_bad || ~isfinite(vx_raw);
for i=1:4
 if isfinite(T_max(i)) && T_max(i)>=0,cap(i)=T_max(i);else,input_bad=true;end
 if isfinite(T_base(i)),base(i)=max(T_base(i),0);else,input_bad=true;end
 if isfinite(T_actual_prev(i)),applied(i)=max(T_actual_prev(i),0);else,input_bad=true;end
 if ~isfinite(dv_ctrl(i)),input_bad=true;end
end
T_pref=zeros(4,1);T_lim_out=cap;T_cmd=zeros(4,1);diag_torque=zeros(4,1);
T_pref_open=zeros(4,1);I_dv_out=zeros(4,1);cap_out=cap;T_target=zeros(4,1);
T_slip_lim=cap;slip_ratio_out=ones(4,1);slip_recovering=false(4,1);cut_f_out=zeros(4,1);
gate_diag=zeros(72,1);
if reset>0.5 || stage==uint8(255)
 envelope=zeros(4,1);bound=ones(4,1)*1e12;bound_target=ones(4,1)*1e12;anchor=zeros(4,1);previous_cmd=zeros(4,1);
 previous_warning=false(4,1);previous_spin=false(4,1);multi_bound=1e12;multi_anchor=0;
 multi_previous=false;exit_timer=0;handed_off=false;return;
end
protect=input_bad || stage==uint8(6);
if vx_raw>=P.gate_exit_speed && ~protect,exit_timer=min(P.gate_exit_hold,exit_timer+P.Ts);else,exit_timer=0;end
if exit_timer>=P.gate_exit_hold,handed_off=true;end
% Re-enter launch supervision only after an actual return to near standstill.
if handed_off && vx_raw<.1 && stage<=uint8(1),handed_off=false;exit_timer=0;end
nconfirmed=sum(double(spin_mask));multi=(nconfirmed>=2)&&~handed_off;
for i=1:4
 warning=prewarn(i)&&~handed_off;confirmed=spin_mask(i)&&~handed_off;
 warning_rise=warning && ~previous_warning(i);
 confirmed_rise=confirmed && ~previous_spin(i);
 if warning_rise || confirmed_rise
  % Capture already applied torque once; changes of motor cap do not update anchor.
  anchor(i)=max(applied(i),min(base(i),cap(i)));
 end
 if handed_off
  envelope(i)=max(envelope(i),applied(i));
  envelope(i)=min(base(i),envelope(i)+P.gate_handoff_rate*rated(i)*P.Ts);
  if bound(i)<base(i),bound(i)=min(base(i),bound(i)+P.gate_handoff_rate*rated(i)*P.Ts);end
 elseif confirmed
  if confirmed_rise
   bound_target(i)=max(P.gate_abs_floor,P.gate_spin_ratio*max(applied(i),0));
  end
  bound(i)=max(bound_target(i),bound(i)-P.gate_spin_cut_rate*rated(i)*P.Ts);
 elseif warning
  if warning_rise
   bound_target(i)=max(applied(i),P.gate_warn_ratio*anchor(i));
  end
  if warn_age(i)>=P.gate_escalate_delay && (fast_worsening(i) || dv_ctrl(i)>=P.dv_spin_on)
   bound(i)=max(bound_target(i),bound(i)-P.gate_warn_cut_rate*rated(i)*P.Ts);
  end
 else
  % Normal launch follows the common executable demand immediately; only
  % the shared command-rate limiter shapes the actuator trajectory.
  if stage==uint8(2)
   envelope(i)=min(base(i),max(envelope(i),applied(i))+P.gate_no_move_rate*rated(i)*P.Ts);
  else
   envelope(i)=min(base(i),cap(i));
  end
  bound_target(i)=min(base(i),cap(i));
  if bound(i)<bound_target(i),bound(i)=min(bound_target(i),bound(i)+P.gate_recover_rate*rated(i)*P.Ts);end
 end
 % Demand reductions may lower the command but do not invent extra safety memory.
 T_pref_open(i)=min(base(i),max(envelope(i),0));
 T_pref(i)=T_pref_open(i);T_slip_lim(i)=min(base(i),max(bound(i),0));
 T_lim_out(i)=min(cap(i),T_slip_lim(i));
 if protect,T_lim_out(i)=min(T_lim_out(i),P.q_protect*cap(i));end
 T_target(i)=min(T_pref(i),T_lim_out(i));
 previous_warning(i)=warning;previous_spin(i)=confirmed;
end
% One total bound is intersected with wheel bounds; penalties are not multiplied.
sum_target=sum(T_target);
if multi && ~multi_previous,multi_anchor=sum(applied);multi_bound=multi_anchor;end
if multi
 multi_bound=max(P.gate_multi_ratio*multi_anchor,multi_bound-P.gate_multi_cut_rate*sum(rated)*P.Ts);
elseif multi_bound<sum(base)
 multi_bound=min(sum(base),multi_bound+P.gate_multi_recover_rate*sum(rated)*P.Ts);
end
multi_previous=multi;
multi_scale=1;if sum_target>multi_bound && sum_target>0,multi_scale=max(multi_bound,0)/sum_target;end
transfer=zeros(4,1);
% Optional candidate: only healthy, unconfirmed, unwarned receivers with headroom.
if P.gate_redistribute>0 && ~protect && ~handed_off
 lost=sum(max(base-T_target,0));room=zeros(4,1);
 for i=1:4
  if ~prewarn(i)&&~spin_mask(i),room(i)=max(0,min(cap(i),envelope(i))-T_target(i));end
 end
 if sum(room)>0
  transfer=room/sum(room)*min(P.gate_redistribute*lost,sum(room));
  T_target=T_target+transfer;
 end
end
rate_cmd=zeros(4,1);hard_lim=zeros(4,1);override=zeros(4,1);
for i=1:4
 % The per-wheel hard limit is never raised to preserve a rate limit.
 hard_lim(i)=min(cap(i),min(base(i),max(T_lim_out(i),0)));
 if protect,hard_lim(i)=min(hard_lim(i),P.q_protect*cap(i));end
 T_lim_out(i)=hard_lim(i);
 target=min(max(T_target(i),0),hard_lim(i));
 prev=previous_cmd(i);
 if target>=prev,rate_cmd(i)=min(target,prev+P.gate_cmd_rise_rate*rated(i)*P.Ts);
 else,rate_cmd(i)=max(target,prev-P.gate_cmd_fall_rate*rated(i)*P.Ts);end
 rate_cmd(i)=min(max(rate_cmd(i),0),1e12);
end
% Project the rate-limited command onto the vehicle-level safety bound.
% This safety override is allowed to exceed the normal fall-rate and is
% recorded in gate_diag rather than hidden by increasing T_lim_out.
if multi && sum(rate_cmd)>multi_bound && sum(rate_cmd)>0
 safety_scale=max(multi_bound,0)/sum(rate_cmd);
else
 safety_scale=1;
end
for i=1:4
 T_cmd(i)=min(rate_cmd(i)*safety_scale,hard_lim(i));
 override(i)=max(rate_cmd(i)-T_cmd(i),0);
 slip_ratio_out(i)=min(max(bound(i)/max(base(i),1),0),1);
 slip_recovering(i)=~prewarn(i)&&~spin_mask(i)&&bound(i)<base(i);
 reason=0;
 if envelope(i)<base(i)-1,reason=1;end
 if prewarn(i)&&bound(i)<min(base(i),envelope(i))-1,reason=2;end
 if spin_mask(i)&&bound(i)<min(base(i),envelope(i))-1,reason=3;end
 if multi_scale<1,reason=4;end
 if cap(i)<min(base(i),min(envelope(i),bound(i)))-1,reason=5;end
 if abs(T_cmd(i)-target)>1,reason=6;end
 if protect,reason=8;end
 gate_diag(i)=envelope(i);gate_diag(4+i)=bound(i);gate_diag(8+i)=anchor(i);
 gate_diag(12+i)=double(prewarn(i));gate_diag(16+i)=double(spin_mask(i));
 gate_diag(20+i)=double(envelope(i)<min(base(i),cap(i))-1);
 gate_diag(24+i)=double(bound(i)<min(base(i),min(envelope(i),cap(i)))-1);
 gate_diag(28+i)=double(cap(i)<min(base(i),min(envelope(i),bound(i)))-1);
 gate_diag(32+i)=double(multi_scale<1);gate_diag(36+i)=reason;
 gate_diag(40+i)=double(handed_off);gate_diag(44+i)=transfer(i);
 gate_diag(48+i)=double(protect);gate_diag(52+i)=target;
 gate_diag(56+i)=double(slip_recovering(i));gate_diag(60+i)=multi_bound;
 gate_diag(64+i)=double(override(i)>1e-9);gate_diag(68+i)=override(i);
end
previous_cmd=T_cmd;diag_torque=[min(sum(envelope)/max(sum(base),1),1);multi_scale;nconfirmed;double(stage)];
end
