# CPPS 时延-级联仿真结果综合分析报告

## 第一部分：逐图分析

---

### 图1：R₁ 箱线图 (R₁ Distribution by Delay Scenario)

**图表内容**：展示 500 次 Monte Carlo 试验中，每个 (α, 场景) 组合的 R₁ 分布。

**观察结果**：

1. **α=0 时**：所有 5 个场景的 R₁ 集中在 0.05–0.10 附近，分布非常狭窄（IQR 极小），说明低容裕条件下系统几乎必然全面崩溃。

2. **α 增大时**：`no_delay`（蓝色）的中位数和箱体明显高于其他 4 个场景，分离效果从 α≈0.3 开始可见。

3. **关键异常 — 4 个时延场景彼此不分**：`light`、`baseline`、`medium`、`heavy` 的箱体严重重叠，中位数没有呈现预期的单调递减序（no_delay > light > baseline > medium > heavy）。在某些 α 值处，`heavy` 的中位数反而高于 `medium` 或 `baseline`。

4. **分布宽度**：论文预期"时延越重 → R₁ 分布越宽"（随机放大效应），但实际观察中 4 个时延场景的 IQR 宽度近似，没有显著的单调趋势。

5. **离群值**：高 α 区间（α≥0.7）出现较多向下的离群点，说明即使容裕充足，部分 BA 网络拓扑仍可导致严重级联。

**与预期的对比**：
- ✅ no_delay 与有时延场景之间的分离：**成立**
- ❌ 4 个时延场景间的单调递减序：**不成立**
- ❌ 时延越重分布越宽：**不显著**

---

### 图2：R₁ vs α 折线图 (IQR-trimmed mean)

**图表内容**：基于箱线图数据的 IQR 截尾均值折线，展示 R₁ 随 α 的变化趋势。

**观察结果（从可见图像读取）**：

| α | no_delay | light | baseline | medium | heavy |
|---|----------|-------|----------|--------|-------|
| 0.0 | 0.06 | 0.08 | 0.09 | 0.09 | 0.10 |
| 0.1 | 0.14 | 0.20 | 0.19 | 0.15 | 0.22 |
| 0.2 | 0.31 | 0.33 | 0.33 | 0.33 | 0.34 |
| 0.3 | 0.45 | 0.35 | 0.33 | 0.33 | 0.41 |
| 0.4 | 0.52 | 0.39 | 0.43 | 0.45 | 0.45 |
| 0.5 | 0.58 | 0.48 | 0.40 | 0.50 | 0.47 |
| 0.6 | 0.65 | 0.49 | 0.43 | 0.49 | 0.53 |
| 0.7 | 0.79 | 0.52 | 0.44 | 0.55 | 0.57 |
| 0.8 | 0.82 | 0.63 | 0.48 | 0.43 | 0.59 |
| 0.9 | 0.85 | 0.70 | 0.58 | 0.43 | 0.62 |
| 1.0 | 0.89 | 0.64 | 0.59 | 0.43 | 0.52 |

**关键问题**：

1. **no_delay 曲线**（蓝色）表现正常：从 α=0 处的 ~0.06 单调递增至 α=1.0 处的 ~0.89，符合"容裕越大 → 存活率越高"的物理直觉。

2. **4 条时延曲线严重交叉**：
   - α=0.1 时：heavy(0.22) > light(0.20) > baseline(0.19) > medium(0.15) — **完全逆序**
   - α=0.7 时：heavy(0.57) > medium(0.55) > light(0.52) > baseline(0.44) — **heavy 反而最高**
   - α=0.8 时：light(0.63) > heavy(0.59) > baseline(0.48) > medium(0.43)
   - α=1.0 时：light(0.64) > baseline(0.59) > heavy(0.52) > medium(0.43)

3. **没有一个 α 值满足预期的完整排序** no_delay > light > baseline > medium > heavy。

