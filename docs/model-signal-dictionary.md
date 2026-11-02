# tractor_mu 联合仿真模型基本信息与信号字典

> 文档状态：第一版基础整理
>
> 整理范围：现有 Simulink/TruckSim 联合仿真程序、模型内部模块、接口截图和当前可从 SLX 文件直接读取的信号信息。
>
> 本文暂不按论文第二章、第三章划分，也不规定后续控制算法。已经确认的单位、轮序、角速度定义和扭矩路径以当前版本记录；其余字段继续补全。

## 1. 文档用途

本文作为后续与其他 AI 工具、程序开发和联合仿真调试共用的基础上下文。所有信号均尽量保留模型中的原始名称；无法从当前文件直接确认的字段留空，并在“确认状态”中标记。

确认状态约定：

- `已核验`：可从 SLX 内部 XML、TruckSim 配置截图或模型文件直接读取。
- `部分核验`：名称或连接关系可读取，但单位、方向、轮序或具体物理含义仍需确认。
- `待确认`：需要在 MATLAB/TruckSim 中查看端口、变量定义或运行波形。

## 2. 文件与版本信息

| 项目 | 当前信息 | 确认状态 |
|---|---|---|
| 主 Simulink 模型 | [`../simulation/models/tractor_mu.slx`](../simulation/models/tractor_mu.slx) | 已核验 |
| 其他 Simulink 模型 | `../simulation/models/tractor_mu2018.slx`；`../simulation/models/noslip_softsoil.slx` | 已核验 |
| TruckSim 参数文件 | `../simulation/config/Tractor.cpar`；`../simulation/config/Tractor1.cpar` | 已核验 |
| MATLAB 参数文件 | [`../simulation/src/value_parameter.m`](../simulation/src/value_parameter.m)；`Total_T3D.m` | 已核验 |
| 联合仿真配置目录 | [`../simulation/config/联合仿真配置`](../simulation/config/联合仿真配置) | 已核验 |
| MATLAB/Simulink | R2022b（由模型 Scope 配置和用户确认） | 部分核验 |
| TruckSim | 2019（用户提供） | 待确认具体小版本 |
| 模型仿真起始时间 | 0 s | 已核验 |
| 模型仿真停止时间 | 30 s | 已核验 |
| Simulink 求解器 | 固定步长、离散（无连续状态） | 已核验 |
| Simulink 固定步长 | 0.001 s | 已核验 |
| Simulink 基础频率 | 1000 Hz | 已核验 |
| TruckSim 数学模型步长 | 0.001 s | 已核验 |
| TruckSim 输出文件步长 | 0.001 s | 已核验 |
| TruckSim 与 Simulink 积分方式 | AB-2，1 step per step | 已核验 |
| TruckSim Live Animator 刷新率 | 60 Hz | 已核验 |
| TruckSim 输入初值 | 四个输入均为 0.0 | 已核验 |
| TruckSim 输入模式 | Add | 已核验 |
| TruckSim 输出/输入同步方式 | Set integration method and time step；Sync kinematic exports with force imports | 已核验 |
| Simulink 与 TruckSim 工作目录 |  | 待确认 |
| TruckSim `.sim` 文件 | 模型 S-Function 内记录为 `simfile.sim` | 部分核验 |

## 3. 联合仿真接口概览

```text
TruckSim 车辆/轮胎/道路/载荷模型
              │
              │ 车辆状态、轮速、轮胎力、载荷、滑移率等输出
              ▼
      TruckSim S-Function
              │
              ▼
      tractor_mu.slx 顶层信号处理
              │
      ┌───────┼───────────────────────────┐
      │       │                           │
      ▼       ▼                           ▼
  车速/状态估计  轮胎力/载荷估计       扭矩控制与分配
      │       │                           │
      └───────┴──────────────┬────────────┘
                             ▼
                 四个轮端扭矩输入
                             │
                             ▼
                         TruckSim
```

当前模型内部同时存在基础四轮扭矩分配、驱动防滑模块、软土扭矩分配和 CBF-QP 相关模块。当前实际运行配置由第二个 Manual Switch 选择垂直载荷扭矩分配结果作为最终四轮扭矩输入。

## 4. 顶层主要模块清单

