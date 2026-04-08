# CPPS Delay Paper Draft (Bilingual)

> Version: v0.1  
> Location: `D:\MATLAB\R2024a\bin\2\CPPS_delay_paper_bilingual_draft.md`  
> Purpose: Store manuscript text in **English + Chinese** with clean structure and citation placeholders.

---

## Recommended Workflow

1. Write and revise in this Markdown file (`.md`) for clean structure and easy versioning.
2. Keep citation placeholders in the form `[Lit-XXX]` during drafting.
3. Replace placeholders with real references later (EndNote/Zotero/Word/Pandoc workflow).
4. Export to `.docx` only near submission stage.

---

## Citation Placeholder Convention

- Overview/background: `[Lit-CPPS-Overview-1]`
- Interdependence/cascading: `[Lit-Interdependence-1]`
- Delay decomposition/control effect: `[Lit-Delay-Control-1]`
- Metrics/attribution: `[Lit-R1R3-1]`, `[Lit-Attribution-1]`
- Reference anchor paper: `[Lit-RefPaper]`

---

# I. Introduction

## I.1 English Draft

The ongoing digitalization of power infrastructure is transforming conventional grids into cyber-physical power systems (CPPS), where physical energy delivery and cyber control services are tightly interdependent [Lit-CPPS-Overview-1, Lit-CPPS-Overview-2]. This integration improves observability and dispatch flexibility in normal operation, but it also creates a bidirectional failure channel: disturbances in the physical layer can impair cyber coordination, while cyber-side degradation can in turn destabilize physical operation [Lit-Interdependence-1, Lit-Interdependence-2]. As a result, resilience analysis in CPPS must move beyond purely topological robustness and explicitly account for control-loop timing quality [Lit-Resilience-Framework-1].

A large body of literature has modeled cascading failures in coupled power-communication systems through interdependency structures, flow-based propagation rules, and vulnerability-oriented attack analyses [Lit-Cascade-Model-1, Lit-Cascade-Model-2, Lit-Attack-Strategy-1]. These studies established important foundations for understanding how failure spreads across layers. However, in many frameworks, communication delay is treated primarily as an observed consequence (e.g., delay increment after disruption) rather than a causal variable that directly reshapes generator response and post-cascade control quality [Lit-Delay-Indicator-1, Lit-Delay-Indicator-2]. Consequently, existing analyses often answer *whether* delay is harmful, but not *which delay components* drive the damage mechanism and *how* that mechanism quantitatively propagates to robustness metrics [Lit-Gap-Mechanism-1].

This gap is also reflected in representative CPPS cascading studies that acknowledge the importance of delay but leave delay-to-control-effect modeling for future work [Lit-RefPaper]. From an engineering perspective, that missing link is crucial: stale measurements and lagged command execution can create temporal mismatch in closed-loop control, causing actual generator outputs to deviate from intended references during cascading evolution [Lit-Delay-Control-1, Lit-Delay-Control-2]. Without an explicit mapping from communication delay to generation behavior, it is difficult to produce actionable mitigation insights for operators.

To address this issue, we develop a delay-aware robustness assessment pipeline that links communication-path timing, control effectiveness, generator-level deviation, and system-level survivability within one consistent evaluation protocol. Following a bidirectional delay decomposition, path delay is separated into serial, propagation, and service components with explicit role asymmetry between control-center and non-control nodes [Lit-Delay-Decomposition-1]. These timing factors are mapped to power-side behavior through measurement delay $\tau_m$ and execution delay $\tau_e$, and the delay-affected generator output is represented as:

$$
P_i^{\text{actual}} = P_i^{\text{ref}}(1-k_m\tau_{m,i})(1-k_e\tau_{e,i}).
$$

This mechanism turns delay from a descriptive symptom into an explicit driver in robustness evaluation [Lit-Delay-to-Control-Model-1].

On top of this model, we implement a unified graded-delay scenario design (**no_delay, light, baseline, medium, heavy**) under a consistent averaging protocol, so that cross-scenario comparisons are methodologically coherent rather than statistically mixed [Lit-Experimental-Protocol-1]. We jointly evaluate two complementary robustness dimensions: $R_1$, which captures retained load supply capability under delay-adjusted generation, and $R_3$, which quantifies normalized generator dispatch deviation from delay-free references [Lit-Metric-R1R3-1]. To move beyond a simple “larger delay, larger damage” statement, we further introduce a mechanism-attribution layer that connects outcome deterioration with interpretable factors, including $\tau_m$, $\tau_e$, composite efficiency $\eta$, path-length characteristics, and generator reachability ratio [Lit-Attribution-1]. In addition, a generator-level sensitivity ranking is used to identify delay-vulnerable units for targeted operational prioritization [Lit-Generator-Criticality-1].

The main contributions of this work are summarized as follows:

1. **Delay-to-control-effect modeling in CPPS cascading analysis.** We explicitly map bidirectional communication delay to generator active-power realization through measurement and execution channels.
2. **A unified and comparable robustness evaluation protocol.** We establish a graded-delay scenario framework with consistent averaging and jointly assess system-level ($R_1$) and generator-level ($R_3$) robustness.
3. **Mechanism attribution for delay-induced degradation.** We decompose robustness deterioration into interpretable delay factors rather than reporting only aggregate performance decline.
4. **Actionable vulnerability localization at generator level.** We provide a sensitivity-based ranking that supports practical prioritization of delay-aware protection and control resources.

The remainder of this paper is organized as follows. Section II presents the delay-aware CPPS modeling basis and metric definitions. Section III describes the experimental protocol and implementation details. Section IV reports graded-scenario robustness results. Section V provides mechanism-attribution analysis. Section VI presents generator-level sensitivity findings and operational implications. Section VII discusses limitations and future extensions. Section VIII concludes the paper.

## I.2 中文翻译

随着电力基础设施持续数字化，传统电网正逐步演化为信息物理电力系统（CPPS），其中物理层负责能量传输，信息层负责感知、协同与控制，两者紧密耦合并形成闭环运行架构【Lit-CPPS-Overview-1, Lit-CPPS-Overview-2】。这种融合在正常工况下提升了可观测性和调度灵活性，但也引入了双向失效通道：物理层扰动会削弱信息层协调能力，而信息层退化又会反向影响物理层稳定性【Lit-Interdependence-1, Lit-Interdependence-2】。因此，CPPS 的韧性分析不能仅停留在拓扑鲁棒性层面，还必须显式刻画控制闭环中的时序质量【Lit-Resilience-Framework-1】。

