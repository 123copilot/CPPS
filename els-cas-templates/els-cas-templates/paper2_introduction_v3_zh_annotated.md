# Introduction v3 — 中英对照逐段解读

> 这份文档不是用来投稿的，是给你**读懂英文版**用的。  
> 投稿用的是 `paper2_introduction_v3.tex`。  
> 这里左侧是英文（与 v3 完全一致），右侧/下方是中文翻译 + ⓘ 写作意图说明。

---

## §0 段（开场）

> **EN.** The deep integration of physical infrastructure with high-speed communication networks has transformed traditional power grids into *cyber-physical power systems* (CPPS), in which a physical power layer and a cyber communication layer operate as a tightly coupled whole [Rinaldi2001, Ouyang2014]. Under nominal conditions this coupling improves dispatch flexibility, situational awareness and wide-area control performance. Under stress, however, it opens a bidirectional failure channel: a disturbance originating in either layer can propagate to the other and trigger cascading failures of a magnitude neither layer would experience in isolation [Buldyrev2010, Gao2012].

**中文.** 物理基础设施与高速通信网络的深度融合，使传统电网演变为**信息物理电力系统 (CPPS)**——物理电力层和信息通信层作为一个紧耦合的整体协同运行。在正常工况下，这种耦合提升了调度灵活性、态势感知与广域控制性能；但在受扰工况下，它同时开启了一条双向故障通道：任一层的扰动都可能传播到另一层，触发任何单一层独立运行时都不会出现的级联失效。

> ⓘ **写作意图**：这是审稿人最常跳过的一段——所以**不能写得新颖**，反而要写得"标准"。Rinaldi 2001 + Ouyang 2014 是该领域的"必引"奠基文，Buldyrev 2010 + Gao 2012 是耦合网级联的"必引"经典。先用四个老熟人取得审稿人信任，再开始讲我们自己的事。

---

## §1 段（综述 + 缺口的两步定位）

> **EN.** A substantial body of work has investigated such failures through topological percolation models, flow-redistribution rules and attack-vulnerability analyses [Motter2002, Dobson2007, Brummitt2012, Schneider2011]. These studies established *how* structural interdependence amplifies failure propagation, and they remain the conceptual backbone of modern CPPS robustness analysis. In most of them, however, the communication layer is represented as a binary entity—a link is either functional or failed—without modelling the quality of service that surviving links provide. When end-to-end latency is addressed at all, it is either absent from the cascade dynamics or applied as a post-hoc rescaling of the final performance metric, so that all delay scenarios share an identical structural cascade [Milano2012, LaiCPPS2019]. More recent work has begun to relax this binary view by modelling a single delay channel explicitly—typically queueing on transmission links or jitter on PMU streams—and embedding it inside the cascade [Cai2016TSG, Falahati2014TSG, Huang2015]. This direction is the right one, but the chain that feeds modern wide-area protection is not single-channel. Industrial measurement budgets distinguish sensor and PMU acquisition, edge processing, transmission and actuation as separately bounded components [NASPI, IEEE C37.118.2], and the redundancy practices that sit on top of them [IEC 61850 PRP] suppress the loss probability of each component to very different degrees. A model in which all of these components collapse into a scalar τ therefore cannot, by construction, reproduce the asymmetric way real cyber stress maps into closed-loop control degradation.