| 模块名称 | 类型 | 顶层输入端口数 | 顶层输出端口数 | 当前可读取的输出/信号 | 备注 |
|---|---:|---:|---:|---|---|
| `TruckSim S-Function` | Reference | 1 | 1 | TruckSim 状态向量 | 输入输出向量内部通道需要按 TruckSim 配置核对 |
| `总驱动力矩制定` | Subsystem | 10 | 2 | `T0_out` 等 | 产生或处理总驱动扭矩 |
| `挡位与刹车处理1` | Subsystem | 1 | 2 |  | 挡位、制动相关处理 |
| `四轮转矩分配` | Subsystem | 17 | 4 | 四轮基础扭矩/分配结果 | 输出端口对应关系待确认 |
| `驱动防滑模块` | Subsystem | 10 | 6 | `dTfl`、`dTfr`、`dTrl`、`dTrr`、`v`、`slip_valid` | 四轮扭矩修正和车速/滑移有效性相关 |
| `PF车速估计` | Subsystem | 5 | 2 | `vx_est`、`vy_est` | 粒子滤波或改进 PF 估计 |
| `垂直载荷估算` | Subsystem | 4 | 5 | `Fz1`、`Fz2`、`Fz3`、`Fz4` | 四轮垂向载荷估计 |
| `加速度滑模观测` | Subsystem | 6 | 3 |  | 加速度/状态观测 |
| `质心侧偏角估计` | Subsystem | 4 | 1 | `Beta_estimate_3` | 质心侧偏角估计 |
| `质心侧偏角滑模观测器估计` | Subsystem | 3 | 3 |  | 观测器输出待确认 |
| `质心侧偏角观测` | Subsystem | 5 | 3 |  | 观测器输出待确认 |
| `车轮腾空判断` | Subsystem | 11 | 0 | 内部判断信号 | 当前顶层未暴露输出端口 |
| `软土分配策略` | Subsystem | 5 | 4 |  | 软土/低附着扭矩策略 |
| `软土扭矩分配` | Subsystem | 12 | 9 | `selected_torques_n_m`、`drawbar_power_w`、`wheel_power_w`、`phi_raw`、`filtered_phi`、`filtered_normalized_phi`、`lambda_est`、`qp_status`、`disturbance_state_out` | 内部包含滑移目标、滑移跟踪和 CBF-QP 相关函数 |
| `Dugoff轮胎模型` | Subsystem | 11 | 8 | 四轮 `Fx`、`Fy` 相关信号 | 当前模型内部轮胎力计算 |
| `PID_Controller/直线循迹` | Subsystem | 8 | 2 |  | 直线控制相关模块 |
| `Subsystem` | Subsystem | 18 | 10 |  | 具体名称和作用待在 MATLAB 中补充 |
| `Subsystem1` | Subsystem | 11 | 8 |  | 具体名称和作用待在 MATLAB 中补充 |
| `Subsystem2` | Subsystem | 1 | 1 |  | 具体名称和作用待在 MATLAB 中补充 |

## 5. TruckSim 输入信号字典

截图中“Variables Activated for Import”显示当前启用 4 个 TruckSim 输入变量，均为 Add 模式，初值为 0.0。四个输入均为正常前进工况下的正扭矩，单位为 N·m。D1 表示前轴，D2 表示后轴。

| 序号 | TruckSim 变量名 | 方向 | 当前用途判断 | 单位 | 初值 | 采样周期 | 轮序/轴位 | 确认状态 |
|---:|---|---|---|---|---:|---:|---|---|
| 1 | `IMP_MY_OUT_D1_L` | Simulink → TruckSim | 前轴左侧轮端扭矩输入 | N·m | 0.0 | 0.001 s | D1-L = FL | 已核验 |
| 2 | `IMP_MY_OUT_D1_R` | Simulink → TruckSim | 前轴右侧轮端扭矩输入 | N·m | 0.0 | 0.001 s | D1-R = FR | 已核验 |
| 3 | `IMP_MY_OUT_D2_L` | Simulink → TruckSim | 后轴左侧轮端扭矩输入 | N·m | 0.0 | 0.001 s | D2-L = RL | 已核验 |
| 4 | `IMP_MY_OUT_D2_R` | Simulink → TruckSim | 后轴右侧轮端扭矩输入 | N·m | 0.0 | 0.001 s | D2-R = RR | 已核验 |

待确认事项：

- TruckSim 中是否还存在未在截图中启用的输入变量。

已确认：D1 为前轴，D2 为后轴；L/R 分别为左/右侧，对应 `FL/FR/RL/RR`；输入扭矩正常均为正，不考虑倒车工况。

## 6. TruckSim 输出信号字典

