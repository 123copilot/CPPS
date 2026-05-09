# `paper2_intro_v2.md` — Introduction (重写) · 思路 + 全新草稿

> 目标稿件：`els-cas-templates/els-cas-templates/paper2_delay_cascade.tex`
> 期刊模板：Elsevier CAS double-column (`cas-dc.cls`)，author-year 引用
> （`cas-model2-names.bst`，宏 `\citep` / `\citet`）。
> 本文件 = 重写思路（A）+ 可直接替换 §1 的 LaTeX 全文（B）+ 待补的 bib 键
> （C）。代码态以 `bet_homo_gudingCC_myself_bet_8.m`、`computeEtaPlus.m`、
> `createDelayConfig.m`、`cascadeLogicdebug2gudingCC_bet_8.m`、
> `computeR3Deviation.m` 当前主分支为准。

---

## A. 重写思路（先和你对齐写作逻辑）

### A.1 为什么必须重写

仓库里其实已经有两份风格不同的"导言原料"——

| 文档 | 关键状态 |
|---|---|
| `paper2_delay_cascade.tex:120-218`（在审版） | 仍写"two degradation channels"（连续 η 侵蚀 + 离散可达性崩溃），与代码里 **三通道** η⁺ = Φ_sat·Φ_loss·Φ_crit **直接矛盾**；α 仍只是一个容量裕度参数 |
| `paper_draft_v3.md:11-28`（早期 markdown 草稿） | 已升级到三通道 η⁺ + α 三联杠杆 + UFLS 切除帽 α-耦合，但 (1) 用了 `[Lit-XXX]` 占位符没真引文献；(2) 与"其他文章如何对比"这条主线交代得不清晰 |

我们这一稿要做三件事：
1. **跟代码彻底对齐**：所有 contribution 都能在仓库里找到具体函数 / 行号支撑。
2. **把"和别人的对比"这条主线说清楚**：每一段落都明确指出"prior X 做到这里→
   仍缺什么→我们补上什么"，让审稿人一眼看到差异化。
3. **用 Elsevier CAS 的 LaTeX 风格**写出来，可以直接拷贝替换在审稿件第 120–218 行。

### A.2 创新点 → 对比对象 → 段落映射（核心思路）

这是这次写作的"骨头"。每一行 = 我们的一个创新点 = 一段 intro 的一个论证回合。

| # | 我们的创新点 (C-i) | 我们用什么 prior-work 类型来"立靶子"对比 | 体现在第几段 / 哪条 contribution | 代码出处 |
|---|---|---|---|---|
| **C1** | 把延迟从"事后的观察量"升格为"嵌入每一轮 DCPF 之前的因果驱动量"，形成**闭环反馈**：延迟↓发电→功流重分布→线路跳→拓扑退化→延迟↑ | (a) **拓扑型互依级联**（Buldyrev10 / Gao12 / Brummitt12）：通信链路只有 0/1，没有时序质量；(b) **后处理型延迟**（Lai et al. 类，把延迟当作一个对终端 metric 的乘性折扣）；(c) **DRL 单步缓解**（Wang 2023 MDPI Electronics 等）：只把延迟塞在某一个 mitigation 决策环节，不进入级联流程本身 | ¶2 + ¶3 + Contribution 1 | `cascadeLogicdebug2gudingCC_bet_8.m:486-603` 在 DCPF 之前调用 `computeEtaPlus` 折减发电；`bet_homo…:121-321` 逐轮记录 |
| **C2** | **三通道 η⁺ = Φ_sat · Φ_loss · Φ_crit**：饱和/死区 + 并行可靠性 + 暂稳临界，每一通道都锚一项工程标准 | (a) **线性 (1−k_mτ_m)(1−k_eτ_e) 模型**（既有 CPPS 韧性文献最常见的延迟刻画）：单通道、无死区、无暂稳硬墙；(b) **随机时延丢包模型**（队列论 / Markov 链）：刻画通信但不刻画发电控制 | ¶4 + Contribution 2 | `computeEtaPlus.m:1, 96-205`（Φ_sat 死区，Φ_loss 并行 k_eff，Φ_crit 临界 sigmoid）；`createDelayConfig.m:62-95`（PMU/AVR 死区、IEC 61850 PRP / G.8032 / NERC CIP-012 冗余、WAMS 暂稳窗 0.7–1.5 s） |
| **C3 (头号)** | **α 的 cyber-physical 重新解读**：单一 α 同时拨动四件事——(i) 通信冗余度 k_eff(α)，(ii) PMU/AVR 死区 τ_m0/τ_e0(α)，(iii) 暂稳临界窗 τ_crit_max(α)，(iv) UFLS 切除帽 shed_max(α)，并保证 α=0 比特级回归 legacy | (a) **α 仅作为支路容量裕度**（Motter02 起的标准用法）：抹掉了"高 N-k 容量裕度的系统在工程上必然伴随更厚通信冗余、更宽控制死区、更长暂稳容忍"这条 cyber-physical 红利；(b) 把 α 简单设为通信丢包率或路径长度倍数的工作：与物理裕度脱节 | **¶3 完整一段（新增）+ Contribution 3——主推创新点** | `createDelayConfig.m:73-194`（四组 α 增益常数）；`computeEtaPlus.m:14, 100-205`（Φ_loss / Φ_sat / Φ_crit 三处 α 入口）；`cascadeLogicdebug2gudingCC_bet_8.m:555, 631-689`（α 传参 + UFLS shed_max α 耦合） |
| **C4** | **物理锚定的 5 级延迟分级 + UFLS 过切（over-shed）+ R₁/R₃ 双指标 + (α, round) 二维归因热图**：把延迟惩罚的"位置"和"何时发生"也讲清楚 | (a) 现行延迟扫描类工作只报终端单指标 R₁，看不见发电出力跑偏的"隐性退化"；(b) UFLS 通常被建模为"按 0.85/0.10 阶梯切除"或干脆不建，从而让 slack 母线无界吸收 η 缺口 | ¶4 末段方法 + ¶5 经验性陈述 + Contribution 4 | `createDelayScenarioConfigs.m:14-39`（NERC PRC-002-2 60% / NASPI P95 锚定）；`cascadeLogic…:580-689`（UFLS γ_over 与 shed_max(α)）；`bet_homo…:121-130, 211-321, 685-810`（per-round R₁/R₃ + Fig4b 热图）；`computeR3Deviation.m`（容量加权 NRMSE） |

