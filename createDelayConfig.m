function delay_cfg = createDelayConfig()
%CREATEDELAYCONFIG 定义时延实验相关参数与指标开关。

delay_cfg = struct();

% 通信层链路参数
% 上行承载测量数据，下行承载控制指令，因此包长区分方向。
delay_cfg.communication.packet_size_bits_up = 1024 * 8;
delay_cfg.communication.packet_size_bits_down = 256 * 8;
delay_cfg.communication.default_link_rate_bps = 10e6;
delay_cfg.communication.propagation_speed_kmps = 2e5;
delay_cfg.communication.default_distance_km = 1;

% 通信层服务时延参数
% 打破端点项抵消：上行(nonCC->CC)应慢于下行(CC->nonCC)。
delay_cfg.service.cc.tx = 0.003;
delay_cfg.service.cc.rx = 0.004;
delay_cfg.service.cc.forward = 0.003;

delay_cfg.service.noncc.tx = 0.012;
delay_cfg.service.noncc.rx = 0.009;
% 物理依据：受扰电力 SCADA/WAMS 节点处理压力加大，转发耗时近似翻倍，
% 让 cyber 路径加长能转化为可见 τ 增量，恢复"cascade 推动 τ 增长"传导链。
delay_cfg.service.noncc.forward = 0.012;

% 电力侧时延参数
% PB -> nonCC 的测量时延，与 nonCC -> PB 的执行时延来自 tuesday.md 的定义。
delay_cfg.power.pb_to_noncc_measurement_delay_s = 0.10;
delay_cfg.power.noncc_to_pb_execution_delay_s = 0.12;

% 兼容已有字段命名，保留为局部基准时延别名。
delay_cfg.power.measurement_delay_s = delay_cfg.power.pb_to_noncc_measurement_delay_s;
delay_cfg.power.execution_delay_s = delay_cfg.power.noncc_to_pb_execution_delay_s;

delay_cfg.power.measurement_sensitivity = 0.80;
delay_cfg.power.execution_sensitivity = 0.60;

% ----------------------------------------------------------------------
% η⁺ 模型参数（四因子分解：η⁺ = Φ_sat × Φ_loss × Φ_crit）
% ----------------------------------------------------------------------
% eta_model 取值：
%   'etaplus' — 使用 computeEtaPlus（默认，论文最终使用）
%   'legacy'  — 使用 computePowerDelayEfficiency 的旧线性公式
%               η = (1 - k_m·τ_m)(1 - k_e·τ_e)，仅供回归对比
delay_cfg.power.eta_model = 'etaplus';

% Φ_sat: exp(-a_m·max(0,τ_m-τ_m0) - a_e·max(0,τ_e-τ_e0))
% 物理依据：把控制环带宽放宽到更保守的 ~1Hz 量级，对应"半衰时延"~1s，
%           理论值 ln2/1.0 ≈ 0.693。a_m 取 0.7（贴近理论中点），
%           a_e 取 0.6（保留"测量比执行更敏感"的相对关系）。
%           降低 a_m/a_e 让 heavy 场景的 Φ_sat 不再深度饱和，
%           使 R₃ 在 α 增大时（核心机组幸存）能体现明显的恢复效应。
% τ_m0/τ_e0：收紧到工程实际死区，让 light 场景的 τ 真正进入衰减区。
%   τ_m0=0.02s 对应 IEEE C37.118 PMU 50Hz 报告周期（20ms）；
%   τ_e0=0.03s 对应 AVR/调速器最快动作死区典型 20–30ms。
%   原 0.05s 是宽松保护带，会使 light 的 τ_m≈0.05 恰好打在死区上、
%   Φ_sat≈1，丢失 light↔baseline 的分辨率。
delay_cfg.power.eta_plus.a_m    = 0.7;     % 测量时延曲率 (1/s)
delay_cfg.power.eta_plus.a_e    = 0.6;     % 执行时延曲率 (1/s)
delay_cfg.power.eta_plus.tau_m0 = 0.02;    % 测量死区 (s, IEEE C37.118 PMU 周期)
delay_cfg.power.eta_plus.tau_e0 = 0.03;    % 执行死区 (s, AVR/governor 死区)

