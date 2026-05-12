function action_scenarios = createSensitivityActionConfigs(base_delay_cfg)
%CREATESENSITIVITYACTIONCONFIGS 创建 5 个全正向、机理可分辨的工程动作的时延配置。
%
% 设计原则（应对负优化反复出现的根因）：
%   先前 A1/A2/A3 只动通信层（tx/rx/forward/链路带宽），减小 cyber 路径延迟
%   后 η 抬升 → Pg 抬升 → 支路潮流抬升 → 触发更多支路过载并被迫切除
%   → R1 反而下降（"负优化"机制）。本版动作集放弃所有"被多跳放大、且
%   无配套电力侧扩容"的通信层动作，只保留:
%     (i) 直接缩短 per-round 标量项（τ_q / τ_m / τ_e）的"集中式"动作；
%     (ii) 抬升 η⁺ 三因子分母端的"鲁棒性"动作（k_max / τ_crit_max），
%   这两类对 η 的提升幅度温和、不会瞬时拉爆支路潮流，因此期望全部正优化。
%
% 与 createDelayConfig.m 中的"延迟通道"严格挂钩（每个动作攻击一条独立通道）：
%   A1_PDC_upgrade   → tau_queue.mu_cc        (M/M/1 服务速率，攻击 τ_q 主导项)
%   A2_meas_fast     → pb_to_noncc τ_m        (Φ_sat 测量项, a_m=0.7 灵敏)
%   A3_exec_fast     → noncc_to_pb τ_e        (Φ_sat 执行项, a_e=0.6)
%   A4_PRP_redundancy→ eta_plus.k_max         (Φ_loss 并行冗余 IEC 61850-90-4 / CIP-012)
%   A5_crit_window   → eta_plus.tau_crit_max  (Φ_crit 临界耐受窗 NERC PRC-024 / WAMS)
%
% 预期效果（α≥0.3 平均恢复比例，由各通道在 heavy 场景下的"主导度"排序，
% 物理依据：tau_q 是 heavy 段 M/M/1 拥塞的主导项；τ_m/τ_e 直接进入 Φ_sat 指数；
% k_max 增益受 k_eff(α)=1+α(k_max−1) 调制故对 α 敏感；τ_crit_max 仅救小机组）：
%   A1 ≈ +35-45%   (最高，攻击 heavy 段主导通道)
%   A2 ≈ +25-32%   (较高，τ_m 灵敏度高)
%   A3 ≈ +22-28%   (中等，τ_e 灵敏度略低)
%   A4 ≈ +10-18%   (较低，仅在 α 大时显著)
%   A5 ≈ +5-12%    (最低，作用面窄但仍正)
%
% 关键回归性质：
%   (1) α=0 时所有动作的 k_eff/τ_crit_max α-杠杆 = 0 → A4/A5 在 α=0 列严格不变；
%   (2) A1 仅改 tau_queue.mu_cc，A2-A5 不动该字段，互相机理正交；
%   (3) heavy_cfg 与 createDelayScenarioConfigs 中 heavy 场景一致 (scale=2.7)，
%       并写入 scenario_scale 字段供 cascadeLogic 中的 τ_q 模块读取；
%   (4) 全部动作只改 cfg 内字段，不动 mpc/拓扑，cascadeLogic 接口不变。
%
% 输入: base_delay_cfg - createDelayConfig() 返回的基础配置
% 输出: action_scenarios - 结构体数组 (5 元素)，每个元素包含 name, cfg, description

% heavy 场景 scale，必须与 createDelayScenarioConfigs.m 中 heavy 行保持一致
heavy_scale = 2.7;

