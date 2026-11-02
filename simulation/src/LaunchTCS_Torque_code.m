function [T_pref, T_lim_out, T_cmd, diag_torque] = LaunchTCS_Torque(stage, spin_mask, T_base, T_max, reset, P)
%#codegen
persistent initialized q total_scale Tlim Tcmd_prev prev_stage
cap=zeros(4,1); base=zeros(4,1);
for i=1:4
    if ~(isnan(T_max(i))||isinf(T_max(i))) && T_max(i)>=P.TcapFloor(i), cap(i)=T_max(i); else, cap(i)=0; end
    if ~(isnan(T_base(i))||isinf(T_base(i))), base(i)=max(T_base(i),0); end
end
if isempty(initialized)
    initialized=true; q=P.q_start; total_scale=1; Tlim=cap; Tcmd_prev=zeros(4,1); prev_stage=uint8(255);
end
T_pref=zeros(4,1); T_lim_out=zeros(4,1); T_cmd=zeros(4,1); diag_torque=zeros(4,1);
if reset>0.5 || stage==uint8(255)
    q=P.q_start; total_scale=1; Tlim=cap; Tcmd_prev=zeros(4,1); prev_stage=stage; T_lim_out=cap; return;
end
s=stage; if s>uint8(6), s=uint8(6); end
if s==uint8(0)&&prev_stage==uint8(5), q=P.q_start; end
if s==uint8(0)||s==uint8(1)
    q=min(1,q+P.q_probe_rate*P.Ts);
    for i=1:4, T_pref(i)=min(base(i),q*cap(i)); end
elseif s==uint8(2)
    q=min(P.q_no_move_max,q+P.q_no_move_rate*P.Ts);
    for i=1:4, T_pref(i)=min(base(i),q*cap(i)); end
elseif s==uint8(3)
    q=max(P.q_start,q-P.q_spin_down*P.Ts); T_pref=base;
    for i=1:4
        if spin_mask(i), Tlim(i)=max(P.q_limit_floor*cap(i),Tlim(i)-P.q_limit_cut_rate*cap(i)*P.Ts); else, Tlim(i)=min(cap(i),Tlim(i)+P.q_limit_rec_rate*cap(i)*P.Ts); end
    end
elseif s==uint8(4)
    q=max(P.q_start,q-P.q_spin_down*P.Ts); total_scale=max(P.q_multi_min,total_scale-P.q_multi_cut_rate*P.Ts); T_pref=total_scale*base;
    for i=1:4, Tlim(i)=max(P.q_limit_floor*cap(i),Tlim(i)-P.q_limit_cut_rate*cap(i)*P.Ts); end
elseif s==uint8(5)
    q=1; T_pref=base;
else
    q=max(P.q_start,q-P.q_protect_down*P.Ts);
    for i=1:4, T_pref(i)=min(base(i),P.q_protect*cap(i)); end
end
if s~=uint8(4), total_scale=min(1,total_scale+P.q_multi_rec_rate*P.Ts); end
if s~=uint8(3)&&s~=uint8(4)
    for i=1:4, Tlim(i)=min(cap(i),Tlim(i)+P.q_limit_rec_rate*cap(i)*P.Ts); end
end
for i=1:4, Tlim(i)=min(max(Tlim(i),0),cap(i)); T_pref(i)=min(max(T_pref(i),0),cap(i)); end
T_lim_out=Tlim;
if s==uint8(4), T_lim_out=min(T_lim_out,total_scale*cap); elseif s==uint8(6), T_lim_out=min(T_lim_out,P.q_protect*cap); end
for i=1:4
    target=min(T_pref(i),T_lim_out(i)); rise=P.cmd_rise_rate*cap(i)*P.Ts; fall=P.cmd_fall_rate*cap(i)*P.Ts;
    if target>=Tcmd_prev(i), T_cmd(i)=min(target,Tcmd_prev(i)+rise); else, T_cmd(i)=max(target,Tcmd_prev(i)-fall); end
    T_cmd(i)=min(max(T_cmd(i),0),T_lim_out(i));
end
Tcmd_prev=T_cmd; prev_stage=s; diag_torque=[q;total_scale;sum(double(spin_mask));double(s)];
end