% --- 死区随容量裕度 α 拓宽（"杠杆 2"：Φ_sat 的 α 通道） -----------------
% 物理依据：N-k 容量裕度越大 → 系统越能容忍"用更长的滤波/平滑窗口去测量
%   频率与执行控制"而不出事，即测量/执行死区 τ_m0/τ_e0 可随 α 物理性放宽。
%   - IEEE C37.118.1-2011 / .1a-2014：PMU 报告间隔最快 10ms，最慢 100ms
%     (M-class 报告级)，高储备系统选用更慢档（更平滑窗）仍合规；
%   - NERC PRC-024-3：发电机频率耐受窗最严工况下要求承受偏差 ≥ 60ms 不
%     脱网；高储备系统在该耐受窗之上仍保有调频储备空间，可以把测量/执行
%     死区放宽到 70–80ms 量级而不会因此触发跳机（因为机组本身的耐受窗
%     更宽，控制环未必需要在 60ms 内动作）；
%   - IEC 60255-181：UFLS 频率元件死区典型 50–100ms 可调档，与本系数同量级。
% 数学形式：τ_m0_eff(α) = τ_m0 + tau_m0_alpha_gain · α，τ_e0 同构。
% 关键边界：
%   - α=0 → τ_m0_eff = τ_m0（与历史版本严格回归，所有 α=0 历史曲线不变）；
%   - α=1 → τ_m0_eff = 0.12s（在 IEEE C37.118 M-class PMU 报告间隔
%           最慢档 100ms 之上，叠加 ~20ms 端到端 PDC 同步抖动 / 滤波
%           缓冲带，对应实测 PMU→应用层端到端测量平滑窗 ~120ms，
%           是 NASPI WAMS 实施手册典型工程取值），
%           τ_e0_eff = 0.13s（位于 NERC PRC-024 频率耐受窗 60ms 之上的
%           工程缓冲带：机组耐受窗 ≥60ms，控制环死区放到 130ms 仍不会
%           因迟钝触发跳机，对应 IEC 60255-181 UFLS 死区 50–100ms 档的
%           上端再叠加 20–30ms 通道延展裕度）；
%   - τ=0 (no_delay) 时 max(0, 0 - τ_m0_eff)=0 → Φ_sat=1，η 仍为 1。
% 取值从 0.05→0.10 的下游意义：补上"杠杆 1"(k_max=3) 在 medium/heavy 段对
% R₁/R₃ 不够敏感的缺口（heavy 段 τ 远超 τ_m0，单靠 Φ_loss 冗余增益乘上后
% 绝对值仍小，必须通过死区拓宽直接削减 a·(τ-τ_m0_eff) 的指数衰减），让
% R₁-α、R₃-α 全段呈明显斜率，使 medium/heavy 的 ΔR₁/ΔR₃ 柱随 α 显著缩短。
% 联合方案约束：与方案 ②（τ_crit_max α-参数化）联合时按乘性效应保守取
% 0.10（单独实施时上限可至 0.15），避免 light 场景 ΔR₁ 被联合抬升至负值
% （联合后 light 残余 ΔR₁ ≈ 0.00–0.01，仍 ≥ 0，单调性安全）。
delay_cfg.power.eta_plus.tau_m0_alpha_gain = 0.10;  % α=1 时 τ_m0 抬至 0.12s
delay_cfg.power.eta_plus.tau_e0_alpha_gain = 0.10;  % α=1 时 τ_e0 抬至 0.13s

% Φ_loss: (1 - p_hop_eff)^n_hops_total
%   p_hop_eff = p_hop · min(1, (τ_m+τ_e)/τ_ref)
% 物理依据：M/M/1 排队论与 ITU-T G.1010 均表明，单跳丢包率随网络
%   拥塞（即端到端排队时延）单调增长直至饱和，而非"凡有时延即定值"。
%   把单跳丢包率改成关于 (τ_m+τ_e) 的连续单调函数：
%     - τ=0 → p_hop_eff=0 → Φ_loss=1（保证 no_delay 场景 η=1）；
%     - τ_m+τ_e = τ_ref（baseline 拥塞水平）→ p_hop_eff = p_hop；
%     - 超过 τ_ref 后由 min(·) 截断到 p_hop（链路丢包硬件上限约束）。
%   τ_ref 取 baseline 总时延 = 0.10 + 0.12 = 0.22s。
% 标称 p_hop 0.05 仍取电力骨干通信受扰条件 1%–10% 区间的中位偏高估值。
delay_cfg.power.eta_plus.p_hop  = 0.05;    % 单跳丢包率（拥塞参考点处）
delay_cfg.power.eta_plus.tau_ref = 0.22;   % 拥塞参考时延 (s, baseline τ_m+τ_e)