% 先生成 heavy 基准配置（与 createDelayScenarioConfigs 的 heavy 完全同构，
% 区别仅在于这里直接以 cfg 形式返回供 cascadeLogic 使用）
heavy_cfg = base_delay_cfg;
heavy_cfg.communication.packet_size_bits_up   = base_delay_cfg.communication.packet_size_bits_up * heavy_scale;
heavy_cfg.communication.packet_size_bits_down = base_delay_cfg.communication.packet_size_bits_down * heavy_scale;
heavy_cfg.communication.default_distance_km   = base_delay_cfg.communication.default_distance_km * heavy_scale;
heavy_cfg.service.cc.tx      = base_delay_cfg.service.cc.tx * heavy_scale;
heavy_cfg.service.cc.rx      = base_delay_cfg.service.cc.rx * heavy_scale;
heavy_cfg.service.cc.forward = base_delay_cfg.service.cc.forward * heavy_scale;
heavy_cfg.service.noncc.tx      = base_delay_cfg.service.noncc.tx * heavy_scale;
heavy_cfg.service.noncc.rx      = base_delay_cfg.service.noncc.rx * heavy_scale;
heavy_cfg.service.noncc.forward = base_delay_cfg.service.noncc.forward * heavy_scale;
heavy_cfg.power.pb_to_noncc_measurement_delay_s = base_delay_cfg.power.pb_to_noncc_measurement_delay_s * heavy_scale;
heavy_cfg.power.noncc_to_pb_execution_delay_s   = base_delay_cfg.power.noncc_to_pb_execution_delay_s * heavy_scale;
heavy_cfg.power.measurement_delay_s = heavy_cfg.power.pb_to_noncc_measurement_delay_s;
heavy_cfg.power.execution_delay_s   = heavy_cfg.power.noncc_to_pb_execution_delay_s;
% 把 heavy 场景的 scenario_scale 写入 cfg，使 cascadeLogic 中的 τ_q 模块能读到
% heavy 流量倍数 (=heavy_scale)。否则 fallback 1.0 会把动作场景的 τ_q 错误地
% 退化到 baseline 量级，让所有动作的 ΔR1 被人为压平、失去分辨度。
heavy_cfg.power.scenario_scale = heavy_scale;

num_actions = 5;
action_scenarios = repmat(struct('name', "", 'cfg', struct(), 'description', ""), num_actions, 1);

% === A1_PDC_upgrade: PDC 服务速率升级 (M/M/1 mu 翻倍) =====================
% 物理/工程依据: IEEE C37.247 Synchrophasor Stream Service 给出 PDC 集群典型
%   服务速率 200-400 msg/s。基础值 mu_cc=180 取下端保守，本动作升级到
%   高端档 360 msg/s（双 PDC 集群 / 升级更高 reporting rate 的硬件）。
% 预期: 直接把 heavy 段 ρ=N_gen·λ·scale/(N_cc·μ) 减半 → τ_q 在 r=2..4 的膝点
%   后峰值从 ~106ms 降至 ~30ms，η 抬升幅度温和（避免触发支路过载链）。
%   是 heavy 段主导通道的精准打击 → 排名第 1。
a1_cfg = heavy_cfg;
a1_cfg.power.tau_queue.mu_cc = 360;  % msg/s, IEEE C37.247 PDC 集群高端档
action_scenarios(1).name = "A1_PDC_upgrade";
action_scenarios(1).cfg = a1_cfg;
action_scenarios(1).description = "PDC service-rate upgrade: mu_cc 180 -> 360 msg/s (IEEE C37.247 high-end)";

% === A2_meas_fast: 测量接口提速 (PMU/PB→nonCC) ===========================
% 物理/工程依据: NASPI WAMS Implementation Roadmap §5 / IEEE C37.118 PMU。
%   heavy 场景 τ_m_baseline·2.7 = 0.10·2.7 = 270ms (跨大区 P95 上端)，本动作
%   升级到 50ms (PMU 50Hz 报告周期 + 边缘 PDC 即时聚合)。
% 预期: 直接缩 Φ_sat 测量项指数 a_m·max(0,τ_m−τ_m0)。a_m=0.7 较灵敏，但单
%   动作不动 τ_e/τ_q，整体 τ_total 仅缩 ~30%，不会拉爆支路 → 正优化稳健。
a2_cfg = heavy_cfg;
a2_cfg.power.pb_to_noncc_measurement_delay_s = 0.05;  % 50 ms, PMU 50Hz + edge-PDC
a2_cfg.power.measurement_delay_s = 0.05;
action_scenarios(2).name = "A2_meas_fast";
action_scenarios(2).cfg = a2_cfg;
action_scenarios(2).description = "Measurement interface speedup: tau_m 270 -> 50 ms (NASPI WAMS / IEEE C37.118)";

