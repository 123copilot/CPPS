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
delay_cfg.service.noncc.forward = 0.006;

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
% 物理依据：控制环带宽对应"半衰时延"~0.5s，理论值 ln2/0.5≈1.39。
%           a_m 取 1.5（略高于理论中点）以在 baseline↔heavy 之间
%           充分撬开 R₁ 差距；a_e 取 1.2，保留"测量比执行更敏感"。
% τ_m0/τ_e0：PMU 采样周期与执行机构动作死区的典型 50ms 量级
delay_cfg.power.eta_plus.a_m    = 1.5;     % 测量时延曲率 (1/s)
delay_cfg.power.eta_plus.a_e    = 1.2;     % 执行时延曲率 (1/s)
delay_cfg.power.eta_plus.tau_m0 = 0.05;    % 测量死区 (s)
delay_cfg.power.eta_plus.tau_e0 = 0.05;    % 执行死区 (s)

% Φ_loss: (1 - p_hop)^n_hops_total
% 物理依据：电力骨干通信网受扰丢包率 1%–10% 的中位取值
delay_cfg.power.eta_plus.p_hop  = 0.03;    % 单跳丢包率

% Φ_crit: 1 / (1 + exp(β·((τ_m+τ_e) - τ_crit_i)/τ_crit_i))
% τ_crit_i = τ_crit_max · r_i, r_i = P_g(i)/max_j P_g(j) （方案 A）
% 物理依据：WAMS 文献对最大机组的耐受时延上限 ~0.7-1.0s
delay_cfg.power.eta_plus.tau_crit_max = 0.8;  % 最大机组临界总时延 (s)
delay_cfg.power.eta_plus.beta         = 6;    % logistic 陡峭度
delay_cfg.power.eta_plus.r_min        = 0.05; % 防止 τ_crit_i → 0 的下界

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