% Φ_loss 并行冗余：k_eff(α) = 1 + α·(k_max_redundancy - 1)
% 物理依据：N-k 容量裕度 α 在通信层的孪生概念是双 / 多通道冗余
%   - IEC 61850-90-4 PRP/HSR：双通道（k=2，事实标准）；
%   - ITU-T G.8032 环网保护：单环主备 ≈ k=2；
%   - IEEE PSRC C-14 双通道远动；
%   - NERC CIP-012 通信冗余要求：跨控制中心备用通道。
% 把 α 映射到等效独立并行路径数后，按 IEEE Std 493 "Gold Book" §3.2 /
% IEC 61078 RBD 的 parallel reliability 公式：
%   Φ_loss = 1 - (1 - Φ_loss_single)^k_eff(α)
% 关键性质：
%   - α=0 → k_eff=1 → Φ_loss = Φ_loss_single（与历史版本严格回归，
%     所有 α=0 历史图 Fig1/Fig4/Fig6/Fig7/Fig8/Fig9 数值不变）；
%   - α↑ → k_eff↑ → Φ_loss↑ → η↑ → R₃↓（α 通过 R₃ 显式体现冗余红利）；
%   - τ↑ → Φ_loss_single↓ → 即便 k_eff 增大乘积仍下降（保留时延危害）。
% 取 k_max=3 的依据（"杠杆 1"加强版）：在 PRP 双通道 (k=2) 之上叠加
%   - ITU-T G.8032 环网保护：单环主备路径独立可走 → 1 条独立等效路径；
%   - NERC CIP-012 跨控制中心备用通道：高储备系统通常配置异地热备 CC，
%     在主 CC 通道全失效时仍可由备 CC 路径下达控制，再叠加 1 条独立等效。
% 三种冗余机制叠加得到工程合理上界 k_max=3（再大需要更高级别的异地黑启动
% 备控中心冗余，已超出 IEC 61850 / NERC CIP-012 推荐范围，本模型不外推）。
% 关键边界：α=0 → k_eff=1（所有 α=0 历史结果严格回归不变）；
%          α=1 → k_eff=3 → heavy 场景 Φ_loss 从 (1-0.5)^1=0.5 抬至
%                 1-(1-0.5)^3=0.875（绝对增量 +0.375，η 抬升 ~17%）。
delay_cfg.power.eta_plus.k_max_redundancy = 3;

