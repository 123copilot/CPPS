# `paper2_intro_v3.md` — Introduction（按"三层递进"重写）· 思路 + 草稿

> 目标：替换 `els-cas-templates/els-cas-templates/paper2_delay_cascade.tex`
> 第 120–218 行。
> 这一稿严格按你的口径："绝大部分文章建模 CPPS 不考虑时延 → 少部分考虑了但
> 不像我们这样对每一类时延做精细分析 → 我们的精细化方案"。
> 真实文献已通过 web 检索定位（见 §C），不再是占位符。

---

## A. 重写思路（这次按你的逻辑——三层递进，不再把 4 个创新点平铺）

### A.1 全文骨架 = 一条对比的"漏斗"

```
        全部 CPPS 级联文献  (~100% 建模物理 + 拓扑级 cyber 互依)
                  │
                  │ ① 第一道筛：是否把"通信时延"作为变量进入模型？
                  ▼
   ─────  绝大部分：完全不建模时延（拓扑互依、纯 0/1 通信）  ───── 立第一道靶
                  │
                  │ ② 第二道筛：时延是否被分解到链路 / 路径 / 方向 / 角色 / 闭环？
                  ▼
   ─────  少部分考虑了，但停留在"单一标量时延"或"端到端总时延"  ───── 立第二道靶
                  │
                  │ ③ 我们的位置：把时延一刀刀切开
                  ▼
   ─────  本文：链路级 (T = S/R + d/V) →
                上下行非对称 (S_up=8192 vs S_down=2048 bit) →
                角色相关转发 (τ_CC^fwd vs τ_nonCC^fwd) →
                端到端逐 hop 聚合 →
                每一轮 DCPF 之前注入 η⁺ → 形成闭环  ───── 我们的差异
```

每一层只回答一个问题：**"和谁比？比出来什么差距？我们补上了什么？"**

### A.2 段落分配（5 段，比 v2 短 / 更聚焦）

| 段 | 任务 | 对应"漏斗"位置 | 主要引用 |
|---|---|---|---|
| ¶1 | 30-字背景：CPPS 是什么、为什么时延重要 | 漏斗顶 | Rinaldi01, Buldyrev10 |
| ¶2 | **第一层批评**：绝大多数 CPPS 级联模型完全不建模时延（拓扑互依派 + 容量裕度派），通信只是 0/1 | 立第一道靶 | Buldyrev10, Parshani10, Motter02, Kinney05, Gao12, Brummitt12 |
| ¶3 | **第二层批评**：少数考虑了时延，但只用单一标量（端到端总时延 / 拓扑路径长度 / 单步决策延迟），没有按链路 / 方向 / 角色分解 | 立第二道靶 | Falahati14, Cai21, Atat22, Wei23, Zhang24 |
| ¶4 | **我们的方案**：把时延分到链路级 → 上下行非对称 → 角色相关 → 路径聚合 → 每轮 DCPF 闭环注入 η⁺；评估方案概述 | 落到我们的位置 | （内部代码 + ChenTu26 前作） |
| ¶5 | **Contributions**（按三层递进顺序写 3 条而不是 4 条），收 roadmap | — | — |

注意三处刻意收窄，相比 v2：
- **从 4 条收到 3 条 contribution**：分别对应"嵌入闭环 / 分解到链路-方向-角色 /
  双指标 + 热图归因"。把 v2 里的"α 四联杠杆"降级为 §3 的实现细节，不在 intro
  里抢戏——你的核心叙事是"时延的分级精细化建模"，α 杠杆是手段不是主题。
- **删掉 intro 里的公式**：η⁺ = Φ_sat·Φ_loss·Φ_crit 留到 §3 第一次出现，让
  intro 更像导言而不是预览。
- **¶3 的"标量延迟"批评要点名到具体论文类型**：才能落地"和别人比"。

### A.3 关键叙事句（先把核心论证句子定下来）

- (¶2 收尾) *"In all of these works, the communication layer is rendered as a
  static, binary substrate: a link is either present or absent, and the time
  cost of using a present link is implicitly zero."*
- (¶3 收尾) *"In each of these works the entire latency budget is collapsed
  into a single scalar — most often an end-to-end delay applied uniformly to
  every control action — so that the question of which physical mechanism
  (serialization, propagation, queueing, role-dependent processing,
  uplink-vs-downlink asymmetry) actually drives the damage cannot, by
  construction, be answered."*
