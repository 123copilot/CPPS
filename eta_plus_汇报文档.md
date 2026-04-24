# 新版时延效率 η⁺ 设计汇报文档

> 面向：组会汇报；目标：用大白话讲清楚 η⁺ 是怎么从单因子升级到四因子的、每个因子的物理含义、数学公式、参数取值依据、与既有时延配置的衔接，以及它在代码里如何被调用。

---

## 1. 为什么要换 η？——从"一根线"到"三根线相乘"

### 1.1 旧版 η（线性）回顾
旧的时延效率公式（保留在 `computePowerDelayEfficiency.m` 中作为对照基线）是
$$
\eta_{\text{legacy}} = (1 - k_m\tau_m)(1 - k_e\tau_e)
$$
- $\tau_m$ ：测量时延（PB→nonCC 上行链路总时延）
- $\tau_e$ ：执行时延（nonCC→PB 下行链路总时延）
- $k_m=0.80$，$k_e=0.60$ ：测量与执行的"敏感度"系数

**它的两大缺点：**
1. **线性**：当 $\tau$ 大到一定程度，$1 - k\tau$ 会变负数，需要硬截断到 0；物理上 η 应该平滑趋近 0，不是突然清零。
2. **只看延迟时长，不看通信路径长短，也不看机组大小**：所有发电机被一视同仁地折算，无法体现"小机组本来就更怕时延"、"路径越长丢包越多"等真实工程现象。

### 1.2 新版 η⁺ 的核心想法
把"为什么时延会让发电机出力打折扣"拆成三个独立的物理机制，每个机制各自给出一个 [0,1] 之间的因子，**相乘**得到最终 η⁺：

$$
\boxed{\;\eta^{+} \;=\; \Phi_{\text{sat}} \cdot \Phi_{\text{loss}} \cdot \Phi_{\text{crit}}\;}
$$

| 因子 | 含义（大白话） | 类比 |
|------|----------------|------|
| $\Phi_{\text{sat}}$ | "时延越长，控制越跟不上趟，但有一段死区可以容忍" | 汽车油门踩下去到发动机响应有延迟；延迟越长，能拉的功率比例越小 |
| $\Phi_{\text{loss}}$ | "信息要走很多跳通信节点才能到，跳数越多越容易丢包" | 接力赛跑越多人交接，掉棒的总概率越大 |
| $\Phi_{\text{crit}}$ | "小机组本来出力就少，时延一长更容易直接掉" | 小水管比大水管更怕水压波动 |

三者相乘，物理意义就是 **"信号能及时到 × 信号没丢 × 机组扛得住" = 能用上的功率比例**。

---

## 2. 三个因子的数学公式与参数

### 2.1 $\Phi_{\text{sat}}$ ：指数饱和因子（"时延久了控制饱和"）

$$
\Phi_{\text{sat}}(\tau_m,\tau_e) \;=\; \exp\!\Big(-a_m\,\max(0,\tau_m-\tau_{m0}) \;-\; a_e\,\max(0,\tau_e-\tau_{e0})\Big)
$$

**参数含义与代码取值（`createDelayConfig.m:50-53`）：**

| 符号 | 代码字段 | 取值 | 单位 | 物理依据 |
|------|----------|------|------|---------|
| $a_m$ | `eta_plus.a_m` | **1.5** | 1/s | 测量回路的衰减"曲率"。控制环带宽对应的半衰时延约 0.5s，理论值 ln2/0.5≈1.39；取 1.5 略高，目的是把 baseline 与 heavy 之间的差距撬开 |
| $a_e$ | `eta_plus.a_e` | **1.2** | 1/s | 执行回路对应的衰减曲率，比 $a_m$ 略小，体现"测量比执行更敏感"的工程经验 |
| $\tau_{m0}$ | `eta_plus.tau_m0` | **0.05** | s | 测量死区：PMU 采样周期的典型 50ms |
| $\tau_{e0}$ | `eta_plus.tau_e0` | **0.05** | s | 执行死区：执行机构动作死区的典型 50ms |