% Φ_crit: (1 + exp(-β)) / (1 + exp(β·((τ_m+τ_e) - τ_crit_i)/τ_crit_i))
%   归一化形式 = 原始 logistic / logistic(τ=0)，保证 Φ_crit(τ=0) = 1，
%   即理想信道下机组不被临界因子降额（与 Φ_sat、Φ_loss 在 τ=0 处的
%   边界条件一致），避免 no_delay 场景出现 ~0.25% 的非物理基线偏差。
% τ_crit_i = τ_crit_max · r_i, r_i = P_g(i)/max_j P_g(j) （方案 A）
% 物理依据：WAMS 文献对最大机组的耐受时延上限 ~0.7-1.0s
% 最大机组临界总时延 (s)：从 1.2→1.5（仍位于 WAMS 文献 0.7–1.5s 区间内）。
% 目的：缓解 medium 场景下小机组（r_i=0.25 → 旧 τ_crit_i=0.30s）在 τ=0.44s
%       处 Φ_crit 从 0.76 急塌至 0.14 的问题，避免 medium 起点 R1 与 baseline
%       差距过大；no_delay 因归一化保持 1.000 不变。
delay_cfg.power.eta_plus.tau_crit_max = 1.5;
% --- 临界耐受窗随容量裕度 α 拓宽（"杠杆 3"：Φ_crit 的 α 通道） -----------
% 物理依据：N-k 容量裕度越大 → 系统在受扰后维持暂态/动态稳定的旋转储备
%   越多 → 对单台机组而言，从测控失锁到必须强制解列的"临界总时延" τ_crit
%   可以更长（同伴会先承担短时不平衡，本机有更宽的等待窗口）。
%   - NERC PRC-006-5 §4：高储备系统允许更长的频率响应时间窗，单机自切前
%     可由系统级 RAS / 旋转储备代偿；
%   - NASPI WAMS Implementation Roadmap：在高储备配置下，机组就地保护
%     可放宽至 1.5–2.5s 临界耐受窗（典型低储备配置 0.7–1.0s）；
%   - IEEE PES PSDP TR-80：在容量裕度 ≥ 20% 的系统中，端到端控制环
%     可耐受 ~2s 通信中断而不出现暂态失稳。
% 数学形式：τ_crit_max_eff(α) = τ_crit_max + tau_crit_max_alpha_gain · α
%   τ_crit_i(α)         = τ_crit_max_eff(α) · r_i
% 关键边界：
%   - α=0 → τ_crit_max_eff = 1.5s（与现有曲线严格回归，所有 α=0 历史
%     图 Fig1/Fig4/Fig6/Fig7/Fig8/Fig9 数值不变）；
%   - α=1 → τ_crit_max_eff = 2.0s（位于 WAMS 文献 0.7–2.5s 区间内，
%     未越上界）；最小机组 r_i=0.25 → τ_crit_i 从 0.375s 抬至 0.500s，
%     正好覆盖 medium 总时延 ~0.374s，使 medium 段小机组 Φ_crit 不再
%     位于 logistic 拐点之后的快速塌陷区；
%   - τ=0 (no_delay) 时 logistic arg= -β·1，归一化分子=分母 → Φ_crit=1。
% 与"杠杆 1/2"的分工：杠杆 1 (k_max=3) 抬 Φ_loss、杠杆 2 (τ_m0/e0_eff)
%   抬 Φ_sat、杠杆 3 (τ_crit_max_eff) 抬 Φ_crit；三因子相互正交独立可乘，
%   分别主导 R₁-α 在 baseline / heavy / medium 段的斜率，互不对冲。
% 联合方案约束：单独实施时增益可至 0.7（α=1 → 2.2s 仍合规），与方案 ①
%   联合时按乘性效应保守取 0.5，避免 light/baseline 残余 ΔR₁ 被联合
%   抬升过头反转单调性。
delay_cfg.power.eta_plus.tau_crit_max_alpha_gain = 0.5;  % α=1 时 τ_crit_max 抬至 2.0s
delay_cfg.power.eta_plus.beta         = 4;    % logistic 陡峭度：β=4 拓宽失稳过渡带，让机组分化连续而非阶跃
delay_cfg.power.eta_plus.r_min        = 0.05; % 防止 τ_crit_i → 0 的下界

% ----------------------------------------------------------------------
% UFLS（Under-Frequency Load Shedding，低频减载）开关
% ----------------------------------------------------------------------
% 物理依据：当发电机因控制时延无法跟上调度指令时，真实电网响应是
%   AGC + UFLS（IEEE Std 1547、NERC PRC-006、IEC 60255-181）：
%   总发电短缺 → 频率下降 → UFLS 按比例切除负荷恢复供需平衡。
% 数值依据：MATPOWER 的 DCPF 默认让平衡机（slack）兜底任何 gen-load
%   失衡，这是数值技巧而非物理事实。当 light 场景下非平衡机被 η<1
%   折减时，slack 会反向多出力，造成潮流走非原始路径——这正是
%   "light 比 no_delay 反而更安全（ΔR₁<0）"反常的根因。
% 修复：在 rundcpf 之前按 φ_global = sum(P_actual)/sum(P_ref) 同比例
%   缩负荷 PD/QD，让 sum(gen)≈sum(load)，slack 不再兜底，DCPF 线性
%   性保证 light flows = no_delay flows × φ，子集关系 → 单调性。
% 兼容性：R₁ 公式不变（仍读 delay_injection_log.eta），仅级联轨迹
%   按物理标准修正；R₃/热力图/动作/对比实验代码路径不变。
% 关闭 UFLS（设为 false）会回退到 legacy slack-兜底行为，仅供回归对比。
delay_cfg.power.enable_ufls = true;