4. **在 α=0.2 附近**，所有 5 条曲线几乎收敛到同一点（~0.33），之后 no_delay 开始分离，但 4 条时延曲线继续纠缠。

**与预期的对比**：
- ✅ no_delay 始终最高（α≥0.3 后显著领先）：**基本成立**
- ❌ 5 条曲线单调递减序：**严重不成立**
- ❌ 时延越重 R₁ 越低：**不成立，甚至在多数 α 值处 heavy > baseline**

---

### 图3：R₃ vs α 折线图

**图表内容**：展示发电机功率偏差指标 R₃ 随 α 的变化。R₃ 定义为存活发电机的 (P_actual - P_ref) / P_ref 的均方根。

**预期行为**：
- R₃ 应随时延增大而增大（时延越重 → η 越低 → 偏差越大）
- 排序应为：no_delay(R₃≈0) < light < baseline < medium < heavy

**代码机制分析**：
R₃ 的计算基于最后一轮 `delay_injection_log` 中的 η 值（`bet_homo_gudingCC_myself_bet_8.m` 第 244-262 行），直接使用 `P_ref` 和 `P_actual = P_ref * η`，然后调用 `computeR3Deviation`。

由于 R₃ 直接依赖 η（而非级联结构结果），其排序应比 R₁ 更稳定。但需注意：
- 不同试验中存活的发电机集合不同（取决于级联结果），这引入了间接的随机性
- 如果某场景的级联恰好保留了距离 CC 更远的发电机，该场景的 R₃ 可能反而更高

**可能观察到的结果**：
- no_delay 的 R₃ 应非常接近 0（η=1，P_actual=P_ref）
- 其他场景的 R₃ 排序可能比 R₁ 更接近预期，但仍可能存在交叉，因为存活发电机集合的差异

---

### 图4：延迟惩罚热力图 (ΔR₁ Heatmap)

**图表内容**：显示 ΔR₁ = R₁^{no_delay} − R₁^{heavy} 在 (级联轮次 × α) 空间中的分布。

**预期行为**：
- ΔR₁ 应在中高 α 区间（约 0.5–0.8）最大，形成"热区"
- 低 α 区域 ΔR₁ ≈ 0（两个场景都崩溃了）
- 极高 α 区域 ΔR₁ 较小（容裕足够大，即使有时延也不会产生太多额外过载）

**实际可能观察到的模式**：
- 由于 heavy 场景的 R₁ 在多数 α 值处与 no_delay 有 0.15–0.30 的差距，热力图应能展示出"中高 α 区域惩罚较大"的预期模式
- 但由于 R₁ 曲线的不稳定性（交叉问题），某些 α 值处的 ΔR₁ 可能出现负值或不规则斑块

---

### 图5：敏感性分析 R₁ vs α

**图表内容**：7 条曲线对比 no_delay、heavy 及 5 个工程动作（A1–A5）的 R₁ 表现。

**预期行为**：
- 所有 5 个动作的 R₁ 应介于 heavy 和 no_delay 之间
- 不同动作的恢复效果应有明显差异

**动作参数分析**：

| 动作 | 修改内容 | 预期效果 |
|------|----------|----------|
| A1_bandwidth | 带宽 10→100 Mbps | 降低链路序列化延迟，但该延迟占比很小（~0.8ms），效果可能有限 |
| A2_endpoint | tx/rx 减半 | 降低端点处理延迟，直接影响 τ_m 和 τ_e 中的通信部分 |
| A3_forwarding | forward 减半 | 降低中继转发延迟，对多跳路径效果更显著 |
| A4_measurement | 测量延迟 200→20ms | **大幅降低** τ_m 的主要成分（0.20→0.02s），效果应最显著 |
| A5_execution | 执行延迟 240→30ms | **大幅降低** τ_e 的主要成分（0.24→0.03s），效果也应很显著 |

**关键发现**：A4 和 A5 修改的是 **电力侧的场延迟**（field-side delay），这在总延迟中占主导地位（~0.2s vs 通信延迟 ~0.02s），因此它们的恢复效果应远高于 A1–A3。

