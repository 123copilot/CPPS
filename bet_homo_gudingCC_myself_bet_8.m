% % main.m — 延迟注入级联仿真主脚本
% 核心改动：每个延迟场景独立运行完整级联，delay已在rundcpf前注入
clc ;
clearvars -except num_samples_override ;
rehash;
clear('cascadeLogicdebug2gudingCC_bet_8', 'computeCascadeR3Metric', 'computeDelayAdjustedR1');

%% --- 主实验设置 ---
propagation_probability = 0.3;
attackMode = 'betweenness';
conn_modes = {'homogametic'};
delay_cfg = createDelayConfig();
delay_scenarios = createDelayScenarioConfigs(delay_cfg);
num_delay_scenarios = numel(delay_scenarios);
scenario_labels = strings(num_delay_scenarios, 1);
for idxScenario = 1:num_delay_scenarios
    scenario_labels(idxScenario) = delay_scenarios(idxScenario).name;
end

% 透明化：打印每个场景在"无 cyber 链路时延"假设下的理论 φ，
% 用于事前校准 5 个场景在 R1 上的预期间距（cyber 链路时延会让实际 φ 略低）。
use_etaplus_print = isfield(delay_cfg.power, 'eta_model') && ...
    strcmpi(delay_cfg.power.eta_model, 'etaplus');
if use_etaplus_print
    ep_print = delay_cfg.power.eta_plus;
    fprintf('\n===== 各时延场景理论 Φ_sat 上界 (η⁺ 模型) =====\n');
    fprintf('  a_m=%.2f, a_e=%.2f, τ_m0=%.3fs, τ_e0=%.3fs\n', ...
        ep_print.a_m, ep_print.a_e, ep_print.tau_m0, ep_print.tau_e0);
    fprintf('  p_hop=%.3f, τ_ref=%.3fs, τ_crit_max=%.2fs, β=%.1f (Φ_loss/Φ_crit 取决于路径与机组)\n', ...
        ep_print.p_hop, ep_print.tau_ref, ep_print.tau_crit_max, ep_print.beta);
    for idxScenario = 1:num_delay_scenarios
        sc_cfg = delay_scenarios(idxScenario).cfg;
        tau_m_th = sc_cfg.power.pb_to_noncc_measurement_delay_s;
        tau_e_th = sc_cfg.power.noncc_to_pb_execution_delay_s;
        ep_sc = sc_cfg.power.eta_plus;
        tilde_m = max(0, tau_m_th - ep_sc.tau_m0);
        tilde_e = max(0, tau_e_th - ep_sc.tau_e0);
        phi_sat_th = exp(-ep_sc.a_m * tilde_m - ep_sc.a_e * tilde_e);
        if ep_sc.tau_ref > 0
            p_hop_eff_th = ep_sc.p_hop * min(1, (tau_m_th + tau_e_th) / ep_sc.tau_ref);
        else
            p_hop_eff_th = ep_sc.p_hop * double((tau_m_th + tau_e_th) > 0);
        end
        fprintf('  %-10s: scale=%.2f, τ_m=%.3fs, τ_e=%.3fs, Φ_sat≈%.3f, p_hop_eff≈%.4f\n', ...
            char(scenario_labels(idxScenario)), delay_scenarios(idxScenario).scale, ...
            tau_m_th, tau_e_th, phi_sat_th, p_hop_eff_th);
    end
else
    fprintf('\n===== 各时延场景理论 φ (legacy 线性模型) =====\n');
    fprintf('  k_m=%.2f, k_e=%.2f, baseline τ_m=%.3fs, τ_e=%.3fs\n', ...
        delay_cfg.power.measurement_sensitivity, delay_cfg.power.execution_sensitivity, ...
        delay_cfg.power.pb_to_noncc_measurement_delay_s, delay_cfg.power.noncc_to_pb_execution_delay_s);
    for idxScenario = 1:num_delay_scenarios
        sc_cfg = delay_scenarios(idxScenario).cfg;
        tau_m_th = sc_cfg.power.pb_to_noncc_measurement_delay_s;
        tau_e_th = sc_cfg.power.noncc_to_pb_execution_delay_s;
        f_m_th = max(0, 1 - delay_cfg.power.measurement_sensitivity * tau_m_th);
        f_e_th = max(0, 1 - delay_cfg.power.execution_sensitivity * tau_e_th);
        phi_th = f_m_th * f_e_th;
        fprintf('  %-10s: scale=%.2f, τ_m=%.3fs, τ_e=%.3fs, f_m=%.3f, f_e=%.3f, φ≈%.3f\n', ...
            char(scenario_labels(idxScenario)), delay_scenarios(idxScenario).scale, ...
            tau_m_th, tau_e_th, f_m_th, f_e_th, phi_th);
    end
end

% 定义不同的连接模式和绘图样式
plot_styles = ':^';
line_colors = [0 0.6 0];
marker_colors = 'k';
conn_labels = 'betweenness_homogametic';

% 启动并行池
if isempty(gcp('nocreate'))
    numWorkers = feature('numcores');
    parpool('local', numWorkers);
    fprintf('已启动并行池，使用 %d 个 workers\n', numWorkers);
end


%% 构造电网连接矩阵Ap

mpopt = mpoption('verbose',1,'out.all',0,'out.sys_sum',1);
mpc = loadcase('case39') ;
results_dc = rundcpf(mpc,mpopt) ;
Vp = size(mpc.bus, 1);

Ap = zeros(Vp, Vp);

for k = 1:size(mpc.branch, 1)
    i = mpc.branch(k, 1);
    j = mpc.branch(k, 2);
    Ap(i, j) = 1;
    Ap(j, i) = 1;
end

for i = 1:Vp
    Ap(i, i) = 0;
end

%构造电力系统的图
nodeNames_Vp = string(1:Vp);
G_power = graph(Ap,nodeNames_Vp);

%计算每个电力节点度数中心性
degP = centrality(G_power, 'degree');

%计算每个电力节点介数中心性
betP = centrality(G_power, 'betweenness')+1;

%% 用BA网络构造信息层
num_cc = max(1,round(0.2*Vp));
Vc      = Vp + num_cc;
m = 4;
m_edge = 2;


%% 确定电力层与信息层节点/连边的负载
P_bus = results_dc.bus(:,3) + 1;
P_branch = abs(results_dc.branch(:,14)) + 1;
initial_power_load = mpc.bus(:, 3);

% R3 现仅统计"在场机组"的跟踪偏差（NERC BAL-001-2 / Kundur §11.1.6 /
% Jaleeli 1992：committed and on-AGC 样本集），无需预计算原始机组
% 列表——被切除/孤岛机组的危害由 R1 的 surviving_load·φ_eff 通路承担，
% 不再以 (P_ref=Pg, P_actual=0) 形式重复计入 R3，避免双重计费。

total_P_bus = sum(P_bus);
total_P_branch = sum(P_branch);


% 设置要生成的A_pc数量
if exist('num_samples_override', 'var')
    num_samples = num_samples_override;
else
    num_samples = 500;
end


[A_pc_cell, control_centers_cell, info_pool_cell,isCC_cell,Ac_cell,betC_cell, betCE_cell,G_cyber_ba_cell,MSIS_myself_cell] = generate_multiple_A_pc_gudingCC_myself_bet_homo_8(num_samples, Vc, num_cc, betP, Vp,m,m_edge) ;

%% ====================================================================
%% 核心改动：每个延迟场景独立运行完整级联
%% ====================================================================

% 预分配跨场景结果存储
failP_all = cell(num_delay_scenarios, 1);        % {scenario}(alpha, trial)
failC_all = cell(num_delay_scenarios, 1);
failed_nodes_all = cell(num_delay_scenarios, 1);  % {scenario}{alpha, trial}
round_log_all = cell(num_delay_scenarios, 1);     % {scenario}{alpha, trial}

fprintf('\n========== 开始多场景级联仿真 ==========\n');
fprintf('共 %d 个延迟场景，每个场景 %d samples\n', ...
    num_delay_scenarios, num_samples);

for idxScenario = 1:num_delay_scenarios
    current_delay_cfg = delay_scenarios(idxScenario).cfg;
    scenario_name = delay_scenarios(idxScenario).name;
    fprintf('\n===== 场景 %d/%d: %s (scale=%.1f) =====\n', ...
        idxScenario, num_delay_scenarios, scenario_name, delay_scenarios(idxScenario).scale);

    [failP_mat_s, failC_mat_s, alpha_range_s, failed_power_nodes_cell_s, cascade_round_log_cell_s] = ...
        cascadeLogicdebug2gudingCC_bet_8(...
            mpc, Vc, Ap, Ac_cell, A_pc_cell, propagation_probability, ...
            P_branch, betC_cell, betCE_cell, info_pool_cell, attackMode, ...
            control_centers_cell, isCC_cell, mpopt, G_cyber_ba_cell, current_delay_cfg);

    % 使用级联引擎返回的 alpha_range（确保一致性）
    if idxScenario == 1
        alpha_range = alpha_range_s;
        numA = numel(alpha_range);
        fprintf('从级联引擎获取 alpha_range: %d 个值 [%.1f : %.1f : %.1f]\n', ...
            numA, alpha_range(1), alpha_range(2)-alpha_range(1), alpha_range(end));
    end

    failP_all{idxScenario} = failP_mat_s;
    failC_all{idxScenario} = failC_mat_s;
    failed_nodes_all{idxScenario} = failed_power_nodes_cell_s;
    round_log_all{idxScenario} = cascade_round_log_cell_s;

    fprintf('场景 %s 级联仿真完成。\n', scenario_name);
end

fprintf('\n========== 所有场景级联仿真完成 ==========\n');

%% ====================================================================
%% 后处理：从级联结果中提取 R1, R3, 延迟因素指标
%% ====================================================================

% 验证数据一致性
assert(numA == size(failed_nodes_all{1}, 1), ...
    'alpha_range 与级联数据不一致: numA=%d 但数据有 %d 行', ...
    numA, size(failed_nodes_all{1}, 1));
assert(num_samples == size(failed_nodes_all{1}, 2), ...
    'num_samples 与级联数据不一致: num_samples=%d 但数据有 %d 列', ...
    num_samples, size(failed_nodes_all{1}, 2));