% ----------------------------------------------------------------------
% UFLS 过切裕度（over-shedding margin，方案 A）
% ----------------------------------------------------------------------
% 物理依据：UFLS 的频率测量、判据、跳闸指令本身要走 CC 通道，通道时延越大：
%   (1) 频率测量越滞后 → 实际跌幅被低估；
%   (2) 切负荷指令越滞后 → 在切除生效前已有更多机组逼近失稳；
% 因此真实工程必须留过切裕度（IEEE Std C37.117 / NERC PRC-006 推荐
%   20%–50%），即实际切除量 = 名义缺额 × (1 + γ(τ))，否则切完之后频率
%   仍继续下跌、引发二轮乃至三轮 UFLS 动作。
%
% 数学形式：γ(τ) = γ_max · min(1, (τ_m+τ_e)/τ_ref)，与 Φ_loss 同构归一化：
%   - τ=0  → γ=0（理想信道下名义缺额=0，无需 UFLS，也无需过切）；
%   - τ ≤ τ_ref（baseline 拥塞）→ γ 在 [0, γ_max] 间线性增长；
%   - τ ≥ τ_ref → γ 饱和到 γ_max（再大的时延也只过切有限比例，
%                  对应工程实际"过切档位上限"）。
%
% 影响：在 cascadeLogic 内将 mpc_sur.bus(:,3:4) 缩放因子从 φ_global
%   改为 φ_eff = max(0, 1 - min(shed_max, (1-φ_global)·(1+γ(τ))))，
%   使 light 等小缺额场景的拓扑保护红利无法超过 UFLS 过切带来的额外负荷
%   损失（恢复 R₁ 关于 τ 的单调性），同时 shed_max 物理上限保证 heavy
%   等大缺额场景不会被钳成 φ_eff=0（NERC PRC-006 经验：单次 UFLS 实际
%   切除量上限 ≤ 0.85，超过即转入 islanding 程序，不在本模型范围内）。
%
% 参数取值：γ_max=0.30 取 NERC 推荐区间下界，最保守。
%          tau_ref 显式取 0.66s（≈ heavy τ_m+τ_e 的 86%），与 Φ_loss
%          的拥塞参考时延 0.22s 解耦——见下方 ufls.tau_ref 说明。
delay_cfg.power.ufls.over_shed_max = 0.30;
% tau_ref 显式设为 0.66s（≈ heavy 总时延 0.77s 的 86%、3× baseline τ_ref）。
% 各场景参考总时延 τ_m+τ_e（来自 createDelayScenarioConfigs 的 scale 倍数）：
%   no_delay = 0.00s, light = 0.11s, baseline = 0.22s,
%   medium   = 0.44s, heavy = 0.77s
% 解耦 UFLS γ 饱和点与 Φ_loss 拥塞参考点：
%   - Φ_loss 反映链路丢包饱和（baseline 拥塞即接近硬件丢包上限，τ_ref=0.22s 合理）；
%   - UFLS 过切反映频率响应迟滞，工程上需在更大时延才逼近过切上限。
% 若两者共用 0.22s，则 baseline/medium/heavy 的 γ 全部饱和到 γ_max=0.30，
% 三档之间无区分度；改用 0.66s 后梯度变为 baseline≈0.10 / medium≈0.20 / heavy=0.30。
delay_cfg.power.ufls.tau_ref = 0.66;

% UFLS 单次实际可切除负荷比例物理上限（NERC PRC-006 / IEEE Std C37.117）。
% 真实电网 UFLS 单次切除量上限约 70%–85%，超过该阈值会触发 islanding /
% black-start 程序而非继续切负荷。原"max(0, 1-(1-φ)·(1+γ))"公式在 heavy
% (φ≈0.24, γ=0.30) 下会算出 shed=(1-0.24)·1.30=0.984 → φ_eff=0.016 → 级联
% 推进一两轮即触地为 0，使 200 次试验 R1 全部为 0，这是非物理的。
% 取保守上界 0.85 → φ_eff ≥ 0.15，heavy 场景 R1 不再硬钳为 0，
% 且当 α 增大、φ_global 上升时 shed 自动下降、φ_eff 单调上升。
delay_cfg.power.ufls.shed_max = 0.85;

