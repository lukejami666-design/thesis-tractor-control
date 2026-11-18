function [d_hat,d_raw,kappa_dot,disturbance_reinit] = WorkSlip_Disturbance(kappa_fb,a_hat,T_applied_cmd_prev,slip_valid,reset,P)
%#codegen
% 中文注释永久保留：后续修改代码时不得删除注释，只能根据代码更新修改注释表述。
% 四轮向量顺序固定为 [FL; FR; RL; RR]；P 为集中管理的参数结构体，P.Ts 为采样周期（s）。
% 功能：离散差分重构滑转率动力学残差，再低通得到总扰动估计，不使用 ESO。
% 输入 kappa_fb 为滑转率，a_hat 为扭矩输入增益（1/(N·m·s)），reset 为复位。
% T_applied_cmd_prev 单位 N·m，由外部 Unit Delay 提供，必须与上一拍输入增益配对。
% 当前主模型命令取自 Common motor capability 输出经唯一全局 Unit Delay，等同 TruckSim 四路输入前一拍。
% 旁路选择和最终能力限幅均位于该延迟前；WorkSlip 内部不再重复延迟，命令并非电机实测扭矩。
% d_hat/d_raw/kappa_dot 单位均为 1/s；d_hat 是等效总扰动，不能解释为力或负载扭矩。
% Residual reconstruction uses the previous final command supplied through
% an explicit Unit Delay, avoiding an algebraic loop.
% 保存上一拍滑转率、上一拍输入增益和滤波扰动状态。
persistent initialized kappa_prev a_prev d_state
if isempty(initialized), initialized=false; kappa_prev=zeros(4,1); a_prev=P.work_a_min; d_state=zeros(4,1); end
% 首次调用或复位时对齐差分历史量并清零扰动，避免初始化差分尖峰。
% 无论有效性如何均更新差分历史量；无效期间冻结的是扰动状态。
disturbance_reinit=reset>0.5 || ~initialized;
if disturbance_reinit, initialized=true; kappa_prev=kappa_fb; a_prev=a_hat; d_state=zeros(4,1); end
% 低通系数 beta=Ts/(tau_d+Ts)，对完整残差统一滤波。
kappa_dot=zeros(4,1); d_raw=zeros(4,1); d_hat=d_state; beta=P.Ts/(P.work_tau_d+P.Ts);
for i=1:4
    % 由相邻两拍滤波滑转率计算离散变化率。
    kappa_dot(i)=(kappa_fb(i)-kappa_prev(i))/P.Ts;
    % 仅在本轮滑转率有效且上一拍命令有限时更新扰动；否则保持扰动状态。
    if slip_valid(i) && isfinite(T_applied_cmd_prev(i)) && isfinite(kappa_fb(i)) && isfinite(a_prev(i))
        % 残差扣除上一拍增益乘上一拍非负命令；不使用本拍扭矩，避免直接代数环。
        d_raw(i)=kappa_dot(i)-a_prev(i)*max(T_applied_cmd_prev(i),0);
        % 一阶低通抑制离散差分噪声。
        d_state(i)=(1-beta)*d_state(i)+beta*d_raw(i);
    end
    d_hat(i)=d_state(i);
end
% 无论有效性如何均更新差分历史量；无效期间冻结的是扰动状态。
kappa_prev=kappa_fb; a_prev=a_hat;
end