% R1: 使用 delay-adjusted R1，将时延效率 φ 纳入负荷保持率计算
% R1_delay = (surviving_load × φ) / initial_total_load
% 其中 φ = min(1, sum(P_actual) / sum(P_ref))，反映时延导致的发电出力折减
R1_mat = NaN(numA, num_samples, num_delay_scenarios);

% R3 与延迟因素：从 delay_injection_log 提取
R3_mat = NaN(numA, num_samples, num_delay_scenarios);
A1_eta_mat = NaN(numA, num_samples, num_delay_scenarios);
A1_tau_m_mat = NaN(numA, num_samples, num_delay_scenarios);
A1_tau_e_mat = NaN(numA, num_samples, num_delay_scenarios);
A1_unreachable_ratio_mat = NaN(numA, num_samples, num_delay_scenarios);

% 逐轮时间序列
round_ts_R1_cell = cell(numA, num_samples, num_delay_scenarios);
% R3 逐轮时间序列：第 r 轮的值 = "本轮（仅本轮）在场机组的容量加权 NRMSE"
% （per-round R3，使用 P_ref_round, P_actual_round 调用 computeR3Deviation）。
% 与 R1 的逐轮口径对齐（R1 也是逐轮、不累计），让 Fig4b 的 ΔR3 热力图与
% Fig4 的 ΔR1 热力图在"轮次"维度上同语义可比，从而能一致地判断"哪一轮
% 时延危害最大"。注意：该 per-round 序列只用于 Fig4b 热力图；
% trial 级 R3（R3_mat，line ~402）以及 plotCombinedR3 仍使用全程累计
% (P_ref_traj, P_actual_traj) 的 NRMSE，口径不变（向后兼容所有现有图）。
% 因此 round_ts_R3_cell 的最后一项不再恒等于 R3_mat（这是预期变化）。
round_ts_R3_cell = cell(numA, num_samples, num_delay_scenarios);
round_ts_eta_cell = cell(numA, num_samples, num_delay_scenarios);
round_ts_unreachable_cell = cell(numA, num_samples, num_delay_scenarios);
round_ts_n_failed_power_cell = cell(numA, num_samples, num_delay_scenarios);
round_ts_n_failed_cyber_cell = cell(numA, num_samples, num_delay_scenarios);

% (per-generator η 相关变量已移除，改用 R1 分布 box plot)

for idxScenario = 1:num_delay_scenarios
    for idxAlpha = 1:numA
        for trial = 1:num_samples
            failed_pn = failed_nodes_all{idxScenario}{idxAlpha, trial};

            % 从 round_log 中提取逐轮信息
            round_logs = round_log_all{idxScenario}{idxAlpha, trial};

            % R1：使用 delay-adjusted 计算，但 φ 改为"全程加权 φ_traj"，
            % 即对该 trial 的所有级联轮次累计 (P_ref, P_actual)，避免只取最后一轮
            % 时由于幸存发电机数极少导致的高方差/反转。
            % φ_traj = (Σ_round Σ_g P_ref_g_round · η_g_round) / (Σ_round Σ_g P_ref_g_round)
            % 实际计算逻辑：累加 P_ref/P_actual 之后调一次 computeDelayAdjustedR1，
            % 利用其内部公式 R1 = surviving_load * (sum(P_actual)/sum(P_ref)) / total_load 一次成型。
            % 另外，为反映 UFLS 主动减载（拓扑外的"被切走的负荷"），同时按 w_r=ΣP_ref_round
            % 加权累计 φ_eff_round 与 surviving_load_round，最终以
            %   R1 = surviving_load_traj × min(φ_global_traj, φ_eff_traj) / L_initial
            % 计算 trial 级 R1。这样 (A) 拓扑停电、(B) η 折损、(C) UFLS 主动减载
            % 三种"用户失电"通道都被纳入，不会再出现 light < no_delay 的反转。
            % R1 与 R3 共用全程在场机组样本集 (P_ref_traj, P_actual_traj)：
            % R3 只统计"在场机组"的跟踪偏差；α 通过 (1) 改变每轮 S_r 集合
            % 与 P_ref 容量权重 (2) 通过 γ_over/UFLS 改变 η 这两条路径进入 R3；
            % 被切机组的危害归 R1，避免双重计费。
            P_ref_traj = [];
            P_actual_traj = [];

            if isempty(round_logs)
                R1_mat(idxAlpha, trial, idxScenario) = computeR1LoadRatio(initial_power_load, failed_pn);
                continue;
            end

            num_rounds = numel(round_logs);
            round_R1_values = NaN(num_rounds, 1);
            round_R3_values = NaN(num_rounds, 1);
            round_eta_values = NaN(num_rounds, 1);
            round_unreachable_values = NaN(num_rounds, 1);
            round_n_fp = NaN(num_rounds, 1);
            round_n_fc = NaN(num_rounds, 1);

            trial_eta_sum = 0; trial_eta_count = 0;
            trial_tau_m_sum = 0; trial_tau_m_count = 0;
            trial_tau_e_sum = 0; trial_tau_e_count = 0;
            trial_unreachable = 0; trial_gen_total = 0;

            % UFLS 加权累计器：以本轮参考发电量 w_r=ΣP_ref_round 为权
            traj_w_total = 0;
            traj_w_phi_eff_sum = 0;
            traj_w_surv_load_sum = 0;

            for roundIdx = 1:num_rounds
                rl = round_logs{roundIdx};
                round_n_fp(roundIdx) = numel(rl.failed_power_nodes);
                round_n_fc(roundIdx) = numel(rl.failed_cyber_nodes);

                % R1 per round（delay-adjusted）
                if isfield(rl, 'delay_injection_log') && ~isempty(rl.delay_injection_log.eta)
                    dil_round = rl.delay_injection_log;
                    P_ref_round = [];
                    P_actual_round = [];
                    for gk_round = 1:numel(dil_round.eta)
                        match_round = find(mpc.gen(:,1) == dil_round.gen_bus(gk_round), 1, 'first');
                        if ~isempty(match_round) && abs(mpc.gen(match_round, 2)) > eps
                            pg_ref_round = mpc.gen(match_round, 2);
                            P_ref_round(end+1, 1) = pg_ref_round; %#ok<AGROW>
                            P_actual_round(end+1, 1) = pg_ref_round * dil_round.eta(gk_round); %#ok<AGROW>
                        end
                    end
                    if ~isempty(P_ref_round) && sum(P_ref_round) > 0
                        % 提取本轮 UFLS 实际保留比例 φ_eff（默认 1：UFLS 关闭或未触发）
                        if isfield(dil_round, 'ufls_phi_eff') && ~isempty(dil_round.ufls_phi_eff)
                            phi_eff_round = dil_round.ufls_phi_eff;
                        else
                            phi_eff_round = 1;
                        end
                        % 本轮拓扑幸存负荷（A 类停电之后剩余的用户负荷）
                        [~, surv_load_round, ~] = computeR1LoadRatio(initial_power_load, rl.failed_power_nodes);
                        round_R1_values(roundIdx) = computeDelayAdjustedR1( ...
                            initial_power_load, rl.failed_power_nodes, P_actual_round, P_ref_round, ...
                            phi_eff_round);
                        % 追加到全程轨迹累计向量，R1（φ_traj）与 R3（容量加权
                        % NRMSE）共用同一在场机组样本集
                        P_ref_traj = [P_ref_traj; P_ref_round]; %#ok<AGROW>
                        P_actual_traj = [P_actual_traj; P_actual_round]; %#ok<AGROW>
                        % 以 w_r=ΣP_ref_round 加权累计 φ_eff 与 surviving_load
                        w_r = sum(P_ref_round);
                        traj_w_total = traj_w_total + w_r;
                        traj_w_phi_eff_sum = traj_w_phi_eff_sum + w_r * phi_eff_round;
                        traj_w_surv_load_sum = traj_w_surv_load_sum + w_r * surv_load_round;

                        % 本轮 per-round R3：仅以本轮在场机组样本
                        % (P_ref_round, P_actual_round) 计算容量加权 NRMSE，
                        % 不累计前序轮次。这样 Fig4b 热力图与 Fig4 (R1) 的
                        % "轮次"维度同语义——两者都反映"该轮单独承受的时延伤害"，
                        % 从而能一致地指示危害峰所在的轮次。
                        % 仅用于 round_ts_R3_cell → mean_ts_R3 → Fig4b；
                        % trial 级 R3_mat（见下方 line ~402，全程累计 NRMSE）
                        % 与 plotCombinedR3 走累计口径，互不影响。
                        round_R3_values(roundIdx) = computeR3Deviation( ...
                            P_actual_round, P_ref_round);
                    else
                        round_R1_values(roundIdx) = computeR1LoadRatio(initial_power_load, rl.failed_power_nodes);
                    end
                else
                    round_R1_values(roundIdx) = computeR1LoadRatio(initial_power_load, rl.failed_power_nodes);
                end

                % 从 delay_injection_log 提取延迟指标
                if isfield(rl, 'delay_injection_log') && ~isempty(rl.delay_injection_log.eta)
                    dil = rl.delay_injection_log;
                    n_gen = numel(dil.eta);
                    reachable = logical(dil.is_reachable(:));

                    % 不可达比例
                    if n_gen > 0
                        round_unreachable_values(roundIdx) = sum(~reachable) / n_gen;
                        trial_unreachable = trial_unreachable + sum(~reachable);
                        trial_gen_total = trial_gen_total + n_gen;
                    end

                    % 可达发电机的平均 eta
                    eta_reachable = dil.eta(reachable);
                    if ~isempty(eta_reachable)
                        round_eta_values(roundIdx) = mean(eta_reachable);
                        trial_eta_sum = trial_eta_sum + sum(eta_reachable);
                        trial_eta_count = trial_eta_count + numel(eta_reachable);
                    end

                    % tau_m, tau_e
                    tau_m_reachable = dil.tau_m(reachable);
                    tau_m_valid = tau_m_reachable(~isnan(tau_m_reachable));
                    if ~isempty(tau_m_valid)
                        trial_tau_m_sum = trial_tau_m_sum + sum(tau_m_valid);
                        trial_tau_m_count = trial_tau_m_count + numel(tau_m_valid);
                    end

                    tau_e_reachable = dil.tau_e(reachable);
                    tau_e_valid = tau_e_reachable(~isnan(tau_e_reachable));
                    if ~isempty(tau_e_valid)
                        trial_tau_e_sum = trial_tau_e_sum + sum(tau_e_valid);
                        trial_tau_e_count = trial_tau_e_count + numel(tau_e_valid);
                    end
                end
            end

            % 保存逐轮时间序列
            round_ts_R1_cell{idxAlpha, trial, idxScenario} = round_R1_values;
            round_ts_R3_cell{idxAlpha, trial, idxScenario} = round_R3_values;
            round_ts_eta_cell{idxAlpha, trial, idxScenario} = round_eta_values;
            round_ts_unreachable_cell{idxAlpha, trial, idxScenario} = round_unreachable_values;
            round_ts_n_failed_power_cell{idxAlpha, trial, idxScenario} = round_n_fp;
            round_ts_n_failed_cyber_cell{idxAlpha, trial, idxScenario} = round_n_fc;

            % 用全程累计 (P_ref_traj, P_actual_traj) 一次性算 trial 级 R1：
            % R1 = surviving_load_traj × min(φ_global_traj, φ_eff_traj) / L_initial
            % 其中 φ_global_traj 等价于 sum(P_actual_traj)/sum(P_ref_traj)（P_ref 加权），
            % φ_eff_traj 与 surviving_load_traj 是按 w_r=ΣP_ref_round 加权的全程累计。
            % computeDelayAdjustedR1 内部对 phi_eff_override / surviving_load_override
            % 取 min 与替换，完整覆盖 (A) 拓扑停电、(B) η 折损、(C) UFLS 主动减载三类失电。
            if ~isempty(P_ref_traj) && sum(P_ref_traj) > 0
                if traj_w_total > 0
                    phi_eff_traj_val = traj_w_phi_eff_sum / traj_w_total;
                    surv_load_traj_val = traj_w_surv_load_sum / traj_w_total;
                else
                    phi_eff_traj_val = [];
                    surv_load_traj_val = [];
                end
                R1_mat(idxAlpha, trial, idxScenario) = computeDelayAdjustedR1( ...
                    initial_power_load, failed_pn, P_actual_traj, P_ref_traj, ...
                    phi_eff_traj_val, surv_load_traj_val);
            else
                R1_mat(idxAlpha, trial, idxScenario) = computeR1LoadRatio(initial_power_load, failed_pn);
            end

            % R3：复用 R1 的全程在场机组样本集 (P_ref_traj, P_actual_traj)，
            % 采用容量加权 NRMSE（computeR3Deviation 内实现）。R3 只度量
            % "在场机组的跟踪偏差"——被切除/孤岛机组的危害已由 R1 的
            % surviving_load·φ_eff 通路完整承担，不在 R3 中重复计费。
            % α 通过两条物理通路进入 R3：
            %   (1) (1+α)·rate 抬高线路阈值 → 改变每轮在场集合 S_r
            %       与 P_ref 权重分布
            %   (2) UFLS shed_max_eff(α) → γ_over → η_round
            % computeR3Deviation 的 P_ref==0 守卫由上游 abs(.)>eps 过滤保证。
            if ~isempty(P_ref_traj) && sum(P_ref_traj) > 0
                R3_mat(idxAlpha, trial, idxScenario) = computeR3Deviation(P_actual_traj, P_ref_traj);
            end

            % 聚合延迟因素
            if trial_eta_count > 0
                A1_eta_mat(idxAlpha, trial, idxScenario) = trial_eta_sum / trial_eta_count;
            end
            if trial_tau_m_count > 0
                A1_tau_m_mat(idxAlpha, trial, idxScenario) = trial_tau_m_sum / trial_tau_m_count;
            end
            if trial_tau_e_count > 0
                A1_tau_e_mat(idxAlpha, trial, idxScenario) = trial_tau_e_sum / trial_tau_e_count;
            end
            if trial_gen_total > 0
                A1_unreachable_ratio_mat(idxAlpha, trial, idxScenario) = trial_unreachable / trial_gen_total;
            end
        end
    end
