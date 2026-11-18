function [T_pref,T_lim_out,T_cmd,diag_torque,T_pref_open,I_dv_out,cap_out,T_target,T_slip_lim,slip_ratio_out,slip_recovering,cut_f_out,gate_diag] = ...
 LaunchTCS_Torque(stage,spin_mask,dv_ctrl,T_base,T_max,reset,fast_worsening,prewarn,warn_age,T_actual_prev,vx_raw,source_bad,control_phase,T_pref_work,work_slip_valid,handover_alpha,P)
%#codegen
% Actuator-side launch gate. The supervisor owns control_phase; this block
% never latches a private handoff state.
% Wheel order: [FL; FR; RL; RR].
persistent previous_phase
if isempty(previous_phase),previous_phase=uint8(0);end
persistent initialized envelope bound bound_target bound_enable anchor previous_warning previous_spin previous_cmd multi_bound multi_enable multi_anchor multi_previous
if isempty(initialized)
    initialized=true;
    envelope=zeros(4,1); bound=zeros(4,1); bound_target=zeros(4,1);
    bound_enable=false(4,1); anchor=zeros(4,1);
    previous_warning=false(4,1); previous_spin=false(4,1); previous_cmd=zeros(4,1);
    multi_bound=0; multi_enable=false; multi_anchor=0; multi_previous=false;
end
cap=zeros(4,1); base=zeros(4,1); applied=zeros(4,1);
rated=max(P.TcapDefault,1); input_bad=source_bad || ~isfinite(vx_raw);
for i=1:4
    if isfinite(T_max(i)) && T_max(i)>=0, cap(i)=T_max(i); else, input_bad=true; end
    if isfinite(T_base(i)), base(i)=max(T_base(i),0); else, input_bad=true; end
    if isfinite(T_actual_prev(i)), applied(i)=max(T_actual_prev(i),0); else, input_bad=true; end
    if ~isfinite(dv_ctrl(i)), input_bad=true; end
    if ~isfinite(T_pref_work(i)), T_pref_work(i)=0; end
end
T_pref=zeros(4,1); T_lim_out=cap; T_cmd=zeros(4,1); diag_torque=zeros(4,1);
T_pref_open=zeros(4,1); I_dv_out=zeros(4,1); cap_out=cap; T_target=zeros(4,1);
T_slip_lim=cap; slip_ratio_out=ones(4,1); slip_recovering=false(4,1); cut_f_out=zeros(4,1);
gate_diag=zeros(72,1);
if reset>0.5 || stage==uint8(255)
    envelope=zeros(4,1); bound=zeros(4,1); bound_target=zeros(4,1);
    bound_enable=false(4,1); anchor=zeros(4,1); previous_cmd=zeros(4,1);
    previous_warning=false(4,1); previous_spin=false(4,1);
    multi_bound=0; multi_enable=false; multi_anchor=0; multi_previous=false;
    T_lim_out=cap; return;
end
phase=uint8(control_phase);
% 返回 LAUNCH 从上一拍实际下发命令初始化，不恢复旧事件锁存。
if phase==uint8(0) && previous_phase~=uint8(0)
 envelope=applied;bound=cap;bound_target=cap;bound_enable=false(4,1);previous_warning=false(4,1);previous_spin=false(4,1);multi_enable=false;multi_previous=false;
end
previous_phase=phase;
if phase>uint8(3), phase=uint8(3); end
protect=input_bad || phase==uint8(3);
launch_active=(phase==uint8(0));
nconfirmed=sum(double(spin_mask));
multi=(nconfirmed>=2) && launch_active;
% BLEND and WORK release all launch event bounds. The command-rate limiter
% still provides a continuous transition from the last launch command.
if ~launch_active
    for i=1:4
        envelope(i)=min(base(i),max(envelope(i),applied(i))+P.gate_handoff_rate*rated(i)*P.Ts);
        bound_enable(i)=false; bound(i)=cap(i); bound_target(i)=cap(i);
    end
end
for i=1:4
    warning=prewarn(i) && launch_active;
    confirmed=spin_mask(i) && launch_active;
    warning_rise=warning && ~previous_warning(i);
    confirmed_rise=confirmed && ~previous_spin(i);
    if warning_rise || confirmed_rise
        anchor(i)=max(applied(i),min(base(i),cap(i)));
        if ~bound_enable(i), bound(i)=min(base(i),cap(i)); end
        bound_enable(i)=true;
    end
    if ~launch_active
        envelope(i)=min(base(i),max(envelope(i),applied(i))+P.gate_handoff_rate*rated(i)*P.Ts);
        bound_enable(i)=false; bound(i)=cap(i); bound_target(i)=cap(i);
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
        if stage==uint8(2)
            envelope(i)=min(base(i),max(envelope(i),applied(i))+P.gate_no_move_rate*rated(i)*P.Ts);
        else
            envelope(i)=min(base(i),cap(i));
        end
        if bound_enable(i)
            recover_target=min(base(i),cap(i));
            bound(i)=min(recover_target,bound(i)+P.gate_recover_rate*rated(i)*P.Ts);
            if bound(i)>=recover_target-1e-9
                bound_enable(i)=false; bound(i)=cap(i); bound_target(i)=cap(i);
            end
        else
            bound(i)=cap(i); bound_target(i)=cap(i);
        end
    end
    T_pref_open(i)=min(base(i),max(envelope(i),0));
    T_pref(i)=T_pref_open(i);
    % BLEND/WORK 的混合与最终控制权已迁移至 TCS_Handover。
    if bound_enable(i), T_slip_lim(i)=min(base(i),max(bound(i),0)); else, T_slip_lim(i)=cap(i); end
    T_lim_out(i)=min(cap(i),T_slip_lim(i));
    if protect, T_lim_out(i)=min(T_lim_out(i),P.q_protect*cap(i)); end
    T_target(i)=min(T_pref(i),T_lim_out(i));
    previous_warning(i)=warning; previous_spin(i)=confirmed;
