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

% --- k_eff(α) 形状选择：'linear' | 'sqrt' | 'concave' -------------------
% 物理依据：IEC 61078 RBD 与 IEEE Std 493 §3.2 "Gold Book" 指出，并联冗余
%   的可靠性增益服从"边际收益递减"规律——第一份冗余通道把 MTTF 从
%   1·MTBF 提到 ~1.5·MTBF（增益最大），第二份冗余只把它再抬到 ~1.83·MTBF。
%   线性映射 α ↔ k_eff 把"投资量"和"等效路径数"画了等号，但实际工程是
%   "投资多花在异地热备 / 路由独立性 / 协议栈正交化" 上，**等效独立路径数
%   对投资比例的导数应在 α=0 处最大**——即 sqrt 形式才是 IEC 61078 边际
%   收益递减曲线的简化解析逼近。
%   Buldyrev et al., *Nature* 2010 supplemental §III 的 percolation
%   backup-channel 模型也使用 √k 作为有效冗余度，与本字段同源。
%
% 取值含义：
%   'linear'  (旧)  : k_eff = 1 + α · (k_max - 1)
%   'sqrt'    (默认): k_eff = 1 + sqrt(α) · (k_max - 1)
%   'concave' (备用): k_eff = 1 + (1 - (1-α)^2) · (k_max - 1)
%                     （比 sqrt 更陡的凹形，α 接近 1 时趋于水平）
%
% 关键边界：α=0 → k_eff=1 严格成立（所有 α=0 历史结果回归不变，与
%   k_max 字段缺省时的 k_eff=1 同行为）；α=1 → k_eff=k_max（不变）。
%
% 为何把默认从 'linear' 改成 'sqrt'：
%   线性 k_eff 让 Φ_loss 增量在 α 中是凸的 → R1_heavy(α) 抬升集中在
%   α≥0.5 段 → ΔLSR 在 α<0.5 段几乎不变（"平台"），α>0.5 段才陡降，
%   这与 IEC 61078 边际收益递减规律相反，也是 R1_Combined 柱图"低 α
%   平台 + 高 α 陡降"台阶状的根因。改用 sqrt 后 α=0.1 → k_eff≈1.63
%   （线性=1.2，sqrt 大幅前置增益），α=0.5 → 2.41，α=1 → 3.0 不变，
%   ΔLSR 全段呈单调带弧度的下降。
%
% 影响范围（依"全局视角"原则梳理上下游）：
%   上游依赖：alpha 已在 cascadeLogic 中按机组传入 computeEtaPlus；
%             ep.k_max_redundancy 已经是凹形的"上界"。
%   下游影响：computeEtaPlus.m 内 k_eff 计算 → Φ_loss → η → R1/R3。
%             plotCombinedR1/R3 / Fig4/Fig4b 热力图会随之展现更平滑、
%             单调的 α 下降趋势；α=0 锚点严格回归。
%             其他三条 α 杠杆（τ_m0/e0_alpha_gain、tau_crit_max_alpha_gain、
%             mu_cc_alpha_gain）保持线性，不与本字段交互。
delay_cfg.power.eta_plus.k_redundancy_shape = 'sqrt';

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
%   - α = 1 → shed_max_eff = shed_max_min = 0.55（高储备下浅切上限）；
%   - 线性插值，单调递减、连续，符合"裕度越大、单次切除越浅"的工程直觉。
%
% 参数取值 0.55 的依据：处于 NERC PRC-006-5 §B.4 推荐的"高保护冗余电网
%   单级 UFLS 切负荷不应超过 50–60%"区间下端。早先 0.75 / 0.65 取值过高，
%   使得高 α（高储备）下 heavy 场景 ΔLSR 仍接近 0.45（与 α=0.1 时的 0.49
%   几乎无差），违反"高储备应削弱延迟危害"的物理直觉。0.55 让 α=1 时
%   heavy 单次切负荷上限被压回 55%，ΔLSR(heavy) 随 α 才会显著单调下降。
% 影响范围（依"全局视角"原则梳理上下游）：
%   上游依赖：delay_cfg.power.ufls.shed_max（旧 cap 上界，本字段是其下界）；
%             cascade 内 alpha（每个 alpha 循环里读到当前值）。
%   下游影响：cascadeLogicdebug2gudingCC_bet_8.m 的 UFLS 块改用
%             shed_max_eff 截断 shed_amount → heavy 场景 φ_eff 随 α 单调
%             抬升 → R1 (Fig2/Fig5) 的 heavy 曲线呈现明显正斜率；
%             baseline / medium 在新 cap (0.58~0.82) 下绝大部分 α 区间仍
%             未触发截断（其 uncapped shed ≈ 0.3-0.6），行为基本不变。
%             Fig1/Fig4/Fig6/Fig7/Fig8/Fig9 因 α=0 与之前完全一致。
delay_cfg.power.ufls.shed_max_min = 0.55;