- (¶4 leading) *"This paper takes the opposite path: we do not collapse
  delay into a scalar; we slice it open."*

这三句是每段的"钉子"，写的时候先把它们定住，剩下的论述围绕它们填充。

### A.4 写作纪律（同 v2，但更克制）

- intro 仅 ≈ 1.0 页 CAS 双栏（v2 偏长，~1.7 页）。
- 全文 `\citep` / `\citet`，不用 `\cite`。
- intro 里**完全不放公式**（你没要求要展示公式，把它留给 §2/§3，更突出
  "对比"主题）。
- 保留 `ChenTu2026` 前作引用 1 句。

---

## B. 新版 §1 Introduction（LaTeX，可整段替换 `paper2_delay_cascade.tex` 第 120–218 行）

```latex
%% ====================================================================
%%  SECTION 1 — INTRODUCTION  (rewritten 2026-05; "three-layer funnel"
%%  framing — most CPPS models ignore delay; a few include it as a
%%  scalar; we decompose it per link / direction / role / cascade round.)
%% ====================================================================
\section{Introduction}\label{sec:intro}

The continuing digitalization of power infrastructure has turned
conventional grids into cyber-physical power systems (CPPS), in which
a physical energy-delivery layer and a cyber sensing-and-control layer
operate as a tightly coupled whole \citep{Rinaldi2001,Buldyrev2010,%
Ouyang2014}.  Wide-area measurement systems, supervisory control and
data acquisition, and remedial action schemes all rely on the
real-time exchange of measurements and dispatch commands between
substations and one or more control centers (CCs).  This integration
sharpens situational awareness under normal operation, but under
stress it makes communication \emph{timing}---not merely communication
\emph{availability}---a first-order determinant of whether a developing
disturbance is contained or amplified into a cascade.

Despite this, the overwhelming majority of CPPS cascading-failure
studies do not model communication delay at all.  The classical
interdependent-network line of work
\citep{Buldyrev2010,Parshani2010,Gao2012,Brummitt2012} treats the
cyber layer as a static graph in which a link is either present or
absent, and propagates failures across the inter-layer boundary
through binary node-functionality conditions; the time cost of
\emph{using} a surviving link is implicitly zero.  The complementary
line based on overload redistribution and the
$C=(1+\alpha)L_0$ tolerance margin
\citep{Motter2002,KinneyEPL2005,DobsonChaos2007} likewise assumes that
every control or protection action is executed instantaneously after
the operating point changes.  Reviews of the field reach the same
conclusion: although communication latency is widely acknowledged as
an emerging vulnerability, it is rarely incorporated into the
cascade-propagation model itself \citep{Islam2023,Ouyang2014}.  The
practical consequence is that every delay scenario that one might wish
to compare collapses into a single delay-free trajectory, and the
question of how communication timing reshapes the cascade cannot even
be posed.

A smaller but growing body of work has recognized this gap and begun
to introduce communication delay into the analysis.  Falahati \emph{et
al.}\ embed an end-to-end delay into a CPPS reliability evaluation as
an aggregate latency budget that scales an outage-probability factor
\citep{Falahati2014}.  Cai \emph{et al.}\ incorporate a transmission
delay derived from the post-failure shortest-path length in the
communication layer to drive a cascading-failure indicator
\citep{Cai2021}.  Atat \emph{et al.}\ combine partition-based
mitigation with a congestion-induced latency penalty applied to
inter-partition control flows \citep{Atat2022}.  Wei \emph{et al.}\
inject a delay term into the reward of a deep
reinforcement-learning load-shedding agent so that delayed actions
are penalized at decision time \citep{Wei2023}.  These studies are
important precisely because they break with the delay-free convention,
yet in each of them the entire latency budget is collapsed into a
\emph{single scalar}---most often an end-to-end value applied
uniformly to every control action.  The serialization
($S/R$) and propagation ($d/V$) components are not separated; the
asymmetry between uplink measurement traffic and downlink command
traffic is not modeled; the difference between processing latency at
a control-center node and at an ordinary relay node is not modeled;
and the latency itself does not feed back into the cascade
flow-redistribution that produces it.  In effect, delay is read off
the network but never \emph{anatomized}, so the dominant physical
mechanism behind the observed degradation cannot be attributed to a
specific component.

This paper takes the opposite path: we do not collapse delay into a
scalar, we slice it open and re-inject the slices into every cascade
round.  At the link level, the per-hop delay is computed as
$T_{\text{link}} = S/R + d/V$ from the packet size, link rate, link
distance, and propagation speed, exposing the serialization and
propagation channels separately.  At the directional level, uplink
measurement packets and downlink command packets carry different
payload sizes and therefore experience different serialization
delays even on the same physical link.  At the node level, control
centers and ordinary relay nodes contribute role-dependent service
and forwarding latencies, capturing the asymmetric processing that
distinguishes a SCADA-class CC from a passive relay.  These
components are aggregated along multi-hop paths into per-generator
uplink delay $\tau_{m,i}$ and downlink delay $\tau_{e,i}$, which are
then converted into a control-efficiency factor $\eta_i^{+}$ and
applied to every surviving generator's reference output \emph{before}
the next DC power flow.  The cascade therefore evolves under a
delay-shaped power flow rather than a delay-free one, and the
flow-redistribution that follows in turn alters the surviving
communication topology and the next round's link, directional, and
role-level delays --- closing a feedback loop that no scalar-delay
model can express.  The framework is exercised on the IEEE 39-bus
power grid coupled to a Barab\'{a}si--Albert scale-free communication
network with control centers placed by a Multi-attribute Structural
Importance Score; five graded delay scenarios are anchored to
documented operating regimes (IEEE C37.118.1 PMU streams, IEC
61850-90-5 class M2/M3, the NASPI cross-region P95 band, and roughly
$60\%$ of the NERC PRC-002-2 upper bound), and robustness is
jointly measured by a delay-adjusted load-retention ratio $\Rone$
and a capacity-weighted dispatch-deviation metric $\Rthree$ across
$1\,000$ Monte Carlo realizations and eleven values of the tolerance
margin~$\alpha$.  Our prior work \citep{ChenTu2026} established the
distributed-CC cascading framework on which this study builds, but
did not model communication delay's influence on generator control
during the cascade --- the present paper fills exactly this gap.

The contributions of this paper, organized along the same
``layer-by-layer'' progression as the literature review above, are
as follows.

\begin{enumerate}
\item \textbf{From delay-absent to delay-driven cascading.}  In
  contrast to the dominant interdependent-network and
  overload-redistribution lines of CPPS cascading work
  \citep{Buldyrev2010,Motter2002,Gao2012,Brummitt2012}, which propagate
  failures under instantaneous communication, we embed communication
  delay as an endogenous driver of every cascade round and close the
  loop by which delay degrades generation, generation degrades flow,
  flow degrades the cyber topology, and the degraded topology
  degrades delay.

\item \textbf{From scalar end-to-end delay to a per-link, per-direction,
  per-role decomposition.}  In contrast to delay-aware studies that
  use a single aggregate latency variable
  \citep{Falahati2014,Cai2021,Atat2022,Wei2023}, we resolve delay into
  link-level serialization and propagation channels, into asymmetric
  uplink measurement and downlink command paths, and into
  role-dependent service latencies for control-center versus relay
  nodes, so that the dominant mechanism behind any observed
  degradation can be physically attributed rather than aggregated
  away.

\item \textbf{Mechanism attribution through dual robustness metrics
  and per-round heatmaps.}  We jointly report a system-level
  delay-adjusted load-retention ratio $\Rone$ and a generator-level
  capacity-weighted dispatch-deviation metric $\Rthree$ as terminal
  scalars, per-round cumulative trajectories, and
  $(\alpha,\text{round})$ heatmaps; this exposes a hidden form of
  functional degradation invisible to load-based metrics alone, and
  localizes the delay penalty to the moderate-to-high tolerance and
  late-cascade-round regime where delay-free analysis offers the
  greatest --- and most misleading --- reassurance.
\end{enumerate}

The remainder of this paper is organized as follows.
Section~\ref{sec:model} presents the CPPS model, including the
role-aware bidirectional delay decomposition and the
betweenness-assortative coupling.  Section~\ref{sec:cascade}
describes the delay-integrated cascading dynamics and the
closed-loop feedback mechanism.  Section~\ref{sec:experiment}
reports Monte Carlo results, mechanism attribution, and the
asymmetric delay-penalty regime.  Section~\ref{sec:conclusion}
concludes the paper.
```

