function [R3, details] = computeCascadeR3Metric(mpc, failed_power_nodes, A_pc, control_centers, isCC, Ac, delay_cfg)
%COMPUTECASCADER3METRIC 按 tuesday.md 定义计算级联结束后的 R3 指标。
%
% 约束：
% 1) 不改动级联失效主逻辑，只基于级联结束后的存活发电机做后处理。
% 2) P_ref 使用系统初始状态下、且在级联结束后仍存活的发电机初始有功 Pg。
% 3) P_actual = P_ref .* (1 - k_m * tau_m) .* (1 - k_e * tau_e)

failed_power_nodes = unique(failed_power_nodes(:));
bus_count = size(mpc.bus, 1);
failed_power_nodes = failed_power_nodes(failed_power_nodes >= 1 & failed_power_nodes <= bus_count);

gen_bus = mpc.gen(:, 1);
gen_pg_initial = mpc.gen(:, 2);
if size(mpc.gen, 2) >= 8
    gen_status = mpc.gen(:, 8);
else
    gen_status = ones(size(gen_bus));
end

online_gen_mask = gen_status > 0;
surviving_gen_mask = ~ismember(gen_bus, failed_power_nodes);
participating_gen_mask = online_gen_mask & surviving_gen_mask & (abs(gen_pg_initial) > eps);

surviving_gen_idx = find(participating_gen_mask);
num_participating = numel(surviving_gen_idx);

details = struct();
details.surviving_generator_indices = surviving_gen_idx;
details.surviving_generator_buses = gen_bus(surviving_gen_idx);
details.failed_power_nodes = failed_power_nodes;
details.num_participating_generators = num_participating;

if num_participating == 0
    R3 = NaN;
    details.P_ref = [];
    details.P_actual = [];
    details.relative_deviation = [];
    details.message = '级联结束后没有参与调节且存活的发电机，R3 记为 NaN。';
    return;
end

Ac = double(full(Ac ~= 0));
isCC = logical(isCC(:));
control_centers = unique(control_centers(:));

link_delay_scalar_up = computeCyberLinkDelay( ...
    delay_cfg.communication.packet_size_bits_up, ...
    delay_cfg.communication.default_link_rate_bps, ...
    delay_cfg.communication.default_distance_km, ...
    delay_cfg.communication.propagation_speed_kmps);
link_delay_scalar_down = computeCyberLinkDelay( ...
    delay_cfg.communication.packet_size_bits_down, ...
    delay_cfg.communication.default_link_rate_bps, ...
    delay_cfg.communication.default_distance_km, ...
    delay_cfg.communication.propagation_speed_kmps);

link_delay_matrix_up = Ac .* link_delay_scalar_up;
link_delay_matrix_down = Ac .* link_delay_scalar_down;

if link_delay_scalar_down <= 0
    cyber_delay_graph = graph(Ac, 'upper');
else
    cyber_delay_graph = graph(link_delay_matrix_down, 'upper');
end

P_ref = gen_pg_initial(surviving_gen_idx);
P_actual = zeros(num_participating, 1);
eta = zeros(num_participating, 1);
f_m = zeros(num_participating, 1);
f_e = zeros(num_participating, 1);
tau_m = zeros(num_participating, 1);
tau_e = zeros(num_participating, 1);
selected_cc = zeros(num_participating, 1);
mapped_cyber_nodes = zeros(num_participating, 1);
up_path_length = zeros(num_participating, 1);
down_path_length = zeros(num_participating, 1);
is_reachable = false(num_participating, 1);
unreachable_generator_rows = [];
unreachable_generator_buses = [];
unreachable_cyber_nodes = [];

% η⁺ 模型所需：参考 Pg 的极值（方案 A 归一化分母），全局唯一基准
P_g_ref_max_for_eta = max(gen_pg_initial);
use_etaplus = isfield(delay_cfg, 'power') && ...
    isfield(delay_cfg.power, 'eta_model') && ...
    strcmpi(delay_cfg.power.eta_model, 'etaplus');
if use_etaplus && ~(P_g_ref_max_for_eta > 0)
    error('computeCascadeR3Metric:invalidPmax', ...
        'gen_pg_initial 的最大值必须 > 0 才能用于 η⁺ 归一化。');
end