以下变量来自 TruckSim “Variables Activated for Export”截图。Demux 按照 TruckSim 34 个输出变量的严格顺序输出；下表的单位按当前提供的单位序列填写。需要注意：进入 Demux 后，部分信号为了程序计算方便已经在 Simulink 内做过单位转换，因此表中单位是 TruckSim 导出端单位，不一定等于控制器内部使用单位。

| 序号 | TruckSim 变量名 | 中文含义暂定 | 单位 | 坐标系/正方向 | 采样周期 | 确认状态 |
|---:|---|---|---|---|---:|---|
| 1 | `Vx` | 车辆纵向速度 | km/h | 车辆坐标系纵向 | 0.001 s | 已核验 |
| 2 | `Steer_L` | 左侧转向角 | deg |  | 0.001 s | 部分核验 |
| 3 | `Steer_R` | 右侧转向角 | deg |  | 0.001 s | 部分核验 |
| 4 | `Beta` | 车辆质心侧偏角 | deg |  | 0.001 s | 已核验 |
| 5 | `AVz` | 横摆角速度 | deg/s |  | 0.001 s | 已核验 |
| 6 | `AVy_L1` | 左前轮角速度 | rpm |  | 0.001 s | 已核验 |
| 7 | `AVy_R1` | 右前轮角速度 | rpm |  | 0.001 s | 已核验 |
| 8 | `AVy_L2` | 左后轮角速度 | rpm |  | 0.001 s | 已核验 |
| 9 | `AVy_R2` | 右后轮角速度 | rpm |  | 0.001 s | 已核验 |
| 10 | `Ax_Rd` | 车辆纵向加速度 | g |  | 0.001 s | 已核验 |
| 11 | `Ay_Rd` | 车辆横向加速度 | g |  | 0.001 s | 已核验 |
| 12 | `Fz_L1` | 左前轮垂向载荷 | N |  | 0.001 s | 已核验 |
| 13 | `Fz_L2` | 左后轮垂向载荷 | N |  | 0.001 s | 已核验 |
| 14 | `Fz_R1` | 右前轮垂向载荷 | N |  | 0.001 s | 已核验 |
| 15 | `Fz_R2` | 右后轮垂向载荷 | N |  | 0.001 s | 已核验 |
| 16 | `AVx` | 侧倾角速度 | deg/s |  | 0.001 s | 已核验 |
| 17 | `AVy` | 俯仰角速度 | deg/s |  | 0.001 s | 已核验 |
| 18 | `Vy` | 车辆横向速度 | km/h | 车辆坐标系横向 | 0.001 s | 已核验 |
| 19 | `Az_Rd` | 车辆垂向加速度 | g |  | 0.001 s | 已核验 |
| 20 | `Kappa_L1` | 左前轮纵向滑移率 | - | 大于 0 为驱动，小于 0 为制动 | 0.001 s | 已核验 |
| 21 | `Kappa_R1` | 右前轮纵向滑移率 | - | 大于 0 为驱动，小于 0 为制动 | 0.001 s | 已核验 |
| 22 | `Kappa_L2` | 左后轮纵向滑移率 | - | 大于 0 为驱动，小于 0 为制动 | 0.001 s | 已核验 |
| 23 | `Kappa_R2` | 右后轮纵向滑移率 | - | 大于 0 为驱动，小于 0 为制动 | 0.001 s | 已核验 |
| 24 | `Xo` | 车辆 X 方向位置 | m |  | 0.001 s | 已核验 |
| 25 | `Yo` | 车辆 Y 方向位置 | m |  | 0.001 s | 已核验 |
| 26 | `Fx_L1` | 左前轮纵向力 | N |  | 0.001 s | 已核验 |
| 27 | `Fx_R1` | 右前轮纵向力 | N |  | 0.001 s | 已核验 |
| 28 | `Fx_L2` | 左后轮纵向力 | N |  | 0.001 s | 已核验 |
| 29 | `Fx_R2` | 右后轮纵向力 | N |  | 0.001 s | 已核验 |
| 30 | `Pitch` | 车辆俯仰角 | deg |  | 0.001 s | 已核验 |
| 31 | `Fy_L1` | 左前轮侧向力 | N |  | 0.001 s | 已核验 |
| 32 | `Fy_R1` | 右前轮侧向力 | N |  | 0.001 s | 已核验 |
| 33 | `Fy_L2` | 左后轮侧向力 | N |  | 0.001 s | 已核验 |
| 34 | `Fy_R2` | 右后轮侧向力 | N |  | 0.001 s | 已核验 |