**大白话：** 当 $\tau \le 50$ms（死区内），$\Phi_{\text{sat}}=1$，时延对系统没影响；超出死区后开始指数衰减。

**数值示例：**
- $\tau_m = \tau_e = 0$（no_delay）：$\Phi_{\text{sat}} = e^{0} = 1.000$
- $\tau_m = 67.5$ms，$\tau_e = 75.5$ms（light）：$\Phi_{\text{sat}} = \exp(-1.5\cdot0.0175-1.2\cdot0.0255) = e^{-0.057} \approx 0.945$
- $\tau_m = 472$ms，$\tau_e = 528$ms（heavy）：$\Phi_{\text{sat}} = \exp(-1.5\cdot0.422-1.2\cdot0.478) = e^{-1.207} \approx 0.299$

---

### 2.2 $\Phi_{\text{loss}}$ ：跳数累积可靠性因子（"信息走得越远越容易丢"）

$$
\Phi_{\text{loss}}(n_{\text{hops}}) \;=\; (1 - p_{\text{hop}})^{n_{\text{hops,total}}}
$$

**参数含义与代码取值（`createDelayConfig.m:57`）：**

| 符号 | 代码字段 | 取值 | 物理依据 |
|------|----------|------|---------|
| $p_{\text{hop}}$ | `eta_plus.p_hop` | **0.03** | 电力骨干通信网受扰条件下单跳丢包率的中位取值（文献区间 1%–10%） |
| $n_{\text{hops,total}}$ | 实时计算 | 上行 + 下行的总跳数 | 由 cyber 路径的节点数减 1 累加 |

代码中实现位置 `cascadeLogicdebug2gudingCC_bet_8.m:545-547`：
```matlab
n_hops_up   = max(0, numel(best_up_path_g)   - 1);
n_hops_down = max(0, numel(best_down_path_g) - 1);
n_hops_total_g = n_hops_up + n_hops_down;
```

**大白话：** 每跳成功率 97%，跳数越多累积成功率越低。

**数值示例：**
- 4 跳：$0.97^4 \approx 0.885$（信息能完整送达 88.5%）
- 8 跳：$0.97^8 \approx 0.784$（信息能完整送达 78.4%）

> **关键说明：** $\Phi_{\text{loss}}$ 与时延场景无关，只看路径拓扑。这就解释了为什么即便在 no_delay 场景下，R₁ 也不能达到 100%——因为通信路径本身仍有跳数。

---

### 2.3 $\Phi_{\text{crit}}$ ：异质 logistic 临界因子（"小机组更怕时延"）

$$
\Phi_{\text{crit}}(\tau_m,\tau_e\,;\,r_i) \;=\; \frac{1}{1 + \exp\!\Big(\beta\cdot\dfrac{(\tau_m+\tau_e) - \tau_{\text{crit},i}}{\tau_{\text{crit},i}}\Big)}
$$

其中 **临界总时延** 与机组规模相关：
$$
\tau_{\text{crit},i} \;=\; \tau_{\text{crit,max}}\cdot r_i,\qquad
r_i \;=\; \frac{P_{g,i}}{\max_j P_{g,j}} \quad(\text{方案 A：极值归一化})
$$

**参数含义与代码取值（`createDelayConfig.m:62-64`）：**

| 符号 | 代码字段 | 取值 | 物理依据 |
|------|----------|------|---------|
| $\tau_{\text{crit,max}}$ | `eta_plus.tau_crit_max` | **0.8** s | WAMS 文献里"最大机组耐受时延"上限的 0.7–1.0s 中点 |
| $\beta$ | `eta_plus.beta` | **6** | logistic 陡峭度，6 表示"穿过临界点附近 0.2s 区间内 η 从 0.7 跌到 0.05" |
| $r_{\min}$ | `eta_plus.r_min` | 0.05 | 防止极小机组造成 0/0；case39 实际 $r_i\in[0.25,1.0]$ 不会触发 |
| $r_i$ | 实时计算 | $P_{g,i}/\max_j P_{g,j}$ | 方案 A：以全网最大机组为分母 |
| $P_{g,i}$ | `mpc.gen(gIdx, 2)` | 各机组参考有功 | 直接读 `mpc` |