大量已有研究通过互依结构、流驱动传播规则以及面向脆弱性的攻击分析来建模电力—通信耦合系统中的级联失效【Lit-Cascade-Model-1, Lit-Cascade-Model-2, Lit-Attack-Strategy-1】。这些工作为理解跨层失效传播奠定了重要基础。然而，在许多框架中，通信时延主要被视为一种“结果型观测量”（例如故障后的时延增量），而非能够直接重塑机组响应与级联后控制质量的“因果变量”【Lit-Delay-Indicator-1, Lit-Delay-Indicator-2】。因此，现有分析往往能回答“时延是否有害”，却难以回答“究竟是哪类时延分量在驱动损害机制”，以及“这种机制如何定量传导到鲁棒性指标”【Lit-Gap-Mechanism-1】。

这一缺口在代表性 CPPS 级联研究中同样存在：相关工作明确指出时延的重要性，但将“时延到控制效果”的建模留作未来工作【Lit-RefPaper】。从工程角度看，这一缺失非常关键：测量信息陈旧与控制命令滞后会造成闭环控制中的时间失配，使级联过程中机组实际出力偏离目标参考值【Lit-Delay-Control-1, Lit-Delay-Control-2】。如果缺乏从通信时延到发电行为的显式映射，就很难形成可执行的运行缓解建议。

为解决上述问题，本文构建了一套时延感知的鲁棒性评估链路，将通信路径时序、控制有效性、机组层偏差与系统层生存能力纳入统一评估框架。遵循双向时延分解思想，本文区分上行与下行路径，并对串行时延、传播时延、服务时延进行分项建模，同时考虑控制中心与非控制节点的角色差异【Lit-Delay-Decomposition-1】。进一步地，我们通过测量时延 $\tau_m$ 与执行时延 $\tau_e$ 将通信侧时序映射到电力侧行为，对第 $i$ 台机组的时延作用后出力建模为：

$$
P_i^{\text{actual}} = P_i^{\text{ref}}(1-k_m\tau_{m,i})(1-k_e\tau_{e,i}).
$$

该建模使时延从“描述性症状”转化为鲁棒性评估中的显式驱动因素【Lit-Delay-to-Control-Model-1】。

在此基础上，本文采用统一的分级时延场景设计（**no_delay, light, baseline, medium, heavy**），并在一致统计口径下进行场景比较，从方法上避免“统计口径混杂”带来的结论偏差【Lit-Experimental-Protocol-1】。我们联合评估两类互补指标：$R_1$ 用于刻画时延折减后系统负荷保持能力，$R_3$ 用于刻画存活机组相对于无时延参考出力的归一化偏差【Lit-Metric-R1R3-1】。为避免只得到“时延越大危害越大”这一低信息量结论，本文进一步引入机制归因层，将性能恶化分解为可解释因素，包括 $\tau_m$、$\tau_e$、综合效率 $\eta$、路径长度特征以及机组可达率【Lit-Attribution-1】。此外，本文在机组层面构建敏感性排序，以识别时延脆弱机组并支撑有针对性的运行优先级配置【Lit-Generator-Criticality-1】。

本文的主要贡献如下：

1. **提出 CPPS 级联场景下的时延—控制效果映射模型。** 通过测量与执行双通道，将双向通信时延显式映射到机组有功出力实现过程。
2. **构建统一且可比的鲁棒性评估协议。** 在分级时延场景下以一致统计口径联合评估系统层（$R_1$）与机组层（$R_3$）鲁棒性。
3. **提出时延致损机制归因框架。** 将鲁棒性退化分解为可解释时延因子，而非仅报告总体性能下降。
4. **实现机组级可行动脆弱性定位。** 提供基于敏感性的机组排序，为时延感知保护与控制资源配置提供依据。

本文后续结构安排如下：第二节给出时延感知 CPPS 建模基础与指标定义；第三节介绍实验协议与实现细节；第四节报告分级场景鲁棒性结果；第五节进行机制归因分析；第六节给出机组敏感性结果与运行启示；第七节讨论局限与扩展方向；第八节总结全文。

---

# II. Delay-Aware CPPS Modeling and Implemented Metrics

## II.1 English Draft

### A. System Context and Layer Coupling

We consider a cyber-physical power system (CPPS) consisting of a physical power layer and a communication-control layer coupled through node-level associations. The physical layer governs generation-load balance and topology-constrained power transfer, while the cyber layer provides measurement collection, command computation, and command delivery. Under cascading disturbances, failures in either layer may alter both physical connectivity and cyber routing conditions, which in turn affects control effectiveness in a closed-loop manner [Lit-CPPS-Model-1, Lit-Interdependence-1].

Let $G_P=(V_P,E_P)$ denote the physical network and $G_C=(V_C,E_C)$ denote the cyber network. A coupling matrix $A_{pc}$ maps power buses to cyber nodes, and control centers (CC) are a designated subset of cyber nodes. This formulation provides the structural basis for computing path-dependent delay and generator-level control realization.

### B. Bidirectional Delay Decomposition

To preserve physical interpretability, communication delay is modeled directionally: uplink (non-CC $\rightarrow$ CC) and downlink (CC $\rightarrow$ non-CC) are distinguished [Lit-Delay-Decomposition-1]. For a directed hop $(u,v)$, one-way delay is decomposed as

$$
T_{u\rightarrow v}=T_{\text{serial}}(u,v)+T_{\text{prop}}(u,v)+T_{\text{service}}(u\rightarrow v).
$$

Serial and propagation components are represented by

$$
T_{\text{serial}}(u,v)=\frac{P_s}{R_{u,v}},\qquad
T_{\text{prop}}(u,v)=\frac{d_{u,v}}{V},
$$

where $P_s$ is packet size, $R_{u,v}$ is link rate, $d_{u,v}$ is distance, and $V$ is propagation speed.

For a multi-hop path $\pi$, total delay equals hop-wise link-delay accumulation plus endpoint processing and intermediate forwarding terms. Service-delay parameters are role-dependent (CC vs. non-CC), which allows the model to capture asymmetric processing behavior in uplink/downlink control loops [Lit-Service-Heterogeneity-1].

### C. Delay-to-Control Mapping for Surviving Generators

The implemented framework maps cyber timing to power response through measurement delay $\tau_m$ and execution delay $\tau_e$ for each surviving participating generator $i$. Measurement delay combines field-to-cyber sensing/interface delay and cyber uplink delay; execution delay combines cyber downlink delay and command execution delay at the field side [Lit-Delay-Control-Bridge-1].

Given delay sensitivities $k_m$ and $k_e$, we define

$$
f_{m,i}=1-k_m\tau_{m,i},\qquad
f_{e,i}=1-k_e\tau_{e,i},\qquad
\eta_i=f_{m,i}f_{e,i},
$$

