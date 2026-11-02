# 仓库整理验收 · 2026-11-02

## 已完成

- 分类迁移 100 个文件，迁移前后 SHA-256 一致；模型、MAT 样例、CPAR、文档与图片的二进制内容未改。清单见 `file-migration.csv`。
- 仓库候选体积约 18.6 MiB；单文件上限、本机配置/原始数据/生成物忽略规则、必需入口和源代码绝对盘符路径检查通过。
- Python 与 PowerShell 语法检查通过；4 个 SLX ZIP 完整性通过。
- MATLAB R2022b 初始化成功，`tractor_mu`、`tractor_mu2018`、`noslip_softsoil`、`launch_chart_check_valid` 均成功加载，主模型固定步长为 0.001 s。
- 历史 MAT 样例完成指标计算和速度、加速度图生成。样例缺少 `wheel_speed`、`wheel_torque`、`slip`、`launch_state`、`spin_flag`、`torque_limit`；分析返回的 `PASS` 只反映现有信号指标，不能视为控制器回归通过。
- 修正分析函数移除项目源目录的路径副作用：保留并恢复调用前 MATLAB 路径。
- 从 Git 候选清单建立无本机配置的干净导出，逐文件哈希通过；独立 MATLAB 进程确认初始化、参数读取与样例分析成功（`CLEAN_EXPORT_MATLAB_OK`）。这是干净文件副本验证，尚非真实 Git 克隆。

## 仿真限制

内存占位模型更新停留在 `SENSOR_STUB_READY` 后约 4 分钟未返回，已中止本次专用批处理进程；没有保存主模型，也没有留下验证进程。仅能确认模型加载，不能确认编译成功。验收日志位于本地忽略目录 `results/generated/`。

本机已找到 TruckSim 公共文档目录的现有 `simfile.sim`、展开参数文件与 4 输入/34 输出接口；配置仅保留在忽略的 `local_paths.m`。初次 10 ms 联合仿真尝试失败于 `Simulink:Parameters:InvParamSetting`。修正分析路径副作用后的批次因前置编译检查停滞，未再次到达联合仿真步骤；完整联合仿真未通过验收。后续可在独立进程单独调用 `verify_cosimulation(cfg)` 排查，不应把本次整理基线当作运行基线。

## 尚未完成的 Git 发布

当前原有 Git 分支仍为无提交的 `master`。`.git` 被沙箱设为只读；普通暂存报权限不足，申请写入授权时自动审批服务返回 503，因此未创建索引、提交、标签、`main` 或 `dev`。

打开 GitHub 新建仓库页面也被同一自动审批服务 503 阻断，页面未打开。尚未创建 GitHub 私有仓库、配置远程、推送或设置分支保护。没有绕过审批，也没有替换现有 `.git`。

用户已选择自行完成最后的 Git 提交与 GitHub 推送。请运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/finish_repository_setup.ps1`，建立初始提交、`v0.1-baseline`、`dev`，并做真实本地克隆验证。远程创建和推送见 `github-setup.md`。
