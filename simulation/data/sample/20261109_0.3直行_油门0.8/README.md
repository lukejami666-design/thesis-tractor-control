# 2026-11-09 基线运行

## 工况

- 文件记录名称：`基线-0.3直行-油门0.8`
- 仿真时长：20 s
- 采样周期：0.001 s，共 20,001 个采样点
- 主要工况：直行、油门 0.8；文件名中的 `0.3` 物理含义需结合 TruckSim 运行配置解释
- 轮序：FL、FR、RL、RR
- 模型：`simulation/models/tractor_mu1109.slx`
- 基线代码：`simulation/src/baselines/baseline_torque_distribution.m`
- 参数：`simulation/src/baselines/P_runtime_20261109.m`

## 文件

- `baseline-0.3-straight-throttle-0.8.mat`：20 s 基线运行数据
- `P_runtime_20261109.mat`：运行时 `P` 结构体快照

动态信号按数组保存：标量为 N×1，四轮量为 N×4。数据包含 `tout`、`vx`、`v_wheel`、`lamda`、`TMax`、`T_base`、`T_lim_out`、四轮实际扭矩、`T0`、`Throttle`、`Mz`、`k` 和状态/诊断信号。

## 版本关联

本次运行由工作记录确认完成；原始日志未记录当时的 Git 提交哈希和墙钟耗时。模型文件和数据文件的 SHA-256 由迁移清单记录。后续复现实验需补充 TruckSim `simfile.sim` 运行目录、完整参数配置和实际提交哈希。
