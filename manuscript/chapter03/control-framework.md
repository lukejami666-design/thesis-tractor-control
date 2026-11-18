# tractor_mu1118 驱动防滑全过程与模块说明

核查日期：2026-11-18。对象为 `工作记录/2026-11-18/tractor_mu1118.slx` 中保存的实际连线、MATLAB Function 内嵌代码及 Stateflow 标签。此次只读模型，没有改写模型、程序或注释，没有运行仿真。模型哈希见同目录 `model_identity.json`，内嵌源码只读导出为 `chart_*.m`。

## 一、先理解整体框架

当前驱动防滑模块同时保留三部分：旧版 PI 补偿链、起步门控链、新增作业 SMC 链。其中，起步门控与作业 SMC 通过新增监督、交接和最终约束模块组成全过程控制；旧 PI 通过另一组 dT 输出保留供对比。因此不能把画面上所有模块理解成一条依次执行的控制链。

全过程运行逻辑是：

1. 接收车轮转速、车体纵横向速度、横摆角速度、加速度、转角、基础四轮需求 `T_base`、总需求 `T0`、电机能力 `TMax` 和上一拍最终命令。
2. 起步探测链计算轮面速度与地速之差 `dv`，识别“有驱动却没走”“车轮空转”等运动证据；起步 Chart 对证据计时、锁存，得到预警和确认事件。
3. 与此同时，WorkSlip 状态模块计算可用于作业闭环的逐轮滑转率、有效性及输入增益。两套状态计算并行存在，不能把它们的滤波和信号定义混用。
4. `TCS_ModeSupervisor` 根据速度、有效轮数、持续时间、源故障和参数合法性决定当前是起步、交接、作业还是保护。
5. 起步时采用起步门控给出的扭矩候选；交接时从上一拍真实下发的命令平滑混合至作业 SMC 偏好；作业时采用有效的 SMC 偏好，无效轮退回基础分配。
6. `TCS_TorqueConstraints` 对候选执行非负、电机能力、总需求预算和变化率约束，产生全过程 `T_cmd`。
7. 顶层“扭矩接口”选择全过程分支或旧分支，再经过 `Common motor capability`，送入 TruckSim。其输出经一个全局 `Unit Delay` 回到控制器，供下一拍使用。

实际核心依赖可以写成：

```text
运动输入 ── 起步探测 → launch_state → 起步扭矩控制 ──────────┐
    │                         │ source_bad                  │ 起步候选
    └── WorkSlip_State ────────┼──→ TCS_ModeSupervisor        │
              │ slip_valid    │       │ phase、alpha         │
              ├→ Reference ───┤       │                     ↓
              └→ Disturbance → SMC → 作业扭矩偏好 ────→ TCS_Handover
                                                           ↓
                                              TCS_TorqueConstraints
                                                           ↓
                                                       T_cmd
                                                           ↓
                           顶层扭矩接口 → Common motor capability → TruckSim
                                              │
                                              └→ Unit Delay → 上一拍命令反馈
```

这是信号依赖示意，并非要求 Simulink 按屏幕位置或文件名逐个调用。采样周期为 1 ms；具有 `persistent` 的模块保留滤波、计时或记忆状态，一拍延迟隔开命令反馈闭环。

## 二、两套“阶段”必须区分

### 全过程控制阶段 control_phase

由 `TCS_ModeSupervisor` 唯一产生，负责实际控制权。

| 编码 | 名称 | 实际选择 |
|---:|---|---|
| 0 | LAUNCH 起步 | 起步候选及起步安全上界 |
| 1 | BLEND 交接 | 起步入口命令锚点与作业偏好混合 |
| 2 | WORK 作业 | 作业 SMC 偏好，有效性不足的轮回退基础分配 |
| 3 | PROTECT 保护 | 最终统一约束层将允许扭矩置零 |

当前磁盘参数脚本 `simulation/src/launch_gate_params.m` 默认设置：速度至少 2 km/h、至少 3 轮滑转率有效，持续 80 ms 后从起步进入交接；混合时间 300 ms 后进入作业。交接期间速度低于 1.3 km/h 会立即退回起步；作业期间低于该速度持续 200 ms 后退回起步。故障或参数非法优先进入保护，故障解除后回到起步。默认值不等于该副本保存时 MATLAB 工作区的实际 P；若已有合法 P，模型初始化会沿用它。