and compute delay-affected active power as

$$
P_i^{\text{actual}}=P_i^{\text{ref}}\eta_i
= P_i^{\text{ref}}(1-k_m\tau_{m,i})(1-k_e\tau_{e,i}).
$$

This conversion is explicitly implemented for generators that remain online and survive cascading evolution, thereby making delay a direct driver of post-cascade regulation quality rather than a secondary observation [Lit-Delay-to-Power-Model-1].

### D. Implemented Robustness Metrics: $R_1$ and $R_3$

#### 1) Delay-Adjusted Load Retention $R_1$

Let $L_{\text{initial}}$ be the initial total load and $L_{\text{surviving}}$ the post-cascade surviving load before delay adjustment. Define a delay penalty factor

$$
\phi=\min\!\left(1,\frac{\sum_i P_i^{\text{actual}}}{\sum_i P_i^{\text{ref}}}\right),
$$

then

$$
L_{\text{final}}=L_{\text{surviving}}\phi,\qquad
R_1=\frac{L_{\text{final}}}{L_{\text{initial}}}.
$$

This metric captures the effective supply capability after accounting for delay-induced generation realization loss [Lit-R1-DelayAware-1].

#### 2) Delay-Induced Generator Deviation $R_3$

For $N$ surviving participating generators,

$$
R_3=\sqrt{\frac{1}{N}\sum_{i=1}^{N}
\left(\frac{P_i^{\text{actual}}-P_i^{\text{ref}}}{P_i^{\text{ref}}}\right)^2 }.
$$

$R_3$ quantifies normalized mismatch between intended and realized generator outputs under delay effects. Higher $R_3$ indicates stronger dispatch distortion and lower control fidelity [Lit-R3-Definition-1].

> **Implementation scope note:** Although $R_2$ is conceptually defined in the study motivation, the current implemented pipeline focuses on $R_1$ and $R_3$, and does not include an active $R_2$ computation module in the present experiments.

### E. Unified Scenario Protocol and Mechanism Variables

To ensure comparability, delay settings are evaluated under a fixed graded order:

$$
\texttt{no\_delay},\ \texttt{light},\ \texttt{baseline},\ \texttt{medium},\ \texttt{heavy},
$$

with scale factors $0.0, 0.5, 1.0, 1.5, 2.0$, respectively [Lit-Scenario-Protocol-1]. A consistent averaging protocol is used across scenarios to avoid mixed statistical baselines.

In addition to $R_1$ and $R_3$, mechanism variables are recorded for attribution analysis, including mean $\tau_m$, mean $\tau_e$, composite efficiency $\eta$, path-length statistics, and generator unreachable ratio. These variables support mechanism-level interpretation in later sections, enabling the analysis to explain *why* degradation occurs.

## II.2 中文翻译

### A. 系统背景与层间耦合

本文考虑一个由物理电力层与通信控制层构成的信息物理电力系统（CPPS），两层通过节点级关联进行耦合。物理层负责发电-负荷平衡及受拓扑约束的功率传输，信息层负责测量采集、控制计算与命令下发。在级联扰动下，任一层中的失效都可能改变物理连通性与信息路由条件，并以闭环方式影响控制有效性【Lit-CPPS-Model-1, Lit-Interdependence-1】。

记 $G_P=(V_P,E_P)$ 为物理网络，$G_C=(V_C,E_C)$ 为信息网络。耦合矩阵 $A_{pc}$ 用于描述电力母线到信息节点的映射，信息节点中的一个子集被设定为控制中心（CC）。该建模为后续路径时延计算与发电机级控制实现分析提供了结构基础。

### B. 双向时延分解

为保持物理可解释性，通信时延采用方向化建模：上行（non-CC $\rightarrow$ CC）与下行（CC $\rightarrow$ non-CC）分别处理【Lit-Delay-Decomposition-1】。对于有向跳边 $(u,v)$，单向时延分解为

$$
T_{u\rightarrow v}=T_{\text{serial}}(u,v)+T_{\text{prop}}(u,v)+T_{\text{service}}(u\rightarrow v).
$$

其中串行项与传播项表示为

$$
T_{\text{serial}}(u,v)=\frac{P_s}{R_{u,v}},\qquad
T_{\text{prop}}(u,v)=\frac{d_{u,v}}{V},
$$

$P_s$ 为数据包大小，$R_{u,v}$ 为链路速率，$d_{u,v}$ 为距离，$V$ 为传播速度。

对多跳路径 $\pi$，总时延由逐跳链路时延累加、端点处理时延与中间转发时延组成。为体现运行异质性，服务时延参数按节点角色区分（CC 与 non-CC），从而刻画上/下行控制链路中的非对称处理行为【Lit-Service-Heterogeneity-1】。

### C. 面向存活发电机的时延—控制映射

当前实现将信息侧时序通过测量时延 $\tau_m$ 与执行时延 $\tau_e$ 映射到电力侧响应；该映射针对每台“存活且参与调节”的发电机 $i$。测量时延由电力节点测量/接口时延与上行通信时延组成；执行时延由下行通信时延与现场执行时延组成【Lit-Delay-Control-Bridge-1】。

给定时延灵敏度 $k_m$ 与 $k_e$，定义

$$
f_{m,i}=1-k_m\tau_{m,i},\qquad
f_{e,i}=1-k_e\tau_{e,i},\qquad
\eta_i=f_{m,i}f_{e,i},
$$

并计算时延作用后的有功出力

$$
P_i^{\text{actual}}=P_i^{\text{ref}}\eta_i
= P_i^{\text{ref}}(1-k_m\tau_{m,i})(1-k_e\tau_{e,i}).
$$

该映射使“时延”从次级观测量转变为直接驱动级联后调节质量的核心变量【Lit-Delay-to-Power-Model-1】。

### D. 已实现鲁棒性指标：$R_1$ 与 $R_3$

#### 1) 时延修正负荷保持率 $R_1$

设 $L_{\text{initial}}$ 为初始总负荷，$L_{\text{surviving}}$ 为级联后（未施加时延折减前）的存活负荷。定义时延惩罚因子

$$
\phi=\min\!\left(1,\frac{\sum_i P_i^{\text{actual}}}{\sum_i P_i^{\text{ref}}}\right),
$$

则

$$
L_{\text{final}}=L_{\text{surviving}}\phi,\qquad
R_1=\frac{L_{\text{final}}}{L_{\text{initial}}}.
$$

该指标反映了在考虑时延导致的机组出力折减后，系统仍可维持的供电能力【Lit-R1-DelayAware-1】。

#### 2) 时延诱导机组偏差指标 $R_3$

对 $N$ 台参与计算的存活发电机，定义

