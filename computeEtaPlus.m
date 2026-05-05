function [eta, components] = computeEtaPlus(tau_m, tau_e, n_hops_total, P_g_ref_i, P_g_ref_max, delay_cfg, alpha)
%COMPUTEETAPLUS  四因子时延效率 η⁺ = Φ_sat · Φ_loss · Φ_crit
%
% 公式
% ----
%   Φ_sat  = exp(-a_m · max(0, τ_m - τ_m0) - a_e · max(0, τ_e - τ_e0))
%   Φ_loss = 1 - (1 - Φ_loss_single)^k_eff(α)   （并行冗余可靠性，IEEE Std 493 / IEC 61078）
%       Φ_loss_single = (1 - p_hop_eff)^n_hops_total
%       p_hop_eff     = p_hop · min(1, (τ_m + τ_e)/τ_ref)
%       k_eff(α)      = 1 + α · (k_max - 1)         （k_max 来自 delay_cfg.power.eta_plus.k_max_redundancy）
%   Φ_crit = (1 + exp(-β)) / (1 + exp(β · ((τ_m + τ_e) - τ_crit_i)/τ_crit_i))
%       （归一化形式：等价于 logistic 除以其 τ=0 处取值，保证 Φ_crit(0)=1）
%   τ_crit_i = τ_crit_max · r_i,   r_i = P_g_ref_i / P_g_ref_max  （方案 A）
%
% 物理含义
% --------
%   Φ_sat  打开"baseline ↔ heavy"的功率衰减差距（旧线性 η 之改进）
%   Φ_loss 让"通信路径越远越不可靠"在 R₁ 上可见
%   Φ_crit 让小机组在轻延迟下也可能崩溃，制造异质协同效应
%
% 参数
% ----
%   tau_m, tau_e        标量：测量/执行时延 (s)，必须 ≥ 0
%   n_hops_total        标量：上行 + 下行 cyber 跳数，整数 ≥ 0
%   P_g_ref_i           标量：发电机 i 的参考有功 (MW)，可为 0
%   P_g_ref_max         标量：所有发电机参考有功最大值 (MW)，必须 > 0
%   delay_cfg           struct：必须包含 .power.eta_plus 子结构
%   alpha               (可选) 标量：N-k 容量裕度系数 ∈ [0,1]，
%                        映射到 CC↔gen 通信通道的等效并行冗余度
%                        k_eff(α) = 1 + α·(k_max-1)。默认 0（=单通道，
%                        与历史版本 Φ_loss 严格回归，所有 α=0 历史结果不变）。
%
% 返回
% ----
%   eta                 标量：η⁺ ∈ [0, 1]
%   components          struct：phi_sat / phi_loss / phi_crit / r_i / tau_crit_i
%
% 说明
% ----
%   * 当 r_i < r_min 时（机组参考出力极小），Φ_crit 退化为 1，避免 0/0；
%     此时 η⁺ 仍会被 P_ref 乘以接近 0，物理结果不变。
%   * 与旧 η 的退化关系：把 (τ_m0, τ_e0, p_hop, 1/τ_crit_max) 全部置 0
%     且 (a_m, a_e) 置 (k_m, k_e)，η⁺ 在小延迟下退化为旧 η 的指数化版本。

% --- 输入校验 -----------------------------------------------------------
if ~isfield(delay_cfg, 'power') || ~isfield(delay_cfg.power, 'eta_plus')
    error('computeEtaPlus:missingConfig', ...
        'delay_cfg.power.eta_plus 子结构缺失，请检查 createDelayConfig。');
end
ep = delay_cfg.power.eta_plus;

% alpha 为可选参数：未提供时按 0 处理 → k_eff=1 → Φ_loss 退化为单路径形式，
% 与历史版本（无并行冗余）逐位等价，保证既有调用点（α=0 工况、未传 α 的
% 后处理脚本如 computeCascadeR3Metric）行为不变。
if nargin < 7 || isempty(alpha)
    alpha = 0;
end
if any(alpha(:) < 0) || any(alpha(:) > 1)
    error('computeEtaPlus:invalidAlpha', 'alpha 必须 ∈ [0, 1]。');