特别注意：进入作业没有要求旧 Chart 必须先进入 stage=5，也没有直接要求 nspin=0。有效滑转率意味着信号可以计算，不代表滑转率已经很低。

### 起步事件阶段 stage

由旧 `launch_state` 产生，用于起步内部的场景辨识：255 禁用、0 探测、1 正常起步、2 重载未起动、3 单轮空转、4 多轮空转、5 WORK_PASS、6 故障保护。

它仍然向起步门控提供 `stage/spin_mask/prewarn/warn_age`，并提供全局使用的 `source_bad`。但它保留的旧 `control_phase/handover_alpha` 输出已改接为 `Legacy_chart_*` 标签，不决定新增全过程控制权。所以“stage=4，同时 control_phase=2”不一定是连线错误：前者是旧事件分类，后者才表示作业 SMC 已经取得控制权。

## 三、起步部分逐模块说明

### 1. 起步探测 LaunchTCS_Motion

输入：四轮角速度 w、vx/vy、ax、横摆角速度 r、逐轮转角、速度源有效标志、上一拍命令、当拍能力、reset 和 P。

功能：滤波运动信号；按车体平动、横摆和转角算各轮滚动方向地速；计算 `dv=轮面速度-轮向地速`，再形成用于判别的非负 `dv_ctrl` 及增长率。结合上一拍是否真正有驱动，给出空转、快速恶化、清除、未起动、已运动和速度有效的瞬时证据。

它只给“这一拍像不像空转”的证据，不做确认计时，不直接决定最终阶段。还检查原始信号有限性、速度源和车速/加速度一致性。

### 2. launch_state Stateflow

它不是 MATLAB Function，而是包含 MONITOR 与 MODE 并行区的状态机。MONITOR 先执行：对空转/清除计时、预警保持与重新武装、重载未起动、速度有效和信号健康进行判断。MODE 再根据 desired_stage 切换起步场景。

输出中最重要的是 `prewarn`、`spin_mask`、`warn_age`、`stage` 与 `source_bad`。即使进入作业阶段，后台起步检测链仍有连接，尤其源故障仍可使全过程进入保护；“释放起步扭矩限制”不等于整条起步链停止计算。

### 3. 起步扭矩控制 LaunchTCS_Torque

输入起步事件、基础需求、电机能力、上一拍命令，以及新增全过程 phase。正常起步跟随可执行基础需求；重载未起动时缓慢探测；预警/确认空转时使用包络、事件锚点、逐轮 bound 和多轮总量上界限制需求；清除后恢复。

当前副本的 bound 已采用事件时有限初始化，不能套用 11 月 14 日“始终从 1e12 下降”的旧候选缺陷说明。

只有 `control_phase=0` 时起步预警和确认约束拥有控制权；BLEND/WORK 释放起步事件上界。尽管接口仍接收作业偏好、有效性和混合系数，实际作业选择/交接已经移至 `TCS_Handover`，不要看到这些输入就认为混合在本模块内完成。

本模块第 3 个输出仍叫 `T_cmd`，但外面接到标签 **T_cmd_launch**。它是起步候选，不是最终车辆命令。`T_lim_out`、`T_target` 等也属于起步支路诊断，不能代表作业阶段最终统一约束。

## 四、新增全过程模块逐个说明

### 4. TCS_ModeSupervisor 阶段监督

作用是唯一决定 0/1/2/3 四种全过程 phase 和交接系数 alpha。依据车速、WorkSlip 有效轮数和保持时间切换，对 source_bad、非有限速度/轮速/能力、负能力及非法 WorkSlip 参数进入保护。

输出还包含进入/退出作业事件、阶段变化和 launch/work/protect_enable，主要用于状态观察。它没有直接输入旧 stage 或 nspin，因此不能用旧 Chart 状态替代该模块的判断。

### 5. WorkSlip_Control 作业控制子系统

这是封装容器，不是一个独立控制律。内部有以下四个 MATLAB Function。

#### 5.1 WorkSlip_State 状态计算

