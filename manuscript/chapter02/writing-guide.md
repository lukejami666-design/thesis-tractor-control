# 第二章写作指南与公式起点

这是根据现有材料整理的写作辅助，不是已经定稿的论文正文。先读[正式目录](../outline.md)、[研究对象参数](vehicle-parameters.md)、[信号字典](model-signal-dictionary.md)和[版本边界](../VERSION.md)。

## 2.1 研究对象与典型工况

介绍重型、四轮分布式电驱、前轮转向和农机牵引任务。用vehicle-parameters.md中的原始参数表描述研究对象，再对照控制参数中的轮径、轮心坐标与采样时间。典型工况可从静止起步、重载未起动、局部/多轮空转、速度建立和稳定作业组织；这里只说明控制需求，不填仿真数据。

## 2.2.1 整车三自由度模型

建议统一车体坐标：x向前、y向左、z向上，r为逆时针横摆角速度；轮序FL/FR/RL/RR。若采用其他约定，要同步修改全部力矩符号。

对第i轮，轮胎坐标力为F_xi、F_yi，车轮转角为δ_i，轮心坐标为(x_i,y_i)：

$$F_{Xi}=F_{xi}\cos\delta_i-F_{yi}\sin\delta_i,\quad F_{Yi}=F_{xi}\sin\delta_i+F_{yi}\cos\delta_i.$$

平面三自由度方程的基本形式为：

$$m(\dot v_x-rv_y)=\sum_iF_{Xi}-F_{res,x},$$
$$m(\dot v_y+rv_x)=\sum_iF_{Yi}+F_{ext,y},$$
$$I_z\dot r=\sum_i(x_iF_{Yi}-y_iF_{Xi})+M_{ext,z}.$$

需交代平面、刚体、轮胎力集中于接地点等假设。坡度、农具牵引及滚阻怎样分组应避免重复计算；这里没有默认采用小侧偏线性轮胎模型，也没有给出尚未核定的侧偏刚度和横摆惯量。

## 2.2.2 四轮旋转动力学与轮端扭矩

在一致的轮端口径下：

$$J_i\dot\omega_i=T_i-R_iF_{xi}-T_{loss,i}.$$

T_loss包含本模型中单独计入的旋转损失。若轮胎/传动模型已计算某项损失，不应再次叠加。电机轴端额定/峰值扭矩不等于T_i；传动比、效率与等效惯量需要明确。平台资料见[Powertrain_system.txt](platform/Powertrain_system.txt)和[Tire_Models.txt](platform/Tire_Models.txt)。

## 2.3.1 滑移定义与低速局限

各轮滚动方向地速：

$$v_i=(v_x-r y_i)\cos\delta_i+(v_y+r x_i)\sin\delta_i.$$

当前前进控制实现把负向轮向地速截为零，且轮速非负化后u_i=R_i max(ω_i,0)。反馈计算为：

$$\kappa_i=\frac{u_i-v_i}{\max(u_i,v_\varepsilon)}.$$

实际计算包含速度滤波、原始滑转率诊断截断和有效性判断；见[WorkSlip_State.m](../chapter03/source/WorkSlip_State.m)。分母保护防止数值异常，不代表零速附近可可靠闭环；小地速时仍应转用起步证据链。

## 2.3.2 软土轮地作用与模型适用性

从[轮胎—土壤综述](../references/pdf/tire-soil-review.pdf)组织沉陷、剪切、滑转和牵引力关系，并讨论土壤、轮胎、载荷及重复通过的影响。若引入Bekker/Wong类关系，应从原文核对变量、量纲、参数辨识和适用假设。不能把TruckSim常规低附着路面直接描述成已标定的可变形软土模型。

## 2.4 平台建模方法

说明TruckSim负责被控车辆动力学、Simulink负责控制与接口、四路轮端扭矩输入和状态输出；见[数学模型资料](platform/TruckSim_Math_Models.txt)及信号字典。只写模型结构、参数和接口方法，不写3.4的结果。中期报告与后续运行环境版本存在差别，应注明本章采用的对象和软件版本来源。

## 可选材料

[纵向力估计](optional/轮端纵向力估计.docx)与[负载阻力估计](optional/负载阻力估计.docx)提供额外观测器草稿，只有确认采用才展开。它们不是当前WorkSlip的d_hat模块，旧章节编号不沿用。