$$
R_3=\sqrt{\frac{1}{N}\sum_{i=1}^{N}
\left(\frac{P_i^{\text{actual}}-P_i^{\text{ref}}}{P_i^{\text{ref}}}\right)^2 }.
$$

$R_3$ 用于量化时延作用下“目标出力”与“实际实现出力”的归一化偏差。$R_3$ 越大，说明调度失真越强、控制保真度越低【Lit-R3-Definition-1】。

> **实现范围说明：** 尽管 $R_2$ 在研究动机中有概念性定义，但当前已实现实验流程聚焦于 $R_1$ 与 $R_3$，尚未包含可运行的 $R_2$ 计算模块。

### E. 统一场景协议与机制变量

为保证可比性，本文采用固定顺序的分级时延场景：

$$
\texttt{no\_delay},\ \texttt{light},\ \texttt{baseline},\ \texttt{medium},\ \texttt{heavy},
$$

对应缩放系数分别为 $0.0, 0.5, 1.0, 1.5, 2.0$【Lit-Scenario-Protocol-1】。各场景统一采用同一统计口径，避免因基线口径不一致导致的比较偏差。

除 $R_1$ 与 $R_3$ 外，本文还记录机制归因变量，包括平均 $\tau_m$、平均 $\tau_e$、综合效率 $\eta$、路径长度统计量与发电机不可达比例。这些变量用于后续章节的机制解释，从而回答“为何恶化”，而不仅是“是否恶化”。

---

## Next Writing Slot

- Section III (English + Chinese): Experimental Protocol and Implementation Details.

---

# III. Experimental Protocol and Implementation Details

## III.1 English Draft

### A. Objective and Evaluation Scope

This section describes the implemented protocol for delay-aware robustness evaluation in cascading CPPS simulations.
The current workflow evaluates robustness through two implemented metrics, $R_1$ and $R_3$, together with mechanism-level attribution variables.
The protocol follows a minimal-intrusion principle: cascading dynamics are generated by the original cascading engine, while delay effects are introduced in round-wise post-cascade metric computation [Lit-Methodological-Control-1].

### B. Simulation Backbone and Input Construction

The physical layer is based on the IEEE 39-bus system, where adjacency is derived from branch connectivity.
The cyber layer is generated as a BA-type communication network with designated control-center (CC) and non-control (non-CC) nodes.
For each trial, the coupling matrix $A_{pc}$, control-center set, cyber adjacency, and role masks are generated and reused across tolerance settings to ensure cross-setting comparability [Lit-CPPS-Setup-1].

Cascading simulations are executed over:

$$
\alpha \in \{0.0,\,0.5,\,1.0\},
$$

and each $\alpha$ is evaluated with multiple independently generated coupling/network samples.

### C. Cascading Simulation and Round-Level Logging

For each $(\alpha,\text{trial})$, an initial cyber node is attacked according to the configured attack mode (current default: betweenness-based selection).
Failure then evolves through iterative cross-layer propagation and overload checks until the system reaches stability.

At each main cascading round $r$, the simulator records a structured round state:

$$
\mathcal{S}^{(r)}=
\{\text{failed power nodes},\text{failed cyber nodes},\text{failed power branches},\text{failed cyber edges},A_c^{(r)},A_{pc},\text{CC mask}\}.
$$

These logged round states enable delay-state reconstruction and round-wise robustness evaluation rather than final-state-only assessment [Lit-Roundwise-Evaluation-1].

### D. Delay Configuration and Graded Scenarios

A baseline delay configuration specifies communication and control-delay parameters, including packet size, link rate, propagation speed, CC/non-CC service delays, and measurement/execution sensitivities.
From this baseline, five graded scenarios are generated in fixed order:

$$
\texttt{no\_delay},\ \texttt{light},\ \texttt{baseline},\ \texttt{medium},\ \texttt{heavy},
$$

with scale factors:

$$
[0.0,\ 0.5,\ 1.0,\ 1.5,\ 2.0].
$$

All delay-relevant communication and interface parameters are scaled coherently under the same scenario factor [Lit-Scenario-Design-1].

### E. Metric Computation Pipeline ($R_1$, $R_3$)

For each $(\alpha,\text{trial},\text{scenario})$, the pipeline iterates over all logged rounds:

1. Reconstruct the round delay state from $\mathcal{S}^{(r)}$ and scenario configuration.
2. Compute surviving-generator $P^{\text{ref}}$, delay-affected $P^{\text{actual}}$, and delay factors $(\tau_m,\tau_e,\eta)$.
3. Compute round $R_1$ using delay-adjusted served-load ratio.
4. Compute round $R_3$ using normalized generator-output deviation.
5. Aggregate by round average within each trial, then by sample average across trials.

This averaging hierarchy is consistently applied across all delay scenarios, ensuring fair between-scenario comparison [Lit-Statistics-Consistency-1].

### F. Mechanism Attribution and Generator Sensitivity Outputs

To explain why robustness changes, the implementation records attribution variables per $(\alpha,\text{trial},\text{scenario})$, including:
- mean $\tau_m$,
- mean $\tau_e$,
- mean $\eta$,
- mean uplink/downlink path length,
- unreachable-generator ratio.

These variables are aggregated into scenario-wise and $\alpha$-wise attribution views.
In parallel, generator-level sensitivity is quantified by mean absolute relative deviation, and complemented by baseline explanatory descriptors (e.g., mean delay components, path lengths, unreachable ratio, dominant control-center association) [Lit-Attribution-and-Criticality-1].

### G. Reporting Conventions and Reproducibility

For reproducible and interpretable reporting, the protocol enforces:
- fixed scenario order,
- explicit round-wise then sample-wise averaging,
- round-log-based delay-state traceability,
- consistent metric computation semantics across all scenarios.

All quantitative comparisons in subsequent sections follow this protocol unless explicitly stated otherwise.

## III.2 中文翻译

### A. 实验目标与评估范围

本节给出已实现的时延感知鲁棒性评估流程。
当前工作流通过两个已实现指标 $R_1$ 与 $R_3$ 及其机制归因变量开展评估。
该流程遵循“最小侵入”原则：级联动力学由原有级联引擎生成，时延效应在逐轮的级联后指标计算中引入【Lit-Methodological-Control-1】。

### B. 仿真骨架与输入构建

物理层采用 IEEE 39 节点系统，邻接关系由支路连接确定。
信息层采用 BA 型通信网络，并设置控制中心（CC）与非控制节点（non-CC）。
对每个 trial，会生成并在不同容错设置下复用 $A_{pc}$、控制中心集合、信息层邻接与角色掩码，以保证跨设置比较的一致性【Lit-CPPS-Setup-1】。