end
% k_max_redundancy 字段缺省时回退到 1（=无冗余），同样保证旧 cfg 仍可运行。
if isfield(ep, 'k_max_redundancy') && ~isempty(ep.k_max_redundancy)
    k_max = ep.k_max_redundancy;
else
    k_max = 1;
end
if k_max < 1
    error('computeEtaPlus:invalidKmax', 'k_max_redundancy 必须 ≥ 1。');
end

required_fields = {'a_m', 'a_e', 'tau_m0', 'tau_e0', 'p_hop', 'tau_ref', ...
    'tau_crit_max', 'beta', 'r_min'};
for kf = 1:numel(required_fields)
    if ~isfield(ep, required_fields{kf})
        error('computeEtaPlus:missingField', ...
            'delay_cfg.power.eta_plus.%s 字段缺失。', required_fields{kf});
    end
end

if any(tau_m(:) < 0) || any(tau_e(:) < 0)
    error('computeEtaPlus:negativeDelay', 'tau_m 和 tau_e 必须 ≥ 0。');
end
if any(n_hops_total(:) < 0)
    error('computeEtaPlus:negativeHops', 'n_hops_total 必须 ≥ 0。');
end
if ~(P_g_ref_max > 0)
    error('computeEtaPlus:invalidPmax', 'P_g_ref_max 必须 > 0。');
end
if ep.tau_crit_max <= 0
    error('computeEtaPlus:invalidTauCrit', 'tau_crit_max 必须 > 0。');
end
if ep.p_hop < 0 || ep.p_hop > 1
    error('computeEtaPlus:invalidPhop', 'p_hop 必须 ∈ [0, 1]。');
end

% --- Φ_sat: 指数饱和 + 死区 ---------------------------------------------
tilde_tau_m = max(0, tau_m - ep.tau_m0);
tilde_tau_e = max(0, tau_e - ep.tau_e0);
phi_sat = exp(-ep.a_m .* tilde_tau_m - ep.a_e .* tilde_tau_e);
phi_sat = max(0, min(1, phi_sat));

% --- Φ_loss: 跳数累积可靠性 + α-参数化并行冗余 -------------------------
% 物理依据 (单路径 p_hop_eff)：网络拥塞导致的端到端时延与丢包率正相关
% （M/M/1 排队论：利用率 ρ↑ → 队列时延↑ 且 丢包率↑；ITU-T G.1010 同样
% 指出丢包率随拥塞时延近似线性增长直至饱和）。因此把单跳丢包率写成关于
% 端到端总时延的连续单调函数，并以 baseline 总时延 τ_ref 作为达到
% 标称丢包率 p_hop 的拥塞参考点：
%   p_hop_eff = p_hop · min(1, (τ_m + τ_e) / τ_ref)
% 满足三项关键性质：
%   (1) τ=0 → p_hop_eff=0 → Φ_loss=1（自动满足"理想信道"边界，
%       即 no_delay 场景 η=1，无需出口硬编码）；
%   (2) 在 (τ_m+τ_e) ≤ τ_ref 区间内连续单调递增，使 light/baseline
%       场景间获得可分辨的 Φ_loss 阶梯，取代旧版"非零即 p_hop"的阶跃；
%   (3) (τ_m+τ_e) ≥ τ_ref 后 min(·) 截断到 1，避免 p_hop_eff>p_hop
%       带来的非物理外推（拥塞超过参考后丢包率仍受链路硬件上限约束）。
%
% 物理依据 (并行冗余 k_eff(α))：N-k 容量裕度 α 在通信层的孪生概念是
% 双 / 多通道冗余（IEC 61850-90-4 PRP/HSR、ITU-T G.8032 环网保护、
% IEEE PSRC C-14 双通道远动、NERC CIP-012 通信冗余要求）。把 α 映射到
% CC↔gen 之间等效独立并行路径数：
%   k_eff(α) = 1 + α · (k_max - 1),   α ∈ [0,1],  k_max 默认 2 (PRP 双通道)
% 对 k 条独立路径用 IEEE Std 493 §3.2 / IEC 61078 RBD 标准的 parallel
% reliability 公式：Φ_loss = 1 - (1 - Φ_loss_single)^k_eff，从而：
%   - α=0 → k_eff=1 → Φ_loss = Φ_loss_single（与历史版本严格回归）；
%   - α↑ → k_eff↑ → Φ_loss↑ → η↑ → R₃↓（α 的冗余红利经 R₃ 体现）；
%   - τ↑ → Φ_loss_single↓ → 即便 k_eff 增大乘积仍下降（保留时延危害）。
tau_total = tau_m + tau_e;
if ep.tau_ref > 0
    p_hop_eff = ep.p_hop * min(1, tau_total / ep.tau_ref);
