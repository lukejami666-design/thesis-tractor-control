# 仿真与复现

## 环境和模型

- MATLAB/Simulink R2022b，使用 Stateflow；完整工具箱依赖尚需逐项确认。
- TruckSim 2019（本机目录标识为 2019.0），固定步长 `0.001 s`。
- `models/tractor_mu.slx`：现有主模型，迁移时不改二进制内容。
- `tractor_mu2018.slx`：历史参考，文件名不代表已验证的 MATLAB 兼容性。
- `noslip_softsoil.slx`：独立对照模型；`launch_chart_check_valid.slx`：历史小型检查模型。
- 原有修复版本留在 `archive/`；该目录默认不入 Git，新克隆不会包含它们。

## 初始化

从仓库根目录执行：

```matlab
addpath('scripts');
cfg = setup_project();
open_system(fullfile(cfg.modelRoot, 'tractor_mu.slx'));
```

初始化注入基础工作区的 `P` 来源于 `src/launch_tcs_params.m`，协同博弈参数来源于 `src/value_parameter.m`；不覆盖模型内部工作区。`Total_T3D.m` 会清理工作区并绘图，只手动执行。

复制 `config/local_paths.example.m` 为 `config/local_paths.m`，配置本机 `cfg.truckSimRoot` 和完整 TruckSim 运行导出的 `cfg.simfile`，或通过环境变量 `TRUCKSIM_ROOT` 指定安装目录。`local_paths.m` 不提交。初始化会添加求解器路径，但不会自动改写 S-Function 的运行文件设置。

## 联合仿真

现有 `Tractor.cpar`、`Tractor1.cpar` 是参数包，截图说明见 `config/联合仿真配置`。它们不等于完整、可直接运行的 TruckSim 数据库；原模型记录了相对运行文件 `simfile.sim`。本机公共文档目录发现了现有 TruckSim 运行数据，已在忽略的本机配置中引用；这些机器专属数据不会随仓库分发。

在 TruckSim 中导入所需参数，准备车辆、土壤/道路、工况和输入输出定义，导出完整运行目录。在本机配置中记录其 `simfile.sim` 路径。核对 S-Function 实际设置和输入输出顺序后，在该运行目录进行联合仿真。不要把许可证、安装包、求解器 DLL 或机器专属运行文件提交。

```matlab
cfg = setup_project();
assert(isfile(cfg.simfile), '先配置完整 TruckSim 运行导出');
previous = pwd;
cleanup = onCleanup(@() cd(previous));
cd(fileparts(cfg.simfile));
% 在模型界面将 TruckSim S-Function 的运行文件指向 cfg.simfile。
% 先核对路径与接口，再执行短时仿真；完成后记录工况及提交哈希。
```

## 无 TruckSim 时的检查与离线分析

MAT 样例可直接分析，不启动联合仿真：

```matlab
cfg = setup_project();
report = analyze_launch_run(fullfile(cfg.simulationRoot,'data','sample','stage6_workspace.mat'));
```

输出默认进入 `results/generated/analysis/stage6_workspace`。缺失信号由 `report.missingSignals` 列出，历史样例不被解释为当前模型的完整回归基准，也不据此自动修改参数。

`diagnose_launch_model` 在独立 MATLAB 进程中用内存中的传感器占位块替代 TruckSim，并尝试更新模型；不保存模型。它只检查部分维度与编译关系，不能代表 TruckSim 联合仿真成功。若主模型已打开，此检查拒绝运行以保护未保存编辑。

完整验收可从仓库根目录执行 `run('scripts/verify_project.m')`；检查结果与限制见 `docs/validation.md`。