**中文.** 在该领域已有大量工作，围绕拓扑渗流模型、潮流重分配规则与攻击-脆弱性分析展开 [Motter2002, Dobson2007, Brummitt2012, Schneider2011]，建立了"结构耦合如何放大故障传播"的理论骨架，至今仍是 CPPS 鲁棒性分析的概念基础。然而其中大多数把通信层视为**二值**实体——链路要么完好要么断——而不刻画存活链路的"服务质量"。即便提到端到端时延，也往往是把它从级联动力学中剥离，或者作为对最终指标的事后缩放——所有时延场景共用同一条结构级联轨迹 [Milano2012, LaiCPPS2019]。较新的工作开始放松这种二值假设，把**单一**时延通道（典型地是传输链路上的排队，或 PMU 流的抖动）显式建模并嵌入级联过程 [Cai2016TSG, Falahati2014TSG, Huang2015]——方向是对的，但**现代广域保护链路本身就不是单通道的**。工业级测量预算把传感/PMU 采集、边缘处理、传输与执行作为独立设界的组件 [NASPI, IEEE C37.118.2]；其上的冗余机制 [IEC 61850 PRP] 又对每个组件的丢包率压缩程度差异巨大。**一个把所有这些组件压成一个标量 τ 的模型，从结构上就不可能复现真实信息侧压力映射到闭环控制退化的非对称性。**

> ⓘ **写作意图**：这一段是整篇论文的支点。它做了两件事：
> 1. 把已有工作分成两层（"二值通信层" → "单通道时延"），承认每一层都做对了一些事，不是把别人贬低；
> 2. 论证为什么再走单通道路线已经不够——用**工业标准**（NASPI/C37.118.2/IEC 61850）作硬证据，而不是凭主观判断。
>
> v2 写过一张 T0/T1/T2/T3 表格，把"我们这篇"作为 T3 列在表里。这是审稿人特别讨厌的"自我标榜"格式，v3 把它**整张删掉**，改用两段叙述，让"缺口"成为一个**逻辑结论**而非"我们自己宣布的位置"。

---

## §2 段（研究问题 RQ）

> **EN.** This observation motivates the central research question of the present paper:  
> *"Does embedding a standard-anchored, multi-component communication delay model inside every round of a CPPS cascade produce qualitatively different vulnerability conclusions from a delay-free or single-τ model on the same network?"*

**中文.** 由此引出本文的核心研究问题：  
**在同一张网上，把一个"以工业标准为参数依据、多组件分解"的通信时延模型嵌入到 CPPS 级联的每一轮里，是否会得出与"无时延"或"单标量 τ"模型在性质上不同的脆弱性结论？**

> ⓘ **写作意图**：审稿人偏爱看到一个**显式的研究问题**（RQ）。它让审稿人在心里立刻标记一句"OK 这篇文章我读完之后该用什么标准来评判它是否成立"。v2 没有这一步，v3 补上。

---

## §3 段（答案预告 + 闭环机制 + 与前作的关系）

> **EN.** We answer this question affirmatively, on three counts that we develop in the body of the paper: the delay penalty is asymmetrically concentrated at moderate-to-high tolerance margins (precisely the operating regime in which a delay-free analysis predicts safety); delay amplifies the stochastic variability of cascade outcomes, producing heavy-tailed terminal distributions that ideal-communication models do not exhibit; and a generator-fidelity metric exposes functional degradation that aggregate load-retention metrics fail to detect. The mechanism that produces all three effects is a self-reinforcing loop: degraded communication reduces the closed-loop control efficacy of every surviving generator, the resulting imbalance triggers additional branch overloads, the structural failures further damage the cyber topology, and the damaged topology amplifies the latency that drives the next round. Our prior work [ChenTu2026] established the underlying CPPS framework with distributed control centers, an FVC-ID mechanism and a CPIM metric for control-center placement, but did not model the influence of communication delay on generator control during the cascade itself. The present paper closes that gap.

**中文.** 我们对该问题给出肯定回答，并在正文中分三点展开：(i) 时延惩罚**非对称地**集中在中-高容限段——恰恰是无时延分析判定为"安全"的运行区；(ii) 时延会放大级联结果的随机波动性，产生理想通信模型中不会出现的**重尾**终态分布；(iii) 一个面向发电机的"出力保真度"指标，能揭示总体负荷保留率所看不到的功能退化。三者共同源于一个**自我强化闭环**：通信质量下降 → 每台存活机组的闭环控制效能降低 → 由此引发的功率不平衡触发额外支路过载 → 结构故障进一步损伤通信拓扑 → 退化拓扑放大下一轮的时延。我们在前作 [ChenTu2026] 中已经搭建了带分布式控制中心、含 FVC-ID 解列机制与 CPIM 控制中心选址度量的 CPPS 框架，但没有建模"通信时延对级联期间发电机控制的影响"——本文正是填补这一空白。

