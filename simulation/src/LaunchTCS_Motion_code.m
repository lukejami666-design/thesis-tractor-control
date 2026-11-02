function [v_ref, dv, spin_on_raw, spin_clear_raw, no_move_raw, move_ok, ...
          speed_on_raw, speed_off_raw, consistency_ok, ...
          source_immediate_bad, drive_active, diag_motion] = ...
    LaunchTCS_Motion(w, vx, vy, ax, r, delta, speed_src_valid, ...
                     T_actual, T_max, reset, P)
%#codegen
% 前级：只计算运动量和瞬时判据，不做计时、不锁存、不决定 stage。
% 四轮顺序 [FL;FR;RL;RR]。

persistent initialized w_f vx_f vy_f ax_f r_f vx_prev dv_prev

if isempty(initialized)
    initialized = false;
    w_f = zeros(4,1); vx_f = 0; vy_f = 0; ax_f = 0; r_f = 0;
    vx_prev = 0; dv_prev = zeros(4,1);
end

%% 1. 先统一定义所有局部变量（避免"未定义"报错）
w_s = zeros(4,1);
delta_s = zeros(4,1);
vx_s = 0; vy_s = 0; ax_s = 0; r_s = 0;
raw_ok = true;
vx_dot = 0;
v_ref = zeros(4,1);
dv = zeros(4,1);
wheel_speed = zeros(4,1);
dv_rate = zeros(4,1);
active = zeros(4,1);

%% 2. 输入检查：异常值用上一拍滤波值顶替，并记录故障
for i = 1:4
    w_s(i) = w(i);
    delta_s(i) = delta(i);
    if isnan(w_s(i)) || isinf(w_s(i))
        w_s(i) = w_f(i); raw_ok = false;
    end
    if isnan(delta_s(i)) || isinf(delta_s(i))
        delta_s(i) = 0; raw_ok = false;
    end
end

vx_s = vx; vy_s = vy; ax_s = ax; r_s = r;
if isnan(vx_s) || isinf(vx_s), vx_s = vx_f; raw_ok = false; end
if isnan(vy_s) || isinf(vy_s), vy_s = vy_f; raw_ok = false; end
if isnan(ax_s) || isinf(ax_s), ax_s = ax_f; raw_ok = false; end
if isnan(r_s)  || isinf(r_s),  r_s  = r_f;  raw_ok = false; end

src_flag_ok = ~(isnan(speed_src_valid) || isinf(speed_src_valid));
src_val = speed_src_valid;
if ~src_flag_ok, src_val = 0; end

%% 3. 滤波与车速微分
do_init = (reset > 0.5) || ~initialized;
if do_init
    initialized = true;
    w_f = w_s; vx_f = vx_s; vy_f = vy_s; ax_f = ax_s; r_f = r_s;
    vx_prev = vx_f;
    dv_prev = zeros(4,1);
else
    vx_prev = vx_f;
    w_f  = (1-P.alpha_w)  * w_f  + P.alpha_w  * w_s;
    vx_f = (1-P.alpha_v)  * vx_f + P.alpha_v  * vx_s;
    vy_f = (1-P.alpha_vy) * vy_f + P.alpha_vy * vy_s;
    ax_f = (1-P.alpha_a)  * ax_f + P.alpha_a  * ax_s;
    r_f  = (1-P.alpha_r)  * r_f  + P.alpha_r  * r_s;
end
vx_dot = (vx_f - vx_prev) / P.Ts;

%% 4. 四轮参考速度与轮端-车体速度差
for i = 1:4
    v_ref(i) = max(0, (vx_f - r_f*P.y(i))*cos(delta_s(i)) ...
                     + (vy_f + r_f*P.x(i))*sin(delta_s(i)));
    wheel_speed(i) = max(w_f(i), 0) * P.R(i);
    dv(i) = wheel_speed(i) - v_ref(i);
    if do_init
        dv_rate(i) = 0;
    else
        dv_rate(i) = (dv(i) - dv_prev(i)) / P.Ts;
    end
end

%% 5. 信号健康与有效驱动
plausible = (vx_f >= P.vx_min) && (vx_f <= P.vx_max);
src_ok = (src_val > 0.5) && src_flag_ok;
actual_ok = true;

for i = 1:4
    cap_valid = ~(isnan(T_max(i)) || isinf(T_max(i))) && ...
                (T_max(i) >= P.TcapFloor(i));
    act_valid = ~(isnan(T_actual(i)) || isinf(T_actual(i)));
    if ~act_valid, actual_ok = false; end
    if cap_valid && act_valid
        active(i) = double(T_actual(i) >= P.applied_active_frac * T_max(i));
    end
end

drive_active = any(active > 0.5);
source_immediate_bad = (~raw_ok) || (~src_ok) || (~plausible) || ...
                       (~actual_ok);
consistency_ok = (~source_immediate_bad) && ...
                 (abs(vx_dot - ax_f) <= P.a_cons_max);

%% 6. 四轮空转瞬时条件
spin_on_raw = false(4,1);
spin_clear_raw = false(4,1);
for i = 1:4
    spin_on_raw(i) = (~source_immediate_bad) && ...
        (dv(i) > P.dv_spin_on) && ...
        (wheel_speed(i) > P.v_wheel_min) && ...
        (active(i) > 0.5) && ...
        ((ax_f < P.a_spin_max) || (dv_rate(i) > P.dv_growth_on));
    spin_clear_raw(i) = (~source_immediate_bad) && (dv(i) < P.dv_spin_off);
end

%% 7. 未起动与车速切换瞬时条件
no_move_raw = (~source_immediate_bad) && drive_active && ...
              (vx_f < P.v_move_on) && (ax_f < P.a_response);
move_ok = (~source_immediate_bad) && ...
          ((vx_f >= P.v_move_on) || (ax_f >= P.a_response));
speed_on_raw = (~source_immediate_bad) && consistency_ok && ...
               (vx_f >= P.v_valid_on);
speed_off_raw = source_immediate_bad || (vx_f < P.v_valid_off);

%% 8. 观察量与历史更新
diag_motion = [vx_f; ax_f; vx_dot; max(dv)];
dv_prev = dv;

end