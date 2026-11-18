# WorkSlip 固定目标滑转率控制说明

模型：`simulation/models/tractor_mu.slx` 中的 `work_slip_control` / 驱动防滑执行链。四轮信号顺序统一为 `[FL; FR; RL; RR]`，扭矩单位为轮端 N·m，采样周期为 `P.Ts=0.001 s`。

## 信号链

1. `WorkSlip_State` 使用轮速、有效半径、车体速度估计及有效性输入计算反馈滑转率 `kappa_fb`、有效标志 `slip_valid` 和状态诊断。状态滤波与目标生成并不在 SMC 中重复执行。
2. `WorkSlip_Reference` 生成逐轮固定目标 `kappa_ref` 及其变化率 `kappa_ref_dot`。本轮对比将四轮目标统一设为 `0.30`；起步阶段参考按有效性和交接状态初始化。
3. `WorkSlip_Disturbance` 输出扭矩输入增益估计 `a_hat` 与等效扰动估计 `d_hat`。输入增益低于 `P.work_a_min` 时由 `a_floor_active` 标记，避免将失真的逆模型增益送入控制律。
4. `WorkSlip_SMC` 计算误差 `e=kappa_fb-kappa_ref`，首版滑模面 `s=e`，边界层输出 `sat(e/phi)`。控制偏好为 `T_pref_work_raw=(kappa_ref_dot-d_hat-k*e-eta*sat(e/phi))/a_hat`。负值经非负和数值保护后成为 `T_pref_work`；无效轮、增益保护或非 WORK/BLEND 阶段时回退到 `max(T_base,0)`，并通过 `smc_fallback`、`smc_valid`、`smc_pref_clipped` 标记。
5. `TCS_Handover` 在 LAUNCH 使用 `T_launch_pref`；进入 BLEND 时锁存上一拍实际下发的扭矩作为 `T_launch_anchor`，再与有效 SMC 偏好按 `blend_alpha` 插值；WORK 使用 SMC 偏好。SMC 无效时保留基础分配作为安全回退。
6. `TCS_TorqueConstraints` 是 SMC 命令的统一投影层。真实 `T0` 是总扭矩预算；`T_base` 仅作为参考，不代替预算或在 WORK 中形成逐轮上限。逐轮上下界由能力、阶段安全上限及上一拍命令变化率确定，并求解加权偏好投影：

   `min 0.5*sum(w_i*(T_i-T_pref_i)^2)`，满足 `L_i<=T_i<=U_i` 且 `sum(T_i)<=T0`。

   输出 `T_cmd` 及能力、总需求、上升/下降变化率、变化率优先级放松、需求未满足、保护及投影乘子诊断。LAUNCH 才施加 `T_launch_safe`；WORK 不再受旧起步门控上界约束。
7. 根级“扭矩接口”选择 PI-TCS 或 SMC-TCS 分支，之后由模型现有的最终执行/电机能力接口送入 TruckSim。该开关按本轮动态验证结果配置：`CurrentSetting=1` 为 PI，`CurrentSetting=0` 为 SMC。PI-TCS 由基础分配扭矩叠加四轮 PI 补偿量 `dTfl/dTfr/dTrl/dTrr` 构成；本轮没有改 PI 参数。

## 主要信号

| 信号 | 含义 | 单位/维度 |
|---|---|---|
| `T0` / `EX_T0` | 根级原始总扭矩需求，统一约束层总预算 | 标量，轮端 N·m |
| `T_base_tcs` | 四轮基础扭矩分配 | 4 维，N·m |
| `T_max_tcs` | 四轮电机能力上限 | 4 维，N·m |
| `WorkSlip_kappa_fb` | 四轮反馈滑转率 | 4 维，无量纲 |
| `WorkSlip_kappa_ref` | 四轮目标滑转率 | 4 维，无量纲 |
| `EX_T_pref_work_raw` | SMC 未作非负/数值保护的偏好 | 4 维，N·m |
| `WorkSlip_T_pref_work` | SMC 处理后的偏好 | 4 维，N·m |
| `EX_T_pref_blend` | 阶段交接后的控制偏好 | 4 维，N·m |
| `EX_T_cmd_pre_limit` / `T_cmd` | 统一投影层命令输出 | 4 维，N·m |
| `EX_T_applied_cmd` / `T_actual` | 根级选择后实际执行扭矩记录 | 4 维，N·m |
| `EX_total_demand_source` | 总预算来源；`0` 表示 T0 有效，`2` 表示 T0 无效保护 | 标量枚举 |
| `EX_control_phase` | 阶段；`0/1/2/3` 分别为 LAUNCH/BLEND/WORK/PROTECT | 标量枚举 |

## 当前参数与限制

- 固定目标：四轮 `0.30`。
- SMC 参数：`k=2 s^-1`、`eta=0.5 s^-1`、`phi=0.020`；扰动估计、滤波和参考轨迹沿用当前正式参数。
- 逐轮惯量按工程参数 `P.work_J_wheel` 设置；模型控制接口采用轮端扭矩，传动系统等效惯量由外部车辆模型处理。
- PI 的 `dT` 原始向量未作为独立日志量保存；当前数据可验证模式切换和最终扭矩影响，但不足以逐拍审计 PI 内部积分器、抗饱和和原始补偿量。
- PI 与 SMC 对比之外，独立“无主动滑转控制”的 TruckSim 基础分配组仍需补测；`T_base_tcs` 不能代替一组闭环车辆响应。