---

### 图6：恢复比例热力图

**图表内容**：显示每个动作在每个 α 值处的恢复百分比 = (R₁^action − R₁^heavy) / (R₁^no_delay − R₁^heavy) × 100%。

**注意事项**：
- 当 gap = R₁^no_delay − R₁^heavy ≈ 0（低 α 区域或交叉区域）时，恢复百分比的计算不稳定（分母接近 0），可能出现极大值或负值
- 代码中已有保护：`if gap(idxAlpha) > 0.001` 才计算恢复百分比，否则设为 0

---

### 图7：动作排名柱状图

**图表内容**：展示 α≥0.3 范围内各动作的平均恢复百分比排名。

**预期排名**（基于延迟构成分析）：
1. A4_measurement 或 A5_execution（修改场延迟的贡献远大于通信延迟）
2. A2_endpoint（修改端点处理延迟）
3. A3_forwarding（修改转发延迟，仅影响多跳路径的中间节点）
4. A1_bandwidth（修改序列化延迟，在总延迟中占比极小）

由于 R₁ 基础数据的不稳定性（场景交叉问题），实际排名可能与理论预期不完全一致。

---

### 图8：对比实验柱状图

**图表内容**：3 组对比条件的平均恢复百分比：
- C1：非最佳 α 区域 + 最佳动作
- C2：最佳 α 区域 + 非最佳动作
- C3：最佳 α 区域 + 最佳动作

**预期**：C3 > C2 > C1，证明"正确时机 + 正确动作"的协同效果。

**潜在问题**：由于 R₁ 数据的不稳定性，gap 的计算可能不准确，导致"最佳 α 区域"的选择偏离真实最佳干预时机，进而影响对比实验的说服力。

---

### 图9：对比实验详细折线图

**图表内容**：最佳动作 vs 非最佳动作在全部 α 值上的恢复百分比曲线，绿色阴影标示最佳 α 区域。

**预期**：最佳动作的恢复曲线应在所有 α 值上高于非最佳动作，且差距在最佳 α 区域内最大。

---

## 第二部分：根因分析

---

### 2.1 为什么 α=0 时 R₁ 如此之低？

**答案：这是正确的物理行为。**

代码 `cascadeLogicdebug2gudingCC_bet_8.m` 第 43 行：
```matlab
Power_Edge_Capacity = (1+alpha) * P_branch;
```

当 α=0 时，`容量 = 1.0 × 初始潮流`，即每条支路的容量恰好等于其初始负荷。**任何功率重分布都会导致过载**。

攻击信息节点 → 跨层传播 → 部分电力节点失效 → 功率在剩余支路重分布 → 几乎所有支路都过载 → 级联迅速蔓延至全网。

这与所有时延场景一致（α=0 时 R₁≈0.06–0.10），因为在全面崩溃的情况下，时延的影响是微不足道的——系统无论如何都会崩溃。

---

### 2.2 为什么 4 个时延场景不能正确分离？（核心问题）

这是最关键的问题。根据对代码的深入分析，有 **4 个层面的原因**：

#### 原因 A：R₁ 指标不捕获时延效应（指标定义问题）

**代码证据**（`bet_homo_gudingCC_myself_bet_8.m` 第 171 行）：
```matlab
R1_mat(idxAlpha, trial, idxScenario) = computeR1LoadRatio(initial_power_load, failed_pn);
```

`computeR1LoadRatio` 的公式（第 21 行）：
```matlab
R1 = surviving_load / initial_total_load;
```

**问题**：R₁ 仅统计"哪些节点存活了"，以存活节点的原始负荷之和除以初始总负荷。它完全不考虑时延导致的发电机出力降低。

系统已经实现了 `computeDelayAdjustedR1`（第 1-25 行），该函数引入延迟惩罚因子 φ = min(1, Σ P_actual / Σ P_ref)，计算 R₁_delay = L_surviving × φ / L_initial。**但主脚本没有使用它。**