代码实现位置 `computeEtaPlus.m:79-91`，调用位置 `cascadeLogicdebug2gudingCC_bet_8.m:548-550`：
```matlab
P_g_ref_i = mpc.gen(gIdx, 2);   % 第 i 台机组参考有功
eta_g = computeEtaPlus(tau_m_g, tau_e_g, n_hops_total_g, P_g_ref_i, P_g_ref_max_for_eta, delay_cfg);
```

**大白话：** 每台机组都有自己的"耐受总时延" $\tau_{\text{crit},i}$。这个耐受度跟它的体量成正比——大机组（$r_i=1$）耐受 0.8s，小机组（$r_i=0.3$）只耐受 0.24s。一旦实际总时延超过自己的耐受度，η 就会以 logistic 形式急剧崩塌。

**数值示例（case39，最大机组 bus 39 的 $P_g=1000$ MW，所以分母 $\max_j P_{g,j}=1000$）：**

| 机组 | $P_{g,i}$ (MW) | $r_i$ | $\tau_{\text{crit},i}$ (s) | heavy 下 $\tau_m+\tau_e=1.0$s 时的 $\Phi_{\text{crit}}$ |
|------|---------------|-------|---------------------------|----------------------------------------------------|
| 大机组 | 1000 | 1.0 | 0.80 | $1/(1+e^{6\cdot 0.25})=1/(1+4.48)\approx 0.183$ |
| 中机组 | 600 | 0.6 | 0.48 | $1/(1+e^{6\cdot 1.083})=1/(1+667)\approx 0.0015$ |
| 小机组 | 300 | 0.3 | 0.24 | $1/(1+e^{6\cdot 3.167})\approx 5.4\times10^{-9}$ ≈ 0 |

**核心结论：** heavy 场景下，**小机组的 $\Phi_{\text{crit}}\approx0$**，等价于"小机组实际出力清零"，这就是"异质性"的来源。

---

## 3. η⁺ 与既有时延配置（tuesday.md）的衔接

新 η⁺ **完全没有抛弃** 之前定义的时延体系，而是把它作为 $\tau_m,\tau_e$ 的输入：

```
                                     ┌──────────────────────────┐
   (已有的 cyber 路径模型)            │       η⁺ 计算              │
   computeCyberPathDelay            │                          │
   ├─ link_delay_sum (传输+传播)    │  Φ_sat(τ_m,τ_e)          │
   ├─ endpoint_delay (tx+rx)       ─┤  Φ_loss(n_hops_total)    │  → η⁺ ∈ [0,1]
   └─ forward_delay_sum            │  Φ_crit(τ_m,τ_e ; r_i)   │
                                    └──────────────────────────┘
   τ_m = pb_to_noncc_measurement_delay_s + cyber_up_delay
   τ_e = noncc_to_pb_execution_delay_s   + cyber_down_delay
   n_hops_total = (上行节点数-1) + (下行节点数-1)
   r_i = P_g(i) / max_j P_g(j)
```

各场景下的 $\tau_m,\tau_e$ 仍由 `createDelayScenarioConfigs.m` 通过 scale (no_delay=0, light=0.5, baseline=1.0, medium=2.0, heavy=3.5) 缩放得到，**与之前完全一致**；η⁺ 只是把这些 τ 喂给三个因子做更精细的折算。

---

## 4. η⁺ 在代码与项目中的作用

### 4.1 代码调用链

```
bet_homo_gudingCC_myself_bet_8.m  (主驱动)
   └─→ createDelayConfig.m         (eta_model='etaplus' 默认)
   └─→ createDelayScenarioConfigs  (生成5个时延场景)
   └─→ cascadeLogicdebug2gudingCC_bet_8.m  (级联仿真)
            ├── (每轮内)对每个发电机算路径 → τ_m, τ_e, n_hops
            └── computeEtaPlus(τ_m, τ_e, n_hops, P_g_ref_i, P_g_ref_max, delay_cfg)
                   ├── Φ_sat
                   ├── Φ_loss
                   └── Φ_crit
                   → η⁺ → mpc_sur.gen(gIdx,2) *= η⁺ → DC 潮流重分布
   └─→ computeDelayAdjustedR1     (用幸存机组的 ΣP_actual/ΣP_ref 作为 R1 折扣)
   └─→ computeCascadeR3Metric     (R3 也走相同的 η⁺ 路径)
```