级联仿真按下式执行：

$$
\alpha \in \{0.0,\,0.5,\,1.0\},
$$

每个 $\alpha$ 下评估多个独立生成的耦合/网络样本。

### C. 级联仿真与逐轮日志

对每个 $(\alpha,\text{trial})$，先按配置攻击模式选择初始信息节点（当前默认：基于介数的选择）。
随后通过跨层传播与过载检查迭代演化，直到系统稳定。

在每一轮主级联迭代 $r$ 中，仿真记录结构化轮次状态：

$$
\mathcal{S}^{(r)}=
\{\text{失效电力节点},\text{失效信息节点},\text{失效电力支路},\text{失效信息连边},A_c^{(r)},A_{pc},\text{CC掩码}\}.
$$

这些逐轮日志支持时延状态重建与逐轮鲁棒性评估，而不是只看最终态【Lit-Roundwise-Evaluation-1】。

### D. 时延参数与分级场景

基准时延配置定义通信与控制相关参数，包括包大小、链路速率、传播速度、CC/non-CC服务时延、测量/执行灵敏度。
在此基础上构建五个分级场景，顺序固定为：

$$
\texttt{no\_delay},\ \texttt{light},\ \texttt{baseline},\ \texttt{medium},\ \texttt{heavy},
$$

对应缩放系数：

$$
[0.0,\ 0.5,\ 1.0,\ 1.5,\ 2.0].
$$

场景缩放对通信与接口时延参数统一生效，确保场景间可比【Lit-Scenario-Design-1】。

### E. 指标计算流程（$R_1$、$R_3$）

对每个 $(\alpha,\text{trial},\text{scenario})$，流程遍历所有轮次日志并执行：

1. 由 $\mathcal{S}^{(r)}$ 和场景参数重建轮次时延状态；
2. 计算存活机组 $P^{\text{ref}}$、时延作用后 $P^{\text{actual}}$ 及 $(\tau_m,\tau_e,\eta)$；
3. 计算该轮 $R_1$（时延修正负荷保持率）；
4. 计算该轮 $R_3$（机组归一化偏差）；
5. trial 内先做逐轮平均，再在样本维度做平均。

该平均层级在所有场景下完全一致，以保证场景间比较公平【Lit-Statistics-Consistency-1】。

### F. 机制归因与机组敏感性输出

为解释“为什么会恶化”，实现中按 $(\alpha,\text{trial},\text{scenario})$ 记录归因变量，包括：
- 平均 $\tau_m$；
- 平均 $\tau_e$；
- 平均 $\eta$；
- 上/下行路径长度均值；
- 发电机不可达比例。

这些变量可聚合为场景维度与 $\alpha$ 维度的归因视图。
同时，机组层敏感性由平均绝对相对偏差量化，并辅以基准场景解释变量（如平均时延分量、路径长度、不可达比例、主导控制中心）【Lit-Attribution-and-Criticality-1】。

### G. 报告口径与可复现性

为保证报告可复现、可解释，本文统一采用：
- 固定场景顺序；
- 明确的“逐轮平均 → 样本平均”统计层级；
- 基于轮次日志的时延状态可追溯重建；
- 跨场景一致的指标计算语义。

后续章节的全部定量比较默认遵循该协议，除非特别说明。

---

## Next Writing Slot

- Section IV (English + Chinese): Graded-Scenario Robustness Results.

---

# IV. Graded-Scenario Robustness Results

## IV.1 English Draft

### A. Reporting Structure and Statistical Semantics

This section reports scenario-level robustness results under graded delay settings.
For each tolerance level $\alpha$, trial $j$, scenario $s$, and cascading round $r$, the round-level metrics are first computed and then aggregated in two stages (round-wise, then sample-wise).
For $m\in\{1,3\}$, we define:

$$
\bar{R}_m(\alpha,j,s)=\frac{1}{T_{\alpha,j}}\sum_{r=1}^{T_{\alpha,j}}R_m(\alpha,j,s,r),
$$

$$
\mu_{R_m}(\alpha,s)=\frac{1}{N}\sum_{j=1}^{N}\bar{R}_m(\alpha,j,s),
$$

where $T_{\alpha,j}$ is the number of recorded cascading rounds in trial $j$, and $N$ is the number of samples.
This two-stage aggregation is used consistently across all scenarios to ensure fair comparison [Lit-Statistics-Consistency-1].

### B. Scenario-Wise $R_1$ Behavior Across $\alpha$

Figure [Fig-R1-Scenario] presents $\mu_{R_1}(\alpha,s)$ for the ordered scenarios

$$
\texttt{no\_delay},\ \texttt{light},\ \texttt{baseline},\ \texttt{medium},\ \texttt{heavy}.
$$

As an effective-load retention metric, $R_1$ reflects post-cascade service capability after delay-adjusted generation realization.
In expectation, lower-delay scenarios tend to preserve higher $R_1$, while stronger delay settings tend to reduce $R_1$ [Lit-R1-Interpretation-1].

Because cascading evolution includes stochastic cross-layer propagation and sample-dependent topology realizations, local curve overlap or crossing may appear at specific $\alpha$ points.
Such overlap should be interpreted as sample-level variability rather than inconsistency of the evaluation logic.
The key comparison remains the scenario-level trend under unified averaging semantics [Lit-Uncertainty-Reporting-1].

### C. Scenario-Wise $R_3$ Behavior Across $\alpha$

Figure [Fig-R3-Scenario] reports $\mu_{R_3}(\alpha,s)$, where $R_3$ measures normalized generator-level deviation between delay-affected output and reference output for surviving generators.
Higher $R_3$ indicates stronger delay-induced dispatch distortion and weaker control realization fidelity [Lit-R3-Interpretation-1].

Compared with $R_1$, $R_3$ provides a more direct control-quality perspective at the generator level.
Thus, $R_1$ and $R_3$ should be interpreted jointly: $R_1$ captures service retention, while $R_3$ captures regulation mismatch.
This dual-view reading avoids one-dimensional conclusions based on a single metric [Lit-DualMetric-Argument-1].

### D. Cross-Scenario Summary Indicators

To provide compact scenario-level comparison, we further summarize:

$$
\bar{R}_1(s)=\frac{1}{|\mathcal{A}|}\sum_{\alpha\in\mathcal{A}}\mu_{R_1}(\alpha,s),\qquad
\bar{R}_3(s)=\frac{1}{|\mathcal{A}|}\sum_{\alpha\in\mathcal{A}}\mu_{R_3}(\alpha,s),
$$