end

%% ====================================================================
%% 汇总统计
%% ====================================================================

mean_R1 = reshape(mean(R1_mat, 2, 'omitnan'), numA, num_delay_scenarios);
mean_R3 = reshape(mean(R3_mat, 2, 'omitnan'), numA, num_delay_scenarios);

% --- 箱体截尾均值（保留以备回归对比，绘图不再使用；折线统一改用 mean_R1） ---
trimmed_mean_R1 = NaN(numA, num_delay_scenarios);
for idxScenario = 1:num_delay_scenarios
    for idxAlpha = 1:numA
        r1_vals = R1_mat(idxAlpha, :, idxScenario);
        r1_vals = r1_vals(~isnan(r1_vals));
        if isempty(r1_vals)
            trimmed_mean_R1(idxAlpha, idxScenario) = NaN;
        else
            q25 = prctile(r1_vals, 25);
            q75 = prctile(r1_vals, 75);
            inliers = r1_vals(r1_vals >= q25 & r1_vals <= q75);
            if isempty(inliers)
                trimmed_mean_R1(idxAlpha, idxScenario) = median(r1_vals);
            else
                trimmed_mean_R1(idxAlpha, idxScenario) = mean(inliers);
            end
        end
    end
end
% --- R3 箱体截尾均值（保留以备回归对比，绘图不再使用；折线统一用 mean_R3） ---
trimmed_mean_R3 = NaN(numA, num_delay_scenarios);
for idxScenario = 1:num_delay_scenarios
    for idxAlpha = 1:numA
        r3_vals = R3_mat(idxAlpha, :, idxScenario);
        r3_vals = r3_vals(~isnan(r3_vals));
        if isempty(r3_vals)
            trimmed_mean_R3(idxAlpha, idxScenario) = NaN;
        else
            q25 = prctile(r3_vals, 25);
            q75 = prctile(r3_vals, 75);
            inliers = r3_vals(r3_vals >= q25 & r3_vals <= q75);
            if isempty(inliers)
                trimmed_mean_R3(idxAlpha, idxScenario) = median(r3_vals);
            else
                trimmed_mean_R3(idxAlpha, idxScenario) = mean(inliers);
            end
        end
    end
end
mean_A1_eta = reshape(mean(A1_eta_mat, 2, 'omitnan'), numA, num_delay_scenarios);
mean_A1_tau_m = reshape(mean(A1_tau_m_mat, 2, 'omitnan'), numA, num_delay_scenarios);
mean_A1_tau_e = reshape(mean(A1_tau_e_mat, 2, 'omitnan'), numA, num_delay_scenarios);
mean_A1_unreachable_ratio = reshape(mean(A1_unreachable_ratio_mat, 2, 'omitnan'), numA, num_delay_scenarios);
scenario_colors = lines(num_delay_scenarios);

% 打印每个场景的汇总表
for idxScenario = 1:num_delay_scenarios
    scenario_name = delay_scenarios(idxScenario).name;
    scenario_table = table(alpha_range(:), mean_R1(:, idxScenario), mean_R3(:, idxScenario), ...
        mean_A1_eta(:, idxScenario), mean_A1_unreachable_ratio(:, idxScenario), ...
        'VariableNames', {'alpha', 'mean_R1', 'mean_R3', 'mean_eta', 'mean_unreachable_ratio'});
    disp("场景 " + scenario_name + " 的 R1 / R3 / 延迟因素汇总：");
    disp(scenario_table);
end

% --- 安全等级分类表 ---
R1_safety_levels = strings(numA, num_delay_scenarios);
for idxScenario = 1:num_delay_scenarios
    for idxAlpha = 1:numA
        R1_safety_levels(idxAlpha, idxScenario) = classifyR1SafetyLevel( ...
            mean_R1(idxAlpha, idxScenario), ...
            delay_cfg.experiment.r1_threshold_percent);
    end
end

safety_level_table = table(alpha_range(:), 'VariableNames', {'alpha'});
for idxScenario = 1:num_delay_scenarios
    safety_level_table.(char(scenario_labels(idxScenario))) = R1_safety_levels(:, idxScenario);
end
disp('基于 R1 的时延安全等级划分：');
disp(safety_level_table);

%% ====================================================================
%% 核心图表（体现时延的危害）
%% ====================================================================
% 出图顺序：箱线图(分布) → R1折线图(从箱线图数据取均值) → R3折线图 → 热力图(when)

% --- 图1: ΔR1 均值差柱状图（取代原 R1 箱线图，主攻 R1 单调性诊断） ---
% 设计动机：原箱线图无法直接回答"R1 是否随时延加重而单调恶化"这一主要矛盾。
% 改造为：每个 α 下展示 4 根柱子（light / baseline / medium / heavy），
% 纵坐标 ΔR1 = mean(R_1^{no_delay}) - mean(R_1^{scenario})。
% 预期：所有柱高 ≥ 0 且按 light < baseline < medium < heavy 单调递增。
% 若任何柱高为负 => 代码逻辑有问题（time-delayed 场景反而比 no_delay 更好）。
alpha_repr_vals = alpha_range;      % 全部 α 值
alpha_repr_idx = 1:numA;            % 对应索引

% 计算每个 (α, scenario) 的均值
mean_R1_per_scenario = NaN(numA, num_delay_scenarios);
for ai = 1:numel(alpha_repr_idx)
    idxA = alpha_repr_idx(ai);
    for idxS = 1:num_delay_scenarios
        r1_trials = R1_mat(idxA, :, idxS);
        r1_trials = r1_trials(~isnan(r1_trials));
        if ~isempty(r1_trials)
            mean_R1_per_scenario(ai, idxS) = mean(r1_trials);
        end
    end
end

% 定位 no_delay 列与其它 4 个时延场景列
nodelay_idx = find(strcmp(string(scenario_labels), "no_delay"), 1);
if isempty(nodelay_idx)
    error('未找到 no_delay 场景，无法计算 ΔR1。');
end
delay_scenario_idx = setdiff(1:num_delay_scenarios, nodelay_idx);
delay_scenario_labels = scenario_labels(delay_scenario_idx);

% ΔR1 = mean(R1_no_delay) - mean(R1_scenario)
% 维度：numA x numel(delay_scenario_idx)
delta_R1_bar = mean_R1_per_scenario(:, nodelay_idx) - mean_R1_per_scenario(:, delay_scenario_idx);