> ⓘ **写作意图**：这一段做"承接"。先剧透结论（让审稿人看到 payoff 值得继续读），再讲机制（让审稿人确认这是一篇有物理直觉的工程文章而不是纯数据论文），最后明确**与你前一篇 Chaos 论文的边界**——避免被审稿人质疑"自我重复发表"。

---

## §4 段（贡献清单：4 条，不是 5 条）

> ⓘ **写作意图说明**：v2 列了 5 条贡献。审稿评论里**最高频的一句**就是 *"the contributions are not focused"*。EPSR / RESS / Applied Energy 这一档期刊偏好 3–4 条。v3 把 v2 的"UFLS 过切"折叠进**贡献 1** 的子句里，让它仍然出现，但不占用"主条"位置。

### Contribution 1 — 闭环时延级联框架

> **EN.** A delay-integrated, closed-loop cascading failure framework. Communication delay is computed inside every cascade round and applied to generator output *before* the DC power-flow redistribution that determines branch overloads. Each delay scenario therefore evolves along a genuinely different trajectory—different overload patterns, different failure sequences, different terminal states—rather than along a rescaled copy of a common delay-free trajectory. The same loop also drives a UFLS rule whose shed depth is a function of the prevailing latency, so that the standard NERC PRC-006-5 single-stage rule is recovered as the zero-delay limit.

**中文.** **嵌入式闭环时延级联框架。** 在每一轮级联内部都计算通信时延，并在决定支路过载的 DC 潮流重分配之前先把它作用到发电机出力上——所以每一种时延场景都沿一条**真正不同**的轨迹演化（不同的过载模式、不同的故障序列、不同的终态），而不是同一条无时延轨迹的等比缩放。同一个闭环也驱动一个**切负荷深度随当前时延变化**的 UFLS 规则；零时延时它退化为标准的 NERC PRC-006-5 单段切负荷规则。

> ⓘ "退化为零时延极限"这一句很重要——审稿人会问"你的新规则是不是覆盖了行业标准"，提前回答即可。

### Contribution 2 — 四组件、角色感知的时延分解

> **EN.** A four-component, role-aware end-to-end delay decomposition. Latency is split into measurement (τ_m), edge processing (τ_e), transmission (τ_t) and actuation (τ_a) components, with role-dependent service times for control centers and ordinary relay nodes, mirroring the asymmetric processing behaviour of SCADA/EMS architectures. Each component is parameterised against an externally defensible reference: NASPI synchrophasor latency guidelines and IEEE C37.118.2 bound τ_m and τ_t, the IEC 61850 PRP/HSR redundancy stack bounds the residual loss probability, and the NERC PRC-002-2 sub-second budget bounds the heaviest scenario we test.

**中文.** **四组件、角色感知的端到端时延分解。** 把端到端时延拆为采集 (τ_m)、边缘处理 (τ_e)、传输 (τ_t)、执行 (τ_a) 四个组件，对控制中心节点与普通中继节点分别设置不同的服务时间，反映 SCADA/EMS 架构本身的非对称处理特性。每个组件都以一个**外部可验证**的参考做参数依据：NASPI 同步相量时延指南与 IEEE C37.118.2 给出 τ_m / τ_t 的取值带；IEC 61850 PRP/HSR 冗余栈给出残余丢包率的上界；NERC PRC-002-2 的亚秒预算给出我们最重场景的上界。

> ⓘ v2 在这条里堆了 6 个标准，v3 砍到 3 个核心标准（NASPI / C37.118.2、IEC 61850 PRP、NERC PRC-002-2）。其余两个（CIP-012、PRC-006-5）放到正文 Methods 里使用时再引——不在 Introduction 一次性堆完。