说明：TruckSim 的 34 个输出经 S-Function 后由 Demux 严格按上述顺序拆分。进入 Demux 后，部分量会经过单位转换，例如速度、角度、角速度、轮速和加速度；控制器内部使用的单位必须以具体转换模块为准。

## 7. Simulink 内部信号补充

### 四轮命名规范

当前模型采用三种等价的四轮编号方式，后续整理信号时统一按以下关系解释：

| 表达形式 | 左前轮 | 右前轮 | 左后轮 | 右后轮 |
|---|---|---|---|---|
| 数字编号 | `1` | `2` | `3` | `4` |
| 位置缩写 | `FL` | `FR` | `RL` | `RR` |
| 左右/轴位编号 | `L1` | `R1` | `L2` | `R2` |

因此，`Fz1/Fz2/Fz3/Fz4`、`Tfl/Tfr/Trl/Trr`、`FzL1/FzR1/FzL2/FzR2` 和 `Kappa_L1/Kappa_R1/Kappa_L2/Kappa_R2` 在语义上都应映射到同一套四轮位置；TruckSim 输入中 D1=前轴、D2=后轴。

### 扭矩与扭矩修正信号

| 信号 | 当前含义 | 单位 | 来源/去向 | 确认状态 |
|---|---|---|---|---|
| `T0` | 总驱动扭矩需求或基础扭矩 | N·m | 总驱动力矩制定/分配模块 | 部分核验 |
| `T0_out` | 总驱动力矩制定模块输出 | N·m | 顶层 `Goto` 标签 | 部分核验 |
| `Tfl` | 左前轮基础/实际扭矩 | N·m | 扭矩分配模块 | 已确认单位和轮序 |
| `Tfr` | 右前轮基础/实际扭矩 | N·m | 扭矩分配模块 | 已确认单位和轮序 |
| `Trl` | 左后轮基础/实际扭矩 | N·m | 扭矩分配模块 | 已确认单位和轮序 |
| `Trr` | 右后轮基础/实际扭矩 | N·m | 扭矩分配模块 | 已确认单位和轮序 |
| `dTfl` | 左前轮扭矩修正量 | N·m | 驱动防滑模块输出 1 | 已确认单位和轮序 |
| `dTfr` | 右前轮扭矩修正量 | N·m | 驱动防滑模块输出 2 | 已确认单位和轮序 |
| `dTrl` | 左后轮扭矩修正量 | N·m | 驱动防滑模块输出 3 | 已确认单位和轮序 |
| `dTrr` | 右后轮扭矩修正量 | N·m | 驱动防滑模块输出 4 | 已确认单位和轮序 |
| `Tm4` | 实际输出的四轮扭矩向量 | N·m | 最终扭矩选择路径；向量顺序为 FL、FR、RL、RR | 已确认定义 |
| `base_Torque` | 基础总扭矩/基础轮端扭矩 | N·m | 软土扭矩分配相关模块 | 已确认单位 |
| `Torque_soft` | 软土策略输出扭矩 | N·m | 软土分配策略/软土扭矩分配 | 已确认单位 |
| `TMaxFL` | 左前轮扭矩上限 | N·m | 限幅/软土扭矩分配 | 已确认单位和轮序 |
| `TMaxFR` | 右前轮扭矩上限 | N·m | 限幅/软土扭矩分配 | 已确认单位和轮序 |
| `TMaxRL` | 左后轮扭矩上限 | N·m | 限幅/软土扭矩分配 | 已确认单位和轮序 |
| `TMaxRR` | 右后轮扭矩上限 | N·m | 限幅/软土扭矩分配 | 已确认单位和轮序 |
| `selected_torques_n_m` | 软土/CBF-QP 最终选定四轮扭矩 | N·m | `软土扭矩分配` | 四元顺序为 FL、FR、RL、RR；当前不一定是最终送入 TruckSim 的一路 | 部分核验 |
| `R_load` | 估计的行驶阻力 |  | 负载/阻力估计与扭矩分配 | 已确认定义 |

### 状态、驾驶输入和模式信号