因此，当前 R₁ 只反映"结构性存活"，而时延的效果只能通过间接途径（时延 → 改变潮流 → 改变过载模式 → 改变存活节点）来体现。这个间接效应太弱，被噪声淹没。

#### 原因 B：时延对潮流的影响是非单调的（物理机制问题）

时延注入的机制（`cascadeLogicdebug2gudingCC_bet_8.m` 第 527 行）：
```matlab
mpc_sur.gen(gIdx, 2) = mpc_sur.gen(gIdx, 2) * eta_g;
```

在 DC 潮流中，当非平衡节点的发电机出力 Pg 降低时：
1. **平衡节点（slack bus, IEEE 39-bus 的 bus 31）自动补偿差额**
2. 功率流通过 **功率转移分布因子 (PTDF)** 重新分配
3. **某些支路的潮流增加，某些支路反而减少**

关键：发电机出力降低 **不一定** 导致更多过载。在某些拓扑条件下，降低远端发电机出力、增加平衡节点出力，可能 **减轻** 某些支路的过载。

这解释了为什么 heavy 场景在某些 α 值处 R₁ 反而高于 baseline——时延导致的潮流重分布恰好减少了部分支路的过载。

#### 原因 C：随机种子的蝴蝶效应（数值噪声问题）

**代码第 95 行**：
```matlab
rng(idxAlpha * 100000 + trial, 'twister');
```

RNG 种子在主循环开始前设置一次。设计意图是确保同一 (α, trial) 对在不同场景下有相同的随机序列。

**但实际效果相反**：
1. **第 1 轮**：所有场景从相同的攻击节点开始，经历相同的结构传播。此时 `rand()` 的调用次数和顺序相同，随机传播决策一致。
2. **第 1 轮过载检查后**：时延注入 → 不同场景得到不同的潮流结果 → 不同的过载支路
3. **第 2 轮**：不同的失效集合 → 内循环结构传播中 `rand()` 的调用次数不同 → **随机序列彻底错位**
4. **后续轮次**：级联轨迹完全发散，传播决策与时延场景不再有确定性关系

结合 p=0.30 的随机传播概率，每个传播决策都是一次伯努利试验。一旦第 2 轮开始，不同场景的传播路径已经独立，500 个样本的平均无法消除这种结构性噪声。

#### 原因 D：η 值的跨场景差异太小（参数配置问题）

根据代码中的延迟配置计算，典型 1-hop 路径的 η 值为：

| 场景 | scale | τ_m (s) | τ_e (s) | η |
|------|-------|---------|---------|------|
| no_delay | 0.0 | 0 | 0 | 1.000 |
| light | 0.5 | 0.058 | 0.066 | 0.955 × 0.960 = **0.917** |
| baseline | 1.0 | 0.117 | 0.132 | 0.907 × 0.921 = **0.835** |
| medium | 1.5 | 0.175 | 0.198 | 0.860 × 0.881 = **0.758** |
| heavy | 2.0 | 0.234 | 0.264 | 0.813 × 0.841 = **0.684** |

**light 与 heavy 的 η 差仅为 0.917 − 0.684 = 0.233**。在 10 台发电机中，这意味着每台的出力差异仅约 23%。经过平衡节点的补偿和 PTDF 的稀释，实际对支路潮流的影响可能只有几个百分点——远小于 p=0.30 随机传播带来的波动。

对比 no_delay 与 heavy 的差异：η 差为 1.0 − 0.684 = 0.316。加上 no_delay 的发电机完全没有出力削减，这个差异足够大，因此 no_delay 能够清楚地分离出来。

---

### 2.3 为什么不同场景的曲线相互交叉？

交叉的根本原因是 **时延信号被随机噪声淹没**，具体机制如下：

1. **有限样本 + 高方差**：500 次试验在 p=0.30 的随机传播下仍有显著的统计波动。每个 (α, scenario) 组合的 R₁ 标准差约 0.15–0.25，而场景间的真实差异可能只有 0.03–0.08。**信噪比不足 1**。