### Contribution 3 — 三机制控制效能函数 η⁺

> **EN.** A three-mechanism control-efficacy function η⁺ = Φ_loss · Φ_sat · Φ_crit. Delay-induced generator-control loss is decomposed into three orthogonal mechanisms with separately tunable parameters: redundancy-attenuated message loss (Φ_loss), continuous controller saturation under elevated τ_m+τ_e (Φ_sat) and a normalised collapse near each machine's critical delay τ_crit,i (Φ_crit, normalised so that η⁺(τ=0)=1 exactly). Because the three mechanisms are orthogonal in parameter space, any observed vulnerability can be attributed to a specific physical channel, rather than absorbed into a single black-box delay penalty.

**中文.** **三机制控制效能函数 η⁺ = Φ_loss · Φ_sat · Φ_crit。** 把时延引起的发电机控制损失分解为三种正交机制：受冗余衰减的丢包 (Φ_loss)、在 τ_m+τ_e 升高下的控制器连续饱和 (Φ_sat)、以及在每台机自身临界时延 τ_crit,i 附近的归一化坍塌 (Φ_crit，归一化使 η⁺(τ=0)=1 严格成立)。三种机制在参数空间正交——任何观察到的脆弱性都可以归因到一个**具体的物理通道**，而不是被吞进一个黑箱时延惩罚里。

> ⓘ "归一化使 η⁺(0)=1 严格成立"是回应审稿人最常问的一句"你的模型在零时延极限下是否可还原"。一句话堵掉。

### Contribution 4 — 双指标 + 非对称惩罚区

> **EN.** Twin resilience metrics that reveal the asymmetric delay-penalty regime and its hidden component. The cascade is evaluated jointly on a supply-conservation ratio R₁ and on a capacity-weighted dispatch-fidelity NRMSE R₃. A delay-penalty heatmap on the (tolerance, cascade-round) plane shows that the damage is largest at moderate-to-high tolerance margins, narrowing the critical intervention window to the early cascade rounds, while R₃ exposes generator-level functional degradation that R₁ alone misses. These results show that delay-free and single-τ robustness models are not merely imprecise but systematically misleading in the operating regime that operators most often rely on.

**中文.** **双弹性指标，揭示非对称惩罚区与其隐藏成分。** 用"供给守恒率"R₁ 与"容量加权调度保真度 NRMSE"R₃ 同时评估级联。在 (容限, 级联轮次) 平面上的时延惩罚热图显示，伤害最大处出现在中-高容限段，并把"关键干预窗口"压缩到了前几轮；与此同时，R₃ 揭示了 R₁ 单独无法发现的发电机层面的功能退化。这些结果表明：无时延与单 τ 鲁棒性模型并非"只是不够精确"，而是**系统性地误导**——尤其在运维人员最常依赖的运行区。

> ⓘ "Not merely imprecise but systematically misleading"——这是 Introduction 的"金句"，给审稿人留下印象的那种。一篇文章一般留 1 句这样的话。

---

## §5 段（章节路线图）

> **EN.** The remainder of this paper is organised as follows. Section 2 presents the CPPS model… Section 3 describes the delay-integrated cascading failure dynamics… Section 4 reports Monte Carlo experiments on the IEEE 39-bus test system coupled to a Barabási–Albert scale-free communication network, covering 1 000 coupling realisations, eleven tolerance levels and the five delay scenarios… Section 5 concludes the paper.

**中文.** 本文余下部分组织如下：第 2 节给出 CPPS 模型，含四组件通信时延刻画与基于介数同配的层间耦合；第 3 节描述时延集成的级联动力学，含 η⁺ 控制效能函数、与时延耦合的 UFLS 规则及五个时延严重程度场景；第 4 节给出 IEEE 39 节点系统耦合 BA 通信网络上的蒙特卡洛实验（1 000 组耦合实现 × 11 个容限 × 5 个时延场景），分析非对称惩罚区、重尾终态分布、R₃ 隐藏退化、轮次干预窗口与缓解动作的灵敏度；第 5 节给出结论。