| 信号 | 当前含义 | 单位/编码 | 来源/去向 | 确认状态 |
|---|---|---|---|---|
| `st` | 前轮转角 | deg 或模型内部换算单位 | 多个控制模块 | 已确认定义 |
| `st_L` | 左前轮转角 | deg 或模型内部换算单位 | 顶层 Goto/From | 已确认定义 |
| `st_R` | 右前轮转角 | deg 或模型内部换算单位 | 顶层 Goto/From | 已确认定义 |
| `mode` | 当前控制/运行模式 | 离散编码 | 状态判断与控制器 | 部分核验 |
| `GearD` | 挡位状态 | 离散编码 | 挡位与刹车处理；用于前后电机两档减速比选择 | 已确认用途 |
| `sw` | 开关/控制使能 | 离散 | 驱动防滑相关 | 待确认 |
| `k1`、`k2` | 控制增益或模式参数 |  | 扭矩控制相关 | 待确认 |
| `beta_ref` | 侧偏角参考值 |  | 侧偏角/横向控制 | 部分核验 |
| `omega_ref` | 横摆角速度参考值 |  | 直线/横摆控制 | 部分核验 |
| `wr_d` | 参考轮速或相关目标量 |  | 车速/轮速控制 | 待确认 |
| `yaw_ref` | 航向角参考值 |  | 直线控制 | 待确认 |

### 估计、诊断和软土策略信号

| 信号 | 当前含义 | 单位 | 来源/去向 | 确认状态 |
|---|---|---|---|---|
| `vx_est` | 估计纵向速度 |  | `PF车速估计` | 部分核验 |
| `vy_est` | 估计横向速度 |  | `PF车速估计` | 部分核验 |
| `v_e` | 估计速度或速度误差 |  | 驱动防滑模块输出 5/`Goto` | 待确认 |
| `beta_e` | 侧偏角误差或估计误差 |  | 顶层 To Workspace/控制模块 | 待确认 |
| `Fx_est` | 纵向力估计 |  | 轮胎力估计/驱动防滑 | 部分核验 |
| `EFxL1`、`EFxR1`、`EFxL2`、`EFxR2` | 四轮纵向力估计 |  | 软土/力估计模块 | 待确认 |
| `gamma_est` | 横摆/航向相关估计量 |  | 估计器 | 待确认 |
| `vy_hat_out` | 横向速度估计输出 |  | 估计器 | 待确认 |
| `drawbar_power_w` | 牵引功率 | W（按变量名推定） | 软土扭矩分配 | 部分核验 |
| `wheel_power_w` | 轮端功率 | W（按变量名推定） | 软土扭矩分配 | 部分核验 |
| `phi_raw` | 牵引效率/功率比原始量 |  | 软土扭矩分配 | 部分核验 |
| `filtered_phi` | 滤波后的性能指标 |  | 软土扭矩分配 | 部分核验 |
| `filtered_normalized_phi` | 归一化性能指标 |  | 软土扭矩分配 | 部分核验 |
| `lambda_est` | 牵引效率相关参数估计 |  | 软土扭矩分配 | 部分核验 |
| `qp_status` | QP 求解状态 | 离散/数值状态 | CBF-QP 扭矩分配 | 部分核验 |
| `disturbance_state_out` | 扰动状态估计输出 |  | CBF-QP 扭矩分配 | 部分核验 |
| `objective_valid` | 性能目标是否有效 | 0/1 或逻辑 | 牵引性能相关模块 | 待确认 |

## 8. Goto/From 标签字典

SLX 顶层 XML 中检测到大量 Goto/From 标签。下表列出可作为跨子系统接口的唯一标签名；同一标签可能有多个 From 使用点。标签本身不等于物理量已经确认，仍需结合连线和运行波形核对。