else
    % 退化：tau_ref 非正时回退到旧阶跃形式，保证可回归对比。
    p_hop_eff = ep.p_hop * double(tau_total > 0);
end
p_hop_eff = max(0, min(1, p_hop_eff));
phi_loss_single = (1 - p_hop_eff) .^ n_hops_total;
phi_loss_single = max(0, min(1, phi_loss_single));
% 并行冗余：k_eff(α) = 1 + α·(k_max-1)。α=0 ⇒ k_eff=1 ⇒ phi_loss = phi_loss_single。
k_eff = 1 + alpha * (k_max - 1);
phi_loss = 1 - (1 - phi_loss_single) .^ k_eff;
phi_loss = max(0, min(1, phi_loss));

% --- Φ_crit: 异质 logistic 临界因子（方案 A 归一化 + τ=0 基线归一化）----
% 物理依据：Φ_crit 表达"端到端总时延 τ 相对于理想信道 (τ=0) 的临界稳定性
% 存活率"。原始 logistic 在 τ=0 处取值为 1/(1+exp(-β)) ≈ 0.9975 (β=6)，
% 即使无任何延迟也会让机组被轻微降额，这与"理想信道 ⇒ 不降额"的物理基线
% 不一致；当 light 场景的 η 与 no_delay 仅相差 ~0.25% 时，级联随机扰动
% 会让 ΔR1 在 α=0.1 这样的轻微攻击下出现非物理的负值。
%
% 解决办法：把 Φ_crit 归一化到其 τ=0 处取值，即
%   Φ_crit(τ) = Φ_crit_logistic(τ) / Φ_crit_logistic(0)
%             = (1 + exp(-β)) / (1 + exp(β·(τ - τ_crit_i)/τ_crit_i))
% 理论依据：可靠性工程中"条件/相对存活概率"标准做法——把临界存活率写成
% 相对理想基线的比值，而非绝对值。这样既保留三项关键性质（τ_crit_i 处
% 拐点、大 τ 趋于 0、按容量异质化），又把 τ=0 的基线钉在 1，让
% 三因子乘积 η⁺ 在 no_delay 场景下严格等于 1，符合工程内涵。
r_i = max(0, P_g_ref_i) / P_g_ref_max;
if r_i <= ep.r_min
    % 机组几乎无出力（含 r_i = 0 的情形）→ P_ref ≈ 0 已让结果归零，
    % Φ_crit 取 1 以避免 (τ-0)/0 = Inf。case39 中所有 r_i ≥ 0.25，
    % 此分支不会触发；保留是为兼容其他算例。
    phi_crit = 1;
    tau_crit_i = NaN;
else
    tau_crit_i = ep.tau_crit_max * r_i;
    arg = ep.beta * ((tau_m + tau_e) - tau_crit_i) / tau_crit_i;
    % 归一化：分子 (1+exp(-β)) 即原 logistic 在 τ=0 处的分母，
    % 因此 phi_crit(τ=0) = (1+exp(-β))/(1+exp(-β)) = 1 严格成立。
    phi_crit = (1 + exp(-ep.beta)) ./ (1 + exp(arg));
end
phi_crit = max(0, min(1, phi_crit));

% --- 组合 --------------------------------------------------------------
eta = phi_sat .* phi_loss .* phi_crit;
eta = max(0, min(1, eta));

if nargout > 1
    components = struct( ...
        'phi_sat', phi_sat, ...
        'phi_loss', phi_loss, ...
        'phi_loss_single', phi_loss_single, ...
        'k_eff', k_eff, ...
        'phi_crit', phi_crit, ...
        'r_i', r_i, ...
        'tau_crit_i', tau_crit_i);
end
end
