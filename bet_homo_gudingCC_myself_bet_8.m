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
% 其中 φ = sum(P_actual) / sum(P_ref)，反映时延导致的发电出力折减
R1_mat = NaN(numA, num_samples, num_delay_scenarios);

% R3 与延迟因素：从 delay_injection_log 提取
R3_mat = NaN(numA, num_samples, num_delay_scenarios);
A1_eta_mat = NaN(numA, num_samples, num_delay_scenarios);
A1_tau_m_mat = NaN(numA, num_samples, num_delay_scenarios);
A1_tau_e_mat = NaN(numA, num_samples, num_delay_scenarios);
A1_unreachable_ratio_mat = NaN(numA, num_samples, num_delay_scenarios);

% 逐轮时间序列
round_ts_R1_cell = cell(numA, num_samples, num_delay_scenarios);
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

            % R1：使用 delay-adjusted 计算，将时延效率纳入负荷保持率
            if ~isempty(round_logs)
                last_rl_for_r1 = round_logs{end};
                if isfield(last_rl_for_r1, 'delay_injection_log') && ~isempty(last_rl_for_r1.delay_injection_log.eta)
                    dil_r1 = last_rl_for_r1.delay_injection_log;
                    % 构造 P_ref 和 P_actual 向量用于 delay penalty
                    P_ref_r1 = [];
                    P_actual_r1 = [];
                    for gk_r1 = 1:numel(dil_r1.eta)
                        match_r1 = find(mpc.gen(:,1) == dil_r1.gen_bus(gk_r1), 1, 'first');
                        if ~isempty(match_r1) && abs(mpc.gen(match_r1, 2)) > eps
                            pg_ref_r1 = mpc.gen(match_r1, 2);
                            P_ref_r1(end+1, 1) = pg_ref_r1; %#ok<AGROW>
                            P_actual_r1(end+1, 1) = pg_ref_r1 * dil_r1.eta(gk_r1); %#ok<AGROW>
                        end
                    end
                    if ~isempty(P_ref_r1) && sum(P_ref_r1) > 0
                        R1_mat(idxAlpha, trial, idxScenario) = computeDelayAdjustedR1( ...
                            initial_power_load, failed_pn, P_actual_r1, P_ref_r1);
                    else
                        R1_mat(idxAlpha, trial, idxScenario) = computeR1LoadRatio(initial_power_load, failed_pn);
                    end
                else
                    R1_mat(idxAlpha, trial, idxScenario) = computeR1LoadRatio(initial_power_load, failed_pn);
                end
            else
                R1_mat(idxAlpha, trial, idxScenario) = computeR1LoadRatio(initial_power_load, failed_pn);
            end

            if isempty(round_logs)
                continue;
            end

            num_rounds = numel(round_logs);
            round_R1_values = NaN(num_rounds, 1);
            round_eta_values = NaN(num_rounds, 1);
            round_unreachable_values = NaN(num_rounds, 1);
            round_n_fp = NaN(num_rounds, 1);
            round_n_fc = NaN(num_rounds, 1);

            trial_eta_sum = 0; trial_eta_count = 0;
            trial_tau_m_sum = 0; trial_tau_m_count = 0;
            trial_tau_e_sum = 0; trial_tau_e_count = 0;
            trial_unreachable = 0; trial_gen_total = 0;

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
                        round_R1_values(roundIdx) = computeDelayAdjustedR1( ...
                            initial_power_load, rl.failed_power_nodes, P_actual_round, P_ref_round);
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
            round_ts_eta_cell{idxAlpha, trial, idxScenario} = round_eta_values;
            round_ts_unreachable_cell{idxAlpha, trial, idxScenario} = round_unreachable_values;
            round_ts_n_failed_power_cell{idxAlpha, trial, idxScenario} = round_n_fp;
            round_ts_n_failed_cyber_cell{idxAlpha, trial, idxScenario} = round_n_fc;

            % R3：基于最后一轮的 delay_injection_log
            last_rl = round_logs{end};
            if isfield(last_rl, 'delay_injection_log') && ~isempty(last_rl.delay_injection_log.eta)
                dil_last = last_rl.delay_injection_log;
                n_gen_last = numel(dil_last.eta);
                P_ref_vec = [];
                P_actual_vec = [];
                for gk = 1:n_gen_last
                    match = find(mpc.gen(:,1) == dil_last.gen_bus(gk), 1, 'first');
                    if ~isempty(match) && abs(mpc.gen(match, 2)) > eps
                        pg_ref = mpc.gen(match, 2);
                        P_ref_vec(end+1, 1) = pg_ref; %#ok<AGROW>
                        P_actual_vec(end+1, 1) = pg_ref * dil_last.eta(gk); %#ok<AGROW>
                    end
                end
                if ~isempty(P_ref_vec) && all(P_ref_vec ~= 0)
                    R3_mat(idxAlpha, trial, idxScenario) = computeR3Deviation(P_actual_vec, P_ref_vec);
                end

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

