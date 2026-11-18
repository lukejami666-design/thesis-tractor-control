# 第三章写作指南与控制律核对

先读[正式目录](../outline.md)、[版本边界](../VERSION.md)、[全过程模块说明](control-framework.md)，再按下表看代码。全部算法均按前进驱动工况解释。

| 正式小节 | 主要输入材料 | 应写清的内容 |
|---|---|---|
| 3.1 整体方案 | control-framework.md | 起步证据/事件链与作业闭环并行，统一阶段监督、交接、约束，实际命令延迟反馈 |
| 3.2.1 起步打滑判据 | source/LaunchTCS_Motion.m、launch-stateflow.md | 轮面与地速差、变化趋势、实际驱动证据、可信度、计时及确认 |
| 3.2.2 分场景扭矩控制 | source/LaunchTCS_Torque.m | 正常起步、重载未起动、单轮/多轮空转、故障保护；stage是事件类别 |
| 3.2.3 探测与上界更新 | 同上及parameters/launch_gate_params.m | 探测、预警包络、事件锚点、逐轮有限上界、恢复和多轮总量限制 |
| 3.3.1 目标滑转率设定 | source/WorkSlip_Reference.m | 固定目标、入场初始化、平滑、参考变化率与有效性 |
| 3.3.2 四轮目标驱动扭矩 | State、Disturbance、SMC、TorqueConstraints | 模型增益、残差估计、SMC偏好与可执行命令的区别 |
| 3.3.3 过渡 | ModeSupervisor、Handover | 速度及有效轮数、滞回/驻留、真实命令锚点、混合及回退 |

## 滑转率输入仿射模型

仅在有效前进作业区间u_i=R_iω_i>v_ε、v_i>0，忽略滤波对名义连续模型的影响，可用κ_i=1-v_i/(R_iω_i)。求导并代入轮端动力学：

$$\dot\kappa_i=a_iT_i+d_i,\quad a_i=\frac{v_iR_i}{J_iu_i^2}>0,$$
$$d_i=-\frac{\dot v_i}{u_i}-\frac{v_iR_i}{J_iu_i^2}(R_iF_{xi}+T_{loss,i}).$$

这是未触及分母保护、截断及负向截零时的名义推导。保护区不能无条件沿用a_i正性与模型精度结论。程序对增益设置下限并报告a_floor_active，保护下限不等于真实物理增益。

## 离散残差低通估计

令T_applied[k-1]为上一拍最终下发命令，a[k-1]为配对的上一拍增益：

$$d_{raw}[k]=\frac{\kappa_{fb}[k]-\kappa_{fb}[k-1]}{T_s}-\hat a[k-1]T_{applied}[k-1],$$
$$\hat d[k]=(1-\beta)\hat d[k-1]+\beta d_{raw}[k],\quad\beta=\frac{T_s}{\tau_d+T_s}.$$

见[WorkSlip_Disturbance.m](source/WorkSlip_Disturbance.m)。无效时保持扰动状态，差分历史量仍更新。反馈经过外部唯一Unit Delay，模块内部不再对命令重复延迟。这里估计的是滑转率动力学等效扰动，单位1/s；不是ESO、轮胎力或电机实测扭矩。

## 固定目标边界层SMC

$$e_i=\kappa_{fb,i}-\kappa_{ref,i},\quad s_i=e_i,$$
$$T_{pref,i}^{raw}=\frac{\dot\kappa_{ref,i}-\hat d_i-k_i e_i-\eta_i\operatorname{sat}(e_i/\phi_i)}{\hat a_i}.$$

sat(z)=min(max(z,-1),1)。非负与数值保护后得到作业扭矩偏好；非有效阶段、无效轮或增益保护时按源码回退到基础分配。默认目标0.30是固定设置，Reference只做轨迹处理，在线寻优尚未实现。

若名义模型完全匹配，V=e²/2、残差误差有界|d-d_hat|≤ρ，且不考虑执行约束，则边界层外有V_dot≤-k e²-(η-ρ)|e|，η>ρ给出可达性的充分条件。真实实现还含增益误差、滤波、离散化及扭矩约束；需要把这些等效误差纳入分析，不能凭这条名义推导宣称整个约束切换系统无条件严格收敛。

## 起步到作业交接

阶段由TCS_ModeSupervisor唯一决定：0起步、1交接、2作业、3保护。默认进入作业门限2 km/h、至少3轮有效并保持80 ms，交接300 ms；退出门限1.3 km/h，具体条件见源码。参数为磁盘默认值，不是保存副本运行时P的测量结果。

进入交接时锁存上一拍真实命令T_anchor，按T_pref=(1-α)T_anchor+αT_work过渡，再执行最终约束。起步stage事件类别不决定全过程接管；不要写成必须先stage=5才可交接。

## 统一可执行扭矩约束

在阶段选择后求解加权偏好投影：

$$\min_T\;\frac12\sum_iw_i(T_i-T_{pref,i})^2,\qquad L_i\le T_i\le U_i,\quad\sum_iT_i\le T_0.$$

L/U组合非负、电机能力、逐轮变化率和阶段安全界。发生冲突时硬能力/安全边界优先，变化率可按源码规定放松并记录诊断。起步安全上界仅在LAUNCH生效；WORK中T_base不是逐轮硬上限。该投影不含完整第四章横摆目标与CBF约束，不能把两者合并描述。

## 写作时需补的理论材料

- 将Stateflow中计时、锁存、重置、迟滞和上界更新整理成状态转移表与伪代码。
- 查原始文献支持低速判据、混合监督、边界层SMC及约束处理；AI历史笔记不是引文。
- 明确滤波后误差与物理滑转率的关系、扰动误差有界假设和命令受限时的性能边界。
- 本轮3.4保留标题，暂不填任何仿真/实验数据和效果结论。