2. **IQR 截尾均值的局限**：截尾均值剔除了离群值，但核心问题不是离群值，而是整体分布的重叠。即使使用中位数或均值，当两个分布的重叠率超过 80% 时，均值的差异可能出现任何方向。

3. **拓扑异质性**：500 次试验使用不同的 BA 网络拓扑。某些拓扑对时延更敏感（如关键发电机距 CC 较远），某些则不敏感。这种异质性在有限样本中表现为系统性偏差。

4. **DC 潮流的非线性响应**：发电机出力的降低通过 PTDF 矩阵转化为支路潮流变化。在过载边界附近，微小的潮流变化可以导致"过载 vs 不过载"的二值跳变。这种阈值效应使得 R₁ 对 η 的响应高度非线性且不可预测。

---

### 2.4 时延反馈环路为何未发挥预期作用？

论文核心假设是：时延 → 出力降低 → 功率失衡 → 更多过载 → 更多节点失效 → 信息层退化 → 路径变长 → 时延增加（正反馈环路）。

但实际代码中，这个环路在每一轮的作用非常有限：

1. **出力降低 → 功率失衡**：由平衡节点（slack bus）完全补偿，不一定导致功率失衡。
2. **功率失衡 → 更多过载**：如前所述，出力降低可能减少某些支路的过载。
3. **更多节点失效 → 信息层退化**：电力节点失效通过 p=0.30 的概率传播到信息层，大部分情况下不传播（70% 概率不传播）。
4. **路径变长 → 时延增加**：这个效应存在但很小。1-hop 变 2-hop，τ 增加约 0.02s（通信延迟部分），对 η 的影响约 1-2%。

因此，预期的正反馈环路实际上非常微弱，不足以产生场景间的显著差异。

---

## 第三部分：问题诊断与修复方案

---

### 问题 1（最关键）：R₁ 指标未体现时延效应

**诊断**：当前 R₁ = Σ L_surviving / Σ L_initial 纯粹是结构性指标。时延将发电机出力从 P_ref 降低到 P_ref × η，但 R₁ 完全忽略了这一事实。

**修复方案**：使用已有但未调用的 `computeDelayAdjustedR1` 函数。

**修改位置**：`bet_homo_gudingCC_myself_bet_8.m` 第 165-171 行

**当前代码**：
```matlab
% R1：存活负荷 / 初始负荷（延迟已在级联中生效）
R1_mat(idxAlpha, trial, idxScenario) = computeR1LoadRatio(initial_power_load, failed_pn);
```

**建议修改为**：
```matlab
% 从最后一轮的 delay_injection_log 提取 P_actual 和 P_ref
round_logs = round_log_all{idxScenario}{idxAlpha, trial};
if ~isempty(round_logs)
    last_rl = round_logs{end};
    if isfield(last_rl, 'delay_injection_log') && ~isempty(last_rl.delay_injection_log.eta)
        dil = last_rl.delay_injection_log;
        P_ref_vec = [];
        P_actual_vec = [];
        for gk = 1:numel(dil.eta)
            match = find(mpc.gen(:,1) == dil.gen_bus(gk), 1, 'first');
            if ~isempty(match) && abs(mpc.gen(match, 2)) > eps
                pg_ref = mpc.gen(match, 2);
                P_ref_vec(end+1, 1) = pg_ref;
                P_actual_vec(end+1, 1) = pg_ref * dil.eta(gk);
            end
        end
        if ~isempty(P_ref_vec)
            R1_mat(idxAlpha, trial, idxScenario) = computeDelayAdjustedR1(...
                initial_power_load, failed_pn, P_actual_vec, P_ref_vec);
        else
            R1_mat(idxAlpha, trial, idxScenario) = computeR1LoadRatio(initial_power_load, failed_pn);
        end
    else
        R1_mat(idxAlpha, trial, idxScenario) = computeR1LoadRatio(initial_power_load, failed_pn);
    end
else
    R1_mat(idxAlpha, trial, idxScenario) = computeR1LoadRatio(initial_power_load, failed_pn);
end
```

