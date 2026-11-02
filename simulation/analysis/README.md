# 起步防滑仿真分析工具

第一阶段采用人工确认的半自动流程：联合仿真结束后保存 MAT 文件，再调用 `analyze_launch_run` 读取信号、计算指标、保存波形并生成参数建议。分析脚本不会启动 TruckSim/Simulink，也不会自动修改模型或参数。

## 最小用法

将 `simulation/analysis` 加入 MATLAB 路径后执行：

```matlab
addpath('scripts'); % 从仓库根目录开始
project = setup_project();
report = analyze_launch_run(fullfile(project.simulationRoot,'data','sample','stage6_workspace.mat'));
```

结果默认写入 `results/generated/analysis/<数据文件名>/`，包括 `metrics.mat`、`metrics.csv`、`metrics.md` 和可用信号的 PNG 图。缺失信号保持为空，并会出现在 `report.missingSignals` 和 Markdown 报告中。

若 MAT 文件中的信号名称不同，可修改 `launch_analysis_config.m` 中的 `cfg.signalMap`，或先取得配置后传入：

```matlab
cfg = launch_analysis_config();
cfg.signalMap.slip = {'my_slip_signal'};
report = analyze_launch_run('run_001.mat','Config',cfg);
```

## 参数建议与确认

建议只提供少量参数调整方向。人工检查 `report.suggestions` 后，显式确认才会写入参数文件：

```matlab
apply_launch_params(report.suggestions, ...
    fullfile(project.sourceRoot,'launch_tcs_params.m'), true, 'RunId', report.runId);
```

写入前会生成带时间戳的 `.bak_yyyymmdd_HHMMSS.m` 备份，并追加 `launch_tcs_params_changes.log`。建议每轮只确认 1--3 个参数，再运行下一次联合仿真。

## 当前约定

- 四轮顺序为 `FL, FR, RL, RR`。
- `wheel_speed` 默认按轮端线速度处理；若 MAT 中是角速度，设置 `cfg.wheelSpeedSource = 'angular'`，并确认 `cfg.wheelRadius`。
- TruckSim 的 `kappa` 只作为参考；优先使用控制器计算的 `lambda/lamda1..4`。
- 未实现自动调用 `sim`、TruckSim 许可检查或自动迭代闭环。