% 转义下划线（用于 legend / 标签显示，避免下划线被解析为下标）
legend_labels_disp = strrep(cellstr(scenario_labels), '_', '\_');
delay_legend_labels_disp = legend_labels_disp(delay_scenario_idx);

% --- Fig1_DeltaR1_Bar 已按需求注释（保留 delta_R1_bar / mean_R1_per_scenario
%     等数值计算供下游 plotCombinedR1、动作部分、对比实验 C1-C4 复用）。
%     差值柱状折线图改由 Fig_Combined_R1 (yyaxis 双轴) 单图承担。
%{
figure('Name', 'Fig1_DeltaR1_Bar', 'Position', [100, 100, 1600, 500]);
hb = bar(alpha_repr_vals, delta_R1_bar, 'grouped');
hold on; grid on;
for s = 1:numel(hb)
    hb(s).FaceColor = scenario_colors(delay_scenario_idx(s), :);
    hb(s).FaceAlpha = 0.85;
    hb(s).EdgeColor = [0.2 0.2 0.2];
end
yline(0, 'k--', 'LineWidth', 1);
xlabel('\alpha');
ylabel('\DeltaLSR = mean(R_1^{no\_delay}) - mean(R_1^{scenario})   (load-service drop)');
title(sprintf('\\DeltaLSR (\\DeltaR_1, Load Service Ratio drop) vs \\alpha by Delay Scenario (samples per cell: %d)', num_samples));
legend(hb, delay_legend_labels_disp, 'Location', 'best');
for s = 1:numel(hb)
    xs = hb(s).XEndPoints;
    ys = hb(s).YEndPoints;
    for k = 1:numel(xs)
        if ~isnan(ys(k)) && ys(k) < 0
            text(xs(k), ys(k), '!', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'top', ...
                'Color', 'r', 'FontWeight', 'bold', 'FontSize', 12);
        end
    end
end
hold off;
%}

% 打印全部 (α, scenario) 的 R1 均值与 ΔR1，便于直接定位负值（异常）的 (α, scenario)
fprintf('\n===== R1 均值 & ΔR1 = mean(R1_no_delay) - mean(R1_scenario) =====\n');
header_parts = {'alpha', 'mean_R1_no_delay'};
for s = 1:numel(delay_scenario_idx)
    sc_name = char(delay_scenario_labels(s));
    header_parts{end+1} = sprintf('mean_R1_%s', sc_name); %#ok<AGROW>
    header_parts{end+1} = sprintf('dR1_%s', sc_name); %#ok<AGROW>
end
fprintf('%s\n', strjoin(header_parts, ' | '));
for ai = 1:numel(alpha_repr_idx)
    line_parts = {sprintf('%.2f', alpha_repr_vals(ai)), ...
        sprintf('%.4f', mean_R1_per_scenario(ai, nodelay_idx))};
    for s = 1:numel(delay_scenario_idx)
        idxS = delay_scenario_idx(s);
        line_parts{end+1} = sprintf('%.4f', mean_R1_per_scenario(ai, idxS)); %#ok<AGROW>
        d = delta_R1_bar(ai, s);
        if d < 0
            line_parts{end+1} = sprintf('%+.4f !', d); %#ok<AGROW>
        else
            line_parts{end+1} = sprintf('%+.4f', d); %#ok<AGROW>
        end
    end
    fprintf('%s\n', strjoin(line_parts, ' | '));
end

% 同时保留每个 (α, scenario) 的简要分布统计（方差/中位数），供深入诊断
fprintf('\n===== R1 分布统计（mean / std / median / IQR） =====\n');
for ai = 1:numel(alpha_repr_idx)
    idxA = alpha_repr_idx(ai);
    fprintf('\nalpha = %.2f:\n', alpha_range(idxA));
    for idxS = 1:num_delay_scenarios
        r1_trials = R1_mat(idxA, :, idxS);
        r1_trials = r1_trials(~isnan(r1_trials));
        if isempty(r1_trials)
            fprintf('  %-10s: <无有效样本>\n', char(scenario_labels(idxS)));
            continue;
        end
        fprintf('  %-10s: mean=%.4f, std=%.4f, median=%.4f, IQR=[%.4f, %.4f]\n', ...
            char(scenario_labels(idxS)), mean(r1_trials), std(r1_trials), ...
            median(r1_trials), prctile(r1_trials, 25), prctile(r1_trials, 75));
    end
end

% --- Fig2_R1_vs_alpha 已按需求注释（保留 mean_R1 数值供 plotCombinedR1
%     与下游对比实验 C1-C4 复用）。R1-α 折线图改由 Fig_Combined_R1 承担。
%{
figure('Name', 'Fig2_R1_vs_alpha');
hold on; grid on;
ylim([0 1.05]);
xlabel('\alpha');
ylabel('Load Service Ratio R_1 (LSR, delay-adjusted)');
title(sprintf('Load Service Ratio R_1 (LSR) vs. \\alpha (delay-adjusted mean, attack: %s, samples: %d, p=%.2f)', ...
    attackMode, num_samples, propagation_probability));
for idxScenario = 1:num_delay_scenarios
    plot(alpha_range, mean_R1(:, idxScenario), '-o', 'LineWidth', 1.5, ...
        'Color', scenario_colors(idxScenario, :), 'MarkerFaceColor', scenario_colors(idxScenario, :));
end
legend(strrep(cellstr(scenario_labels), '_', '\_'), 'Location', 'best');
hold off;
%}

% --- 图1+2 同框（Nature 双面板：上 ΔR1 柱 / 下 R1-α 折线，共享 x 轴） ---
% 复用上面已聚合的 mean_R1（不重新计算），仅作展示层叠加。
% 包在 try/catch 里以确保新增可视化绝不影响主流程数值结果。
if exist('mean_R1', 'var') && exist('plotCombinedR1', 'file') == 2
    try
        plotCombinedR1(mean_R1, alpha_range, scenario_labels, ...
            'Colors',  scenario_colors, ...
            'FigName', 'Fig_Combined_R1');
    catch ME_combined
        warning('plotCombinedR1 调用失败（不影响主流程）：%s', ME_combined.message);
    end
end

% --- Fig3_R3_vs_alpha 已按需求注释（保留 mean_R3 数值供 plotCombinedR3 复用）。
%     R3-α 折线图改由 Fig_Combined_R3 承担。
%{
figure('Name', 'Fig3_R3_vs_alpha');
hold on; grid on;
xlabel('\alpha');
ylabel('Dispatch Tracking Error R_3 (DTE; smaller is better)');
title(sprintf('Dispatch Tracking Error R_3 (DTE) vs. \\alpha (attack: %s, samples: %d, p=%.2f)', ...
    attackMode, num_samples, propagation_probability));
for idxScenario = 1:num_delay_scenarios
    plot(alpha_range, mean_R3(:, idxScenario), '-o', 'LineWidth', 1.5, ...
        'Color', scenario_colors(idxScenario, :), 'MarkerFaceColor', scenario_colors(idxScenario, :));
end
legend(strrep(cellstr(scenario_labels), '_', '\_'), 'Location', 'best');
hold off;
%}

% --- 图3 同框（Nature 双面板：上 ΔR3 柱 / 下 R3-α 折线，共享 x 轴） ---
% 与 plotCombinedR1 对偶；R3 越小越好，故 ΔR3 = R3^scenario - R3^no_delay，
% 这样"正值条柱 = 该时延场景比 no_delay 更差"，与 R1 图的视觉读数规则一致。
% 复用上面已聚合的 mean_R3（不重新计算），仅作展示层叠加。
% 包在 try/catch 里以确保新增可视化绝不影响主流程数值结果。
if exist('mean_R3', 'var') && exist('plotCombinedR3', 'file') == 2
    try
        plotCombinedR3(mean_R3, alpha_range, scenario_labels, ...
            'Colors',  scenario_colors, ...
            'FigName', 'Fig_Combined_R3');
    catch ME_combined_R3
        warning('plotCombinedR3 调用失败（不影响主流程）：%s', ME_combined_R3.message);
    end
end

%% ====================================================================
%% 逐轮时间序列分析
%% ====================================================================

% --- 计算全局最大轮次数 ---
global_max_rounds = 0;
for idxAlpha = 1:numA
    for trial = 1:num_samples
        for idxScenario = 1:num_delay_scenarios
            ts = round_ts_R1_cell{idxAlpha, trial, idxScenario};
            if ~isempty(ts)
                global_max_rounds = max(global_max_rounds, numel(ts));
            end
        end
    end
end

if global_max_rounds == 0
    warning('没有有效的逐轮数据，跳过时间序列分析。');
else

% --- 对齐并求均值 (LVCF填充) ---
mean_ts_R1 = NaN(global_max_rounds, numA, num_delay_scenarios);
mean_ts_R3 = NaN(global_max_rounds, numA, num_delay_scenarios);
mean_ts_eta = NaN(global_max_rounds, numA, num_delay_scenarios);
mean_ts_unreachable = NaN(global_max_rounds, numA, num_delay_scenarios);
mean_ts_n_failed_power = NaN(global_max_rounds, numA, num_delay_scenarios);

