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

% Φ_crit: (1 + exp(-β)) / (1 + exp(β·((τ_m+τ_e) - τ_crit_i)/τ_crit_i))
%   归一化形式 = 原始 logistic / logistic(τ=0)，保证 Φ_crit(τ=0) = 1，
%   即理想信道下机组不被临界因子降额（与 Φ_sat、Φ_loss 在 τ=0 处的
%   边界条件一致），避免 no_delay 场景出现 ~0.25% 的非物理基线偏差。
% τ_crit_i = τ_crit_max · r_i, r_i = P_g(i)/max_j P_g(j) （方案 A）
% 物理依据：WAMS 文献对最大机组的耐受时延上限 ~0.7-1.0s
delay_cfg.power.eta_plus.tau_crit_max = 0.8;  % 最大机组临界总时延 (s)
delay_cfg.power.eta_plus.beta         = 6;    % logistic 陡峭度
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
%   改为 φ_eff = max(0, 1 - (1-φ_global)·(1+γ(τ)))，使 light 等小缺额
%   场景的拓扑保护红利无法超过 UFLS 过切带来的额外负荷损失，恢复
%   R₁ 关于 τ 的单调性。
%
% 参数取值：γ_max=0.30 取 NERC 推荐区间下界，最保守。
%          tau_ref 默认复用 Φ_loss 的拥塞参考时延（=baseline τ_m+τ_e=0.22s）。
delay_cfg.power.ufls.over_shed_max = 0.30;
% tau_ref 留空则在运行时回退到 delay_cfg.power.eta_plus.tau_ref，保证
% UFLS 过切归一化时延与 Φ_loss 拥塞归一化时延一致。如需独立调整可设值。
delay_cfg.power.ufls.tau_ref = [];

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
