# 历史维护脚本

这里保留过去调试、修改 Stateflow 和修补 SLX 的一次性工具。`setup_project` 不将本目录加入路径，也不会执行它们。

这些脚本可能保存或覆盖主模型、创建候选文件、关闭模型，部分还会调用 `exit` 结束 MATLAB。执行前必须审阅并提交当前改动，建议在独立克隆及独立 MATLAB 进程运行。旧脚本依赖的修复模型通常位于忽略的 `simulation/archive`，新克隆需从本地备份恢复后才能运行；`normalize_launch_chart.py` 还依赖本地 `_slx_inspect/after_wire` 的历史 XML。

维护脚本中的文件路径已相对化；未重新执行历史修复流程，也不保证适用于当前主模型。不要把它们作为常规启动或测试入口。常规编译检查使用 `simulation/src/diagnose_launch_model.m`。