for idxScenario = 1:num_delay_scenarios
    for idxAlpha = 1:numA
        padded_R1 = NaN(num_samples, global_max_rounds);
        padded_R3 = NaN(num_samples, global_max_rounds);
        padded_eta = NaN(num_samples, global_max_rounds);
        padded_ur = NaN(num_samples, global_max_rounds);
        padded_fp = NaN(num_samples, global_max_rounds);

        for trial = 1:num_samples
            ts_r1 = round_ts_R1_cell{idxAlpha, trial, idxScenario};
            if isempty(ts_r1), continue; end
            n = numel(ts_r1);

            padded_R1(trial, 1:n) = ts_r1(:)';
            ts_r3_trial = round_ts_R3_cell{idxAlpha, trial, idxScenario};
            if ~isempty(ts_r3_trial)
                padded_R3(trial, 1:n) = ts_r3_trial(:)';
            end
            padded_eta(trial, 1:n) = round_ts_eta_cell{idxAlpha, trial, idxScenario}(:)';
            padded_ur(trial, 1:n) = round_ts_unreachable_cell{idxAlpha, trial, idxScenario}(:)';
            padded_fp(trial, 1:n) = round_ts_n_failed_power_cell{idxAlpha, trial, idxScenario}(:)';

            % LVCF 填充
            if n < global_max_rounds
                last_r1 = ts_r1(find(~isnan(ts_r1), 1, 'last'));
                if ~isempty(last_r1), padded_R1(trial, n+1:global_max_rounds) = last_r1; end

                if ~isempty(ts_r3_trial)
                    last_r3 = ts_r3_trial(find(~isnan(ts_r3_trial), 1, 'last'));
                    if ~isempty(last_r3), padded_R3(trial, n+1:global_max_rounds) = last_r3; end
                end

                ts_eta = round_ts_eta_cell{idxAlpha, trial, idxScenario};
                last_eta = ts_eta(find(~isnan(ts_eta), 1, 'last'));
                if ~isempty(last_eta), padded_eta(trial, n+1:global_max_rounds) = last_eta; end

                ts_ur = round_ts_unreachable_cell{idxAlpha, trial, idxScenario};
                last_ur = ts_ur(find(~isnan(ts_ur), 1, 'last'));
                if ~isempty(last_ur), padded_ur(trial, n+1:global_max_rounds) = last_ur; end

                padded_fp(trial, n+1:global_max_rounds) = padded_fp(trial, n);
            end
        end

        mean_ts_R1(:, idxAlpha, idxScenario) = mean(padded_R1, 1, 'omitnan')';
        mean_ts_R3(:, idxAlpha, idxScenario) = mean(padded_R3, 1, 'omitnan')';
        mean_ts_eta(:, idxAlpha, idxScenario) = mean(padded_eta, 1, 'omitnan')';
        mean_ts_unreachable(:, idxAlpha, idxScenario) = mean(padded_ur, 1, 'omitnan')';
        mean_ts_n_failed_power(:, idxAlpha, idxScenario) = mean(padded_fp, 1, 'omitnan')';
    end
end

nodelay_idx = find(strcmp(string(scenario_labels), "no_delay"), 1);
heavy_idx = find(strcmp(string(scenario_labels), "heavy"), 1);

% 有效绘图范围（跨所有场景取最大）
valid_any_scenario = false(global_max_rounds, 1);
for s = 1:num_delay_scenarios
    valid_any_scenario = valid_any_scenario | ...
        (sum(~isnan(mean_ts_R1(:, :, s)), 2) >= ceil(numA * 0.3));
end
plot_max_round = find(valid_any_scenario, 1, 'last');
if isempty(plot_max_round) || plot_max_round < 2
    plot_max_round = global_max_rounds;
end

fprintf('\n===== 时间序列分析参数 =====\n');
fprintf('全局最大轮次: %d, 绘图截止轮次: %d\n', global_max_rounds, plot_max_round);