where $\mathcal{A}=\{0.0,0.5,1.0\}$.
These aggregated indicators correspond to scenario comparison bar charts [Fig-R1-Bar], [Fig-R3-Bar], and serve as concise robustness summaries rather than replacements for full $\alpha$-resolved curves [Lit-Aggregated-Comparison-1].

### E. $R_1$-Based Operational Safety Labels

Using predefined threshold bands, $R_1$ outcomes are additionally mapped into qualitative safety levels for each $(\alpha,s)$ pair [Tab-R1-Safety].
This mapping translates numerical robustness into operator-oriented interpretation and improves readability for engineering decision contexts [Lit-Safety-Mapping-1].

### F. Interim Findings and Transition to Mechanism Analysis

At the scenario-comparison level, Section IV establishes *what* changes under graded delay settings in terms of service retention and generator-output consistency.
However, scenario curves alone do not fully explain *why* deterioration occurs.
Therefore, the next section moves from performance observation to mechanism attribution, using delay-component variables (e.g., $\tau_m$, $\tau_e$, $\eta$, path characteristics, and reachability) to explain robustness degradation pathways [Lit-Attribution-Transition-1].

## IV.2 中文翻译

### A. 报告结构与统计语义

本节给出分级时延场景下的鲁棒性结果。
对每个容错系数 $\alpha$、样本 $j$、场景 $s$ 和级联轮次 $r$，先计算轮次指标，再执行“两级聚合”（先轮次平均，再样本平均）。
对 $m\in\{1,3\}$，定义：

$$
\bar{R}_m(\alpha,j,s)=\frac{1}{T_{\alpha,j}}\sum_{r=1}^{T_{\alpha,j}}R_m(\alpha,j,s,r),
$$

$$
\mu_{R_m}(\alpha,s)=\frac{1}{N}\sum_{j=1}^{N}\bar{R}_m(\alpha,j,s),
$$

其中 $T_{\alpha,j}$ 为样本 $j$ 的记录轮次数，$N$ 为样本数。
该两级统计在所有场景中统一使用，以保证比较公平【Lit-Statistics-Consistency-1】。

### B. $R_1$ 在不同场景与 $\alpha$ 下的表现

图 [Fig-R1-Scenario] 展示了场景顺序

$$
\texttt{no\_delay},\ \texttt{light},\ \texttt{baseline},\ \texttt{medium},\ \texttt{heavy}
$$

对应的 $\mu_{R_1}(\alpha,s)$。
作为有效负荷保持指标，$R_1$ 反映了在考虑时延折减后系统的级联后服务能力。
从期望趋势看，低时延场景通常对应更高 $R_1$，高时延场景通常导致 $R_1$ 下降【Lit-R1-Interpretation-1】。

由于级联演化包含跨层随机传播和样本拓扑差异，在某些 $\alpha$ 点出现局部重叠或交叉是可能的。
这类现象应被解释为样本波动，而非评估逻辑不一致。
核心仍是基于统一口径下的场景级趋势比较【Lit-Uncertainty-Reporting-1】。

### C. $R_3$ 在不同场景与 $\alpha$ 下的表现

图 [Fig-R3-Scenario] 给出 $\mu_{R_3}(\alpha,s)$。
其中 $R_3$ 衡量的是“存活发电机在时延作用下的实际出力”相对于“参考出力”的归一化偏差。
$R_3$ 越高，表示时延导致的调节失真越强、控制实现保真度越低【Lit-R3-Interpretation-1】。

与 $R_1$ 相比，$R_3$ 更直接反映机组层控制质量。
因此应联合解读 $R_1$ 与 $R_3$：$R_1$ 看服务保持，$R_3$ 看调节偏差。
这种双指标视角可避免单一指标带来的片面结论【Lit-DualMetric-Argument-1】。

### D. 场景级汇总指标

为形成紧凑的场景比较，进一步定义：

$$
\bar{R}_1(s)=\frac{1}{|\mathcal{A}|}\sum_{\alpha\in\mathcal{A}}\mu_{R_1}(\alpha,s),\qquad
\bar{R}_3(s)=\frac{1}{|\mathcal{A}|}\sum_{\alpha\in\mathcal{A}}\mu_{R_3}(\alpha,s),
$$

其中 $\mathcal{A}=\{0.0,0.5,1.0\}$。
该汇总对应场景柱状图 [Fig-R1-Bar]、[Fig-R3-Bar]，可作为简洁比较结果；但它不能替代完整的 $\alpha$-分辨曲线【Lit-Aggregated-Comparison-1】。

### E. 基于 $R_1$ 的运行安全分级

结合预设阈值区间，可将每个 $(\alpha,s)$ 的 $R_1$ 结果映射为定性安全等级 [Tab-R1-Safety]。
该映射有助于把数值鲁棒性结果转化为运行侧更易使用的解释形式，提升工程可读性【Lit-Safety-Mapping-1】。

### F. 阶段性结论与向机制分析过渡

在场景比较层面，本节回答了“分级时延下，服务保持与机组输出一致性发生了什么变化”。
但仅靠场景曲线仍不足以完整解释“为何恶化”。
因此下一节将从现象比较转向机制归因，利用时延分量变量（如 $\tau_m$、$\tau_e$、$\eta$、路径特征、可达性）解释鲁棒性退化路径【Lit-Attribution-Transition-1】。

---

## Next Writing Slot

- Section V (English + Chinese): Mechanism Attribution Analysis (A1).

---

# V. Mechanism Attribution Analysis (A1)

## V.1 English Draft

### A. Purpose of A1 Attribution

While Section IV quantifies performance changes across graded delay scenarios, it does not by itself explain the dominant causal pathways of degradation.
To bridge this gap, we introduce an attribution layer (A1) that links robustness outcomes to interpretable delay-driving factors.
The objective is to answer not only whether robustness deteriorates, but also which mechanism components are most associated with that deterioration [Lit-Attribution-Framework-1].

### B. Attribution Variables and Aggregation

For each $(\alpha,\text{trial},\text{scenario})$, the implementation records:
- mean measurement delay $\tau_m$,
- mean execution delay $\tau_e$,
- mean composite efficiency $\eta$,
- mean uplink path length,
- mean downlink path length,
- unreachable-generator ratio.

For any factor $x$, trial-level values are aggregated as

$$
\mu_x(\alpha,s)=\frac{1}{N}\sum_{j=1}^{N}x(\alpha,j,s),
$$

with $N$ denoting the sample count.
These factor summaries are jointly interpreted with $\mu_{R_3}(\alpha,s)$ to form mechanism-level evidence [Lit-Attribution-Variables-1].

### C. Delay-Component Association with Robustness