| 标签 | 归类 | 当前出现的主要用途 |
|---|---|---|
| `Vx` | 车辆速度 | TruckSim 纵向速度、车速估计、滑移计算 |
| `vy` | 车辆速度 | 横向速度、GPS/估计输入 |
| `ax`、`ay`、`az` | 车辆加速度 | 观测器、车轮腾空判断、状态估计 |
| `omega` | 角速度 | 横摆角速度/INS/控制器 |
| `yaw` | 航向 | GPS 航向、直线控制 |
| `beta`、`beta_e`、`beta_ref`、`beta_est` | 侧偏角 | 侧偏角估计、控制参考和误差 |
| `pitch`、`Roll`、`dPitch` | 车身姿态 | 载荷估计、车轮腾空和状态估计 |
| `sp1`–`sp4` | 轮速/转速 | 驱动防滑、轮速计算 |
| `w_fl`、`w_fr`、`w_rl`、`w_rr` | 四轮角速度 | 轮速/滑移率计算 |
| `Fz1`–`Fz4` | 四轮垂向载荷 | 四轮分配、轮胎力估计 |
| `FzL1`、`FzR1`、`FzL2`、`FzR2` | 分轴分侧垂向载荷 | 轮胎和扭矩计算 |
| `FxL1`、`FxR1`、`FxL2`、`FxR2` | 四轮纵向力 | 轮胎力估计、性能计算 |
| `FyL1`、`FyR1`、`FyL2`、`FyR2` | 四轮侧向力 | 轮胎模型、横向控制 |
| `T0`、`T0_out` | 总扭矩 | 总驱动力矩制定和四轮分配 |
| `Tfl`、`Tfr`、`Trl`、`Trr` | 四轮扭矩 | 扭矩分配和 TruckSim 输入映射 |
| `dTfl`、`dTfr`、`dTrl`、`dTrr` | 四轮扭矩修正 | 驱动防滑控制 |
| `TMaxFL`、`TMaxFR`、`TMaxRL`、`TMaxRR` | 四轮扭矩上限 | 限幅和软土扭矩分配 |
| `lamda1`–`lamda4`、`kappa` | 滑移率 | 滑移率计算、软土控制 |
| `slip_valid` | 滑移率有效标志 | 滑移率控制和诊断 |
| `Mu`、`mu` | 附着 | 轮胎/策略参数或估计值 |
| `mode`、`GearD`、`sw` | 状态/模式 | 工况选择和控制使能 |
| `st`、`st_L`、`st_R` | 前轮转角 | 前轮转向输入，分别为总前轮转角、左前轮转角和右前轮转角 |
| `k1`、`k2` | 增益/参数 | 控制器内部参数 |
| `Torque_soft`、`base_Torque` | 扭矩策略量 | 软土策略与基础扭矩 |
| `R_load` | 行驶阻力 | 估计的车辆行驶阻力 |
| `kappa`、`kappa_valid` | 滑移控制状态 | 软土/滑移跟踪相关 |

## 9. 现有 MATLAB Function / Stateflow 算法单元

从 SLX 内嵌 Stateflow XML 中可以读取到以下函数入口。这里仅记录当前程序已有的构建内容，不评价其是否适合作为论文创新。

| 图表文件 | 函数入口 | 当前功能摘要 |
|---|---|---|
| `chart_132.xml` | `fcn(ax,ay,alpha,belta)` | 垂向载荷估算 |
| `chart_145.xml` | `fcn(mode,vx,steer_degree)` | 参考侧偏角、横摆角速度、附着参数相关计算 |
| `chart_182/195/271/284.xml` | `tire(Fz,u,lamda,alpha)` | Dugoff 轮胎纵横向力计算 |
| `chart_208.xml` | `shiche_soft_soil_adaptive_allocation(...)` | 基于四轮滑移差异的直接扭矩再分配 |
| `chart_220.xml` | `MF_StateKinematicsAndGain(...)` | 轮端运动学、滑移率、输入增益和扭矩限幅整理 |
| `chart_243.xml` | `fcn(Mz,T0,derta,k,mode)` | 基于横摆力矩和总扭矩的四轮分配 |
| `chart_257.xml` | `Fx_est...` | 纵向力/轮速观测相关 |
| `chart_297.xml` | `fcn(u)` | Kalman 滤波器矩阵生成 |
| `chart_313.xml` | `fcn(sp1,sp2)` | 前轴轮速相关计算 |
| `chart_322.xml` | `fcn(sp3,sp4)` | 后轴轮速相关计算 |
| `chart_387.xml` | `mpc_torque_allocation_fcn(...)` | MPC 扭矩分配函数 |
| `chart_399.xml` | `fcn(Fd,P_qianyin,P_qudong,v)` | 功率/牵引性能相关计算 |
| `chart_409.xml` | `fcn(F,derta,dwfl,dwfr,dwrl,dwrr)` | 四轮扭矩或力分配相关计算 |
| `chart_424.xml` | `fcn(v,dT1,dT2,dT3,dT4)` | 扭矩修正量与车速相关处理 |
| `chart_526.xml` | `fcn(vfl,vfr,vrl,vrr,omega,brk,st)` | 车速估计/防滑相关逻辑 |
| `chart_575.xml` | `fcn_ImprovedPF(ax_m,ay_m,r_m,init_vx,init_vy)` | 改进粒子滤波车速估计 |
| `chart_587.xml` | `GPS_INS_SlidingMode(...)` | GPS/INS 航向或角度融合 |
| `chart_598.xml` | `accel_SMO_correction(...)` | 加速度滑模修正 |
| `chart_624.xml` | `MF_TractionEfficiencyObjective(...)` | 牵引功率与效率目标计算 |
| `chart_641.xml` | `MF_AdaptiveSlipTarget4W(...)` | 四轮自适应目标滑移率计算 |
| `chart_668.xml` | `shapley_value_all(...)` | 基于联盟/价值的四轮分配评价 |
| `chart_686.xml` | `shiche_soft_soil_adaptive_allocation(...)` | 软土自适应滑移与扭矩分配主函数 |
| `chart_732.xml` | `StraightModeDetector(...)` | 直线控制模式检测 |
| `chart_751.xml` | `stateflow(v,st,avg)` | 状态模式判断 |
| `chart_760.xml` | `MF_SlipTrackingNominalTorque(...)` | 滑移跟踪名义扭矩计算 |
| `chart_773.xml` | `MF_CBF_QP_TorqueAllocator(...)` | CBF 滑移安全上界和 QP 四轮扭矩分配 |
| `chart_797.xml` | 牵引效率评价相关函数 | 具体函数入口待补充 |