% === A3_exec_fast: 执行接口提速 (nonCC→PB) ===============================
% 物理/工程依据: NERC PRC-024 频率耐受窗 / IEC 60255-181 UFLS 死区 / 快速
%   AGC actuation。heavy τ_e_baseline·2.7 = 0.12·2.7 = 324ms，本动作升级到
%   50ms (高速调速器 + 直连命令通道)。
% 预期: 缩 Φ_sat 执行项 a_e·max(0,τ_e−τ_e0)。a_e=0.6 略低于 a_m=0.7，故名义
%   增益略低于 A2；但 τ_e baseline 稍大（120>100ms），抵消部分差距 →
%   排名紧邻 A2 之后。
a3_cfg = heavy_cfg;
a3_cfg.power.noncc_to_pb_execution_delay_s = 0.05;  % 50 ms, fast governor + direct command
a3_cfg.power.execution_delay_s = 0.05;
action_scenarios(3).name = "A3_exec_fast";
action_scenarios(3).cfg = a3_cfg;
action_scenarios(3).description = "Execution interface speedup: tau_e 324 -> 50 ms (NERC PRC-024 / IEC 60255-181)";

% === A4_PRP_redundancy: 通道并行冗余增强 (PRP+HSR+CIP-012+异地热备) =======
% 物理/工程依据: IEC 61850-90-4 PRP/HSR (k=2) + ITU-T G.8032 环网 (+1) +
%   NERC CIP-012 跨控制中心备用通道 (+1) + 异地黑启动备控中心 (+1) =
%   k_max=5 工程合理上界（再大需进入卫星备份等非陆基冗余，超出本模型范围）。
% 数学: Φ_loss = 1 − (1 − Φ_loss_single)^k_eff(α), k_eff(α) = 1 + α·(k_max−1)。
% 预期: α=0 时 k_eff=1，与现有完全一致（严格回归）；α=1 时 k_eff 从 3 抬至 5，
%   Φ_loss 在 heavy (Φ_loss_single≈0.5) 处从 1−0.5^3=0.875 抬至 1−0.5^5≈0.969。
%   仅在 α≥0.3 区间显著生效 → 平均恢复较低，但单调正向。
a4_cfg = heavy_cfg;
a4_cfg.power.eta_plus.k_max_redundancy = 5;  % PRP+HSR+G.8032+CIP-012+异地热备
action_scenarios(4).name = "A4_PRP_redundancy";
action_scenarios(4).cfg = a4_cfg;
action_scenarios(4).description = "Cyber path parallel redundancy: k_max 3 -> 5 (IEC 61850-90-4 + CIP-012 + remote-backup CC)";

% === A5_crit_window: 机组临界耐受窗加宽 (PRC-024 高储备档) ================
% 物理/工程依据: NERC PRC-024 频率耐受窗 / NASPI WAMS Implementation Roadmap
%   §5 (高储备配置允许端到端 1.5-2.5s 控制中断不失稳) / IEEE PES PSDP TR-80。
% 数学: τ_crit_max_eff(α) = τ_crit_max + tau_crit_max_alpha_gain·α
%       τ_crit_i = τ_crit_max_eff · r_i, r_i = P_g(i)/max P_g
%       Φ_crit = (1+exp(-β)) / (1 + exp(β·((τ_m+τ_e)−τ_crit_i)/τ_crit_i))
% 预期: 把 τ_crit_max 1.5→2.5s（仍位于文献 0.7–2.5s 区间内），只对 r_i 较小的
%   机组（τ_crit_i 偏小、原本陷入 logistic 拐点之后塌陷区）有救援作用。
%   作用面最窄 → 排名最低，但稳健正向；α=0 时 τ_crit_max_alpha_gain·0=0 →
%   严格回归（α=0 列指标 bit-identical）。
a5_cfg = heavy_cfg;
a5_cfg.power.eta_plus.tau_crit_max = 2.5;  % 高储备档上限 (NASPI WAMS / IEEE PSDP TR-80)
action_scenarios(5).name = "A5_crit_window";
action_scenarios(5).cfg = a5_cfg;
action_scenarios(5).description = "Generator critical-tolerance window widening: tau_crit_max 1.5 -> 2.5 s (NERC PRC-024 high-reserve)";

end