### 4.2 为什么 R₁ 的计算要走 η⁺
- 对每台幸存机组，把参考出力 $P_{g,i}$ 按 $\eta_i^+$ 折扣 → $P_{\text{actual},i}$
- 全网汇总：$\varphi = \min(1,\sum P_{\text{actual}}/\sum P_{\text{ref}})$
- 最终：$R_1^{\text{delay}} = R_1^{\text{base}} \times \varphi$
- 这样保证"通信时延 → 机组出力损失 → 负荷未供 → R₁ 下降"的因果链是闭合的

### 4.3 切换开关
通过 `createDelayConfig.m:43` 的 `delay_cfg.power.eta_model` 字段切换：
- `'etaplus'` ：使用四因子 η⁺（论文最终方案）
- `'legacy'` ：退回旧线性公式（用作回归对比）

---

## 5. 一组完整的数值例子（贯穿全部因子）

**场景：** baseline，case39 中的中等机组 ($P_g=600$ MW)，cyber 路径上行 4 跳、下行 4 跳，$\tau_m=135$ms，$\tau_e=151$ms。

1. $\Phi_{\text{sat}} = \exp(-1.5\cdot(0.135-0.05) - 1.2\cdot(0.151-0.05)) = \exp(-0.1275 - 0.1212) = e^{-0.249} \approx 0.780$
2. $\Phi_{\text{loss}} = (1-0.03)^8 \approx 0.784$
3. $r_i = 600/1000 = 0.6 \Rightarrow \tau_{\text{crit},i} = 0.8\cdot0.6 = 0.48$s
   - $(\tau_m+\tau_e) - \tau_{\text{crit},i} = 0.286 - 0.48 = -0.194$s
   - $\arg = 6\cdot(-0.194)/0.48 = -2.425 \Rightarrow \Phi_{\text{crit}} = 1/(1+e^{-2.425}) \approx 0.919$
4. $\eta^+ = 0.780\times 0.784\times 0.919 \approx \mathbf{0.562}$
5. 该机组实际出力 $P_{\text{actual}} = 600 \times 0.562 = 337$ MW

---

## 6. 与旧 η 的对比一览（同样的中等机组、baseline）

| 量 | 旧 η（legacy） | 新 η⁺ | 差异说明 |
|----|---------------|--------|---------|
| 计算公式 | $(1-0.8\cdot0.135)(1-0.6\cdot0.151)$ | $\Phi_{\text{sat}}\Phi_{\text{loss}}\Phi_{\text{crit}}$ | — |
| 数值 | $0.892 \times 0.909 = 0.811$ | $0.780\times0.784\times0.919 = 0.562$ | 新版偏低，引入了路径丢包+异质阈值 |
| 物理可解释性 | 单一线性折扣 | 三个独立机理可拆分分析 | 新版更适合写论文做敏感性分析 |
| heavy 时小机组 | $\approx 0.43$ | $\approx 0$ | 新版能体现"小机组在重时延下崩溃" |

---

## 7. 一句话总结

> **η⁺ 把原来"一刀切的线性折扣"升级成"控制饱和 × 通信丢包 × 机组耐受"三个机理的乘积**：每个机理都有清晰的物理含义、独立的可调参数、明确的工程对应物，并且在代码中通过 `computeEtaPlus.m` 集中实现、由 `createDelayConfig.m:43` 的开关一键切换，既能服务于论文（解释"为什么时延会有这种破坏模式"），又方便后续按因子设计针对性的工程缓解动作（每个动作只改一种因子）。

---

*文档生成日期：2026-04-24*
*对应代码版本：`computeEtaPlus.m`、`createDelayConfig.m:43-64`、`cascadeLogicdebug2gudingCC_bet_8.m:540-560`、`computeCascadeR3Metric.m:155-173`*