### A.3 段落叙事骨架（6 段，~1.7 页 CAS 双栏）

每段一个"任务"——任务驱动避免水文：

- **¶1 背景一句话**：CPPS 双层耦合 → 必须把韧性分析从"纯拓扑"扩展到"控制环
  时序质量"。3 个奠基引用（Rinaldi01 / Buldyrev10 / Ouyang14）即收。
- **¶2 立第一靶——延迟被当作"事后观察"**：互依级联（Motter02 / Dobson07 /
  Brummitt12）+ 后处理延迟（Lai 类）+ 单步 DRL 缓解（Wang2023）三类共 6–8
  条，结尾**保留**仓库里那段已经被多次采用的反馈环视觉锚点
  `\begin{quote}…\end{quote}`，但把"degraded topology→delay↑→UFLS over-shed"
  这条新链一并写进去。
- **¶3 立第二靶——α 被孤立处理（全新一段，对应主推 C3）**：先承认 Motter02
  以来 α 的标准定义，然后一句话点出"工程实践里 α 同时买到了通信冗余、控制
  死区、暂稳容忍、UFLS 余裕"，引 IEC 61850-90-4 PRP、ITU-T G.8032、NERC
  CIP-012 / PRC-024-3 / PRC-006-5 与 NASPI WAMS Roadmap，把"为什么 α 必须
  cyber-physical 化"这件事说成"既有文献的盲区"。**这段是这一稿与 v3 草稿
  最大的差异化升级**——v3 把 C3 藏在第二段中间，这一稿单独成段并放头号
  contribution。
- **¶4 我们的方法（一段串联 C1+C2+C4）**：把 ¶2 的环用三通道 η⁺ 闭起来；把
  ¶3 的孤立 α 用四联杠杆 + UFLS 帽耦合补完；评估在 IEEE 39-bus + BA 通信
  + MSIS CC 选址 + betweenness-assortative 耦合上做 1000×11×5 MC，5 场景
  锚 NASPI/NERC 区间。**显式声明 α=0 比特级退化到 legacy**——预防"调参刷
  指标"质疑。intro 里只放一条核心公式 η⁺ = Φ_sat · Φ_loss · Φ_crit，其余
  推导留给 §2/§3。
- **¶5 Contributions（4 条）**：用 `\textbf{lead-in.}` 开头，每条对应一个
  C-i，明确取代旧 4 条。
