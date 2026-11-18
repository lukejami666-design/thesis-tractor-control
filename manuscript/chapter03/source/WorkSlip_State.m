function [kappa_raw,kappa_fb,wheel_speed,wheel_center_speed,slip_valid,a_hat,a_floor_active,kappa_raw_unclipped] = WorkSlip_State(w,vx,vy,r,delta,reset,P)
%#codegen
% 中文注释永久保留：后续修改代码时不得删除注释，只能根据代码更新修改注释表述。
% 四轮向量顺序固定为 [FL; FR; RL; RR]；P 为集中管理的参数结构体，P.Ts 为采样周期（s）。
%% 功能：滤波车辆状态、计算四轮滑转率，并估计滑转率动力学中的扭矩输入增益。
% 输入：w 为轮角速度（rad/s），vx/vy 为车体速度（m/s），r 为横摆角速度（rad/s），delta 为转角（rad）。
% reset>0.5 触发复位；P.R 为有效滚动半径（m），P.x/P.y 为轮心相对车体参考点的位置（m）。
% 输出：kappa_raw/kappa_fb 为截断计算值/控制反馈；默认仅滤波轮速和车速，额外滑转率滤波可配置。
% wheel_speed/wheel_center_speed 为轮面圆周速度/滚动方向轮心地速（m/s）。
% slip_valid 是逐轮信号有效标志，不代表 SMC 已获得控制权。
% a_hat 单位为 1/(N·m·s)；a_floor_active 表示输入增益使用了保护下限。
% Four-wheel work-slip state. Wheel order is [FL; FR; RL; RR].
% 保存滤波状态；第一次调用先分配四轮状态。
persistent initialized w_f vx_f vy_f r_f kappa_f
if isempty(initialized), initialized=false; w_f=zeros(4,1); vx_f=0; vy_f=0; r_f=0; kappa_f=zeros(4,1); end
% 首次调用或复位时以当前输入初始化速度状态，避免从零开始的滤波过渡。
if reset>0.5 || ~initialized
    initialized=true; w_f=w; vx_f=vx; vy_f=vy; r_f=r;
else
    % 一阶低通系数；仅对有限的实时速度输入更新，非有限输入保留上次滤波值。
    alpha=P.Ts/(P.work_tau_slip+P.Ts);
    for i=1:4, if isfinite(w(i)), w_f(i)=(1-alpha)*w_f(i)+alpha*w(i); end, end
    if isfinite(vx), vx_f=(1-alpha)*vx_f+alpha*vx; end
    if isfinite(vy), vy_f=(1-alpha)*vy_f+alpha*vy; end
    if isfinite(r), r_f=(1-alpha)*r_f+alpha*r; end
end
% 每拍分配固定维度的输出；不改变四轮排列顺序。
kappa_raw_unclipped=zeros(4,1); kappa_raw=zeros(4,1); kappa_fb=zeros(4,1); wheel_speed=zeros(4,1); wheel_center_speed=zeros(4,1); slip_valid=false(4,1); a_hat=zeros(4,1); a_floor_active=false(4,1);
% 一阶低通系数；仅对有限的实时速度输入更新，非有限输入保留上次滤波值。
alpha=P.Ts/(P.work_tau_slip+P.Ts);
for i=1:4
    % 当前实现对非有限转角采用零转角；此处不另外增加转角故障标志。
    di=0; if isfinite(delta(i)), di=delta(i); end
    % 将车体平动和横摆速度投影到各轮滚动方向；当前前进控制把负向投影速度截为零。
    vi=(vx_f-r_f*P.y(i))*cos(di)+(vy_f+r_f*P.x(i))*sin(di); vi=max(vi,0);
    % 轮角速度乘有效半径得到圆周速度；以 work_v_eps 保护低速分母。
    ui=max(w_f(i),0)*P.R(i); den=max(ui,P.work_v_eps);
    % 采用轮速分母定义 (ui-vi)/max(ui,v_eps)，同时保留未截断原值及 [-1,2] 诊断截断值。
    wheel_speed(i)=ui; wheel_center_speed(i)=vi; kappa_raw_unclipped(i)=(ui-vi)/den; kappa_raw(i)=min(max(kappa_raw_unclipped(i),-1),2);
    % 复位或默认方案 A 时直接采用状态滤波后的计算滑转率；方案 B 可额外低通。
    if reset>0.5 || P.work_filter_mode==uint8(0), kappa_f(i)=kappa_raw(i); else, kappa_f(i)=(1-alpha)*kappa_f(i)+alpha*kappa_raw(i); end
    kappa_fb(i)=kappa_f(i);
    % 有效性要求速度有限且地速、圆周速度均达到阈值；分母保护不能替代有效性判断。
    slip_valid(i)=isfinite(w(i)) && isfinite(vx) && isfinite(vy) && isfinite(r) && isfinite(delta(i)) && isfinite(ui) && isfinite(vi) && vi>=P.work_v_valid_on && ui>=P.work_w_valid_min;
    % 输入增益理论式为 vi*R/(J*den^2)；J 必须为真实轮端等效惯量（kg·m^2）。
    if isfinite(P.work_J_wheel(i)) && P.work_J_wheel(i)>0 && isfinite(P.R(i)) && P.R(i)>0 && slip_valid(i), araw=vi*P.R(i)/(P.work_J_wheel(i)*den*den); else, araw=0; end
    % 惯量无效或增益过小时采用逐轮下限并置保护标志；保护值不能替代物理参数核对。
    if ~isfinite(araw) || araw<P.work_a_min(i), a_hat(i)=P.work_a_min(i); a_floor_active(i)=true; else, a_hat(i)=araw; end
end
end