end
sum_target=sum(T_target);
if multi && ~multi_previous
    multi_anchor=sum(applied); multi_bound=multi_anchor; multi_enable=true;
end
if multi
    multi_bound=max(P.gate_multi_ratio*multi_anchor,multi_bound-P.gate_multi_cut_rate*sum(rated)*P.Ts);
elseif multi_enable
    multi_bound=min(sum(base),multi_bound+P.gate_multi_recover_rate*sum(rated)*P.Ts);
    if multi_bound>=sum(base)-1e-9, multi_enable=false; multi_bound=sum(base); end
else
    multi_bound=sum(base);
end
multi_previous=multi;
multi_scale=1;
if multi && sum_target>multi_bound && sum_target>0, multi_scale=max(multi_bound,0)/sum_target; end
transfer=zeros(4,1);
if P.gate_redistribute>0 && ~protect && launch_active
    lost=sum(max(base-T_target,0)); room=zeros(4,1);
    for i=1:4
        if ~prewarn(i) && ~spin_mask(i), room(i)=max(0,min(cap(i),envelope(i))-T_target(i)); end
    end
    if sum(room)>0
        transfer=room/sum(room)*min(P.gate_redistribute*lost,sum(room));
        T_target=T_target+transfer;
    end
end
rate_cmd=zeros(4,1); hard_lim=zeros(4,1); target_wheel=zeros(4,1); override=zeros(4,1);
for i=1:4
    hard_lim(i)=min(cap(i),min(base(i),max(T_lim_out(i),0)));
    if protect, hard_lim(i)=min(hard_lim(i),P.q_protect*cap(i)); end
    target_wheel(i)=min(max(T_target(i),0),hard_lim(i));
    % 本输出仅为起步偏好；全阶段最终变化率限制唯一位于 TCS_TorqueConstraints。
    rate_cmd(i)=target_wheel(i);
end
if multi && sum(rate_cmd)>multi_bound && sum(rate_cmd)>0, safety_scale=max(multi_bound,0)/sum(rate_cmd); else, safety_scale=1; end
for i=1:4
    T_cmd(i)=min(rate_cmd(i)*safety_scale,hard_lim(i)); % 兼容输出 T_cmd_launch，非最终车辆命令
    override(i)=max(rate_cmd(i)-T_cmd(i),0);
    slip_ratio_out(i)=min(max(T_slip_lim(i)/max(base(i),1),0),1);
    slip_recovering(i)=~prewarn(i) && ~spin_mask(i) && bound_enable(i);
    reason=0;
    if envelope(i)<base(i)-1, reason=1; end
    if prewarn(i) && bound_enable(i) && bound(i)<min(base(i),envelope(i))-1, reason=2; end
    if spin_mask(i) && bound_enable(i) && bound(i)<min(base(i),envelope(i))-1, reason=3; end
    if multi_scale<1, reason=4; end
    if cap(i)<min(base(i),min(envelope(i),T_slip_lim(i)))-1, reason=5; end
    if abs(T_cmd(i)-target_wheel(i))>1, reason=6; end
    if protect, reason=8; end
    gate_diag(i)=envelope(i); gate_diag(4+i)=bound(i); gate_diag(8+i)=anchor(i);
    gate_diag(12+i)=double(prewarn(i)); gate_diag(16+i)=double(spin_mask(i));
    gate_diag(20+i)=double(envelope(i)<min(base(i),cap(i))-1);
    gate_diag(24+i)=double(bound_enable(i));
    gate_diag(28+i)=double(cap(i)<min(base(i),min(envelope(i),T_slip_lim(i)))-1);
    gate_diag(32+i)=double(multi_scale<1); gate_diag(36+i)=reason;
    gate_diag(40+i)=double(phase==uint8(1)); gate_diag(44+i)=transfer(i);
    gate_diag(48+i)=double(protect);
    % Explicit event targets, ordered FL/FR/RL/RR (indices 53:56).
    gate_diag(52+i)=bound_target(i);
    gate_diag(56+i)=double(slip_recovering(i)); gate_diag(60+i)=multi_bound;
    gate_diag(64+i)=double(override(i)>1e-9); gate_diag(68+i)=override(i);
end
previous_cmd=T_cmd;
diag_torque=[min(sum(envelope)/max(sum(base),1),1);multi_scale;nconfirmed;double(phase)];
end
