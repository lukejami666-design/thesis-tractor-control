# 第二章与第三章论文写作材料包

论文：**分布式电驱动农机动力性与稳定性协调控制**。整理日期：2026-11-18。

本目录可单独下载到另一台设备，用于撰写第二章动力学建模和第三章防滑控制的原理、模型与算法部分。包含正式章节、写作指南、主要公式、原始参数、模型接口、保存副本内嵌源码、Stateflow、原理草稿及六篇本地文献。无需访问原电脑D盘或安装MATLAB即可开始阅读和写作。

## 从哪里开始

1. 阅读[正式章节目录](outline.md)和[版本边界](VERSION.md)，题目与章节不另行重构。
2. 写第二章：从[建模写作指南](chapter02/writing-guide.md)进入，使用[研究对象与参数](chapter02/vehicle-parameters.md)、[信号字典](chapter02/model-signal-dictionary.md)和[轮地文献](references/README.md)。
3. 写第三章：从[控制写作指南](chapter03/writing-guide.md)进入，再读[全过程说明](chapter03/control-framework.md)、[固定目标SMC](chapter03/fixed-target-smc.md)及[起步Stateflow](chapter03/launch-stateflow.md)。
4. 需要核对某条判据、公式或切换条件时，看`chapter03/source/`中的保存副本内嵌函数与XML；参数默认值见`chapter03/parameters/`。
5. 引文从[文献说明](references/README.md)、[阅读笔记](references/core-paper-notes.md)及[已核验BibTeX](references/references.bib)开始，按PDF核对原句、公式和适用条件。

## 目录说明

```text
manuscript/
  README.md                 写作入口
  outline.md                中期报告正式第二、三章目录
  VERSION.md                保存副本、磁盘参数及后续版本边界
  chapter02/
    writing-guide.md        动力学公式与逐节写作入口
    vehicle-parameters.md   中期报告整车与电驱参数原表
    model-signal-dictionary.md
    platform/              TruckSim数学、轮胎、传动系统说明
    optional/              轮端力、负载阻力估计Word草稿
  chapter03/
    writing-guide.md        滑转动力学、残差估计、SMC、交接与投影
    control-framework.md   保存副本实际运行流程与模块说明
    fixed-target-smc.md    SMC接口与控制律说明
    launch-stateflow.md    起步状态机原始标签
    source/                九个内嵌函数、状态机XML及模型身份
    parameters/            磁盘默认参数及合法性校验
    history/               未全部采用的SMC候选设计Word记录
  references/
    README.md              文献—小节映射与核验状态
    core-paper-notes.md
    references.bib
    pdf/                   六篇第二、三章相关文献
  manifest.json             来源、角色与文件SHA256
```

## 给后续写作者与AI

先读outline、VERSION和两章writing-guide，按正式小节逐章撰写。将“已实现算法”“名义模型下的分析”“待完成方案”分开表述。当前作业控制为固定目标SMC；目标寻优尚未实现，残差低通估计不是ESO。保存副本与同日后续PI/SMC共链版本不能混用。所有WorkSlip中文注释及永久保留声明必须保留。

第二章的坐标、符号、量纲、惯量和轮端扭矩口径先统一，再推导第三章。引用原始文献，不引用AI历史笔记作为理论证据；模型参数冲突、未知误差界、未证实的稳定性条件应标“待核实”，不能补造。3.4及所有实验/仿真性能内容暂留空。

本目录是论文写作包，不包含联合仿真的完整运行环境；没有上传结果数据或第四章协调分配材料。Word原稿供查原生公式，Markdown指南便于GitHub和AI直接阅读。原始工程文件保持原位置，本包是有来源记录的快照。