for idx = 1:num_participating
    gen_row = surviving_gen_idx(idx);
    bus_id = gen_bus(gen_row);

    mapped_cyber = find(A_pc(bus_id, :) == 1, 1, 'first');
    if isempty(mapped_cyber)
        error('电力节点 %d 未在 A_pc 中找到对应的信息节点，无法计算 R3。', bus_id);
    end
    mapped_cyber_nodes(idx) = mapped_cyber;

    best_distance = inf;
    best_cc = NaN;
    best_up_path = [];
    best_down_path = [];

    for cc_idx = 1:numel(control_centers)
        cc_node = control_centers(cc_idx);
        [candidate_down_path, candidate_distance] = shortestpath(cyber_delay_graph, cc_node, mapped_cyber);
        if isempty(candidate_down_path) || isinf(candidate_distance)
            continue;
        end
        if candidate_distance < best_distance
            best_distance = candidate_distance;
            best_cc = cc_node;
            best_down_path = candidate_down_path;
            best_up_path = fliplr(candidate_down_path);
        end
    end

    if isnan(best_cc)
        unreachable_generator_rows(end + 1, 1) = gen_row; %#ok<AGROW>
        unreachable_generator_buses(end + 1, 1) = bus_id; %#ok<AGROW>
        unreachable_cyber_nodes(end + 1, 1) = mapped_cyber; %#ok<AGROW>

        selected_cc(idx) = NaN;
        down_path_length(idx) = NaN;
        up_path_length(idx) = NaN;
        tau_m(idx) = NaN;
        tau_e(idx) = NaN;
        P_actual(idx) = 0;
        eta(idx) = 0;
        f_m(idx) = 0;
        f_e(idx) = 0;
        continue;
    end

    is_reachable(idx) = true;
    selected_cc(idx) = best_cc;
    down_path_length(idx) = numel(best_down_path);
    up_path_length(idx) = numel(best_up_path);

    if link_delay_scalar_up <= 0 && link_delay_scalar_down <= 0
        cyber_down_delay = 0;
        cyber_up_delay = 0;
    else
        cyber_down_delay = computeCyberPathDelay(best_down_path, link_delay_matrix_down, isCC, 'down', delay_cfg);
        cyber_up_delay = computeCyberPathDelay(best_up_path, link_delay_matrix_up, isCC, 'up', delay_cfg);
    end

    tau_m(idx) = delay_cfg.power.pb_to_noncc_measurement_delay_s + cyber_up_delay;
    tau_e(idx) = delay_cfg.power.noncc_to_pb_execution_delay_s + cyber_down_delay;

    if use_etaplus
        % η⁺：四因子分解，n_hops_total = 上行跳数 + 下行跳数
        n_hops_total_idx = max(0, numel(best_up_path) - 1) + ...
                           max(0, numel(best_down_path) - 1);
        eta(idx) = computeEtaPlus(tau_m(idx), tau_e(idx), ...
            n_hops_total_idx, P_ref(idx), P_g_ref_max_for_eta, delay_cfg);
        eta(idx) = max(0, min(1, eta(idx)));
        P_actual(idx) = P_ref(idx) * eta(idx);
        % legacy f_m/f_e 输出在 etaplus 模式下不再有可比意义，置 NaN 以提示
        f_m(idx) = NaN;
        f_e(idx) = NaN;
    else
        [P_actual(idx), eta(idx), f_m(idx), f_e(idx)] = computeActualPowerWithDelay( ...
            P_ref(idx), ...
            tau_m(idx), ...
            tau_e(idx), ...
            delay_cfg.power.measurement_sensitivity, ...
            delay_cfg.power.execution_sensitivity);
    end
end

[R3, relative_deviation] = computeR3Deviation(P_actual, P_ref);

details.P_ref = P_ref;
details.P_actual = P_actual;
details.relative_deviation = relative_deviation;
details.eta = eta;
details.f_m = f_m;
details.f_e = f_e;
details.tau_m = tau_m;
details.tau_e = tau_e;
details.selected_control_center = selected_cc;
details.mapped_cyber_nodes = mapped_cyber_nodes;
details.up_path_length = up_path_length;
details.down_path_length = down_path_length;
details.link_delay_per_hop_up = link_delay_scalar_up;
details.link_delay_per_hop_down = link_delay_scalar_down;
details.is_reachable = is_reachable;
details.unreachable_generator_rows = unreachable_generator_rows;
details.unreachable_generator_buses = unreachable_generator_buses;
details.unreachable_cyber_nodes = unreachable_cyber_nodes;
end