Scatter and trend views are used to analyze the relationship between robustness degradation and delay components.
In particular, the following associations are examined:
- $R_3$ versus mean $\tau_m$,
- $R_3$ versus mean $\tau_e$,
- $R_3$ versus unreachable ratio.

These views are interpreted as attribution evidence rather than strict causal-identification tests.
They reveal whether scenario-level degradation is co-moving with specific mechanism factors under a unified simulation protocol [Lit-Attribution-Interpretation-1].

### D. Path and Reachability Effects

Path characteristics and reachability provide a structural channel for delay amplification.
Longer effective paths generally imply larger accumulated communication delay and forwarding overhead, while lower reachability weakens command deliverability to surviving generators.
Accordingly, path-length indicators and unreachable ratio are analyzed as structural mediators between cyber degradation and generator-output mismatch [Lit-Path-Reachability-1].

### E. Reading Rules for Overlap and Variability

In practical simulation outputs, some factor curves may partially overlap across scenarios at specific $\alpha$ values.
Such overlap should be interpreted with caution: it may reflect finite-sample variability, limited sensitivity in that factor under current settings, or coupling constraints in the present network realization.
Therefore, the analysis emphasizes multi-factor consistency rather than one-factor-only conclusions [Lit-Multifactor-Reading-1].

### F. Section Summary

Section V establishes a mechanism-oriented interpretation layer that complements scenario-level performance curves.
By jointly examining delay components, path structure, and reachability with $R_3$, A1 provides an evidence-based explanation of degradation pathways and prepares the ground for asset-level vulnerability localization in the next section.

## V.2 中文翻译

### A. A1归因分析的目的

第四节展示了分级时延场景下的性能变化，但仅靠这些曲线还不足以解释“恶化主要通过什么机制发生”。
为弥补这一点，本文引入 A1 归因层，将鲁棒性结果与可解释的时延驱动因子建立对应关系。
其目标不仅是回答“是否恶化”，还要回答“哪些机制分量与恶化最相关”【Lit-Attribution-Framework-1】。

### B. 归因变量与聚合方式

对每个 $(\alpha,\text{trial},\text{scenario})$，实现中记录：
- 平均测量时延 $\tau_m$；
- 平均执行时延 $\tau_e$；
- 平均综合效率 $\eta$；
- 上行路径长度均值；
- 下行路径长度均值；
- 发电机不可达比例。

对任一因子 $x$，样本聚合定义为

$$
\mu_x(\alpha,s)=\frac{1}{N}\sum_{j=1}^{N}x(\alpha,j,s),
$$

其中 $N$ 为样本数。
这些因子汇总与 $\mu_{R_3}(\alpha,s)$ 联合解读，形成机制层证据【Lit-Attribution-Variables-1】。

### C. 时延分量与鲁棒性的关联分析

本文采用散点与趋势图分析鲁棒性退化与时延分量的关系，重点包括：
- $R_3$ 与平均 $\tau_m$ 的关系；
- $R_3$ 与平均 $\tau_e$ 的关系；
- $R_3$ 与不可达比例的关系。

这些结果用于机制归因，而不是严格意义上的因果识别检验。
它们揭示的是：在统一仿真协议下，场景级性能恶化是否与特定机制因子协同变化【Lit-Attribution-Interpretation-1】。

### D. 路径与可达性的结构作用

路径特征与可达性构成时延放大的结构通道。
有效路径越长，累积通信时延与转发开销通常越大；可达性越低，控制命令越难覆盖存活发电机。
因此，路径长度指标与不可达比例被视为连接“信息层退化”与“机组出力失配”的结构中介变量【Lit-Path-Reachability-1】。

### E. 关于重叠与波动的解读规则

在实际仿真输出中，部分因子曲线可能在某些 $\alpha$ 点出现重叠。
这类重叠应谨慎解读：可能来源于有限样本波动、当前参数下该因子敏感性不足，或当前网络实现中的耦合约束。
因此，本文强调“多因子一致性”而非“单因子决定论”【Lit-Multifactor-Reading-1】。

### F. 本节小结

第五节建立了机制导向的解释层，补充了场景性能曲线的不足。
通过将时延分量、路径结构、可达性与 $R_3$ 联合分析，A1 为退化路径提供证据化解释，并为下一节的资产级脆弱性定位奠定基础。

---

# VI. Generator-Level Vulnerability and Operational Implications

## VI.1 English Draft

### A. Motivation

System-level metrics indicate overall robustness trends, but operation and protection planning require asset-level prioritization.
Therefore, this section identifies delay-vulnerable generators and links their sensitivity to interpretable baseline descriptors [Lit-Asset-Level-Need-1].

### B. Sensitivity Metric Definition

For generator $g$, define its mean absolute relative deviation score as:

$$
S_g=\frac{1}{|\Omega_g|}\sum_{u\in\Omega_g}\left|\frac{P_{g,u}^{\text{actual}}-P_{g,u}^{\text{ref}}}{P_{g,u}^{\text{ref}}}\right|,
$$

where $\Omega_g$ denotes all valid observations of generator $g$ across evaluated rounds/samples/scenarios in the implemented pipeline.
Larger $S_g$ indicates stronger delay sensitivity in output realization [Lit-Sensitivity-Metric-1].

### C. Ranking and Explanatory Fields

Generators are ranked by descending $S_g$ to produce a Top-$k$ vulnerable set.
To support interpretation, the ranking is complemented by baseline descriptive fields, including:
- baseline mean $\tau_m$,
- baseline mean $\tau_e$,
- baseline mean $\eta$,
- baseline mean uplink/downlink path lengths,
- baseline unreachable ratio,
- dominant associated control center.

This joint representation separates “how vulnerable” from “why vulnerable,” improving actionability [Lit-Ranking-Interpretability-1].

### D. Operational Interpretation

A high-sensitivity generator may indicate one or more of the following risk patterns:
1. persistent high delay components ($\tau_m$, $\tau_e$),
2. unfavorable communication-path structure,
3. reduced reachability under disturbance conditions.

Accordingly, mitigation priorities can be assigned to communication-path reinforcement, delay-budget optimization, and control-center service allocation for the most sensitive units [Lit-Operational-Prioritization-1].

### E. Section Summary

Section VI translates mechanism-level evidence into generator-level operational targets.
By constructing sensitivity-based ranking and explanatory descriptors, the framework provides a practical bridge from robustness assessment to intervention planning.

## VI.2 中文翻译

### A. 动机

系统级指标能反映总体鲁棒性趋势，但运行与防护规划需要资产级优先级。
因此，本节识别时延脆弱发电机，并将其敏感性与可解释的基准描述变量关联起来【Lit-Asset-Level-Need-1】。

### B. 敏感性指标定义

