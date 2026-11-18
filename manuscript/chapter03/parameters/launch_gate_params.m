function P = launch_gate_params(P)
% Add the event-gate defaults while preserving the caller's vehicle tuning.
% Existing fields are retained so scenario and motor parameters stay intact.
if nargin < 1 || isempty(P)
    P = launch_tcs_params();
end

P.gate_version = 20261116;
P.gate_warn_on = 0.50;
P.gate_warn_off = 0.25;
P.gate_warn_delay = 0.010;
P.gate_early_on = 0.35;
P.gate_early_delay = 0.005;
P.gate_warn_hold = 0.12;
P.gate_warn_clear = 0.06;
P.gate_escalate_delay = 0.035;
P.gate_warn_rise_scale = 0;
P.gate_warn_ratio = 0.90;
P.gate_spin_ratio = 0.75;
P.gate_abs_floor = 0;
P.gate_warn_cut_rate = 1.0;
P.gate_spin_cut_rate = 2.0;
P.gate_probe_rate = 8;
P.gate_no_move_rate = 1.0;
P.gate_recover_rate = 0.5;
P.gate_cmd_rise_rate = 12;
P.gate_cmd_fall_rate = 6;
P.gate_multi_ratio = 0.95;
P.gate_multi_cut_rate = 1;
P.gate_multi_recover_rate = 0.5;
P.gate_handoff_rate = 0.7;
P.gate_exit_speed = 2/3.6;
P.gate_exit_hold = 0.020;
P.gate_redistribute = 0;
% Unified supervisor phase handover. Torque consumes this phase and does not
% latch handoff independently.
P.gate_handoff_time = 0.30;
P.work_slip_version = 20261116;
P.kappa_set = [0.30;0.30;0.30;0.30];
P.work_tau_slip = 0.005;
P.work_v_eps = 0.20;
P.work_v_valid_on = 1.3/3.6;
P.work_w_valid_min = 0.30;
P.work_tau_ref = 0.080;
P.work_ref_rate = [4;4;4;4];
P.work_k = [2;2;2;2];
P.work_eta = [0.50;0.50;0.50;0.50];
P.work_phi = [0.020;0.020;0.020;0.020];
P.work_tau_d = 0.020;
P.work_a_min = [1e-6;1e-6;1e-6;1e-6];
% 当前四路输入为驱动桥轮端 N·m，差速器/发动机/耦合器/变速器均 external。
% Simulink 无额外转子/轴惯量模型。官方 Tire Models 规定总旋转惯量 IW+IT。
P.work_J_wheel = [221.28;221.28;712.84;712.84];
P.work_R = P.R;
P.work_v_on = 2/3.6;
P.work_v_off = 1.3/3.6;
P.work_on_hold = 0.08;
P.work_off_hold = 0.20;
P.work_blend_time = 0.30;
P.work_min_valid_wheels = 3;
P.work_filter_mode = uint8(0); % 0 仅状态滤波；1 额外滑转率滤波。
P.work_kappa_min = 0;
P.work_kappa_max = 1.0; % 驱动参考允许覆盖交接入口的高滑转值，避免入口硬截断。
P.work_execution_version = 20261117;
P.work_pref_max = 1e7*ones(4,1); % 仅数值保护，不是电机能力。
P.work_proj_weight = ones(4,1);
P.work_rise_rate = P.gate_cmd_rise_rate*P.TcapDefault;
P.work_fall_rate = P.gate_cmd_fall_rate*P.TcapDefault;
P.work_param_valid = WorkSlip_validate_params(P);
end