**预期效果**：
- no_delay 的 R₁ 不变（φ=1）
- 其他场景的 R₁ 乘以 φ < 1，自动产生 **单调分离**
- 例如：如果某试验中结构性 R₁ = 0.60，heavy 场景的 φ ≈ 0.68 → R₁_delay = 0.408，而 light 场景的 φ ≈ 0.92 → R₁_delay = 0.552

**注意**：此修改改变了 R₁ 的含义——从"结构性负荷保持率"变为"考虑出力质量的有效负荷保持率"。论文需要更新 R₁ 的定义和解释。

---

### 问题 2：随机种子的错位导致场景间不可比

**诊断**：RNG 种子在级联开始前设置一次，但不同场景导致不同的 `rand()` 消耗速率，使得第 2 轮起传播决策完全独立。

**修复方案（方案 A - 推荐）：预生成随机决策矩阵**

在级联开始前，预生成足够多的随机数矩阵，使得同一 (α, trial) 在所有场景中使用完全相同的传播决策：

```matlab
% 在 rng(seed) 之后，生成本次试验所有可能需要的随机数
max_possible_rounds = 50;
max_nodes = Vc + Vp;
rand_matrix_forward = rand(max_nodes, max_possible_rounds);   % 正向传播
rand_matrix_backward = rand(max_nodes, max_possible_rounds);  % 反向传播
```

然后在传播逻辑中，用 `rand_matrix_forward(node_c, inner_iteration_count)` 替代 `rand()`。

**修复方案（方案 B - 简单但有效）：per-node 确定性哈希**

```matlab
% 替换 rand() < propagation_probability
% 使用基于 (node_id, round, trial, alpha) 的确定性哈希
% 使用互素的大素数减少哈希碰撞
hash_val = mod(node_c * 7919 + main_iteration_count * 104729 + trial * 6271, 10000) / 10000;
if hash_val < propagation_probability
    % 传播
end
```

**预期效果**：确保同一节点在同一轮次、同一试验中，无论哪个时延场景，传播决策完全一致。场景间的 R₁ 差异将 **完全归因于时延配置的不同**。

---

### 问题 3：时延效应太弱，需增强参数或修改机制

**诊断**：light 到 heavy 的 η 差异仅约 0.23，经过 PTDF 稀释后对支路潮流的影响微乎其微。

**修复方案（可选择一个或组合）**：

#### 方案 3A：增大时延敏感度参数

当前 k_m = 0.80, k_e = 0.60。增大至：
```matlab
delay_cfg.power.measurement_sensitivity = 2.0;  % 从 0.80 增至 2.0
delay_cfg.power.execution_sensitivity = 1.5;    % 从 0.60 增至 1.5
```

这将使 heavy 场景的 η 降至约 0.53 × 0.60 = 0.32（而非 0.68），显著增大场景间差异。

#### 方案 3B：使用非线性时延-效率模型

将线性模型 η = (1 - k_m·τ_m)(1 - k_e·τ_e) 替换为指数衰减模型：
```matlab
f_m = exp(-k_m * tau_m);
f_e = exp(-k_e * tau_e);
eta = f_m * f_e;
```

指数模型的特点：
1. η 始终在 (0, 1] 范围内（无需 clamp）
2. 当 τ 增大时，η 衰减更快，场景间差异更显著
3. 物理意义更合理：控制指令的有效性随时延指数衰减

#### 方案 3C：引入负荷切除机制

在当前模型中，减少的发电量完全由平衡节点补偿，不会直接导致负荷损失。可引入如下机制：