---

## C. 引用清单（已通过 web 检索确认存在；标 *new* 的需要补到 `paper2_refs.bib`）

| 引用键 | 状态 | 出处 / 在 intro 里干什么 |
|---|---|---|
| `Rinaldi2001` | 已在 bib | ¶1 CPPS 概念 |
| `Buldyrev2010` | 已在 bib | ¶1 + ¶2 第一层批评（拓扑互依、无时延）|
| `Ouyang2014` | 已在 bib | ¶1 + ¶2 综述支撑 |
| `Gao2012` | 已在 bib | ¶2 |
| `Brummitt2012` | 已在 bib | ¶2 |
| `Motter2002` | 已在 bib | ¶2 容量裕度派 |
| `DobsonChaos2007` | 已在 bib（即 `Dobson2007`） | ¶2 |
| **`Parshani2010`** *new* | 待补 | Parshani, Buldyrev, Havlin, *PRL* 105 (2010) 048701 — 拓扑互依经典续作，最常被引为"零时延 cyber 层"代表 |
| **`KinneyEPL2005`** *new* | 待补 | Kinney et al., *EPJ B* 46 (2005) 101–107 — 给 C=(1+α)L₀ 一个电网型经典引用 |
| **`Islam2023`** *new* | 待补 | Islam et al., *Front. Energy Res.* 11:1095303 (2023) — 综述，明确指出"延迟很少被纳入级联模型本身"，给 ¶2 提供"综述也这么说"的力证 |
| **`Falahati2014`** *new* | 待补 | Falahati, Fu, *IEEE Trans. Smart Grid* 5(3):1515–1524 (2014) — 第二层批评第一例：把端到端时延做成 outage probability 标量 |
| **`Cai2021`** *new* | 待补 | "A Cascading Failure Model Considering Operation Characteristics of the Communication Layer"（DOAJ/ResearchGate ~2021）— 用最短路长导出单一传输延迟 |
| **`Atat2022`** *new* | 待补 | Atat et al., *IEEE Trans. Smart Grid* (2022) — 拥塞延迟 + 分区缓解，单 scalar |
| **`Wei2023`** *new* | 待补 | Wei et al., *Electronics* 12(14):3024 (2023) — DRL 单步延迟惩罚 |
| **`Zhang2024SFC`** *new*（仅在 ¶3 备用，目前草稿没用到，可不补） | 备用 | Risk-Balanced SFC Routing, *Energy Engineering* 121-9 (2024) |
| `ChenTu2026` | 已在 bib | ¶4 末段，前作传承 |