% --- 图4: 延迟惩罚热力图 (alpha x round) — per-trial per-round 增量口径 ---
%   过去版本基于 mean_ts_R1（LVCF-padded 累计 R1）的跨轮 diff：
%       ΔR1_inc(r) = (R1_nd(r) - R1_nd(r-1)) - (R1_hv(r) - R1_hv(r-1))
%   LVCF 会把"已结束 trial 的最终 R1"复制到后续轮次，跨 trial 平均后
%   mean_ts_R1 在 r≥2 几近平台 → 增量 diff≈0 → 颜色塌陷为 0（黑）；
%   所有 cascade 增量被压缩到 r=1，导致整张图除第 1 列外大面积黑色，
%   无法体现"中段轮次时延危害最大"。
%
%   新口径（对齐 Fig4b 的 R3 处理）：
%   1) 不用 LVCF。对每一个 trial 单独计算"该轮 LSR 跌幅"
%        Δ_trial(r) = R1(r-1) - R1(r)        (r ≥ 2)
%        Δ_trial(1) = 1 - R1(1)              (r = 1，相对级联起点 R1=1)
%      这是该 trial 在第 r 轮内"新增"的负荷损失比，物理上即"本轮失负荷率"。
%   2) 仅在 trial 真实跑到第 r 轮时计入（与 Fig4b 一致：no-LVCF, 实际有数据
%      的 trial 子集）。这样后段轮次只反映"仍在 cascade 的 trial 集合"的真实
%      增量，避免 LVCF 把"该 trial 已经停了，本轮不再损失"误算成"该轮无危害"。
%   3) ΔR1_inc(r,α) = mean_trials Δ_hv(r) - mean_trials Δ_nd(r)
%      正值 ⇒ 该轮 heavy 比 no_delay 多损失了的 LSR（"延迟在该轮造成的额外
%      失负荷"）。
%
%   物理依据（保持不变）：
%   - r=1: 初始攻击轮，cyber 级联尚未抹掉 CC，τ_q 远未过 M/M/1 膝点（heavy
%          ρ≈0.75）→ heavy 与 no_delay 的瞬时差较小（与 Φ_sat/Φ_crit 的小
%          α-lever 一致）；
%   - r=2..4: cyber 级联抹掉若干 CC → ρ 跨过 ρ_max 被钳到 0.95
%             → τ_q 从 ~17ms 跳至 ~106ms，与 baseline τ≈220ms 同量级
%             → 首次让 heavy 的 Φ_sat / Φ_crit 进入塌陷区 → ΔR1_inc 起峰；
%   - r≥5+: 仍在 cascade 的 trial 子集变小、新增损失收敛 → 颜色自然衰减。
%
%   理论基石：Kleinrock 1975 §3.2 (M/M/1 W_q 膝点)、Buldyrev et al. Nature 2010
%             (interdependent-cascade second-wave amplification)。
%
%   x 轴自适应裁剪 heatmap_max_round：要求 heavy 与 no_delay **两个场景同时**
%   至少 30% 的 trial（每个 α 至少有 1 个 trial）跑到第 r 轮，r 列才纳入图。
%   后段因 trial 全部已 cascade 完毕、统计上无数据的列不再画为"假 0"，避免
%   解读上把"无数据"误读成"延迟无危害"。
if ~isempty(nodelay_idx) && ~isempty(heavy_idx)
    % --- 计算 heatmap_max_round：heavy & no_delay 两个场景在所有 α 上同时
    %     至少 30% trial 覆盖的最大轮次（统计上有意义的窗口） ---
    cov_threshold = max(1, ceil(num_samples * 0.30));
    heatmap_max_round = 0;
    for r_check = 1:plot_max_round
        ok = true;
        for a_idx_chk = 1:numA
            n_nd = 0; n_hv = 0;
            for trial = 1:num_samples
                ts_nd_chk = round_ts_R1_cell{a_idx_chk, trial, nodelay_idx};
                ts_hv_chk = round_ts_R1_cell{a_idx_chk, trial, heavy_idx};
                if ~isempty(ts_nd_chk) && r_check <= numel(ts_nd_chk) && ~isnan(ts_nd_chk(r_check))
                    n_nd = n_nd + 1;
                end
                if ~isempty(ts_hv_chk) && r_check <= numel(ts_hv_chk) && ~isnan(ts_hv_chk(r_check))
                    n_hv = n_hv + 1;
                end
            end
            if n_nd < cov_threshold || n_hv < cov_threshold
                ok = false; break;
            end
        end
        if ok
            heatmap_max_round = r_check;
        else
            break;
        end
    end
    if heatmap_max_round < 1
        % 兜底：至少画第 1 轮（攻击轮一定有数据）
        heatmap_max_round = 1;
    end
    fprintf('热力图自适应轮数 heatmap_max_round = %d (full plot_max_round = %d)\n', ...
        heatmap_max_round, plot_max_round);

    % --- per-trial per-round R1 增量（no-LVCF） ---
    delta_delay_heatmap = NaN(heatmap_max_round, numA);
    for a_idx = 1:numA
        for r_idx = 1:heatmap_max_round
            d_nd_r = NaN(num_samples, 1);
            d_hv_r = NaN(num_samples, 1);
            for trial = 1:num_samples
                ts_nd = round_ts_R1_cell{a_idx, trial, nodelay_idx};
                if ~isempty(ts_nd) && r_idx <= numel(ts_nd) && ~isnan(ts_nd(r_idx))
                    if r_idx == 1
                        d_nd_r(trial) = 1 - ts_nd(1);
                    else
                        if ~isnan(ts_nd(r_idx - 1))
                            d_nd_r(trial) = ts_nd(r_idx - 1) - ts_nd(r_idx);
                        end
                    end
                end
                ts_hv = round_ts_R1_cell{a_idx, trial, heavy_idx};
                if ~isempty(ts_hv) && r_idx <= numel(ts_hv) && ~isnan(ts_hv(r_idx))
                    if r_idx == 1
                        d_hv_r(trial) = 1 - ts_hv(1);
                    else
                        if ~isnan(ts_hv(r_idx - 1))
                            d_hv_r(trial) = ts_hv(r_idx - 1) - ts_hv(r_idx);
                        end
                    end
                end
            end
            delta_delay_heatmap(r_idx, a_idx) = ...
                mean(d_hv_r, 'omitnan') - mean(d_nd_r, 'omitnan');
        end
    end
    % 视觉裁剪：只展示"延迟造成的额外失负荷"（≥0）；偶发负值（heavy 该轮少损失）
    % 仅来自有限样本方差，与"延迟惩罚"语义无关，裁掉以保证色尺单语义。
    delta_delay_heatmap = max(0, delta_delay_heatmap);

    figure('Name', 'Fig4_Delay_Penalty_Heatmap');
    imagesc(1:heatmap_max_round, alpha_range, delta_delay_heatmap');
    set(gca, 'YDir', 'normal');
    xlim([0.5, heatmap_max_round + 0.5]);
    cb = colorbar;
    cb.Label.String = '\DeltaLSR_{inc}^{delay}  (per-round \DeltaR_1, this-round extra LSR drop)';
    xlabel('Cascade Round');
    ylabel('\alpha');
    title('Delay Penalty Heatmap — per-round incremental \DeltaLSR (positive = heavy lost more in this round)');
    colormap(hot);

    % --- 图4b: R3 延迟惩罚热力图 (alpha x round) — 逐轮 per-round 口径 ---
    % round_ts_R3_cell 已按 per-round NRMSE（非累计）存储；这里同样不做 LVCF，
    % 仅在真实跑过 r 轮的 trial 上取均值，使 ΔR3_inc(r) 真正反映"该轮 heavy
    % 与 no_delay 的瞬时跟踪偏差差异"。
    %   ΔR3_inc(r,α) = R3_hv_round(r,α) - R3_nd_round(r,α)
    % 物理依据：per-round NRMSE 直接衡量该轮 τ_q + UFLS 过切对调度跟踪精度的
    % 瞬时危害；中段轮 (r=2..4) τ_q 跨膝点 → 瞬时 NRMSE 拉开 → ΔR3_inc 起峰。
    %
    % x 轴使用与 Fig4 相同的 heatmap_max_round 截尾，避免后段无数据列被画为
    % 假"0"黑色。
    mean_ts_R3_nopad_nd = NaN(heatmap_max_round, numA);
    mean_ts_R3_nopad_hv = NaN(heatmap_max_round, numA);
    for a_idx = 1:numA
        for r_idx = 1:heatmap_max_round
            r3_nd_r = NaN(num_samples, 1);
            r3_hv_r = NaN(num_samples, 1);
            for trial = 1:num_samples
                ts3_nd = round_ts_R3_cell{a_idx, trial, nodelay_idx};
                if ~isempty(ts3_nd) && r_idx <= numel(ts3_nd)
                    r3_nd_r(trial) = ts3_nd(r_idx);
                end
                ts3_hv = round_ts_R3_cell{a_idx, trial, heavy_idx};
                if ~isempty(ts3_hv) && r_idx <= numel(ts3_hv)
                    r3_hv_r(trial) = ts3_hv(r_idx);
                end
            end
            mean_ts_R3_nopad_nd(r_idx, a_idx) = mean(r3_nd_r, 'omitnan');
            mean_ts_R3_nopad_hv(r_idx, a_idx) = mean(r3_hv_r, 'omitnan');
        end
    end
    delta_delay_heatmap_R3 = mean_ts_R3_nopad_hv - mean_ts_R3_nopad_nd;
    % R3 同样裁剪到非负：R3_hv ≥ R3_nd 是物理常态（heavy 跟踪误差不会比 no_delay 小），
    % 偶发负值仅来自小样本的有限方差，与"延迟惩罚"语义无关，裁掉以保证色尺单语义。
    delta_delay_heatmap_R3 = max(0, delta_delay_heatmap_R3);

    figure('Name', 'Fig4b_Delay_Penalty_Heatmap_R3');
    imagesc(1:heatmap_max_round, alpha_range, delta_delay_heatmap_R3');
    set(gca, 'YDir', 'normal');
    xlim([0.5, heatmap_max_round + 0.5]);
    cb = colorbar;
    cb.Label.String = '\DeltaDTE_{inc}^{delay}  (per-round \DeltaR_3, this-round extra NRMSE)';
    xlabel('Cascade Round');
    ylabel('\alpha');
    title('Delay Penalty Heatmap — per-round \DeltaDTE (\DeltaR_3 = R_3^{heavy}_{round} - R_3^{no\_delay}_{round})');
    colormap(hot);
end

end % end of global_max_rounds > 0 check

%% ====================================================================
%% 敏感性实验：评估5个工程动作 (A1-A5) 对系统韧性的提升效果
%% ====================================================================
% 基于 heavy 场景，逐一施加工程动作 A1-A5。
% 使用与上方完全相同的网络拓扑（A_pc_cell, Ac_cell 等），
% 确保结果与前面的图可直接对比（控制变量：仅时延配置不同）。

fprintf('\n========== 敏感性实验: 评估 A1-A5 工程动作 ==========\n');

action_scenarios = createSensitivityActionConfigs(delay_cfg);
num_actions = numel(action_scenarios);

% 定位基线场景索引
nodelay_base_idx = find(strcmp(scenario_labels, "no_delay"), 1);
heavy_base_idx   = find(strcmp(scenario_labels, "heavy"), 1);
assert(~isempty(nodelay_base_idx), '未找到 no_delay 场景');
assert(~isempty(heavy_base_idx),   '未找到 heavy 场景');

% 预分配
R1_action_mat = NaN(numA, num_samples, num_actions);
round_log_action_all = cell(numA, num_samples, num_actions);

for ai = 1:num_actions
    action_name = action_scenarios(ai).name;
    action_cfg  = action_scenarios(ai).cfg;
    fprintf('\n===== 动作 %d/%d: %s (%s) =====\n', ...
        ai, num_actions, action_name, action_scenarios(ai).description);

    [~, ~, ~, failed_power_nodes_action, round_log_action] = ...
        cascadeLogicdebug2gudingCC_bet_8(...
            mpc, Vc, Ap, Ac_cell, A_pc_cell, propagation_probability, ...
            P_branch, betC_cell, betCE_cell, info_pool_cell, attackMode, ...
            control_centers_cell, isCC_cell, mpopt, G_cyber_ba_cell, action_cfg);

    for idxAlpha = 1:numA
        for trial = 1:num_samples
            failed_pn = failed_power_nodes_action{idxAlpha, trial};
            % 使用 delay-adjusted R1（与主实验一致：φ 改为全程加权 φ_traj，
            % 而非仅取最后一轮，避免末轮幸存发电机过少导致的高方差/反转）
            action_round_logs = round_log_action{idxAlpha, trial};
            round_log_action_all{idxAlpha, trial, ai} = action_round_logs;
            if isempty(action_round_logs)
                R1_action_mat(idxAlpha, trial, ai) = computeR1LoadRatio(initial_power_load, failed_pn);
                continue;
            end
            P_ref_traj_a = [];
            P_actual_traj_a = [];
            traj_w_total_a = 0;
            traj_w_phi_eff_sum_a = 0;
            traj_w_surv_load_sum_a = 0;
            for rIdx_a = 1:numel(action_round_logs)
                rl_aa = action_round_logs{rIdx_a};
                if isfield(rl_aa, 'delay_injection_log') && ~isempty(rl_aa.delay_injection_log.eta)
                    dil_aa = rl_aa.delay_injection_log;
                    P_ref_round_a = [];
                    for gk_a = 1:numel(dil_aa.eta)
                        match_a = find(mpc.gen(:,1) == dil_aa.gen_bus(gk_a), 1, 'first');
                        if ~isempty(match_a) && abs(mpc.gen(match_a, 2)) > eps
                            pg_ref_a = mpc.gen(match_a, 2);
                            P_ref_traj_a(end+1, 1) = pg_ref_a; %#ok<AGROW>
                            P_actual_traj_a(end+1, 1) = pg_ref_a * dil_aa.eta(gk_a); %#ok<AGROW>
                            P_ref_round_a(end+1, 1) = pg_ref_a; %#ok<AGROW>
                        end
                    end
                    if ~isempty(P_ref_round_a) && sum(P_ref_round_a) > 0
                        if isfield(dil_aa, 'ufls_phi_eff') && ~isempty(dil_aa.ufls_phi_eff)
                            phi_eff_round_a = dil_aa.ufls_phi_eff;
                        else
                            phi_eff_round_a = 1;
                        end
                        [~, surv_load_round_a, ~] = computeR1LoadRatio(initial_power_load, rl_aa.failed_power_nodes);
                        w_r_a = sum(P_ref_round_a);
                        traj_w_total_a = traj_w_total_a + w_r_a;
                        traj_w_phi_eff_sum_a = traj_w_phi_eff_sum_a + w_r_a * phi_eff_round_a;
                        traj_w_surv_load_sum_a = traj_w_surv_load_sum_a + w_r_a * surv_load_round_a;
                    end
                end
            end
            if ~isempty(P_ref_traj_a) && sum(P_ref_traj_a) > 0
                if traj_w_total_a > 0
                    phi_eff_traj_val_a = traj_w_phi_eff_sum_a / traj_w_total_a;
                    surv_load_traj_val_a = traj_w_surv_load_sum_a / traj_w_total_a;
                else
                    phi_eff_traj_val_a = [];
                    surv_load_traj_val_a = [];
                end
                R1_action_mat(idxAlpha, trial, ai) = computeDelayAdjustedR1( ...
                    initial_power_load, failed_pn, P_actual_traj_a, P_ref_traj_a, ...
                    phi_eff_traj_val_a, surv_load_traj_val_a);
            else
                R1_action_mat(idxAlpha, trial, ai) = computeR1LoadRatio(initial_power_load, failed_pn);
            end
        end
    end

    fprintf('动作 %s 完成。\n', action_name);
end

fprintf('\n========== 全部动作场景完成 ==========\n');

% --- 为动作场景计算逐轮R1时间序列（与基线场景LVCF对齐逻辑一致） ---
if global_max_rounds > 0
mean_ts_R1_action = NaN(global_max_rounds, numA, num_actions);

for ai = 1:num_actions
    for idxAlpha = 1:numA
        padded_R1_a = NaN(num_samples, global_max_rounds);
        for trial = 1:num_samples
            round_logs_a = round_log_action_all{idxAlpha, trial, ai};
            if isempty(round_logs_a), continue; end
            % 限制到 global_max_rounds，确保 padded_R1_a 不会被自动扩展，
            % 从而保证与基线 mean_ts_R1 行对齐（C1-C4 对比实验依赖此对齐）。
            % 注意：当动作场景产生的轮次超过 global_max_rounds 时，超出部分
            % 会被有意截断；下游 C1-C4 / 热力图分析也只在 plot_max_round
            % 范围内取值，因此截断不会影响结论。
            n_rounds_a = min(numel(round_logs_a), global_max_rounds);
            for rIdx = 1:n_rounds_a
                rl_a = round_logs_a{rIdx};
                % 计算该轮的delay-adjusted R1（与主实验逻辑完全一致）
                if isfield(rl_a, 'delay_injection_log') && ~isempty(rl_a.delay_injection_log.eta)
                    dil_a = rl_a.delay_injection_log;
                    P_ref_ra = []; P_actual_ra = [];
                    for gk = 1:numel(dil_a.eta)
                        match = find(mpc.gen(:,1) == dil_a.gen_bus(gk), 1, 'first');
                        if ~isempty(match) && abs(mpc.gen(match, 2)) > eps
                            pg_ref = mpc.gen(match, 2);
                            P_ref_ra(end+1,1) = pg_ref; %#ok<AGROW>
                            P_actual_ra(end+1,1) = pg_ref * dil_a.eta(gk); %#ok<AGROW>
                        end
                    end
                    if ~isempty(P_ref_ra) && sum(P_ref_ra) > 0
                        if isfield(dil_a, 'ufls_phi_eff') && ~isempty(dil_a.ufls_phi_eff)
                            phi_eff_round_ra = dil_a.ufls_phi_eff;
                        else
                            phi_eff_round_ra = 1;
                        end
                        padded_R1_a(trial, rIdx) = computeDelayAdjustedR1(...
                            initial_power_load, rl_a.failed_power_nodes, P_actual_ra, P_ref_ra, ...
                            phi_eff_round_ra);
                    else
                        padded_R1_a(trial, rIdx) = computeR1LoadRatio(initial_power_load, rl_a.failed_power_nodes);
                    end
                else
                    padded_R1_a(trial, rIdx) = computeR1LoadRatio(initial_power_load, rl_a.failed_power_nodes);
                end
            end
            % LVCF填充
            if n_rounds_a < global_max_rounds
                last_valid_idx = find(~isnan(padded_R1_a(trial,:)), 1, 'last');
                if ~isempty(last_valid_idx)
                    padded_R1_a(trial, n_rounds_a+1:global_max_rounds) = padded_R1_a(trial, last_valid_idx);
                end
            end
        end
        mean_ts_R1_action(:, idxAlpha, ai) = mean(padded_R1_a, 1, 'omitnan')';
    end
end

fprintf('动作场景逐轮R1时间序列计算完成。\n');
else
    mean_ts_R1_action = NaN(0, numA, num_actions);
    fprintf('global_max_rounds=0，跳过动作场景逐轮R1时间序列计算。\n');
end

% --- 箱体截尾均值（动作场景，保留以备回归对比，绘图不再使用） ---
trimmed_mean_R1_action = NaN(numA, num_actions);
for ai = 1:num_actions
    for idxAlpha = 1:numA
        r1_vals = R1_action_mat(idxAlpha, :, ai);
        r1_vals = r1_vals(~isnan(r1_vals));
        if isempty(r1_vals)
            trimmed_mean_R1_action(idxAlpha, ai) = NaN;
        else
            q25 = prctile(r1_vals, 25);
            q75 = prctile(r1_vals, 75);
            inliers = r1_vals(r1_vals >= q25 & r1_vals <= q75);
            if isempty(inliers)
                trimmed_mean_R1_action(idxAlpha, ai) = median(r1_vals);
            else
                trimmed_mean_R1_action(idxAlpha, ai) = mean(inliers);
            end
        end
    end
end

% --- 普通平均值（动作场景，用于折线图与恢复比例计算） ---
mean_R1_action = reshape(mean(R1_action_mat, 2, 'omitnan'), numA, num_actions);

% --- 恢复比例计算（使用与前面图表完全一致的 mean_R1 基线） ---
R1_nodelay_base = mean_R1(:, nodelay_base_idx);
R1_heavy_base   = mean_R1(:, heavy_base_idx);
gap = R1_nodelay_base - R1_heavy_base;

action_delta_R1 = NaN(numA, num_actions);
action_recovery_pct = NaN(numA, num_actions);

fprintf('\n===== 各动作的 R1 提升效果 =====\n');
fprintf('%-15s  ', 'alpha');
for ai = 1:num_actions
    fprintf('%-18s  ', char(action_scenarios(ai).name));
end
fprintf('\n');

for idxAlpha = 1:numA
    fprintf('alpha=%.1f:     ', alpha_range(idxAlpha));
    for ai = 1:num_actions
        delta = mean_R1_action(idxAlpha, ai) - R1_heavy_base(idxAlpha);
        action_delta_R1(idxAlpha, ai) = delta;
        if gap(idxAlpha) > 0.001
            recovery = delta / gap(idxAlpha) * 100;
        else
            recovery = 0;
        end
        action_recovery_pct(idxAlpha, ai) = recovery;
        fprintf('ΔR1=%.4f(%5.1f%%)  ', delta, recovery);
    end
    fprintf('\n');
end

% 综合排名（α≥0.3 范围内的平均恢复比例）
fprintf('\n===== 综合排名（α≥0.3 平均恢复比例） =====\n');
high_alpha_idx = find(alpha_range >= 0.3);
mean_recovery = mean(action_recovery_pct(high_alpha_idx, :), 1, 'omitnan');
[sorted_recovery, sort_order] = sort(mean_recovery, 'descend');
for rank = 1:num_actions
    ai = sort_order(rank);
    fprintf('  #%d: %-18s  平均恢复 %.1f%%  (%s)\n', ...
        rank, char(action_scenarios(ai).name), sorted_recovery(rank), ...
        char(action_scenarios(ai).description));
end

%% --- 敏感性实验图表 ---

% 合并数据用于对比图: [no_delay, heavy, A1, A2, A3, A4, A5]（普通平均值）
all_compare_means = [R1_nodelay_base, R1_heavy_base, mean_R1_action];
num_compare_scenarios = size(all_compare_means, 2);

all_compare_labels = strings(num_compare_scenarios, 1);
all_compare_labels(1) = "no_delay";
all_compare_labels(2) = "heavy";
for ai = 1:num_actions
    all_compare_labels(2 + ai) = action_scenarios(ai).name;
end

% 颜色方案
sensitivity_colors = [
    0.0  0.45 0.74;   % no_delay: 蓝色
    0.85 0.33 0.10;   % heavy: 红色
    0.93 0.69 0.13;   % A1: 金色
    0.49 0.18 0.56;   % A2: 紫色
    0.47 0.67 0.19;   % A3: 绿色
    0.30 0.75 0.93;   % A4: 青色
    0.64 0.08 0.18;   % A5: 暗红
];
sensitivity_styles = {'-o', '--s', '-^', '-d', '-v', '-p', '-h'};
sensitivity_widths = [2.5, 2.5, 1.5, 1.5, 1.5, 1.5, 1.5];

% --- 图5: 全场景 R1 vs alpha 对比 ---
figure('Name', 'Fig5_Sensitivity_R1_vs_alpha', 'Position', [100, 100, 1200, 600]);
hold on; grid on;
ylim([0 1.05]);
xlabel('\alpha', 'FontSize', 12);
ylabel('Load Service Ratio R_1 (LSR, delay-adjusted, mean)', 'FontSize', 12);
title(sprintf('Sensitivity Analysis: Load Service Ratio R_1 (LSR) vs. \\alpha (delay-adjusted mean, samples: %d)', num_samples), 'FontSize', 14);

for si = 1:num_compare_scenarios
    plot(alpha_range, all_compare_means(:, si), sensitivity_styles{si}, ...
        'LineWidth', sensitivity_widths(si), 'Color', sensitivity_colors(si, :), ...
        'MarkerFaceColor', sensitivity_colors(si, :), 'MarkerSize', 6);
end
legend(strrep(cellstr(all_compare_labels), '_', '\_'), 'Location', 'best', 'FontSize', 10);
hold off;

% --- 图6: 恢复比例热力图 (action × alpha) ---
figure('Name', 'Fig6_Recovery_Heatmap', 'Position', [100, 100, 1000, 400]);
imagesc(alpha_range, 1:num_actions, action_recovery_pct');
set(gca, 'YDir', 'normal');
colormap(hot);
cb_sens = colorbar;
ylabel(cb_sens, 'LSR Recovery %', 'FontSize', 11);
xlabel('\alpha', 'FontSize', 12);
ylabel('Action', 'FontSize', 12);
action_name_list = strings(num_actions, 1);
for ai = 1:num_actions
    action_name_list(ai) = action_scenarios(ai).name;
end
set(gca, 'YTick', 1:num_actions, 'YTickLabel', cellstr(action_name_list));
title('LSR Recovery %: (Action R_1 - Heavy R_1) / (NoDelay R_1 - Heavy R_1)', 'FontSize', 13);

% --- 图7: 动作排名柱状图 ---
figure('Name', 'Fig7_Action_Ranking', 'Position', [100, 100, 800, 500]);
bar_data_sens = mean_recovery(sort_order);
b_sens = bar(bar_data_sens, 'FaceColor', 'flat');
b_sens.CData = zeros(numel(bar_data_sens), 3);
for k = 1:numel(bar_data_sens)
    b_sens.CData(k, :) = sensitivity_colors(2 + sort_order(k), :);
end
sorted_name_list = strings(num_actions, 1);
for ai = 1:num_actions
    sorted_name_list(ai) = action_scenarios(sort_order(ai)).name;
end
set(gca, 'XTickLabel', cellstr(sorted_name_list), 'FontSize', 11);
ylabel('Mean LSR Recovery % (\alpha \geq 0.3)', 'FontSize', 12);
title('Ranking of Mitigation Actions by LSR Recovery Effectiveness', 'FontSize', 14);
grid on;
for k = 1:numel(bar_data_sens)
    text(k, bar_data_sens(k) + 1, sprintf('%.1f%%', bar_data_sens(k)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

%% ====================================================================
%% 对比实验：验证"最佳时间段 × 最佳动作"的协同效果
%% ====================================================================
% 设计思路：
%   图4热力图告诉我们 WHEN —— 在哪些Cascade Round（级联轮次）时延危害最大
%   图7排名告诉我们 HOW —— 哪些工程动作最有效
%   对比实验将两者结合，用2×2设计证明"在最佳时间采取最佳动作"才能获得最大收益
%
% 四组对比条件（基于Cascade Round作为时间维度）：
%   C1: 最佳时间（delay penalty最大的轮次） + 最佳动作 → 效果最好
%   C2: 最佳时间 + 最差动作 → 中等偏低
%   C3: 最差时间（delay penalty最小的轮次） + 最佳动作 → 中等偏高
%   C4: 最差时间 + 最差动作 → 效果最差

fprintf('\n========== 对比实验: 最佳时间(Cascade Round) x 最佳动作 ==========\n');

% --- 从热力图确定最佳/最差干预时间（级联轮次） ---
% delta_delay_heatmap(round, alpha) = ΔR1_inc(r) = mean Δ_hv(r) - mean Δ_nd(r)
%   即"该轮内 heavy 比 no_delay 多损失的 LSR"——逐轮增量惩罚（per-round
%   incremental, no-LVCF, per-trial 计算后再均值；详见 Fig4 处的注释）。
% 对每个round，计算其跨alpha平均delay penalty → 选出"瞬时危害最大"的中段轮做干预。
mean_penalty_per_round = mean(delta_delay_heatmap, 2, 'omitnan');  % (heatmap_max_round, 1)

% 排除第1轮（初始攻击轮，无干预意义）；上界用 heatmap_max_round（与
% delta_delay_heatmap 同形），避免越界。
valid_rounds = 2:numel(mean_penalty_per_round);
if isempty(valid_rounds)
    % 兜底：heatmap_max_round=1 时（极少见），退回 round 1，避免下游空索引。
    valid_rounds = 1:numel(mean_penalty_per_round);
end
[~, sorted_round_idx] = sort(mean_penalty_per_round(valid_rounds), 'descend');
sorted_valid_rounds = valid_rounds(sorted_round_idx);

% 取前1/3轮次为"最佳干预时间"，后1/3为"最差干预时间"
n_round_region = max(1, round(numel(valid_rounds) / 3));
best_rounds = sorted_valid_rounds(1:n_round_region);
worst_rounds = sorted_valid_rounds(end-n_round_region+1:end);

fprintf('最佳干预时间（delay penalty最大的轮次）:\n');
for k = 1:numel(best_rounds)
    fprintf('  Round %d, avg penalty=%.4f\n', best_rounds(k), mean_penalty_per_round(best_rounds(k)));
end
fprintf('最差干预时间（delay penalty最小的轮次）:\n');
for k = 1:numel(worst_rounds)
    fprintf('  Round %d, avg penalty=%.4f\n', worst_rounds(k), mean_penalty_per_round(worst_rounds(k)));
end

% --- 从图7敏感性排名确定最佳/最差动作 ---
best_action_idx = sort_order(1);      % 排名第1的动作
worst_action_idx = sort_order(end);   % 排名最后的动作
best_action_name = char(action_scenarios(best_action_idx).name);
worst_action_name = char(action_scenarios(worst_action_idx).name);

fprintf('最佳动作: %s (平均恢复 %.1f%%)\n', best_action_name, mean_recovery(best_action_idx));
fprintf('最差动作: %s (平均恢复 %.1f%%)\n', worst_action_name, mean_recovery(worst_action_idx));

% --- 计算4组对比条件的恢复比例 ---
% 对于每个(round, alpha)，恢复 = (R1_action(r,a) - R1_heavy(r,a)) / (R1_nodelay(r,a) - R1_heavy(r,a))

% C1: 最佳时间 + 最佳动作
C1_vals = [];
for r = best_rounds
    for a = 1:numA
        denom = mean_ts_R1(r, a, nodelay_idx) - mean_ts_R1(r, a, heavy_idx);
        if denom > 0.001
            numer = mean_ts_R1_action(r, a, best_action_idx) - mean_ts_R1(r, a, heavy_idx);
            C1_vals(end+1) = numer / denom * 100; %#ok<AGROW>
        end
    end
end
C1_mean = mean(C1_vals, 'omitnan');

% C2: 最佳时间 + 最差动作
C2_vals = [];
for r = best_rounds
    for a = 1:numA
        denom = mean_ts_R1(r, a, nodelay_idx) - mean_ts_R1(r, a, heavy_idx);
        if denom > 0.001
            numer = mean_ts_R1_action(r, a, worst_action_idx) - mean_ts_R1(r, a, heavy_idx);
            C2_vals(end+1) = numer / denom * 100; %#ok<AGROW>
        end
    end
end
C2_mean = mean(C2_vals, 'omitnan');

% C3: 最差时间 + 最佳动作
C3_vals = [];
for r = worst_rounds
    for a = 1:numA
        denom = mean_ts_R1(r, a, nodelay_idx) - mean_ts_R1(r, a, heavy_idx);
        if denom > 0.001
            numer = mean_ts_R1_action(r, a, best_action_idx) - mean_ts_R1(r, a, heavy_idx);
            C3_vals(end+1) = numer / denom * 100; %#ok<AGROW>
        end
    end
end
C3_mean = mean(C3_vals, 'omitnan');

% C4: 最差时间 + 最差动作
C4_vals = [];
for r = worst_rounds
    for a = 1:numA
        denom = mean_ts_R1(r, a, nodelay_idx) - mean_ts_R1(r, a, heavy_idx);
        if denom > 0.001
            numer = mean_ts_R1_action(r, a, worst_action_idx) - mean_ts_R1(r, a, heavy_idx);
            C4_vals(end+1) = numer / denom * 100; %#ok<AGROW>
        end
    end
end
C4_mean = mean(C4_vals, 'omitnan');

fprintf('\n===== 对比实验结果 =====\n');
fprintf('  C1 (最佳时间 + 最佳动作 %s):  平均恢复 %.1f%%\n', best_action_name, C1_mean);
fprintf('  C2 (最佳时间 + 最差动作 %s):  平均恢复 %.1f%%\n', worst_action_name, C2_mean);
fprintf('  C3 (最差时间 + 最佳动作 %s):  平均恢复 %.1f%%\n', best_action_name, C3_mean);
fprintf('  C4 (最差时间 + 最差动作 %s):  平均恢复 %.1f%%\n', worst_action_name, C4_mean);

% --- 图8: 对比实验柱状图（4组，基于cascade round作为时间维度） ---
figure('Name', 'Fig8_Comparison_Experiment', 'Position', [100, 100, 1000, 550]);

comparison_data = [C1_mean, C2_mean, C3_mean, C4_mean];
comparison_colors = [
    0.17 0.63 0.17;   % C1: 绿色（最佳时间+最佳动作）
    0.93 0.69 0.13;   % C2: 金色（最佳时间+最差动作）
    0.30 0.75 0.93;   % C3: 青色（最差时间+最佳动作）
    0.60 0.60 0.60;   % C4: 灰色（最差时间+最差动作）
];

b_comp = bar(comparison_data, 'FaceColor', 'flat');
b_comp.CData = comparison_colors;

best_rounds_str = strjoin(arrayfun(@(x) sprintf('%d', x), best_rounds, 'UniformOutput', false), ',');
worst_rounds_str = strjoin(arrayfun(@(x) sprintf('%d', x), worst_rounds, 'UniformOutput', false), ',');

comp_tick_labels = {
    sprintf('C1: Best Time\nRound{%s}\n+ Best %s', best_rounds_str, best_action_name), ...
    sprintf('C2: Best Time\nRound{%s}\n+ Worst %s', best_rounds_str, worst_action_name), ...
    sprintf('C3: Worst Time\nRound{%s}\n+ Best %s', worst_rounds_str, best_action_name), ...
    sprintf('C4: Worst Time\nRound{%s}\n+ Worst %s', worst_rounds_str, worst_action_name)
};
set(gca, 'XTickLabel', comp_tick_labels, 'FontSize', 9);
ylabel('Mean LSR Recovery %', 'FontSize', 12);
title('Comparison: Optimal Timing (Cascade Round) x Best Action — LSR (R_1) Recovery', 'FontSize', 14);
grid on;

% 在柱子上方标注数值
for k = 1:4
    text(k, comparison_data(k) + max(abs(comparison_data)) * 0.03, ...
        sprintf('%.1f%%', comparison_data(k)), ...
        'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end

% --- 图9: 对比实验详细热力图（round × alpha 展开，最佳和最差动作恢复比例） ---
figure('Name', 'Fig9_Comparison_Detail', 'Position', [100, 100, 1200, 500]);

% 计算每个(round, alpha)的action恢复比例
action_recovery_by_round_best = NaN(plot_max_round, numA);
action_recovery_by_round_worst = NaN(plot_max_round, numA);
for r = 1:plot_max_round
    for a = 1:numA
        denom = mean_ts_R1(r, a, nodelay_idx) - mean_ts_R1(r, a, heavy_idx);
        if denom > 0.001
            action_recovery_by_round_best(r, a) = ...
                (mean_ts_R1_action(r, a, best_action_idx) - mean_ts_R1(r, a, heavy_idx)) / denom * 100;
            action_recovery_by_round_worst(r, a) = ...
                (mean_ts_R1_action(r, a, worst_action_idx) - mean_ts_R1(r, a, heavy_idx)) / denom * 100;
        end
    end
end

subplot(1,2,1);
imagesc(1:plot_max_round, alpha_range, action_recovery_by_round_best');
set(gca, 'YDir', 'normal');
colorbar; colormap(hot);
xlabel('Cascade Round'); ylabel('\alpha');
title(sprintf('LSR Recovery %%: Best Action (%s)', best_action_name));
% 用竖线标注best_rounds
hold on;
for r = best_rounds
    xline(r, 'g--', 'LineWidth', 1.5);
end
hold off;

subplot(1,2,2);
imagesc(1:plot_max_round, alpha_range, action_recovery_by_round_worst');
set(gca, 'YDir', 'normal');
colorbar; colormap(hot);
xlabel('Cascade Round'); ylabel('\alpha');
title(sprintf('LSR Recovery %%: Worst Action (%s)', worst_action_name));
hold on;
for r = best_rounds
    xline(r, 'g--', 'LineWidth', 1.5);
end
hold off;

fprintf('\n========== 对比实验完成 ==========\n');

%% ====================================================================
%% 保存结果
%% ====================================================================
save_dir = fullfile(pwd, sprintf('delay_cascade_%s_%d_%d', attackMode, num_samples, Vp));
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

% 保存所有 figure
figHandles = findall(0, 'Type', 'figure');
for fIdx = 1:numel(figHandles)
    fig = figHandles(fIdx);
    fig_name = get(fig, 'Name');
    if isempty(fig_name)
        fig_name = sprintf('figure_%d', fig.Number);
    end
    savefig(fig, fullfile(save_dir, [fig_name, '.fig']));
    saveas(fig, fullfile(save_dir, [fig_name, '.png']));
end

% 保存工作空间
save(fullfile(save_dir, 'workspace.mat'), '-v7.3');
fprintf('\n结果已保存至: %s\n', save_dir);