- **¶6 Roadmap**：与现有 `\label{sec:model}/{sec:cascade}/{sec:experiment}/
  {sec:conclusion}` 严格对齐，不引入新的 section label，避免破坏后文交叉引用。

### A.4 写作 / 格式纪律

- 全文英文（与现稿一致；不双语）。
- 引用一律 `\citep` / `\citet`，禁用 `\cite`；删掉 `[Lit-XXX]` 占位符。
- intro 里仅一个公式（η⁺ 的乘积式），其余靠语言。
- 4 条 contribution 用 `\textbf{lead-in.}` 开头，CAS 期刊常见做法。
- `ChenTu2026` 前作引用**保留 1 句**："our prior work … did not model
  delay's influence on generator control" → 既继承叙事又不喧宾夺主。
- 不在 intro 段里堆 IEEE / IEC 标准号（会显得像综述）；把这些标准号留给
  §2 的具体参数表与 §3 的 UFLS 公式。**例外**：¶3 必须点 1–2 条标准号
  来支持 C3 的合理性，这是它的论据。

---

## B. 新版 §1 Introduction（LaTeX，可整段替换 `paper2_delay_cascade.tex` 第 120–218 行）

```latex
%% ====================================================================
%%  SECTION 1 — INTRODUCTION  (rewritten 2026-05; aligned with η⁺
%%  three-channel model and α-as-cyber-physical-lever framing)
%% ====================================================================
\section{Introduction}\label{sec:intro}

The continuing digitalization of power infrastructure has turned the
conventional grid into a cyber-physical power system (CPPS), in which a
physical energy-delivery layer and a cyber sensing-and-control layer
operate as a tightly coupled whole \citep{Rinaldi2001,Buldyrev2010,%
Ouyang2014}.  Wide-area measurement systems, supervisory control and
data acquisition, and remedial action schemes all rely on the
real-time exchange of measurements and dispatch commands between
substations and one or more control centers (CCs).  This integration
improves observability and dispatch flexibility under normal operation,
but under stress it opens a bidirectional failure channel through which
disturbances cross the inter-layer boundary, so that resilience analysis
must move beyond purely topological robustness and explicitly account
for the \emph{timing quality} of the control loop
\citep{Gao2012,Huang2015}.

Existing cascading-failure studies in coupled power--communication
systems can be grouped into three families, none of which closes this
gap.  The first --- topological interdependency models
\citep{Motter2002,Dobson2007,Brummitt2012} --- treats the cyber layer
as a binary entity in which a link is either functional or failed and
delay is absent by construction.  The second --- post-hoc
delay-indicator models \citep{LaiCPPS2019,Milano2012} --- allows the
cascade to unfold under ideal control and only afterwards reports the
path-length increment or the rescaled performance metric, so that every
delay scenario inherits an identical structural failure sequence and
the question of \emph{which} delay components drive the damage cannot
be answered.  The third --- delay-aware single-step mitigation studies,
e.g.\ deep reinforcement-learning load shedding under communication
delay \citep{WangDRL2023} or risk-balanced service-function-chain
routing for cyber--physical control traffic \citep{ZhangSFC2024} ---
embeds delay into one decision-making step but not into the cascade
flow-redistribution loop itself.  In a closed-loop architecture,
however, stale measurements drive the CC to act on outdated state and
lagged commands arrive after the system has drifted further; both
effects reduce the effective generation output relative to its
intended reference, and when this reduction is fed back into the
power flow that determines which branches overload, a self-reinforcing
loop emerges:
\begin{quote}
\emph{Delay reduces generation $\;\to\;$ altered power flows cause
additional overloads $\;\to\;$ overloaded branches trip $\;\to\;$
structural failures degrade the cyber topology $\;\to\;$ degraded
topology increases delay and tightens the under-frequency
load-shedding cap $\;\to\;$ further output reduction
$\;\to\;\cdots$}
\end{quote}
This loop transforms communication latency from a passive symptom of
distress into an active driver of further damage and is invisible to
any model that applies delay as an exogenous scaling factor.

A second, more subtle gap concerns the standard tolerance-margin
parameter~$\alpha$ that scales branch and node capacity through
$C=(1+\alpha)L_0$ \citep{Motter2002,KinneyEPL2005}.  Although $\alpha$
is universally treated as a purely structural quantity, in real
engineering practice a system designed with greater $N{-}k$ capacity
reserves typically also provisions greater communication redundancy
(IEC 61850-90-4 parallel redundancy, ITU-T G.8032 ring protection,
NERC CIP-012 cross-CC backup channels), broader control dead-bands
(IEEE C37.118 PMU reporting cadence, NERC PRC-024 frequency tolerance
windows), wider transient-stability margins (NASPI WAMS roadmap), and
shallower single-stage under-frequency load shedding (NERC PRC-006).
Decoupling~$\alpha$ from these cyber-physical co-benefits hides the
very mechanism by which capacity margin buys the system additional
tolerance against communication delay, and consequently understates the
operational value of $\alpha$ as a planning lever.

This paper closes both gaps within a single delay-driven cascading
framework.  We embed communication delay as an endogenous driver of
every cascade round: before each DC power flow, every surviving
generator's reference output is multiplied by a control-efficiency
factor
\begin{equation}\label{eq:eta-plus-intro}
  \eta_i^{+} \;=\; \Phi_{\text{sat}}(\tau_{m,i},\tau_{e,i})\;\cdot\;
                   \Phi_{\text{loss}}(\tau_{m,i},\tau_{e,i};k_{\text{eff}})\;\cdot\;
                   \Phi_{\text{crit}}(\tau_{m,i}+\tau_{e,i};r_i),
\end{equation}
in which $\Phi_{\text{sat}}$ captures dead-band-bounded measurement
and execution lag, $\Phi_{\text{loss}}$ captures queueing-induced
packet loss aggregated over hop count and parallel cyber-redundancy
paths, and $\Phi_{\text{crit}}$ models the heterogeneous,
unit-capacity-dependent breakdown of generator controllability when
total round-trip latency approaches the unit's transient-stability
tolerance window.  The same tolerance parameter~$\alpha$ that scales
branch and node capacity is then re-used as a quadruple lever onto
the closed loop --- broadening the saturation dead band, lifting the
parallel redundancy degree~$k_{\text{eff}}$, widening the critical
tolerance window, and relaxing an under-frequency-load-shedding
over-shed cap that mirrors the increased frequency-response margin of
higher-reserve systems.  By construction, every history at $\alpha=0$
regresses bit-identically to the legacy single-channel formulation, so
that the reported gains cannot be confounded with parameter retuning.
The framework is evaluated on the IEEE 39-bus power grid coupled to a
Barab\'{a}si--Albert scale-free communication network through a
betweenness-assortative one-to-one mapping, with control centers
placed by a Multi-attribute Structural Importance Score; five graded
delay scenarios are anchored to documented operating regimes (IEEE
C37.118.1 PMU streams, IEC 61850-90-5 class M2/M3, the NASPI
cross-region P95 band, and roughly $60\%$ of the NERC PRC-002-2 upper
bound), and robustness is jointly measured by the delay-adjusted
load-retention ratio~$\Rone$ and the capacity-weighted dispatch
deviation~$\Rthree$ across $1\,000$ Monte Carlo realizations and
eleven values of~$\alpha$.

Our prior work \citep{ChenTu2026} established a CPPS cascading
framework with distributed control centers, a Functional
Viability-Constrained Island Detection mechanism, and a
Cohesion-Propagation Importance Metric for control-center placement,
but did not model communication delay's influence on generator control
during the cascade.  The present paper makes the following four
contributions, each filling one of the gaps identified above.

\begin{enumerate}
\item \textbf{A closed-loop cascade with delay as an endogenous driver.}
  We embed an $\eta_i^{+}$-based control-efficiency reduction in front
  of every DC power flow, so that each delay scenario produces a
  genuinely different cascade trajectory --- different overload
  patterns, different failure sequences, different terminal states ---
  rather than a rescaled version of a common trajectory.

\item \textbf{A multi-channel delay-to-control mapping anchored to
  engineering standards.}  We replace the legacy linear factor
  $(1-k_m\tau_{m,i})(1-k_e\tau_{e,i})$ with the three physically
  grounded channels of \eqref{eq:eta-plus-intro} --- saturation /
  dead-band, queueing-loss reliability with parallel redundancy, and
  capacity-heterogeneous transient-stability collapse --- so that the
  total efficiency reduction is not a tunable scalar but a composition
  of separately measurable physical effects.

\item \textbf{Cyber-physical reinterpretation of the tolerance
  parameter~$\alpha$.}  We redefine $\alpha$ as a quadruple lever that
  simultaneously broadens the saturation dead band, lifts the cyber
  parallel-redundancy degree, widens the critical tolerance window,
  and relaxes the under-frequency-load-shedding over-shed cap --- so
  that $\alpha$ now captures the cyber-physical co-investment that
  high-reserve systems make in practice, while preserving bit-identical
  regression at $\alpha=0$.  To our knowledge this is the first cascade
  framework to put cyber redundancy, control dead bands, transient
  stability margin, and load-shedding aggressiveness under a single
  planning parameter.

\item \textbf{Per-round mechanism attribution and asymmetric
  vulnerability mapping via dual robustness metrics.}  We report
  $\Rone$ (system-level delay-adjusted load retention) and $\Rthree$
  (generator-level capacity-weighted dispatch deviation) jointly, both
  as terminal scalars and as per-round cumulative trajectories and
  $(\alpha,\text{round})$ heatmaps, revealing that the delay penalty
  concentrates asymmetrically at moderate-to-high tolerance margins
  and late cascade rounds --- precisely where delay-free analysis
  predicts safety but delay-burdened systems collapse.
\end{enumerate}

The remainder of this paper is organized as follows.
Section~\ref{sec:model} presents the CPPS model, including the
role-aware bidirectional delay decomposition and the
betweenness-assortative coupling.  Section~\ref{sec:cascade} describes
the delay-integrated cascading dynamics, the inner structural and
outer overload loops, and the $\alpha$-coupled UFLS over-shed
treatment.  Section~\ref{sec:experiment} reports Monte Carlo results,
mechanism attribution, and the asymmetric delay-penalty regime.
Section~\ref{sec:conclusion} concludes the paper.
```