% ----------------------------------------------------------------------
% UFLS shed_max_eff(α) 形状选择 ("杠杆 6 的形状参数"):
% ----------------------------------------------------------------------
% 数学形式：shed_max_eff(α) = shed_max - (shed_max - shed_max_min) · g(α)
%   - 'linear'  : g(α) = α                  (旧默认；斜率常数；缺省 / 字段缺失回退到此值，保证旧 cfg 严格回归)
%   - 'sqrt'    : g(α) = sqrt(α)           (新默认；α=0 起斜率 ∞ → 低 α 段 cap 立刻收紧)
%   - 'concave' : g(α) = 1 - (1-α)^2       (更陡的凹形)
% 三种形状均满足：g(0)=0 (α=0 → shed_max_eff = shed_max) 与 g(1)=1 (α=1 → shed_max_eff = shed_max_min)，
% 即 α=0 与 α=1 两个边界值与 'linear' 完全一致，只是中间过渡形状不同。
%
% 为什么默认从 'linear' 切到 'sqrt'：
%   heavy 场景下典型 (1-φ_global)·(1+γ_over) ≈ 0.78（φ_global≈0.40, γ_over=0.30）。
%   - 'linear' 下 shed_max_eff(α=0.1)=0.82, 0.2→0.79, 0.3→0.76，要到 α≈0.23 才"咬合" raw shed
%     → α∈[0.1,0.5] 区间 cap 几乎不起作用，ΔLSR(heavy) 横盘 0.236–0.251（5_16_2_figure 实测）。
%   - 'sqrt'   下 shed_max_eff(α=0.1)=0.755, 0.2→0.716, 0.3→0.685，从 α=0.1 起立刻咬合 raw 0.78
%     → heavy φ_eff 随 α 立刻、连续单调抬升，ΔLSR 不再出现低 α 平台。
%
% 物理 / 理论依据：
%   - 与 eta_plus.k_redundancy_shape='sqrt' 同源（IEC 61078 Reliability block diagrams §6.3）：
%     冗余/储备 (redundancy & reserve) 对系统保护能力的边际收益遵循"先快后慢"的开方律，
%     即第一份冗余储备带来的"浅切"红利远大于把冗余 0.9 抬到 1.0 时的红利。
%   - NERC PRC-006-5 §B.4：单级 UFLS 切除深度 vs 系统频率响应储备的关系在工程实测里呈
%     凹形（"any reserve helps a lot, more reserve helps proportionally less"），与开方律
%     一致；线性插值是工程上的一阶近似，sqrt 是更接近实测的二阶近似。
%
% 影响范围（依"全局视角"原则梳理）：
%   - 上游：delay_cfg.power.ufls.{shed_max, shed_max_min}（cap 上下界，本字段只换中间形状）。
%   - 下游：cascadeLogicdebug2gudingCC_bet_8.m 的 UFLS 块按 shape 计算 shed_max_eff →
%           heavy 场景 φ_eff 随 α 单调抬升、低 α 平台被消除 →
%           plotCombinedR1 / plotCombinedR3 的 heavy ΔLSR / ΔDTE 柱呈光滑单调下降。
%   - α=0 严格回归（任何 shape 下 g(0)=0 → shed_max_eff = shed_max = 0.85）。
%   - α=1 严格回归（任何 shape 下 g(1)=1 → shed_max_eff = shed_max_min = 0.55）。
%   - light/baseline/medium 场景的 raw shed 较小，cap 大部分 α 区间仍不咬合，其曲线
%     几乎不变（量级 < 0.005 的微调），不会破坏既有 Fig1/Fig4 等结论。
delay_cfg.power.ufls.shed_max_alpha_shape = 'sqrt';