% --- IQR截尾均值（用于R1折线图，抑制离群值对均值的污染） ---
% 对每个(alpha, scenario)组合，仅对IQR范围内的试验取均值
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
            iqr_val = q75 - q25;
            lower_fence = q25 - 1.5 * iqr_val;
            upper_fence = q75 + 1.5 * iqr_val;
            inliers = r1_vals(r1_vals >= lower_fence & r1_vals <= upper_fence);
            if isempty(inliers)
                trimmed_mean_R1(idxAlpha, idxScenario) = median(r1_vals);
            else
                trimmed_mean_R1(idxAlpha, idxScenario) = mean(inliers);
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

% --- 图1: R1 分布 Box Plot（先展示整体数据分布，揭示延迟对系统不确定性的影响） ---
% 使用全部 α 值，完整展示随 α 变化的分布特征
alpha_repr_vals = alpha_range;      % 全部11个α值
alpha_repr_idx = 1:numA;            % 对应索引

% 构造 box plot 数据：每组 = (α, scenario)
bp_data = [];
bp_group_scenario = [];
bp_group_alpha = [];
for ai = 1:numel(alpha_repr_idx)
    idxA = alpha_repr_idx(ai);
    for idxS = 1:num_delay_scenarios
        r1_trials = R1_mat(idxA, :, idxS);
        r1_trials = r1_trials(~isnan(r1_trials));
        n_valid = numel(r1_trials);
        bp_data = [bp_data; r1_trials(:)]; %#ok<AGROW>
        bp_group_scenario = [bp_group_scenario; repmat(idxS, n_valid, 1)]; %#ok<AGROW>
        bp_group_alpha = [bp_group_alpha; repmat(ai, n_valid, 1)]; %#ok<AGROW>
    end
end

% 组合分组标签：每个 box 由 (alpha_group, scenario) 唯一确定
bp_position = (bp_group_alpha - 1) * (num_delay_scenarios + 1) + bp_group_scenario;

figure('Name', 'Fig1_R1_BoxPlot', 'Position', [100, 100, 1600, 500]);
boxplot(bp_data, bp_position, ...
    'Widths', 0.6, 'Symbol', '.', 'OutlierSize', 3);
hold on; grid on;

% 给每组box上色（通过patch）
h = findobj(gca, 'Tag', 'Box');
% boxplot 从右到左创建 box handles，需要翻转
box_positions = zeros(numel(h), 1);
for bi = 1:numel(h)
    box_positions(bi) = mean(get(h(bi), 'XData'));
end
[~, sort_idx] = sort(box_positions);
h = h(sort_idx);
for bi = 1:numel(h)
    % 确定这个 box 属于哪个 scenario
    s_idx = mod(bi - 1, num_delay_scenarios) + 1;
    patch(get(h(bi), 'XData'), get(h(bi), 'YData'), ...
        scenario_colors(s_idx, :), 'FaceAlpha', 0.4);
end

% X 轴标签：在每组中心位置标注 α 值
group_centers = zeros(numel(alpha_repr_vals), 1);
for ai = 1:numel(alpha_repr_vals)
    group_centers(ai) = (ai - 1) * (num_delay_scenarios + 1) + (num_delay_scenarios + 1) / 2;
end
set(gca, 'XTick', group_centers, ...
    'XTickLabel', arrayfun(@(x) sprintf('\\alpha=%.1f', x), alpha_repr_vals, 'UniformOutput', false));

ylabel('R_1 (delay-adjusted)');
title(sprintf('R_1 Distribution by Delay Scenario (delay-adjusted, samples: %d)', num_samples));
ylim([0 1.05]);

% 手动 legend（因为 boxplot 的 legend 不直观）
legend_handles = gobjects(num_delay_scenarios, 1);
for s = 1:num_delay_scenarios
    legend_handles(s) = patch(NaN, NaN, scenario_colors(s, :), ...
        'FaceAlpha', 0.4, 'EdgeColor', scenario_colors(s, :));