## 10. 当前模型的内部构建层级

### 10.1 TruckSim 与信号解码层

- `TruckSim S-Function` 接收外部输入向量并输出 TruckSim 状态向量。
- 顶层 `Demux` 具有 34 个输出，当前与 TruckSim 导出变量数量一致，具体通道映射需要在 MATLAB 中逐项确认。
- `Demux1`、`Demux2` 为四路信号拆分，可能用于四轮量或四路控制量。
- 顶层存在多组 `Goto/From`，用于跨子系统传递速度、轮速、载荷、力、扭矩和模式信号。

### 10.2 车辆状态与车速估计层

- `PF车速估计` 使用 `fcn_ImprovedPF`，输入包括纵向/横向加速度、横摆角速度和初始速度量，输出 `vx_est`、`vy_est`。
- `GPS测量纵向速度`、`GPS测量横向速度`、`INS测量纵向加速度`、`INS测量横向加速度` 通过 Goto/From 标签接入模型。
- `加速度滑模观测`、GPS/INS 滑模融合和侧偏角观测器同时存在。

### 10.3 轮胎力与载荷层

- `Dugoff轮胎模型` 为四轮纵横向力模型。
- 模型中存在 `Fx`、`Fy`、`Fz` 以及 `Fx_est` 等信号。
- `垂直载荷估算` 输出 `Fz1`–`Fz4`，并使用纵向、横向加速度和姿态相关信号。
- `车轮腾空判断` 使用滑移、轮速变化、扭矩估计和垂向加速度等条件进行判断，当前无顶层输出端口。

### 10.4 扭矩控制与分配层

- `总驱动力矩制定` 产生总需求扭矩。
- `四轮转矩分配` 输出四路扭矩，是基础四轮分配模块。
- `驱动防滑模块` 输出四个扭矩修正量，以及车速和滑移有效性信号。
- `软土扭矩分配` 内含名义扭矩、滑移跟踪、扭矩上限、CBF-QP、扰动估计和性能评价相关计算。
- TruckSim 的四个导入量分别对应 D1-L/D1-R/D2-L/D2-R，即 FL/FR/RL/RR。

## 11. 当前实际扭矩输入路径与执行器约束

### 11.1 两个 Manual Switch 的选择关系

当前实际送入 TruckSim 的四轮扭矩由两个 Manual Switch 共同决定：

1. 第一个 Manual Switch 的上方输入为“协同博弈四轮扭矩分配”结果，该方案目前基本弃用；下方输入为“软土扭矩分配”结果。
2. 第二个 Manual Switch 是最终选择环节：上方输入为“垂直载荷扭矩分配”结果，下方输入为第一个 Manual Switch 的输出。
3. 当前实际运行配置选择的是第二个 Manual Switch 上方的“垂直载荷扭矩分配”结果，因此当前 TruckSim 实际接收的四轮扭矩来自垂直载荷扭矩分配路径。

```text
协同博弈四轮扭矩分配 ─┐
                      ├─ Manual Switch 1 ─┐
软土扭矩分配 ─────────┘                    │
                                           ├─ Manual Switch 2 ── TruckSim 四轮扭矩输入
垂直载荷扭矩分配 ──────────────────────────┘
```

该路径说明的是当前模型的实际选择关系；后续如果切换 Manual Switch，需要同步记录开关位置和最终扭矩来源。

### 11.2 扭矩方向、单位和限幅

