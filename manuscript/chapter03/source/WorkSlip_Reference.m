function [kappa_ref,kappa_ref_dot] = WorkSlip_Reference(kappa_fb,slip_valid,control_phase,reset,P)
%#codegen
% 中文注释永久保留：后续修改代码时不得删除注释，只能根据代码更新修改注释表述。
% 四轮向量顺序固定为 [FL; FR; RL; RR]；P 为集中管理的参数结构体，P.Ts 为采样周期（s）。
% 功能：由当前反馈平滑过渡到固定目标，输出 kappa_ref 及其变化率 kappa_ref_dot（1/s）。
% 输入 kappa_fb 和输出 kappa_ref 均为无量纲四轮向量；slip_valid 为逐轮有效标志。
% control_phase：0=起步 LAUNCH，1=交接 BLEND，2=作业 WORK，3=保护 PROTECT。
% 阶段由上层监督器给定；P.kappa_set 为固定目标（0.30 表示 30%），本模块不做在线寻优。
% Smooth fixed target reference. BLEND initializes from measured slip.
% 保存参考轨迹与上一拍阶段，以识别首次进入交接的时刻。
persistent initialized ref previous_phase
% 按当前代码将阶段转为 uint8，超过 3 的阶段归到保护编号。
if isempty(initialized), initialized=false; ref=zeros(4,1); previous_phase=uint8(3); end
% 按当前代码将阶段转为 uint8，超过 3 的阶段归到保护编号。
phase=uint8(control_phase); if phase>uint8(3), phase=uint8(3); end
% 首次调用或复位时从当前反馈初始化参考。
if reset>0.5 || ~initialized, initialized=true; for i=1:4,if isfinite(kappa_fb(i)),ref(i)=min(max(kappa_fb(i),P.work_kappa_min),P.work_kappa_max);end,end; previous_phase=phase; end
% 起步期间参考跟随反馈，参考变化率输出零。
if phase==uint8(0)
    % 其他分支先将各轮参考变化率置零；无效车轮保持既有参考。
    for i=1:4,if isfinite(kappa_fb(i)) && slip_valid(i),ref(i)=min(max(kappa_fb(i),P.work_kappa_min),P.work_kappa_max);end,end; kappa_ref_dot=zeros(4,1);
% 从起步首次进入交接时再次对齐反馈，减少参考突跳。
elseif phase==uint8(1) && previous_phase==uint8(0)
    % 其他分支先将各轮参考变化率置零；无效车轮保持既有参考。
    for i=1:4,if isfinite(kappa_fb(i)) && slip_valid(i),ref(i)=min(max(kappa_fb(i),P.work_kappa_min),P.work_kappa_max);end,end; kappa_ref_dot=zeros(4,1);
elseif phase==uint8(1) || phase==uint8(2)
    % BLEND/WORK 才推进目标；各轮先置零变化率，无效轮冻结。
    kappa_ref_dot=zeros(4,1);
    for i=1:4
        if slip_valid(i) && isfinite(kappa_fb(i))
            % 参考以一阶误差动态接近固定目标；时间常数不得小于采样周期。
            raw=(P.kappa_set(i)-ref(i))/max(P.work_tau_ref,P.Ts);
            % 逐轮限制参考变化率，再通过显式离散积分更新参考。
            kappa_ref_dot(i)=min(max(raw,-P.work_ref_rate(i)),P.work_ref_rate(i));
            ref(i)=min(max(ref(i)+P.Ts*kappa_ref_dot(i),P.work_kappa_min),P.work_kappa_max);
        end
    end
else
    % PROTECT 阶段冻结参考，不依赖后台目标更新。
    kappa_ref_dot=zeros(4,1);
end
% 输出当前有界参考并保存阶段；阶段使能始终由唯一监督器决定。
kappa_ref=ref; previous_phase=phase;
end