> ⓘ 这一段是给审稿人"导览"用的——他们多半只读 Abstract + Intro 末段 + Conclusion，所以**实验规模数字必须放在这里再说一遍**。

---

## 附：v3 相对 v2 的"审稿人视角"修改清单

| # | v2 的问题 | 审稿人会怎么吐槽 | v3 的修复 |
|---|---|---|---|
| R1 | Introduction 内用了多个 `\subsection*{...}` 小标题 | "Reads like a thesis chapter, not a journal Introduction." | 删除全部 sub-headings，改回单一连贯叙事 |
| R2 | T0/T1/T2/T3 表格里把"This work"列在 T3 行 | "Self-promotional taxonomy." | **整张表删掉**，缺口用两段散文论证，让它成为逻辑结论 |
| R3 | 列了 5 条贡献 | "The contributions are not focused." | 砍到 4 条，UFLS 折叠成贡献 1 的子句 |
| R4 | 用了一段 `\begin{quote}...\end{quote}` 描述闭环 | "Block quotes look essayistic in an engineering paper." | 改写成一句正式陈述句 |
| R5 | 一段里堆了 6 个标准 | "Excessive name-dropping." | 留 3 个核心标准在 Intro，其余移到 Methods |
| R6 | 没有显式的研究问题 (RQ) | "What hypothesis is the paper actually testing?" | §2 段加入一个明确的 RQ |
| R7 | 声称 T2 模型"misses interaction between channels"，但没有证据 | "Unsupported claim about prior work." | 删去；只说我们做了什么，不说别人没做什么 |
| R8 | 引了 `Xin2024CPPSframework` / `Wang2022CPPS` 卷期未核实 | "Reference metadata appears incorrect." | 删除这两条引用，回退到原 bib 已经有的安全引用 |
| R9 | Highlights / Abstract 没和新贡献对齐 | "Abstract claims X but Introduction claims Y." | 在 v3 文件末尾加注释，告诉作者要改 Highlights 第 5 条和 Abstract 中的"uplink/downlink"那句 |

---

## 我自己**仍然不满意**、值得你或导师再权衡的两点

1. **"hidden degradation that R₁ alone misses"** 这句很有冲击力，但严格意义上它是一个**实验结论**而不是 Introduction 应当先验断言的事——一个挑剔的审稿人会画线说 *"prove this in §4 first."*  
   **取舍**：保留它会让 Introduction 更有 punch；删掉它会更稳。我倾向于**保留**，因为同一句话在 Abstract 已经断言过，Intro 重复一次是合规的。如果导师偏保守，可以在前面加 *"in our experiments,"* 这样一个限定词。

2. **NERC PRC-002-2 / NASPI 的引用形式是 `@misc`**。Elsevier 期刊的部分编辑会要求技术标准用 `@techreport` 或加 URL+访问日期。建议在最终投稿前把 `paper2_refs_v2_additions.bib` 里这几条的格式调成期刊 author guide 推荐的 standard reference 样式（NASPI 的 PDF 是有公开 URL 的，加上去更稳）。

---

## 怎么把 v3 实际接进 paper2_delay_cascade.tex

```bash
# 1) 备份
cp paper2_delay_cascade.tex paper2_delay_cascade.tex.v1bak

# 2) 用 v3 替换 lines 120–218 (整个 \section{Introduction}...至下一 \section 之前)

# 3) 合并 bib
cat paper2_refs_v2_additions.bib >> paper2_refs.bib
# (或在 \bibliography{paper2_refs,paper2_refs_v2_additions} 同时写两个)

# 4) 按 v3 文件末尾的注释微调 Highlights 第5条和 Abstract 一句话
```