- 正常前进工况下，四轮扭矩信号均为正值，暂不考虑倒车工况。
- 扭矩单位为 N·m。
- 扭矩上限主要由电机和减速器特性决定。
- 前轮电机减速比：1 档 `63.52`，2 档 `15.88`。
- 后轮电机减速比：1 档 `80.454`，2 档 `30.6204`。
- 挡位信号为 `GearD`，其值用于选择前后电机对应的两档减速比。
- 前、后电机的转速—扭矩特性分别位于模型模块“前电机特性图1”和“后电机特性图1”中，具体曲线断点和限幅数值暂未从当前文件提取。

| 执行器/参数 | 1 档减速比 | 2 档减速比 | 单位 | 当前确认状态 |
|---|---:|---:|---|---|
| 前轮电机 | 63.52 | 15.88 | 无量纲 | 已核验 |
| 后轮电机 | 80.454 | 30.6204 | 无量纲 | 已核验 |

### 11.3 当前最终输入的待核对字段

| 字段 | 当前信息 | 仍需补充 |
|---|---|---|
| 最终四轮扭矩信号所在模块/连线 | 第二个 Manual Switch 的上方输出路径 | 具体端口名称和连线位置 |
| 电机特性曲线 | 前后电机各有一个特性图模块 | 曲线断点、最大电机转速和每档扭矩上限 |
| 减速器输出扭矩限幅 | 由电机和减速器特性共同决定 | 代码中的具体限幅公式和数值 |

## 12. 当前数据记录变量

顶层 `To Workspace` 模块中可直接读取的变量如下。保存格式当前为 `Structure With Time`，最大数据点数为 `inf`。

| To Workspace 模块 | 变量名 | 当前信号含义 | 确认状态 |
|---|---|---|---|
| `To Workspace` | `X` | 车辆 X 位置 | 部分核验 |
| `To Workspace1` | `Y` | 车辆 Y 位置 | 部分核验 |
| `To Workspace11` | `vx` | 车辆纵向速度 | 部分核验 |
| `To Workspace12` | `vx_est` | 估计纵向速度 | 部分核验 |
| `To Workspace14` | `beta_e` | 侧偏角误差/估计量 | 待确认 |
| `To Workspace2` | `omega_ref` | 横摆角速度参考值 | 部分核验 |

模型中还存在大量 Scope、XY Graph 和 Record 记录块。Scope 的完整信号标签包括四轮转速、四轮载荷、四轮纵向力、四轮滑移率、驱动防滑修正量、软土扭矩、牵引功率和 QP 状态等。

## 13. 已确认的信号与仍需补充的信息

### 13.1 当前已经可以作为共享基础的信息

- 模型文件和相关参数文件路径。
- 仿真起止时间。
- Simulink 和 TruckSim 的步长及频率。
- TruckSim 与 Simulink 的同步方式。
- TruckSim 当前 4 个输入变量名。
- TruckSim 当前 34 个输出变量名及导出顺序。
- 顶层主要 Subsystem 名称和端口数量。
- 顶层 Goto/From 标签集合。
- 当前 SLX 中嵌入的主要 MATLAB Function/Stateflow 函数入口。
- 当前 To Workspace 变量名。

### 13.2 后续建议补充的信息

| 待补字段 | 建议来源 |
|---|---|
| TruckSim 34 个输出变量进入 Demux 后的具体单位转换 | Simulink Demux 后的 Gain/Data Type Conversion 模块 |
| 电机特性曲线和最终限幅公式 | “前电机特性图1”“后电机特性图1”模块 |
| `Fz1`–`Fz4` 与 `FzL1/FzR1/FzL2/FzR2` 的程序连线关系 | 顶层连线和运行数据 |
| 各模块实际启用/旁路关系 | MATLAB 模型当前开关、Manual Switch 和运行模式 |
| 最终送入 TruckSim 的具体端口位置 | 顶层连线和 TruckSim 输入端口 |
| 各采样时间、滤波器和延迟 | Simulink Block 参数和模型配置 |
| TruckSim `.sim` 文件实际路径 | TruckSim 配置和模型工作目录 |
| 运行基线的关键数值范围 | 一次完整仿真日志 |

## 14. 后续维护约定

1. 新增信号先登记原始名称，再填写中文含义。
2. 对已经确认的 TruckSim 导出单位与进入 Demux 后的内部换算单位分开记录。
3. 对同一物理量存在多个别名时，保留原始标签，并增加“规范名称”字段。
4. 每次修改模型接口后，更新仿真步长、端口数、输入输出列表和运行模式记录。
5. 当 MATLAB 运行数据可用后，优先用实际波形确认 Demux 通道、轮序、单位和符号。