end
legend(legend_handles, cellstr(scenario_labels), 'Location', 'best');
hold off;

% 打印全部 (α, scenario) 的 R1 分布统计
fprintf('\n===== R1 分布统计（全部 α 值） =====\n');
for ai = 1:numel(alpha_repr_idx)
    idxA = alpha_repr_idx(ai);
    fprintf('\nalpha = %.1f:\n', alpha_range(idxA));
    for idxS = 1:num_delay_scenarios
        r1_trials = R1_mat(idxA, :, idxS);
        r1_trials = r1_trials(~isnan(r1_trials));
        fprintf('  %-10s: mean=%.4f, std=%.4f, median=%.4f, IQR=[%.4f, %.4f]\n', ...
            char(scenario_labels(idxS)), mean(r1_trials), std(r1_trials), ...
            median(r1_trials), prctile(r1_trials, 25), prctile(r1_trials, 75));
    end
end

% --- 图2: R1 vs alpha 多场景对比（基于Box Plot数据的IQR截尾均值） ---
% 从上方箱线图的原始数据中，取IQR范围内的试验取均值，绘制折线图
figure('Name', 'Fig2_R1_vs_alpha');
hold on; grid on;
ylim([0 1.05]);
xlabel('\alpha');
ylabel('R_1 (delay-adjusted)');
title(sprintf('R_1 vs. \\alpha (delay-adjusted IQR-trimmed mean, attack: %s, samples: %d, p=%.2f)', ...
    attackMode, num_samples, propagation_probability));
for idxScenario = 1:num_delay_scenarios
    plot(alpha_range, trimmed_mean_R1(:, idxScenario), '-o', 'LineWidth', 1.5, ...
        'Color', scenario_colors(idxScenario, :), 'MarkerFaceColor', scenario_colors(idxScenario, :));
end
legend(cellstr(scenario_labels), 'Location', 'best');
hold off;

% --- 图3: R3 vs alpha 多场景对比 ---
figure('Name', 'Fig3_R3_vs_alpha');
hold on; grid on;
xlabel('\alpha');
ylabel('R_3');
title(sprintf('R_3 vs. \\alpha (attack: %s, samples: %d, p=%.2f)', ...
    attackMode, num_samples, propagation_probability));
for idxScenario = 1:num_delay_scenarios
    plot(alpha_range, mean_R3(:, idxScenario), '-o', 'LineWidth', 1.5, ...
        'Color', scenario_colors(idxScenario, :), 'MarkerFaceColor', scenario_colors(idxScenario, :));
end
legend(cellstr(scenario_labels), 'Location', 'best');
hold off;

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
mean_ts_eta = NaN(global_max_rounds, numA, num_delay_scenarios);
mean_ts_unreachable = NaN(global_max_rounds, numA, num_delay_scenarios);
mean_ts_n_failed_power = NaN(global_max_rounds, numA, num_delay_scenarios);

for idxScenario = 1:num_delay_scenarios
    for idxAlpha = 1:numA
        padded_R1 = NaN(num_samples, global_max_rounds);
        padded_eta = NaN(num_samples, global_max_rounds);
        padded_ur = NaN(num_samples, global_max_rounds);
        padded_fp = NaN(num_samples, global_max_rounds);

        for trial = 1:num_samples
            ts_r1 = round_ts_R1_cell{idxAlpha, trial, idxScenario};
            if isempty(ts_r1), continue; end
            n = numel(ts_r1);

            padded_R1(trial, 1:n) = ts_r1(:)';
            padded_eta(trial, 1:n) = round_ts_eta_cell{idxAlpha, trial, idxScenario}(:)';
            padded_ur(trial, 1:n) = round_ts_unreachable_cell{idxAlpha, trial, idxScenario}(:)';
            padded_fp(trial, 1:n) = round_ts_n_failed_power_cell{idxAlpha, trial, idxScenario}(:)';

            % LVCF 填充
            if n < global_max_rounds
                last_r1 = ts_r1(find(~isnan(ts_r1), 1, 'last'));
                if ~isempty(last_r1), padded_R1(trial, n+1:global_max_rounds) = last_r1; end

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