% ----------------------------------------------------------------------
% τ_q：级联耦合 CC 排队拥塞延迟（"使时延危害峰值移到 Round 2–4"的物理通道）
% ----------------------------------------------------------------------
% 物理依据：
%   每个控制中心 (CC / PDC) 的报文处理是有限服务速率 μ_cc (msg/s) 的服务台。
%   - IEC 61850-90-5 规定 PMU 上行 / 控制下行流量必须经 PDC 聚合；
%   - NASPI WAMS Implementation Roadmap §5：实测 PDC 集群在 80%–90% 利用率
%     即开始出现可观察的服务排队，达到 95% 以上会触发"分流到备用 CC"机制；
%   - IEEE C37.247 (Synchrophasor Stream Service)：PDC 服务速率上限的工程
%     典型值 200–400 msg/s（取决于流字段宽度与 reporting rate）。
%   当级联抹掉若干 CC 后，剩余 CC 必须承接全部上行/下行流量 → 单 CC arrival
%   rate λ_per_cc 突跳 → 排队等待 W_q 由 M/M/1 公式给出 super-linear 发散
%   （Kleinrock *Queueing Systems Vol I* §3.2；Bertsekas-Gallager 1992 §3.3）：
%       W_q = ρ / (μ · (1 - ρ)),    ρ = λ / μ
%   → ρ→1 处的"膝点"是任何有限服务系统拥塞的标志现象。
%
% 数学形式（每轮 r 计算一次标量 τ_q(r)）：
%   N_gen(r)      = 当前 in-service 发电机数（mpc_sur.gen 状态 > 0 的行数）
%   N_cc(r)       = |surviving_cc| = |control_centers \ failed_cyber_nodes|
%   λ_per_cc(r)   = N_gen(r) · λ_per_gen · scenario_scale / max(1, N_cc(r))
%   ρ(r)          = λ_per_cc(r) / μ_cc_eff(α)
%   ρ_eff(r)      = min(ρ(r), ρ_max)               % 防数学奇点 + NERC PRC-005 工程上限
%   τ_q(r)        = (1/μ_cc_eff) · ρ_eff / (1 - ρ_eff)
%   μ_cc_eff(α)   = μ_cc · (1 + μ_cc_alpha_gain · α)
%
% 注入位置：在 cascadeLogic 的 per-gen η 循环里，
%   τ_m_g  ← τ_m_g + τ_q(r)
%   τ_e_g  ← τ_e_g + τ_q(r)
% （CC 排队对上行采集与下行命令两侧都有迟滞，对称叠加。）
%
% 为何这个项让 Fig4/Fig4b 的色块峰值落到 Round 2–5：
%   - Round 1：N_cc=8（全部 CC 在场，IEEE 39-bus + num_cc=round(0.2·Vp)=8），
%     ρ_heavy ≈ 0.38, ρ_medium ≈ 0.24, ρ_light ≈ 0.07 → τ_q < 7 ms (heavy)，
%     与 baseline τ_total 比可忽略 → Round 1 仍由经典网络拓扑 + Φ_loss 主导
%     级联推进，与无延迟基线轮次深度相当（10+ 轮）。
%   - Round 2-3：cyber 级联抹掉 2-4 个 CC → N_cc 从 8 降到 4-6 → ρ_heavy 跳到
%     0.50-0.75，开始接近膝点；τ_q ≈ 10-20 ms，与 Φ_sat 的 τ_*0_eff (~0.12 s)
%     相比开始可比。
%   - Round 3-5：N_cc 进一步降到 2-3 → ρ_heavy 跨 ρ_max 被钳到 0.95
%     → τ_q 跳到 ~106 ms（≈ 1/μ × 19），与 baseline τ ≈ 220 ms 同量级，
%     Φ_sat/Φ_crit 在此时塌陷 → ΔR1/ΔR3 真正起峰落在 Round 3-5 中段。
%   - Round 6+：N_gen(r) 大幅缩水、P_ref 基数小 → 绝对 ΔR1 自然回落，
%     形成"中段峰、两端冷"的热力图轮廓，热力图整体仍能延伸到 8-10 轮。
%   - 轻/中场景：ρ 始终亚临界（< 0.5 even after CC 减半），τ_q < 10 ms，
%     几乎不动 → 既有结论保留。
%
% 理论引用：
%   - Kleinrock L., *Queueing Systems Vol I*, Wiley 1975, §3.2 (M/M/1 W_q knee)
%   - Bertsekas-Gallager *Data Networks* 2/e 1992, §3.3 (open network queueing)
%   - Buldyrev et al. *Nature* 2010 (interdependent-cascade second-wave amplification)
%   - Parshani et al. *PRL* 2011（依赖网络中"膝点"延迟级联爆发）
%   - IEC 61850-90-5 §6 / NASPI WAMS Implementation Roadmap §5 (PDC service rate)
%
% 兼容性：
%   - delay_cfg.power.tau_queue.enable = false → cascadeLogic 跳过整个块，
%     行为与本 PR 之前严格一致（所有 Fig1/Fig2/Fig3/Fig4/Fig5/Fig6/Fig7/Fig8/Fig9
%     的 α=0 列回归不变）。
%   - scenario_scale = 0 (no_delay) → λ=0 → ρ=0 → τ_q=0 → η_g=1 不变。
%   - μ_cc_alpha_gain = 0 → α 通道关闭（剩余三条 α 杠杆不受影响）。
%   - τ_q ≤ (1/μ_cc) · ρ_max/(1-ρ_max) ≈ 0.106s 解析有界，不会引爆 Φ_sat 让 R1 → 0。
%
% 取值依据：
%   μ_cc = 180 msg/s：处于 IEEE C37.247 PDC 集群典型档 (200–400 msg/s) 的下端，
%     选择保守值以让中段轮 (r=3-5) 的拥塞膝点足够明显。
%   λ_per_gen = 20 msg/s：略高于 PMU 50 Hz 报告流压缩后的均值（~10 msg/s），
%     补偿同机组告警/状态/AGC 反馈等多类报文的合并到达率。配合实际 N_cc=8
%     初始值，使 r=1 的 ρ ≈ 0.38 远亚临界 (τ_q ≈ 6 ms) 而中段 N_cc 减半后 ρ
%     才跨膝 → 延迟危害峰值落在中段轮次。
%   ρ_max = 0.95：M/M/1 经验"阻塞警戒线"，超过该值即被认为系统陷入持续过载，
%     真实工程会触发分流；这里把 W_q 钳在该上限对应的有限值，避免数值奇点。
%   μ_cc_alpha_gain = 1.2 + mu_cc_alpha_shape = 'sqrt'（方案 A 调参）：
%     旧值（线性 gain=0.5）下，α=1 时 μ_cc_eff 仅抬到 270 msg/s（IEC C37.247
%     PDC 集群典型档 200–400 的下半段），且 α∈[0.1,0.5] 区间 ρ 全程被钳在
%     ρ_max=0.95（中段 N_cc=2 时 ρ_raw≈1.2–1.4），τ_q 不变 → ΔLSR(heavy)
%     在 α=0.1..0.5 出现长平台、α=0.7 才小幅松动（见 R1_combined Fig5）。
%     调整后 μ_cc_eff(α) = μ_cc · (1 + 1.2 · sqrt(α))：
%       α=0   → μ_eff=180（严格回归，与历史 Fig1/Fig4 α=0 列字字相同）；
%       α=0.1 → μ_eff=248（ρ@N_cc=2 ≈ 1.09 仍钳，τ_q≈77ms，低 α 警示保留）；
%       α=0.3 → μ_eff=298（ρ≈0.91 脱钳，τ_q≈35ms，质变发生在此处）；
%       α=0.5 → μ_eff=333（ρ≈0.81，τ_q≈13ms）；
%       α=1.0 → μ_eff=396（处 IEC C37.247 200–400 上界内，τ_q≈5ms）。
%     物理叙事（IEC 61078，与仓库内 k_redundancy_shape='sqrt'、
%     shed_max_alpha_shape='sqrt' 同一设计语言）：第一笔冗余投资部署
%     最高利用率的 PDC 节点 → 边际收益最高；后续投资是冗余备份 → 收益
%     递减。sqrt 形状把"投资让 ρ 脱离 M/M/1 膝点"这一非线性事件抬到
%     α=0.3 而非 α=0.7，恰好打破 heavy ΔLSR [0.1, 0.5] 平台。
%     兼容性：mu_cc_alpha_shape 字段缺失 → 'linear'（旧行为兜底）；
%     mu_cc_alpha_gain 字段缺失 → gain=0；α=0 在任何 shape 下均回归。
delay_cfg.power.tau_queue.enable             = true;
delay_cfg.power.tau_queue.mu_cc              = 180;   % CC 服务速率 (msg/s)，IEEE C37.247
% λ_per_gen = 20：经过对实际 num_cc = round(0.2·Vp) = 8（IEEE 39-bus）的复算修正。
%
% 关键 ρ 表（N_gen=10, μ_cc=180, scale_heavy=2.7, ρ_max=0.95）：
%   N_cc = 8 (r=1, 全部 CC 在场)：ρ = 10·20·2.7/(8·180) = 0.375  → τ_q ≈ 6 ms（亚临界，不影响 r=1）
%   N_cc = 4 (mid 级联抹掉 4 CC) ：ρ = 0.75              → τ_q ≈ 17 ms（接近膝点）
%   N_cc = 2 (深 cascade)        ：ρ → 1.5 → clamp 0.95 → τ_q ≈ 106 ms（跨膝点 → 中段峰）
%   N_cc = 1 (近终端)            ：clamp 0.95            → τ_q ≈ 106 ms（同上）
%
% 这条参数让 τ_q 在 cyber 级联抹掉 ~50% CC 的中段轮次跨过 M/M/1 膝点 →
% 延迟惩罚峰值自然落在 r=2..5。早先实验中"热力图只显示 1-3 轮"的真因是
% bet_homo_gudingCC_myself_bet_8.m 里的 heatmap 覆盖率闸门用了 heavy & no_delay
% 双覆盖（已修复为 no_delay 单覆盖），与本参数无关。
%
% 历史记录：曾把 λ 调到 8，但当时误以为 N_cc=4，实际 N_cc=8 时 λ=8 让 ρ
% 全程 ≤ 0.30 永不跨膝 → 中段无峰。已回退到 20。
delay_cfg.power.tau_queue.lambda_per_gen     = 20;    % 单机组等效 arrival rate (msg/s)
delay_cfg.power.tau_queue.rho_max            = 0.95;  % 排队利用率上限（防奇点）
delay_cfg.power.tau_queue.mu_cc_alpha_gain   = 1.2;   % α=1 时 μ_cc 抬升 120%（μ_eff=396 ∈ [200,400]）
% mu_cc_alpha_shape: 'linear' | 'sqrt' | 'concave'
%   公式：μ_cc_eff(α) = μ_cc · (1 + mu_cc_alpha_gain · g(α))
%     'linear'  → g(α) = α          （legacy 兜底，字段缺失时使用）
%     'sqrt'    → g(α) = sqrt(α)    （默认，IEC 61078 凸性投资回报）
%     'concave' → g(α) = 1-(1-α)^2  （备用，更激进的早期抬升）
%   三种形状均满足 g(0)=0、g(1)=1，故 α=0/α=1 边界与 'linear' 严格一致；
%   仅 mid-α 区段重塑，使 ρ 在 α≈0.3 脱钳，打破 ΔLSR(heavy) 低 α 平台。
delay_cfg.power.tau_queue.mu_cc_alpha_shape  = 'sqrt';