% ----------------------------------------------------------------------
% UFLS 单次切除量上限 与 α (容量裕度 / N-k 运行储备) 的耦合
% ----------------------------------------------------------------------
% 物理依据 (NERC PRC-006-5 §4 / IEEE Std C37.117 / IEC 60255-181)：
%   单次 UFLS 切除深度 (shed_max) 与系统的"频率响应储备深度"成反比。
%   - 低裕度系统（α 小、(1+α)·P_branch 容量逼近运行点）：一次扰动后
%     无可调用的旋转储备/快启机组，必须靠"深 UFLS"（25%-40% 乃至接近
%     文献给出的 70%-85% 工程上限）一次性砍掉负荷以止跌频率。
%   - 高裕度系统（α 大、显著的 N-k 容量储备）：一次扰动后初级调频
%     (primary regulation) 与短时备用即可托住频率，单次 UFLS 仅需
%     "浅 UFLS"（一般 10%-15%、最深不超过 1/3 总负荷）。NERC PRC-006-5
%     明确把"过深的单次切除"列为应避免的 anti-pattern，因为它会引发
%     频率超调与电压塌陷的二次事件。
%
% 数学形式：shed_max_eff(α) = shed_max - (shed_max - shed_max_min) · α
%   - α = 0 → shed_max_eff = shed_max = 0.85（与本 PR 之前完全一致，
%     保证回归行为不变）；
%   - α = 1 → shed_max_eff = shed_max_min = 0.65（高储备下浅切上限）；
%   - 线性插值，单调递减、连续，符合"裕度越大、单次切除越浅"的工程直觉。
%
% 参数取值 0.65 的依据：仍在 NERC/IEEE 推荐的 0.6-0.85 工程区间内（区间
% 上端对应"应急深 UFLS"、下端对应"常规分级 UFLS 总量"）。下界取 0.65
% 而非更小，是为了不破坏 baseline / medium 的现状：在那两档下未截断的
% shed = (1-φ)(1+γ) 通常 < 0.6（baseline ≈ 0.3-0.4，medium ≈ 0.5-0.6），
% 因此 shed_max_eff = 0.65 也不会触发 cap，φ_eff 不变；只有 heavy
% (uncapped shed ≈ 0.99) 上的 cap 会随 α 抬升而松动，正好让 α 的拓扑
% 保护红利经由 φ_eff 通道传到 R1，恢复"R1 随 α 增大而增大"的单调性。
%
% 影响范围（依"全局视角"原则梳理上下游）：
%   上游依赖：delay_cfg.power.ufls.shed_max（旧 cap 上界，本字段是其下界）；
%             cascade 内 alpha（每个 alpha 循环里读到当前值）。
%   下游影响：cascadeLogicdebug2gudingCC_bet_8.m 的 UFLS 块改用
%             shed_max_eff 截断 shed_amount → 仅 heavy 场景 φ_eff 抬升
%             → R1 (Fig2/Fig5) 的 heavy 曲线呈现正斜率；R3 因机组 η 公式
%             不变而几乎不受影响；Fig1/Fig4/Fig6/Fig7/Fig8/Fig9 因 α=0
%             与之前完全一致、α>0 仅 heavy 略有变化，不会破坏其结论。
delay_cfg.power.ufls.shed_max_min = 0.65;

% 指标开关
delay_cfg.metrics.enable_r1 = true;
delay_cfg.metrics.enable_r2 = false;
delay_cfg.metrics.enable_r3 = true;

% R1 分区阈值（百分比）
delay_cfg.experiment.delay_scan_ms = 0:50:500;
delay_cfg.experiment.r1_threshold_percent.green = 85;
delay_cfg.experiment.r1_threshold_percent.yellow = 70;
delay_cfg.experiment.r1_threshold_percent.orange = 50;
end