> 说明：`paper2_refs.bib` 当前位置见 `els-cas-templates/els-cas-templates/`。
> 我下一轮可以一次性补完 6 条新条目（标 *new*）。所有评价用语都保持温和
> （"collapse delay into a scalar"、"do not separate"），不直接说同行错。

---

## D. 与 v2 相比的关键差异（一句话总结）

| 维度 | v2 | v3（本稿） |
|---|---|---|
| 主线 | 4 个并列创新点 (C1–C4)，把 α 四联杠杆推到头号 | **3 段递进**：不建模 → 标量建模 → 我们分解；α 降为实现细节不进 intro |
| 长度 | ~1.7 页 | ~1.0 页 |
| intro 里的公式 | 1 个 (η⁺ 乘积式) | 0 个，更聚焦"对比" |
| 引用 | 11 旧 + 3 新 | 8 旧 + 6 新（Parshani10, Kinney05, Islam23, Falahati14, Cai21, Atat22, Wei23），每条都对应一个具体被对比的工作 |
| 你的核心诉求"时延分级精细化"是否前置 | 否（藏在 C2 里） | **是**，¶3 + ¶4 就是它，并明确点出"S/R + d/V / 上下行非对称 / CC vs relay 角色 / 闭环" |

---

## E. 等你拍板的事

1. 上面的 **三层漏斗 (¶2 不建模 → ¶3 标量建模 → ¶4 分解 + 闭环)** 框架是不是你要的？
2. **3 条 contribution（不是 4 条）** 是否 OK？把 α 四联杠杆压到 §3 实现细节，
   intro 不抢这条。
3. 是否同意我下一轮**直接补 6 条新 bib 条目**（Parshani10, Kinney05, Islam23,
   Falahati14, Cai21, Atat22, Wei23——其中 Cai21 / Atat22 我会再核一次精确卷期号
   后入库），并用上面 §B 的 LaTeX **替换** `paper2_delay_cascade.tex` 第
   120–218 行？

确认后我一次性提交。