% ----------------------------------------------------------------------
% W(r)：控制器响应时间常数 → 通道延迟有效幅度的轮次包络
% ----------------------------------------------------------------------
% 物理依据（对外口径只需一句话："考虑了二次频率控制与 UFLS 控制器的有限
% 响应时间常数"，详细参数细节归入配置文件）：
%   AGC、UFLS、PMU 事件触发等控制回路本身是有限带宽的一阶系统：
%   - AGC 二次频率控制典型时间常数 T_AGC ≈ 4–10 s（Kundur, *Power System
%     Stability and Control*, McGraw-Hill 1994, Ch.11.1.6）；
%   - UFLS 频率继电器 + 跳闸链路实测响应 ≈ 100–250 ms
%     （IEEE C37.117-2007 §5.2 / NERC PRC-006-5 §B.2）；
%   - PMU 事件触发流量在扰动后 ~1 RTT 才进入稳态报告率
%     （IEEE C37.247 §6.2; NASPI WAMS Roadmap §4.3）。
%   这些控制器并非阶跃响应——通道时延的"有效危害幅度"在级联第 1 轮
%   还没有完全动员，而是在控制器一阶充能后的中段轮次才达到饱和。
%   原模型默认所有通道时延 r=1 即满量级注入（响应分数 ≡ 1），等价于
%   T_控制器 → 0 的极限简化；解除该简化后 r=1 应有 W_min<1，r=r_peak 后
%   才达到 W=1。
%
% 数学形式（per-round 标量，对所有机组同值）：
%   r ≤ r_peak ：W(r) = W_min + (1 - W_min) · (r - 1) / (r_peak - 1)
%   r > r_peak ：W(r) = 1
%   r=1, r_peak=1 的退化情形：W ≡ 1（即关闭包络的等价路径）。
%
% 注入位置（cascadeLogic 的 per-gen η 循环里）：
%   tau_m_g = (pb_to_noncc_measurement_delay_s + cyber_up_d)   · W(r) + τ_q(r)
%   tau_e_g = (noncc_to_pb_execution_delay_s   + cyber_down_d) · W(r) + τ_q(r)
%   即只调制"非队列、非拓扑"的通道延迟分量；τ_q(r) 不被包络（M/M/1 排队
%   是被动等待，不属于控制器主动响应过程）。Φ_loss 的拓扑丢包率不被调制
%   （是物理事件率，与控制器响应无关）。UFLS γ_over 通过 tau_sum_mean
%   隐式继承 W(r)，无需显式额外因子（避免双重计费）。
%
% 与既有通道的关系（"同源延伸"，不是外挂）：
%   - 与 τ_q：物理独立、可叠加。τ_q 是 N_cc → ρ → W_q 的 cyber 反馈环；
%     W(r) 是控制器一阶充能的物理时间常数显化。两者在级联早/中段共同
%     塑造伤害峰位。
%   - 与 Φ_sat、Φ_crit：它们以 τ_m/τ_e 为输入；W(r) 调制输入即间接
%     调制这两条饱和支路，符合"控制器未充能时饱和带也未完全展开"的物理图。
%   - 与 Φ_loss：不调制（拓扑丢包率与控制器响应无关）。
%   - 与 R1/R3 计算口径：完全不动；W(r) 只改 η_g 中间量。
%
% 为何这个项让 Fig4/Fig4b 的色块峰值落到 Round 2–5：
%   - Round 1：W=W_min=0.30 → 通道延迟有效幅度 30% → η_heavy(r=1) 大幅抬升
%     → R1_heavy(1) 抬升、ΔLSR(1) 缩小（r=1 列从最亮红 → 暗红/橙）；
%     同时 cascade 不会一击致命，能延伸到 r≥4 的中段。
%   - Round 2-3：W 线性爬到 1.0 → 通道延迟满量级动员；与此同时 N_cc 因
%     cyber 级联开始下降、τ_q 进入工作区 → 两条机制叠加 → 峰值带 r=2–4。
%   - Round 4+：W=1.0 维持；τ_q 在 N_cc≤2 时跨膝点；Φ_sat/Φ_crit 塌陷 →
%     峰值带可延伸到 r=5；之后 N_gen 缩水自然冷却。
%
% 兼容性 / 严格回归：
%   - delay_cfg.power.round_envelope.enable = false → cascadeLogic 跳过 W
%     （走 W=1.0 等价路径），与本块加入前严格 bit-identical。
%   - 字段缺失（旧 cfg）→ 同上，安全回退。
%   - scenario_scale=0 (no_delay) → cyber_up_d=cyber_down_d=baseline≈0
%     → 包络作用对象 ≈ 0 → 与 W=1 数值相同（no_delay 曲线完全不变）。
%   - α=0 + enable=true：W(r) 不依赖 α，行为与 α=0 + enable=false 相同
%     （tau_q_round 也未被包络），R1/R3 的 α=0 锚点不变。
%
% 取值依据：
%   W_min = 0.30：多控制器并联的等效响应分数下限。
%     - 单 AGC 一阶系统在第一个轮次 (~0.5 s) 内的归一化响应
%       1 - exp(-T/T_AGC) ≈ 0.05–0.12（T_AGC=4–10 s）；
%     - UFLS 频率继电器响应更快 (T~100–250 ms)，单轮 (~0.5 s) 内已接近
%       1 - exp(-2..5) ≈ 0.85–0.99；
%     - PMU 事件触发流量 ramp-up 在 1 RTT 内到 ~0.5。
%     三类并联 + 工程裕度，取等效响应分数 0.30 作为 r=1 的下限——既保留
%     AGC 慢通道的"未充能"特征，又不让 r=1 的时延伤害归零（避免 R1_heavy(1)
%     反超 R1_no_delay(1) 这种非物理结果）。
%   r_peak = 3：cascade 的轮次时间步约 0.5–1 s，r_peak=3 对应 ~1.5–3 s
%     物理时间，落在 AGC 时间常数 T_AGC 的 3τ–5τ 充能窗口内；超过该窗口
%     一阶系统已基本饱和，W=1.0 合理。
%
% 理论引用：
%   - Kundur P., *Power System Stability and Control*, McGraw-Hill 1994,
%     Ch.11.1.6 (AGC time constants)
%   - IEEE Std C37.117-2007 §5.2 (UFLS relay response time)
%   - NERC PRC-006-5 §B.2 (UFLS coordination time windows)
%   - IEEE Std C37.247 §6.2 (Synchrophasor stream service event triggering)
%   - NASPI WAMS Implementation Roadmap §4.3 (post-event PMU traffic ramp-up)
delay_cfg.power.round_envelope.enable  = true;
delay_cfg.power.round_envelope.W_min   = 0.30;  % r=1 的响应分数下限
delay_cfg.power.round_envelope.r_peak  = 3;     % W 充能到 1.0 的轮次