% --- 图5: 延迟惩罚热力图 (alpha x round) ---
if ~isempty(nodelay_idx) && ~isempty(heavy_idx)
    delta_delay_heatmap = NaN(plot_max_round, numA);
    for idxA = 1:numA
        R1_nd = mean_ts_R1(1:plot_max_round, idxA, nodelay_idx);
        R1_hv = mean_ts_R1(1:plot_max_round, idxA, heavy_idx);
        delta_delay_heatmap(:, idxA) = R1_nd - R1_hv;
    end

    figure('Name', 'Fig4_Delay_Penalty_Heatmap');
    imagesc(1:plot_max_round, alpha_range, delta_delay_heatmap');
    set(gca, 'YDir', 'normal');
    cb = colorbar;
    cb.Label.String = '\DeltaR_1^{delay}';
    xlabel('Cascade Round');
    ylabel('\alpha');
    title('Delay Penalty Heatmap (\DeltaR_1 = R_1^{no\_delay} - R_1^{heavy})');
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
            % 使用 delay-adjusted R1（与主实验一致）
            action_round_logs = round_log_action{idxAlpha, trial};
            if ~isempty(action_round_logs)
                last_rl_action = action_round_logs{end};
                if isfield(last_rl_action, 'delay_injection_log') && ~isempty(last_rl_action.delay_injection_log.eta)
                    dil_action = last_rl_action.delay_injection_log;
                    P_ref_action = [];
                    P_actual_action = [];
                    for gk_a = 1:numel(dil_action.eta)
                        match_a = find(mpc.gen(:,1) == dil_action.gen_bus(gk_a), 1, 'first');
                        if ~isempty(match_a) && abs(mpc.gen(match_a, 2)) > eps
                            pg_ref_a = mpc.gen(match_a, 2);
                            P_ref_action(end+1, 1) = pg_ref_a; %#ok<AGROW>
                            P_actual_action(end+1, 1) = pg_ref_a * dil_action.eta(gk_a); %#ok<AGROW>
                        end
                    end
                    if ~isempty(P_ref_action) && sum(P_ref_action) > 0
                        R1_action_mat(idxAlpha, trial, ai) = computeDelayAdjustedR1( ...
                            initial_power_load, failed_pn, P_actual_action, P_ref_action);
                    else
                        R1_action_mat(idxAlpha, trial, ai) = computeR1LoadRatio(initial_power_load, failed_pn);
                    end
                else
                    R1_action_mat(idxAlpha, trial, ai) = computeR1LoadRatio(initial_power_load, failed_pn);
                end
            else
                R1_action_mat(idxAlpha, trial, ai) = computeR1LoadRatio(initial_power_load, failed_pn);
            end
        end
    end

    fprintf('动作 %s 完成。\n', action_name);
end

fprintf('\n========== 全部动作场景完成 ==========\n');

% --- IQR截尾均值（动作场景，算法与基线第289-312行完全一致） ---
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
            iqr_val = q75 - q25;
            lower_fence = q25 - 1.5 * iqr_val;
            upper_fence = q75 + 1.5 * iqr_val;
            inliers = r1_vals(r1_vals >= lower_fence & r1_vals <= upper_fence);
            if isempty(inliers)
                trimmed_mean_R1_action(idxAlpha, ai) = median(r1_vals);
            else
                trimmed_mean_R1_action(idxAlpha, ai) = mean(inliers);
            end
        end
    end
end

% --- 恢复比例计算（使用与前面图表完全一致的基线） ---
R1_nodelay_base = trimmed_mean_R1(:, nodelay_base_idx);
R1_heavy_base   = trimmed_mean_R1(:, heavy_base_idx);
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
        delta = trimmed_mean_R1_action(idxAlpha, ai) - R1_heavy_base(idxAlpha);
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

% 合并数据用于对比图: [no_delay, heavy, A1, A2, A3, A4, A5]
all_trimmed = [R1_nodelay_base, R1_heavy_base, trimmed_mean_R1_action];
num_compare_scenarios = size(all_trimmed, 2);

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
ylabel('R_1 (delay-adjusted, IQR-trimmed mean)', 'FontSize', 12);
title(sprintf('Sensitivity Analysis: R_1 vs. \\alpha (delay-adjusted, samples: %d)', num_samples), 'FontSize', 14);

for si = 1:num_compare_scenarios
    plot(alpha_range, all_trimmed(:, si), sensitivity_styles{si}, ...
        'LineWidth', sensitivity_widths(si), 'Color', sensitivity_colors(si, :), ...
        'MarkerFaceColor', sensitivity_colors(si, :), 'MarkerSize', 6);
end
legend(cellstr(all_compare_labels), 'Location', 'best', 'FontSize', 10);
hold off;

% --- 图6: 恢复比例热力图 (action × alpha) ---
figure('Name', 'Fig6_Recovery_Heatmap', 'Position', [100, 100, 1000, 400]);
imagesc(alpha_range, 1:num_actions, action_recovery_pct');
set(gca, 'YDir', 'normal');
colormap(hot);
cb_sens = colorbar;
ylabel(cb_sens, 'Recovery %', 'FontSize', 11);
xlabel('\alpha', 'FontSize', 12);
ylabel('Action', 'FontSize', 12);
action_name_list = strings(num_actions, 1);
for ai = 1:num_actions
    action_name_list(ai) = action_scenarios(ai).name;
end
set(gca, 'YTick', 1:num_actions, 'YTickLabel', cellstr(action_name_list));
title('Recovery %: (Action R_1 - Heavy R_1) / (NoDelay R_1 - Heavy R_1)', 'FontSize', 13);

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
ylabel('Mean Recovery % (\alpha \geq 0.3)', 'FontSize', 12);
title('Ranking of Mitigation Actions by Effectiveness', 'FontSize', 14);
grid on;
for k = 1:numel(bar_data_sens)
    text(k, bar_data_sens(k) + 1, sprintf('%.1f%%', bar_data_sens(k)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

%% ====================================================================
%% 对比实验：验证"最佳时间段 × 最佳动作"的协同效果
%% ====================================================================
% 设计思路：
%   前面的热力图告诉我们 WHEN —— 在哪些α值（系统状态）下时延危害最大
%   敏感性实验告诉我们 HOW —— 哪些工程动作最有效
%   对比实验将两者结合，证明只有"在最佳时间段采取最佳动作"才能获得最大收益
%
% 三组对比条件：
%   C1: 非最佳α区域 + 最佳动作 → 效果一般（时延本身在该区域影响不大）
%   C2: 最佳α区域 + 非最佳动作 → 效果中等（找对了问题，但方法不是最优）
%   C3: 最佳α区域 + 最佳动作   → 效果最好（找对问题 + 最优方法）

fprintf('\n========== 对比实验: 最佳时间段 x 最佳动作 ==========\n');

% --- 从R1差距确定最佳/非最佳α区域 ---
% gap = R1_nodelay - R1_heavy（第638行已计算）
% gap(idxAlpha) 越大 → 时延危害越大 → 这是"最佳干预时间段"
[sorted_gap, gap_sort_idx] = sort(gap, 'descend');

% 取约1/3的α值作为最佳/非最佳区域
n_region = max(1, round(numA / 3));
optimal_alpha_idx = gap_sort_idx(1:n_region);           % 延迟危害最大的α值
nonoptimal_alpha_idx = gap_sort_idx(end-n_region+1:end); % 延迟危害最小的α值

fprintf('最佳干预α区域（延迟危害最大）:\n');
for k = 1:numel(optimal_alpha_idx)
    fprintf('  alpha=%.1f, gap(R1)=%.4f\n', alpha_range(optimal_alpha_idx(k)), gap(optimal_alpha_idx(k)));
end
fprintf('非最佳α区域（延迟危害最小）:\n');
for k = 1:numel(nonoptimal_alpha_idx)
    fprintf('  alpha=%.1f, gap(R1)=%.4f\n', alpha_range(nonoptimal_alpha_idx(k)), gap(nonoptimal_alpha_idx(k)));
end

% --- 从敏感性排名确定最佳/非最佳动作 ---
best_action_rank_idx = sort_order(1);      % 排名第1的动作
nonbest_action_rank_idx = sort_order(end); % 排名最后的动作

fprintf('最佳动作: %s (平均恢复 %.1f%%)\n', ...
    char(action_scenarios(best_action_rank_idx).name), mean_recovery(best_action_rank_idx));
fprintf('非最佳动作: %s (平均恢复 %.1f%%)\n', ...
    char(action_scenarios(nonbest_action_rank_idx).name), mean_recovery(nonbest_action_rank_idx));

% --- 计算三组对比条件的恢复比例 ---
% C1: 非最佳α区域 + 最佳动作
C1_recovery_vals = action_recovery_pct(nonoptimal_alpha_idx, best_action_rank_idx);
C1_mean = mean(C1_recovery_vals, 'omitnan');

% C2: 最佳α区域 + 非最佳动作
C2_recovery_vals = action_recovery_pct(optimal_alpha_idx, nonbest_action_rank_idx);
C2_mean = mean(C2_recovery_vals, 'omitnan');

% C3: 最佳α区域 + 最佳动作
C3_recovery_vals = action_recovery_pct(optimal_alpha_idx, best_action_rank_idx);
C3_mean = mean(C3_recovery_vals, 'omitnan');

fprintf('\n===== 对比实验结果 =====\n');
fprintf('  C1 (非最佳alpha + 最佳动作 %s):  平均恢复 %.1f%%\n', ...
    char(action_scenarios(best_action_rank_idx).name), C1_mean);
fprintf('  C2 (最佳alpha + 非最佳动作 %s):  平均恢复 %.1f%%\n', ...
    char(action_scenarios(nonbest_action_rank_idx).name), C2_mean);
fprintf('  C3 (最佳alpha + 最佳动作 %s):    平均恢复 %.1f%%\n', ...
    char(action_scenarios(best_action_rank_idx).name), C3_mean);

% --- 图8: 对比实验柱状图 ---
figure('Name', 'Fig8_Comparison_Experiment', 'Position', [100, 100, 900, 550]);

comparison_data = [C1_mean, C2_mean, C3_mean];
comparison_colors = [
    0.60 0.60 0.60;   % C1: 灰色（一般）
    0.93 0.69 0.13;   % C2: 金色（中等）
    0.17 0.63 0.17;   % C3: 绿色（最佳）
];

b_comp = bar(comparison_data, 'FaceColor', 'flat');
b_comp.CData = comparison_colors;

% 构造标签：显示条件和动作名称
optimal_alpha_str = strjoin(arrayfun(@(x) sprintf('%.1f', x), ...
    alpha_range(optimal_alpha_idx), 'UniformOutput', false), ',');
nonoptimal_alpha_str = strjoin(arrayfun(@(x) sprintf('%.1f', x), ...
    alpha_range(nonoptimal_alpha_idx), 'UniformOutput', false), ',');

comp_tick_labels = {
    sprintf('C1: non-opt alpha\\{%s\\}\n+ best %s', nonoptimal_alpha_str, char(action_scenarios(best_action_rank_idx).name)), ...
    sprintf('C2: opt alpha\\{%s\\}\n+ non-best %s', optimal_alpha_str, char(action_scenarios(nonbest_action_rank_idx).name)), ...
    sprintf('C3: opt alpha\\{%s\\}\n+ best %s', optimal_alpha_str, char(action_scenarios(best_action_rank_idx).name))
};
set(gca, 'XTickLabel', comp_tick_labels, 'FontSize', 9);
ylabel('Mean Recovery %', 'FontSize', 12);
title('Comparison Experiment: Optimal Timing x Best Action', 'FontSize', 14);
grid on;

% 在柱子上方标注数值
for k = 1:3
    text(k, comparison_data(k) + max(abs(comparison_data)) * 0.03, ...
        sprintf('%.1f%%', comparison_data(k)), ...
        'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end

% --- 图9: 对比实验详细折线图（按α值展开） ---
% 展示最佳动作和非最佳动作在全部α值上的恢复比例，用竖线标示最佳/非最佳区域
figure('Name', 'Fig9_Comparison_Detail', 'Position', [100, 100, 1100, 550]);
hold on; grid on;

plot(alpha_range, action_recovery_pct(:, best_action_rank_idx), '-o', 'LineWidth', 2.0, ...
    'Color', [0.17 0.63 0.17], 'MarkerFaceColor', [0.17 0.63 0.17], 'MarkerSize', 7);
plot(alpha_range, action_recovery_pct(:, nonbest_action_rank_idx), '--s', 'LineWidth', 2.0, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerSize', 7);

% 用阴影标注最佳α区域
y_lim = ylim;
for k = 1:numel(optimal_alpha_idx)
    a_val = alpha_range(optimal_alpha_idx(k));
    fill([a_val-0.04, a_val+0.04, a_val+0.04, a_val-0.04], ...
        [y_lim(1), y_lim(1), y_lim(2), y_lim(2)], ...
        [0.85 0.95 0.85], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
end

xlabel('\alpha', 'FontSize', 12);
ylabel('Recovery %', 'FontSize', 12);
title('Recovery % by Action across All \alpha (green shading = optimal \alpha region)', 'FontSize', 13);
legend({sprintf('Best: %s', char(action_scenarios(best_action_rank_idx).name)), ...
    sprintf('Non-best: %s', char(action_scenarios(nonbest_action_rank_idx).name)), ...
    'Optimal \alpha region'}, 'Location', 'best', 'FontSize', 10);
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