---

## C. 需要追加到 `paper2_refs.bib` 的新键（写完上面 LaTeX 后必须补，不然
编译会报 warning，但不至于 fatal）

| 新 bib key | 已在仓库 / 待补 | 用途 / 出处 |
|---|---|---|
| `Rinaldi2001` | 已有 (`paper2_refs.bib:17`) | ¶1 |
| `Buldyrev2010` | 已有 (`:8`) | ¶1 |
| `Ouyang2014` | 已有 (`:27`) | ¶1 |
| `Gao2012` | 已有 (`:68`) | ¶1 |
| `Huang2015` | 已有 (`:36`) | ¶1 |
| `Motter2002` | 已有 (`:59`) | ¶2, ¶3 |
| `Dobson2007` | 已有 (`:49`) | ¶2 |
| `Brummitt2012` | 已有 (`:77`) | ¶2 |
| `Milano2012` | 已有 | ¶2 |
| `LaiCPPS2019` | 已有 | ¶2 |
| `ChenTu2026` | 已有 | ¶5 |
| **`KinneyEPL2005`** | **待补** | Kinney et al., *Modeling cascading failures in the North American power grid*, EPJ B 46 (2005) 101–107。给 ¶3 里 C=(1+α)L₀ 公式提供更经典的电网型引用，避免只引一篇 PRE。 |
| **`WangDRL2023`** | **待补** | Wang Y. et al., *A DRL-Based Load Shedding Strategy Considering Communication Delay for Cascading Failure Mitigation in Power System*, MDPI Electronics 12 (14) 3024 (2023)。¶2 里"delay-aware single-step mitigation"代表作。 |
| **`ZhangSFC2024`** | **待补** | Risk-Balanced Routing Strategy for Service Function Chains of Cyber-Physical Power System (Tech Science Press, Energy Engineering 121-9, 2024)。¶2 里 closing-the-loop routing 类工作。 |

> 备注：所有 prior-work 评价用语刻意保持温和（"treats delay as an
> exogenous scaling factor"、"embeds delay into one decision-making step
> but not into the cascade flow-redistribution loop itself"），不直接说
> 它们"错"——避免审稿人把对比段读成贬低同行。

---

## D. 等你拍板的 4 件事（一旦确认，下一步直接做）

1. **C3（α 作为 cyber-physical 四联杠杆 + UFLS 耦合）作为头号创新点**——OK 吗？
2. **¶3 单独成段**（强化 C3 主推地位）——OK 吗？v3 草稿是把它塞在 ¶2 中部，
   弱化了。
3. **保留 `ChenTu2026` 前作引用**（1 句）——OK 吗？
4. **是否同意把 `WangDRL2023`、`ZhangSFC2024`、`KinneyEPL2005` 三条新引文加到
   `paper2_refs.bib`**？我可以下一轮直接补完整 bib 条目并替换在审稿件第
   120–218 行，跑一次 LaTeX sanity check。