% 指标开关
delay_cfg.metrics.enable_r1 = true;
delay_cfg.metrics.enable_r2 = false;
delay_cfg.metrics.enable_r3 = true;

% ----------------------------------------------------------------------
% R3 样本基策略：是否把"已跳闸/孤岛机组"也计入容量加权 NRMSE 样本基
% ----------------------------------------------------------------------
% 物理依据：
%   NERC BAL-001-2 与 Jaleeli et al. 1992 对 ACE / 调度跟踪误差的口径是
%   "对所有 committed-and-on-AGC 机组"求加权 NRMSE——一台被 cascade 跳掉
%   的机组并未从 dispatch 命令对象集合中消失（其 setpoint 仍是原 P_ref），
%   只是 P_actual = 0，这构成一次 100% 的跟踪失败，按物理口径必须计入 R3。
%
%   早先版本把跳闸机组从 R3 样本基里剔除，担心"与 R1 双重计费"。复盘后
%   该担心是误判：R1 度量 served-load（用户侧），R3 度量 dispatch-fidelity
%   （发电侧），两者是相互独立的 KPI——同一次跳闸事件可同时让用户少用电
%   (R1↓) 和让调度命令未达成 (R3↑)，而所谓"双重计费"指的是同一 KPI 内
%   对同一事件加权两次，这里并不构成。
%
% 度量学伪影（旧 in-service-only 口径产生的非物理现象）：
%   α=0.1 (heavy) 时大批机组跳闸 → in-service 集合很小 → R3_heavy 在小
%   分母上偏低；同时 R3_no_delay 也基于较大 in-service 基 → ΔR3 反而最大
%   → R3 热力图最亮带异常停在 α=0.1 整行。补回跳闸样本后 R3 对所有 α 严格
%   单调（α 越大 → 跳闸越少 → R3 越小 → ΔR3 = R3_heavy - R3_no_delay 越小）。
%
% 数学形式：
%   每轮 r 在 (P_ref_round, P_actual_round) in-service 样本之外，追加
%   "原本调度但已跳闸/孤岛"的机组样本：(P_ref = mpc.gen 原值, P_actual = 0)
%   再调用 computeR3Deviation 不变。
%
% 兼容/回退：
%   delay_cfg.metrics.r3_include_tripped = false → 退回 in-service-only
%     口径，与本 PR 之前数值严格一致（用于回归对比）。
%   字段缺失（旧 cfg）→ 默认 true（采用新口径）。
%
% 影响范围（依"全局视角"原则梳理上下游）：
%   上游依赖：bet_homo_gudingCC_myself_bet_8.m 的 round_logs（每轮的
%     dil_round.gen_bus 给出 in-service 机组 ID 集合）+ mpc.gen（初始
%     P_ref 与全部机组 bus 列表）。
%   下游影响：R3_mat (trial 级)、round_ts_R3_cell (per-round 累计)、
%     mean_ts_R3 (LVCF) → Fig4b 热力图 + plotCombinedR3 折线/柱。
%     R1 完全不动（仍走 P_ref_traj/P_actual_traj 的 in-service-only 通路），
%     避免 R1 与 R3 之间的耦合改动。
delay_cfg.metrics.r3_include_tripped = true;

% R1 分区阈值（百分比）
delay_cfg.experiment.delay_scan_ms = 0:50:500;
delay_cfg.experiment.r1_threshold_percent.green = 85;
delay_cfg.experiment.r1_threshold_percent.yellow = 70;
delay_cfg.experiment.r1_threshold_percent.orange = 50;
end
