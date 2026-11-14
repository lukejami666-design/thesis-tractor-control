function P=gate_params(P)
% Candidate starting point; rates use fixed rated-wheel torque, never moving cap.
P.gate_version=20261113;
P.Kp_dv=zeros(4,1);P.Ki_dv=zeros(4,1);P.Kp_fast=zeros(4,1);
P.gate_warn_on=.50;P.gate_warn_off=.25;
P.gate_warn_delay=.010;P.gate_early_on=.35;P.gate_early_delay=.005;
P.gate_warn_hold=.12;P.gate_warn_clear=.06;
P.gate_escalate_delay=.035;P.gate_warn_rise_scale=0;
P.gate_warn_ratio=.90;P.gate_spin_ratio=.75;
P.gate_abs_floor=0;
P.gate_warn_cut_rate=1.0;P.gate_spin_cut_rate=2.0;
P.gate_probe_rate=8;P.gate_no_move_rate=1.0;
P.gate_recover_rate=.5;P.gate_cmd_rise_rate=12;P.gate_cmd_fall_rate=6;
P.gate_multi_ratio=.95;P.gate_multi_cut_rate=1;
P.gate_multi_recover_rate=.5;P.gate_handoff_rate=.7;
P.gate_exit_speed=2/3.6;P.gate_exit_hold=.020;
P.gate_redistribute=0;
end