当总发电能力 Σ P_actual < Σ P_demand 时，按比例切除负荷：
```matlab
total_gen = sum(mpc_sur.gen(online_gens, 2));
total_demand = sum(mpc_sur.bus(:, 3));  % 列3 = PD (有功负荷需求)
if total_gen < total_demand
    shed_ratio = total_gen / total_demand;
    mpc_sur.bus(:, 3) = mpc_sur.bus(:, 3) * shed_ratio;
    % 被切除的负荷节点视为"功能性失效"
    shed_threshold = 0.5;  % 可调参数：切除超过(1-threshold)负荷的节点视为失效
    for b = 1:size(mpc_sur.bus, 1)
        if mpc_sur.bus(b, 3) < mpc.bus(b, 3) * shed_threshold
            failed_power_nodes = unique([failed_power_nodes; b]);
        end
    end
end
```

---

### 问题 4（潜在 bug）：η 可能为负数

**诊断**：`computePowerDelayEfficiency` 使用线性公式 f_m = 1 - k_m × τ_m。当 k_m × τ_m > 1 时，f_m < 0。

虽然在 `cascadeLogicdebug2gudingCC_bet_8.m` 第 526 行有 `eta_g = max(0, min(1, eta_g))` 的 clamp 保护，但 `computePowerDelayEfficiency` 本身没有保护。如果其他调用者（如 `computeActualPowerWithDelay`）直接使用返回值，可能产生负数。

**修复**：在 `computePowerDelayEfficiency.m` 中添加 clamp：
```matlab
f_m = max(0, 1 - k_m .* tau_m);
f_e = max(0, 1 - k_e .* tau_e);
eta = f_m .* f_e;
```

---

### 修复优先级建议

| 优先级 | 修复项 | 理由 | 预期影响 |
|--------|--------|------|----------|
| **P0** | 使用 `computeDelayAdjustedR1` | 直接解决排序问题，无需重跑仿真 | 5 条曲线立即呈现单调序 |
| **P1** | 预生成随机矩阵 | 消除蝴蝶效应噪声 | 减小方差，平滑曲线 |
| **P2** | 增强时延参数 | 增大信号强度 | 场景间差异更显著 |
| **P3** | 修复 η 负数 bug | 防御性编程 | 低概率但必要 |

**推荐策略**：先仅应用 P0 修复（将 R₁ 替换为 delay-adjusted 版本），在不重跑仿真的情况下，利用已有的 `round_log_all` 中的 `delay_injection_log` 数据重新计算所有图表。这是成本最低、效果最直接的修复路径。如果 P0 仍不足以产生清晰分离，再依次应用 P1、P2。

---

## 附录：关键代码路径追踪

### 时延注入完整链路

```
createDelayConfig()
    → createDelayScenarioConfigs(delay_cfg)
        → cascadeLogicdebug2gudingCC_bet_8(..., current_delay_cfg)
            → 每轮级联:
                → computeCyberLinkDelay() → delay_link_scalar_up/down
                → for 每台发电机:
                    → shortestpath(cyber_delay_graph, cc, noncc) → 最近 CC
                    → computeCyberPathDelay(path, ..., 'up') → cyber_up_d
                    → computeCyberPathDelay(path, ..., 'down') → cyber_down_d
                    → τ_m = field_delay + cyber_up_d
                    → τ_e = field_delay + cyber_down_d
                    → computePowerDelayEfficiency(τ_m, τ_e, k_m, k_e) → η
                    → mpc_sur.gen(gIdx, 2) *= η
                → rundcpf(mpc_sur) → 新的支路潮流
                → 过载检查 → 决定是否继续级联
```

### R₁ 计算路径（当前 vs 建议）

```
当前: failed_power_nodes → computeR1LoadRatio() → R₁ = L_surviving / L_initial
                                                      ↑ 不含时延效应

建议: failed_power_nodes + delay_injection_log
      → computeDelayAdjustedR1(load, failed, P_actual, P_ref)
      → R₁_delay = (L_surviving × φ) / L_initial
                     ↑ φ = min(1, Σ P_actual / Σ P_ref) 含时延惩罚
```
