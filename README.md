# 软土分布式驱动农机扭矩控制 · 毕设

本仓库管理 Simulink 模型、控制器源代码、TruckSim 参数导出、小型样例数据，以及原创研究笔记和论文源稿。参考文献、旧快照和批量输出保留在本地，未使用 Git LFS。

当前文件整理已完成；初始提交、分支、标签和 GitHub 远程发布由你执行。先运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/finish_repository_setup.ps1`，再按 [GitHub 设置](docs/github-setup.md) 推送。详细测试状态见 [验收记录](docs/validation.md)。

## 快速开始

MATLAB R2022b，在仓库根目录执行：

```matlab
addpath('scripts');
cfg = setup_project();
open_system(fullfile(cfg.modelRoot, 'tractor_mu.slx'));
report = analyze_launch_run(fullfile(cfg.simulationRoot, 'data', 'sample', 'stage6_workspace.mat'));
```

`setup_project` 初始化路径与 `P`、`k_f`、`k_r`、`w_1`、`w_2`、`w_3`，不运行仿真、不修改模型、不执行维护脚本。联合仿真需要 TruckSim 2019 的本机许可、求解器及完整的运行数据依赖，详见 [仿真说明](simulation/README.md)。

## 文件入口

| 目录 | 内容 |
|---|---|
| `simulation/models` | 主模型、参考模型和小型检查模型 |
| `simulation/src` | 参数、控制器代码和诊断工具 |
| `simulation/src/maintenance` | 历史修复工具，须审阅后手动执行 |
| `simulation/config` | TruckSim CPAR 导出、配置截图和本机配置模板 |
| `simulation/data/sample` | 小型历史数据样例 |
| `simulation/data/soil` | 原有软土数据输入，来源说明待补充 |
| `simulation/analysis` | 离线指标分析和绘图 |
| `docs` | 信号字典、文献研究笔记、重要论文源稿 |
| `results/figures`、`results/tables` | 人工选定的结果 |
| `results/generated` | 自动生成的缓存、日志、分析和验证输出，忽略 |

## Git 工作方式

- `main` 保存已检查的集成版本；本次 `v0.1-baseline` 是文件管理基线，仿真状态以 [验收记录](docs/validation.md) 为准。
- `dev` 用于日常修改；功能使用 `feature/...`，修复使用 `fix/...`。
- 一个完整修改提交一次，模型与对应参数、说明一起提交；先保存 MATLAB 中的文件，再查看 `git status`。
- 使用 Simulink 的模型比较工具检查 `.slx` 变化；二进制模型冲突需人工选择或逐块合并，不做文本合并。
- 尽量避免同时修改同一模型；`LaunchTCS_*_code.m` 是独立源文件，单独修改它不会自动同步模型内嵌代码。

```powershell
git switch dev
# 修改并保存文件后
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/check_repository.ps1
git add simulation docs results scripts README.md .gitignore .gitattributes
git diff --cached --stat
git commit -m "sim: update launch torque controller"
# 在完成检查并准备集成时
git switch main
git merge --ff-only dev
```

提交前始终审阅暂存清单。根目录采用白名单：新增顶层目录默认忽略，按需修改 `.gitignore`。不要对全部 `.mat`、`.csv` 或 `.pdf` 做扩展名级别忽略，这些格式也可能是必要输入或精选结果。

## 存储与备份

GitHub 普通 Git 单文件限制为 100 MiB；本仓库检查脚本拒绝达到该大小的文件。模型虽小，频繁保存仍会增加二进制历史，避免仅因重新保存而提交。大型数据存放在 `simulation/data/raw` 或外部备份，结果记录提交哈希、工况、参数、数据路径和 SHA-256。

每周将忽略的原始数据、文献和 `simulation/archive` 备份至另一硬盘或网盘。GitHub 只备份已提交并推送的文件；本地忽略文件不会随克隆恢复。首次迁移位置见 [迁移清单](docs/file-migration.csv)，批量修改前的维护脚本另存于本地 `.local/original-sources`。

远程发布步骤见 [GitHub 设置](docs/github-setup.md)。
