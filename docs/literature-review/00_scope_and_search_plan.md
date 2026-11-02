# 分布式四驱大型农机扭矩协调分配策略 文献检索范围与计划

检索日期：2026-10-10。研究对象为可独立调节四轮扭矩的大型农机，聚焦低速起步防滑、作业过程滑移控制、运动意图横摆需求，以及单轮防滑约束下的四轮协调分配。

## 证据边界

- 直接农机证据优先；四轮独立驱动电动车文献仅作为“可迁移方法”，不直接外推到软土农机。
- 已读全文仅指本地 PDF 已解析并人工阅读摘要、方法或试验相关页面；其余条目只能支持元数据层面的候选定位。
- 本轮未能访问 Crossref、IEEE Xplore、ScienceDirect、SpringerLink、CNKI、Web of Science 或 Scopus 的在线页面。`01_search_log.csv` 记录了原因；因此不声称完成这些平台的在线检索或引用追踪。

## 优先检索式（待网络恢复后执行）

1. `("traction control" OR "anti-slip control") AND (launch OR starting OR "low speed" OR "near zero speed")`
2. `("traction control" OR "slip control") AND ("yaw control" OR "torque vectoring") AND (coordination OR "control allocation")`
3. `("electric tractor" OR "agricultural vehicle") AND ("adaptive traction control" OR "optimal slip")`
4. `(GNSS OR GPS OR IMU) AND (tractor OR "agricultural vehicle") AND "velocity estimation"`

## 筛选规则

优先保留：有真实车辆/田间试验；明确独立地速或其缺失；明确扭矩边界、饱和或不可行处理；能区分起步与正常滑移控制。排除：只有效率地图、未涉及低速防滑或协调冲突的论文；与大型轮式农机无可说明迁移关系的机器人论文。

## 未核实候选（不计入已核验书目）

本地还发现 9 篇候选：`Modelling and Analysis of an Electronic Differential-Based Traction Control System for Distributed Drive Electric Vehicle`、`Modelling and Simulation of Torque Vectoring in Electric Vehicles for Enhanced Stability`、`Development of a Variable Torque Distribution for Fully Electric and Hybrid Heavy-duty Trucks based on a Modular Simulation Methodology`、3 篇以能效为主的扭矩分配论文，以及陈浩、武曦、王云飞的 3 篇中文学位论文。它们只完成文件名级筛选，未纳入引用或论证。
