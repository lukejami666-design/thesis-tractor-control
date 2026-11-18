function [T_pref_work,slip_error,sliding_surface,sat_value,smc_valid,T_pref_work_raw,smc_fallback,smc_pref_clipped] = WorkSlip_SMC(kappa_fb,kappa_ref,kappa_ref_dot,a_hat,d_hat,T_max,slip_valid,control_phase,reset,a_floor_active,T_base,P)
%#codegen
% 中文注释永久保留：后续修改代码时不得删除注释，只能根据代码更新修改注释表述。
% 四轮向量顺序固定为 [FL; FR; RL; RR]；P 为集中管理的参数结构体，P.Ts 为采样周期（s）。
% 功能：固定目标边界层滑模控制，输出逐轮作业扭矩偏好 T_pref_work（N·m）。
% 输入 kappa_fb/kappa_ref 为反馈/参考滑转率，kappa_ref_dot 为参考变化率（1/s）。
% a_hat 为扭矩输入增益，d_hat 为等效扰动（1/s），T_max 为逐轮能力上限（N·m）。
% P.work_k、P.work_eta 单位 1/s；P.work_phi 为无量纲边界层厚度。
% 输出 slip_error 为反馈减参考，sliding_surface 当前等于误差，sat_value 为边界层饱和值。
% smc_valid 表示本拍本轮执行有效控制计算；与状态模块的 slip_valid 含义不同。
% reset 为保留接口；当前函数无持久状态，内部未使用 reset，复位由前级有状态模块处理。
% Boundary-layer fixed-target SMC preference; disturbance compensation is
% included once in this control law and no extra feedforward is added.
% 计算有效标志默认假；无效轮或增益保护时退化到基础分配并显式标记，不作为有效 SMC。
T_pref_work_raw=zeros(4,1); smc_fallback=true(4,1); smc_pref_clipped=false(4,1); T_pref_work=max(T_base,0); slip_error=zeros(4,1); sliding_surface=zeros(4,1); sat_value=zeros(4,1); smc_valid=false(4,1);
% 统一阶段编号：0 起步、1 交接、2 作业、3 保护；本模块不决定阶段切换。
phase=uint8(control_phase);
for i=1:4
    % 误差为正表示滑转率高于参考；首版滑模面 s=e，不额外加入积分项。
    e=kappa_fb(i)-kappa_ref(i); slip_error(i)=e; sliding_surface(i)=e;
    % 饱和函数将 e/phi 限在 [-1,1]，形成连续边界层以缓和切换抖振。
    sat_value(i)=min(max(e/max(P.work_phi(i),1e-9),-1),1);
    % 控制律为 (参考变化率-扰动-k*e-eta*sat)/a；扰动补偿只计入一次。
    ain=max(a_hat(i),P.work_a_min(i)); num=kappa_ref_dot(i)-d_hat(i)-P.work_k(i)*e-P.work_eta(i)*sat_value(i);
    % 仅允许滑转有效、增益无保护且参数有效的车轮在 BLEND/WORK 计算扭矩。
    if slip_valid(i) && ~a_floor_active(i) && WorkSlip_validate_params(P) && (phase==uint8(1) || phase==uint8(2)) && isfinite(num)
        % 仅数值限幅并置标志，驱动偏好非负；最终能力、总需求和变化率统一由执行层投影。
        T_pref_work_raw(i)=num/ain; smc_pref_clipped(i)=abs(T_pref_work_raw(i))>P.work_pref_max(i);
        T_pref_work(i)=max(min(max(T_pref_work_raw(i),-P.work_pref_max(i)),P.work_pref_max(i)),0); smc_valid(i)=true; smc_fallback(i)=false;
    end
end
end