对发电机 $g$，定义其平均绝对相对偏差得分：

$$
S_g=\frac{1}{|\Omega_g|}\sum_{u\in\Omega_g}\left|\frac{P_{g,u}^{\text{actual}}-P_{g,u}^{\text{ref}}}{P_{g,u}^{\text{ref}}}\right|,
$$

其中 $\Omega_g$ 表示该发电机在当前实现流程下跨轮次/样本/场景的有效观测集合。
$S_g$ 越大，表示该发电机在出力实现上对时延越敏感【Lit-Sensitivity-Metric-1】。

### C. 排名与解释字段

按 $S_g$ 从高到低排序，得到 Top-$k$ 脆弱机组集合。
为提升解释性，排序结果配套输出基准场景解释字段，包括：
- 基准平均 $\tau_m$；
- 基准平均 $\tau_e$；
- 基准平均 $\eta$；
- 基准上/下行路径长度均值；
- 基准不可达比例；
- 主导关联控制中心。

这种联合表示将“有多脆弱”与“为什么脆弱”分离表达，增强可行动性【Lit-Ranking-Interpretability-1】。

### D. 运行侧解释

高敏感机组通常对应以下一种或多种风险模式：
1. 持续较高的时延分量（$\tau_m$、$\tau_e$）；
2. 不利的通信路径结构；
3. 扰动条件下可达性下降。

据此可将缓解优先级配置到：通信路径加固、时延预算优化、控制中心服务资源分配等方向，并优先作用于高敏感机组【Lit-Operational-Prioritization-1】。

### E. 本节小结

第六节将机制层证据转化为机组层操作目标。
通过构建“敏感性排序 + 解释字段”框架，本文实现了从鲁棒性评估到干预规划的工程闭环。

---

# VII. Discussion and Limitations

## VII.1 English Draft

### A. What Is Established in the Current Study

The present workflow establishes a coherent delay-aware robustness pipeline with:
1. directional delay decomposition,
2. delay-to-generator-output mapping,
3. unified graded-scenario evaluation using $R_1$ and $R_3$,
4. mechanism attribution (A1),
5. generator-level vulnerability ranking.

Together, these components form a complete analysis chain from phenomenon observation to mechanism interpretation and operational targeting [Lit-Framework-Completeness-1].

### B. Scope Boundaries

This study intentionally focuses on implemented and validated components in the current codebase.
Consequently, the conclusions are tied to the present benchmark system scale, current scenario granularity, and the configured delay parameterization.
The reported findings should therefore be interpreted as evidence within this modeling scope rather than universal claims across all CPPS settings [Lit-Scope-Boundary-1].

### C. Methodological Considerations

Because cascading evolution contains stochastic propagation and sample-dependent topology realization, localized curve overlap may occur.
This does not invalidate the framework; rather, it highlights the need for multi-factor reading and uncertainty-aware interpretation.
Future extensions may include broader parameter sweeps, larger test systems, and additional robustness statistics to strengthen external validity [Lit-Uncertainty-Methodology-1].

### D. Practical Implications

Despite the above boundaries, the framework already provides practical value:
- it quantifies delay-induced robustness degradation,
- identifies mechanism-correlated drivers,
- and prioritizes vulnerable generators for targeted intervention.

This supports a transition from descriptive risk awareness to evidence-guided operational planning [Lit-Practical-Value-1].

## VII.2 中文翻译

### A. 当前研究已经建立的内容

当前流程已形成一条完整的时延感知鲁棒性分析链，包括：
1. 方向化时延分解；
2. 时延到机组出力的映射；
3. 基于 $R_1$ 与 $R_3$ 的统一分级场景评估；
4. A1 机制归因；
5. 机组级脆弱性排序。

这些组件共同构成了从现象观察到机制解释、再到运行对象定位的完整闭环【Lit-Framework-Completeness-1】。

### B. 研究边界

本文有意聚焦于当前代码中“已实现且已验证”的部分。
因此，结论与当前测试系统规模、场景粒度以及时延参数设定直接相关。
本文结果应理解为该建模范围内的证据，而非对所有 CPPS 场景的普适结论【Lit-Scope-Boundary-1】。

### C. 方法学层面说明

由于级联演化包含随机传播和样本拓扑差异，局部曲线重叠是可能的。
这并不否定框架本身，而是说明需要采用多因子联合解读和不确定性意识。
未来可通过更广参数扫描、更大规模系统和更多统计量来增强外部有效性【Lit-Uncertainty-Methodology-1】。

### D. 工程启示

尽管存在上述边界，当前框架已具备明确工程价值：
- 可定量刻画时延导致的鲁棒性退化；
- 可识别与退化相关的机制驱动；
- 可定位优先干预的脆弱发电机。

这使研究从“描述风险”推进到“证据驱动的运行规划”【Lit-Practical-Value-1】。

---

# VIII. Conclusion

## VIII.1 English Draft

This paper develops an implemented delay-aware robustness assessment framework for cascading cyber-physical power systems.
By explicitly mapping bidirectional communication delay to surviving-generator output realization, the framework connects timing degradation to two operational robustness dimensions: load-retention capability ($R_1$) and generator-output deviation ($R_3$).

A unified graded-scenario protocol enables coherent cross-scenario comparison, while the A1 attribution layer links observed degradation to interpretable mechanism variables, including delay components, path characteristics, and reachability.
Further, generator-level sensitivity ranking provides an actionable view for prioritizing intervention targets.

Overall, the study establishes a complete analysis chain from scenario-level robustness observation to mechanism-level interpretation and asset-level vulnerability localization.
This provides a practical foundation for delay-aware risk management in CPPS cascading contexts and a structured basis for future extensions with broader systems and richer mitigation designs.

## VIII.2 中文翻译

本文构建并实现了一套面向信息物理电力系统级联场景的时延感知鲁棒性评估框架。
通过将双向通信时延显式映射到存活机组的出力实现过程，本文把时序退化与两类运行鲁棒性维度建立联系：负荷保持能力（$R_1$）与机组出力偏差（$R_3$）。

统一的分级场景协议保证了场景间可比性；A1 归因层进一步将性能退化与可解释机制变量（时延分量、路径特征、可达性）关联起来。
同时，机组级敏感性排序为运行侧优先干预对象提供了可执行依据。

总体而言，本文建立了从场景级性能观察到机制级解释、再到资产级脆弱性定位的完整分析链。
该框架为 CPPS 级联场景下的时延风险管理提供了可落地基础，也为后续在更大系统和更丰富缓解设计上的扩展提供了结构化起点。

---

## Next Writing Slot

- Post-processing step: replace placeholders `[Lit-XXX]`, bind figures/tables, and align target journal format.