将 w、vx、vy、r 滤波后，投影得到每轮地速 vi，轮速乘半径得到 ui。当前计算使用：

`kappa=(ui-vi)/max(ui, work_v_eps)`。

输出未截断滑转率、诊断截断值和控制反馈 `kappa_fb`；按地速、轮面速度、原始信号有限性给出逐轮 `slip_valid`。此外计算滑转动力学的扭矩输入增益 `a_hat`，过小或无效时启用下限并标记 `a_floor_active`。

它回答“现在滑转多大、能不能可靠计算、扭矩对滑转的输入增益是多少”。`slip_valid` 不意味着已经进入 WORK，`a_floor_active` 的轮也不会被当作有效 SMC 控制轮。

#### 5.2 WorkSlip_Reference 固定目标参考轨迹

它已经存在，但目前只负责固定目标的平滑生成，不是自适应最优滑转率计算。

LAUNCH 期间参考跟随有效反馈；首次进入 BLEND 时重新对齐反馈，随后以时间常数和变化率限制逐渐靠近 `P.kappa_set`。PROTECT 冻结参考。输出 `kappa_ref` 和 `kappa_ref_dot`。

当前磁盘默认四轮固定目标均为 0.30。你说的“滑转率目标计算还没做”，准确地说，是在线/自适应目标算法尚未实现；固定参考平滑模块已经接入。

#### 5.3 WorkSlip_Disturbance 总扰动重构

采用近似模型 `kappa_dot=a*T+d`，对反馈滑转率离散差分，再扣除上一拍输入增益与上一拍最终命令的乘积：

`d_raw(k)=[kappa(k)-kappa(k-1)]/Ts-a(k-1)*T_applied(k-1)`。

对残差低通得到 `d_hat`，供 SMC 补偿。这里的 d 是滑转率变化率域的等效总扰动，单位 1/s，不是直接估计土壤附着系数、轮地力或农具阻力，也不是 ESO。模块内部保存上一拍增益，但不再额外延迟外部扭矩。

#### 5.4 WorkSlip_SMC 作业扭矩控制

比较 kappa_fb 与 kappa_ref，令 `e=kappa_fb-kappa_ref`，当前滑模面就是 `s=e`，通过边界层饱和函数缓和抖振：

`T_pref_raw=(kappa_ref_dot-d_hat-k*e-eta*sat(e/phi))/a_hat`。

输出非负作业偏好 `T_pref_work`。它是按动力学求出的扭矩偏好，不是简单把削扭量加到基础扭矩上；最终电机能力、总需求和变化率由外层处理。

仅在 BLEND/WORK、滑转有效、输入增益没有保护下限激活、参数合法时启用；其他情况返回非负基础需求，`smc_valid=false`。`T_max` 虽然是输入端口，当前本函数不以其逐轮钳位，真正能力限制在外层。

### 6. TCS_Handover 扭矩交接

这不是第二个滑转控制器，而是扭矩偏好选择/混合模块。

- LAUNCH：选择 `T_cmd_launch`。
- BLEND：进入该阶段时锁存上一拍真正下发的命令为 anchor，然后输出 `(1-alpha)*anchor+alpha*T_work`。
- WORK：选择有效作业偏好；SMC 无效的轮以 T_base 回退。
- PROTECT：输出零偏好。

注意混合起点是锁存命令，不是持续变化的起步分支输出，这样可减少切换入口突变。

### 7. TCS_TorqueConstraints 统一执行约束

把交接后的偏好投影到当前允许范围，输出驱动防滑子系统真正的 `T_cmd`。

共同约束包括逐轮非负、电机能力、上一拍命令上下变化率，以及 `sum(T_cmd)<=T0` 总需求预算。起步期间额外以 `T_cmd_launch` 作为逐轮安全上界；BLEND/WORK 则释放该起步上界。

WORK **不要求每轮 T_cmd<=T_base**，因此单轮可以超过原始基础份额，但四轮总量仍受真实 T0 和各轮能力限制。这与旧起步候选的上限逻辑不同。

当前保护实现为允许扭矩置零，安全约束必要时可覆盖普通变化率限制。不要用起步函数内部 `q_protect` 比例限扭代替最终保护行为。输出 `demand_unmet` 只表示预算未完全兑现，不一定代表控制故障。

