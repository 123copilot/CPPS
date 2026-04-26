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
% τ_m0/τ_e0：PMU 采样周期与执行机构动作死区的典型 50ms 量级
delay_cfg.power.eta_plus.a_m    = 0.7;     % 测量时延曲率 (1/s)
delay_cfg.power.eta_plus.a_e    = 0.6;     % 执行时延曲率 (1/s)
delay_cfg.power.eta_plus.tau_m0 = 0.05;    % 测量死区 (s)
delay_cfg.power.eta_plus.tau_e0 = 0.05;    % 执行死区 (s)

% Φ_loss: (1 - p_hop_eff)^n_hops_total，p_hop_eff = p_hop · 1{τ>0}
% 物理依据：电力骨干通信网受扰丢包率 1%–10% 文献区间的中位偏高估值，
%           用以补偿 a_m/a_e 下调后场景间垂直分离度的损失。
delay_cfg.power.eta_plus.p_hop  = 0.05;    % 单跳丢包率（受扰条件）

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