### 8. WorkSlip_validate_params 参数检查函数

这是磁盘辅助函数，不是该副本内单独摆放的 MATLAB Function 方块。被 SMC、阶段监督和约束函数调用，检查惯量、半径、采样周期、滤波时间常数、SMC 增益及投影权重等。参数不合格会影响 SMC 有效性并触发监督保护。

## 五、旧模块为什么仍在，分别做什么

| 可见模块 | 功能 | 与新链关系 |
|---|---|---|
| MATLAB Function | 前轮 rpm 转轮面线速度，半径 0.834 m | 旧轮速处理；新链另取 rad/s 四轮向量 |
| MATLAB Function1 | 后轮 rpm 转轮面线速度，半径 0.94 m | 同上 |
| MATLAB Function3 | 根据轮速、制动、转角和横摆等生成旧估计车速 v_e | 当前新链的 vx 直接来自子系统输入，不由 v_e 驱动 |
| 滑转率计算 | 旧四轮滑转率计算，另输出旧 slip_valid | 与新 WorkSlip_State 的反馈/有效性不是同一信号 |
| Discrete Transfer Fcn 等 | 滤波旧滑转率，生成 lamda1…4 | 服务旧 PI 和历史记录 |
| Subsystem、Subsystem1、Subsystem2、Subsystem3 | 四轮旧 PI 补偿，输出 dT1…4 | 旧方案分支，增益按挡位等输入调度 |
| MATLAB Function2 | 对旧四轮 dT 做速度相关后处理，输出 dTfl…dTrr | 与新 T_cmd 为并行输出；高速时同轴采用绝对值较大补偿 |
| 转矩协调控制 | 另一份旧协调 Stateflow | 本层未见接入当前输出链的信号线，不能当作新增统一协调器 |

旧 `MATLAB Function2` 有一处阅读陷阱：前面的 `v<1.5` 清零后，紧接着独立的 `if v<10` 又会写回 dT，因此不能按第一段文字推断其低速必然输出零。此次仅说明代码实际含义，没有修改。

磁盘上现在存在 `WorkSlip_PI.m` 和 `WorkSlip_Select.m`，但对这个 1118 副本的全部相关内嵌脚本和连线核查，未发现它们作为模块接入。不能因为源码文件存在，就把它们画入这个副本的实际流程。这个副本保留的是旧 PI 链与新 SMC 链并列结构。

## 六、最容易混淆的信号和观察入口

| 信号 | 含义 |
|---|---|
| stage | 起步内部事件分类 |
| control_phase | 全过程实际控制阶段，0/1/2/3 |
| speed_valid | 旧起步 Chart 的速度有效判据 |
| WorkSlip slip_valid | 新作业状态的逐轮滑转率有效性 |
| smc_valid | 该轮该拍实际进行了有效 SMC 运算 |
| T_cmd_launch | 起步函数的候选输出 |
| T_pref_work | 作业 SMC 未经最终公共约束的偏好 |
| T_pref_blend | 交接/选择后的偏好 |
| T_cmd | 统一约束后的子系统输出 |
| T_applied_cmd_prev / T_feedback | 经过顶层分支选择、公共能力限制后，再延迟一拍的命令；不是传感器实测扭矩 |
| P.kappa_set | 固定目标，当前磁盘默认 0.30 |

读程序时推荐顺序：先看 ModeSupervisor 和 phase；再看 Handover 的选择；接着看 TorqueConstraints 的实际输出；然后回头按 LAUNCH 或 WORK 分别展开算法。Scope、EX_Record、ArrayVector、WC_G/WC_F、Goto/From 多数是观察或信号路由，不是额外控制律。`EX_` 前缀本身不能判断模块是否控制：例如 `EX_G_EX_T_pref_blend` 也承载主链信号，应以实际连线为准。

顶层保存的“扭矩接口” CurrentSetting=0，接在第 2 输入的是 Torque_TCS；另一输入是原 Memory 分支。上述全过程说明对应 TCS 被选中的执行路径，仿真前仍需确认顶层开关与实际 P。静态阅读只能说明保存版本的程序规则，不能据此认定某次运行已经正常进入 WORK 或验证通过。
