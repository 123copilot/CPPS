function [failP_mat, failC_mat,alpha_range,failed_power_nodes_cell,cascade_round_log_cell] = cascadeLogicdebug2gudingCC_bet_8(...
    mpc ,Vc,Ap, Ac_cell, A_pc_cell, propagation_probability ...
    ,P_branch,betC_cell,betCE_cell,info_pool_cell,attackMode ...
    ,control_centers_cell,isCC_cell,mpopt,G_cyber_ba_cell,delay_cfg)

alpha_range = 0.0:0.1:1.0; % alpha = 0.0, 0.1, 0.2, ..., 1.0 (11个值)
numA = numel(alpha_range);
num_trials = numel(A_pc_cell);

% %% --- 预分配结果矩阵 ---
% 预分配结果矩阵
failP_mat = zeros(numA, numel(A_pc_cell)); % 每个alpha对应100个结果
failC_mat = zeros(numA, numel(A_pc_cell)); % 每个alpha对应100个结果
cascade_round_log_cell = cell(numA, num_trials);
failed_power_nodes_cell = cell(numA, num_trials);


%% --- 最外层 for 循环开始 ---
parfor idxAlpha = 1:numA
    %idxAlpha = 2 ;
    alpha = alpha_range(idxAlpha); % 使用当前循环的 alpha 值
    fprintf('===== 正在运行仿真: alpha = %.2f =====\n', alpha);
    failed_power_nodes_row = cell(1, num_trials);
    round_log_row = cell(1, num_trials);
    % 对于每个alpha，使用所有预先生成的A_pc矩阵
    for trial = 1:num_trials

        fprintf('  使用第 %d/%d 个A_pc矩阵\n', trial, num_trials);

        % 获取当前试验的A_pc矩阵
        current_A_pc = A_pc_cell{trial};
        current_control_centers = control_centers_cell{trial};
        current_info_pool = info_pool_cell{trial};
        current_isCC = isCC_cell{trial};
        current_Ac = Ac_cell{trial};
        current_G_cyber_ba = G_cyber_ba_cell{trial};
        current_betC = betC_cell{trial};
        current_betCE = betCE_cell{trial};


        %电力层容量
        %Power_Node_Capacity = (1+alpha) * P_bus;
        Power_Edge_Capacity = (1+alpha) * P_branch;
        %信息层容量
        Cyber_Node_Capacity = (1+alpha) * current_betC;
        Cyber_Edge_Capacity = (1+alpha) * current_betCE;


        % --- 用下面更健壮的 table 创建方式替换 ---
        StartNode_ori = current_G_cyber_ba.Edges.EndNodes(:,1);
        EndNode_ori = current_G_cyber_ba.Edges.EndNodes(:,2);
        Be_capacity = table(StartNode_ori, EndNode_ori, Cyber_Edge_Capacity, 'VariableNames', {'StartNode', 'EndNode', 'Capacity'});

        %% 模拟级联失效
        %调用pickAttack函数选择攻击模式，以及确定被攻击的信息节点
        attacked_cyber_node = pickAttack_gudingCC_bet_8(current_info_pool, attackMode, current_betC) ;

        % 在并行环境中打印被攻击的信息节点
        disp(['被攻击的信息节点: ', mat2str(attacked_cyber_node)]);
        %=====  P. 级联仿真准备  ====
        %P1.初始化主故障列表
        failed_cyber_nodes = [attacked_cyber_node];%初始只有被攻击的信息节点（行向量）
        failed_power_nodes = [];
        failed_power_branches = [];%只考虑了容量负载那一部分中过载的电力支路
        failed_cyber_edges = [];%只考虑容量负载那一部分中过载的信息连边

        %P2.创建邻接矩阵的"动态副本"，用于在循环中修改
        Ac_k = current_Ac;
        Ap_k = Ap;

        % %P3.移除初始攻击的节点
        % Ac_k(attacked_cyber_node, :) = 0; Ac_k(:, attacked_cyber_node) = 0;

        % P4.--- 为嵌套循环做准备 ---
        %  主循环(Outer Loop)的控制器
        main_loop_keep_iterating = true;
        main_iteration_count = 1;

        %内循环（inner loop）
        inner_iteration_count = 1;

        % %P5.用于在主循环之间传递"新过载故障"的列表
         newly_failed_c_nodes_from_overload = [];
         newly_failed_c_edges_from_overload = [];
         newly_failed_p_branches_from_overload = [];

        %P6.设定故障传播概率
        %propagation_probability = 0.4;% 在这里统一定义，方便修改

        round_logs = {};

        % 设置可复现的随机种子，确保同一(alpha, trial)对
        % 在不同延迟场景下产生相同的随机故障传播路径，
        % 使得场景间的R1差异完全归因于延迟配置的不同
        rng(idxAlpha * 100000 + trial, 'twister');

        %% 2：级联失效主循环
        while main_loop_keep_iterating
            fprintf('\n========== 开始第 %d 轮级联失效迭代 ==========\n', main_iteration_count);

            % --- 将上一轮发现的过载故障，正式加入到总故障列表中 ---
            failed_cyber_nodes = unique([failed_cyber_nodes; newly_failed_c_nodes_from_overload]);
            failed_power_branches = unique([failed_power_branches; newly_failed_p_branches_from_overload]);
            failed_cyber_edges = unique([failed_cyber_edges; newly_failed_c_edges_from_overload]);

            % --- 清空临时的过载列表，为本轮的过载检查做准备 ---
            newly_failed_c_nodes_from_overload = [];
            newly_failed_p_branches_from_overload = [];
            newly_failed_c_edges_from_overload = [];

            % 在进行结构性分析前，需要根据当前所有的故障更新网络拓扑
            Ac_k = current_Ac;
            Ac_k(failed_cyber_nodes, :) = 0,Ac_k(:, failed_cyber_nodes) = 0;

            % --- 新增：根据失效连边列表，进一步破坏网络拓扑 ---
            if ~isempty(failed_cyber_edges)
                % 从原始图中获取连边的端点信息
                original_edges_c_table = current_G_cyber_ba.Edges;
                for k = 1:length(failed_cyber_edges)
                    edge_c_idx = failed_cyber_edges(k);
                    u = original_edges_c_table.EndNodes(edge_c_idx, 1);
                    v = original_edges_c_table.EndNodes(edge_c_idx, 2);
                    Ac_k(u, v) = 0;
                    Ac_k(v, u) = 0;
                end
            end

            %   内部循环(Inner Loop): 模拟"结构性"故障传播, 直到其自身稳定

            inner_loop_keep_iterating = true;
            while inner_loop_keep_iterating

                fprintf('\n========== 开始第 %d 轮结构性故障传播迭代 ==========\n', inner_iteration_count);
                % --- 保存"本轮开始"时的节点集合（行向量已排好序） ---
                prev_c_nodes = failed_cyber_nodes;
                prev_c_nodes = prev_c_nodes(:);
                prev_p_nodes = failed_power_nodes;
                prev_p_nodes = prev_p_nodes(:);

                % ---A 信息层网络分裂与功能性失效 ---
                G_subgraph_ba = graph(Ac_k);
                [c_bin, c_binsize] = conncomp(G_subgraph_ba); % bin是连通分量标识符，binsize是每个连通分量的大小

                % 获取所有独立的孤岛ID
                unique_c_ids = unique(c_bin);
                % 初始化一个列表，用于存放因不满足新规则而失效的节点
                c_failed_from_logic = [];
                % 遍历每一个孤岛，检查其内部"成分"是否满足存活条件
                for i = 1:length(unique_c_ids)
                    c_component = unique_c_ids(i);
                    % 找到当前孤岛中的所有节点
                    c_in_component = find(c_bin == c_component);

                    % 1. 检查该孤岛是否包含"存活的"控制中心
                    % 首先，找出该孤岛里有哪些节点是控制中心
                    cc_in_this_component = intersect(current_control_centers, c_in_component);
                    % 然后，在这些控制中心里，排除掉已经失效的
                    surviving_cc_in_component = setdiff(cc_in_this_component, failed_cyber_nodes);
                    % 设置标志位
                    has_surviving_cc = ~isempty(surviving_cc_in_component);

                    % 2. 检查该孤岛是否包含"普通的"信息节点
                    % 普通信息节点 = 孤岛里的所有节点 - 预设的控制中心节点
                    regular_nodes_in_component = setdiff(c_in_component, current_control_centers);
                    % 设置标志位
                    has_regular_nodes = ~isempty(regular_nodes_in_component);

                    % 3. 应用新规则进行最终判断
                    %孤岛存活条件：只要拥有控制中心即可
                    is_c_viable = has_surviving_cc;

                    % % 孤岛存活的条件：必须同时拥有存活的控制中心和普通信息节点
                    % is_c_viable = has_surviving_cc && has_regular_nodes;

                    % 4. 根据判断结果进行处理
                    if ~is_c_viable
                        % 将这个无效孤岛中的所有节点都加入到新增故障列表
                        c_failed_from_logic = [c_failed_from_logic, c_in_component];%这个是行向量
                    end
                end

                % c_failed_from_logic = setdiff(c_failed_from_logic, control_centers);
                % failed_cyber_nodes  = unique([failed_cyber_nodes, c_failed_from_logic]);

                failed_cyber_nodes = unique([failed_cyber_nodes; c_failed_from_logic(:)]);

                % ---B  正向传播 (信息层 -> 电力层) ---
                %找出由信息层节点失效可能导致的电力层的失效节点
                potential_power_failures = [];
                for i = 1:length(failed_cyber_nodes)
                    node_c = failed_cyber_nodes(i);
                    if current_isCC(node_c),  continue;  end     % 控制中心不参与传播
                    node_p = find(current_A_pc(:, node_c) == 1);
                    if ~isempty(node_p) && ~any(failed_power_nodes == node_p)
                        % 进行一次随机"抽签"
                        if rand < propagation_probability
                            % 将该电力节点加入失效列表
                            potential_power_failures = [potential_power_failures; node_p];
                            failed_power_nodes = unique([failed_power_nodes; potential_power_failures]);
                        end
                    end
                end
                failed_power_nodes = unique([failed_power_nodes; potential_power_failures]);

                % ---C  电力层网络解列与ACI有效性判断 ---
                % 首先，根据当前所有已知的电力故障，更新电力网络拓扑
                Ap_k = Ap; % 从原始 Ap 重新开始
                %  首先，根据失效节点列表，移除所有失效的节点
                if ~isempty(failed_power_nodes)
                    Ap_k(failed_power_nodes, :) = 0; Ap_k(:, failed_power_nodes) = 0;
                end

                %  检查是否存在因过载而失效的线路，如果存在，则将其从 Ap_k 中移除
                if ~isempty(failed_power_branches)

                    % 遍历每一条失效线路的索引
                    for k = 1:length(failed_power_branches)
                        % 获取线路的原始索引
                        branch_idx = failed_power_branches(k);

                        % 关键转换：从 mpc.branch 中查找该线路两端的节点ID
                        u = mpc.branch(branch_idx, 1); % 起始节点 (From bus)
                        v = mpc.branch(branch_idx, 2); % 终止节点 (To bus)

                        % 在邻接矩阵中将这条连接断开
                        Ap_k(u, v) = 0;
                        Ap_k(v, u) = 0; % 因为是无向图，所以要双向断开
                    end
                end

                G_subgraph_power = graph(Ap_k);
                [p_bin, p_binsize] = conncomp(G_subgraph_power);
                %检查孤岛的有效性即是否满足全类型模型
                bus_types = mpc.bus(:, 2);
                % 获取独立的孤岛编号
                unique_p_ids = unique(p_bin);
                % 初始化一个列表，用于存放因孤岛无效而新增的故障节点
                p_newly_failed_nodes = [];
                % 遍历每一个孤岛
                for i = 1:length(unique_p_ids)
                    ids_id = unique_p_ids(i);
                    % 找到当前孤岛中的所有节点
                    nodes_p_in_ids = find(p_bin == ids_id);
                    if ~all(ismember(nodes_p_in_ids, failed_power_nodes))
                        % 获取该孤岛中所有节点的类型
                        types_in_ids = bus_types(nodes_p_in_ids);
                        % 判断孤岛中是否包含各类节点
                        has_load = any(types_in_ids == 1);
                        has_generator = any(types_in_ids == 2);
                        has_slack = any(types_in_ids == 3);
                        % 定义孤岛存活的条件：必须有负荷，且必须有电源（发电机或平衡节点）
                        is_viable = has_load && (has_generator || has_slack);
                        % 如果孤岛不满足存活条件，则其内部所有节点都将失效
                        if ~is_viable
                            % 将这个无效孤岛中的所有节点添加到新增故障列表中
                            p_newly_failed_nodes = [p_newly_failed_nodes, nodes_p_in_ids];%这个是行向量
                        end
                    end
                end
                failed_power_nodes = unique([failed_power_nodes;p_newly_failed_nodes(:)]);%这个是行向量

                % ---D 反向传播 (电力层 -> 信息层) ---
                % 注意：这里的反向传播源是所有当前已知的电力故障
                potential_cyber_failures = [];
                for i = 1:length(failed_power_nodes)
                    node_p_2 = failed_power_nodes(i);
                    node_c_2 = find(current_A_pc(node_p_2, :) == 1);
                    if current_isCC(node_c_2), continue; end
                    if ~isempty(node_c_2) && ~any(failed_cyber_nodes == node_c_2) % 只对尚未失效的节点判断
                        if rand < propagation_probability
                            potential_cyber_failures = [potential_cyber_failures; node_c_2];
                            failed_cyber_nodes = unique([failed_cyber_nodes; potential_cyber_failures]);
                        end
                    end
                end
                %failed_cyber_nodes = unique([failed_cyber_nodes, potential_cyber_failures]);

                % ---E 更新网络状态并检查循环是否继续 ---
                % 根据本轮所有新增的信息层故障，更新信息网络拓扑，为下一轮做准备
                Ac_k = current_Ac; % 从原始 Ac 重新开始
                Ac_k(failed_cyber_nodes, :) = 0; Ac_k(:, failed_cyber_nodes) = 0;
                % ---------- 判断收敛：数量 + 集合内容 ----------
                same_num = (numel(failed_cyber_nodes) == numel(prev_c_nodes)) && ...
                    (numel(failed_power_nodes) == numel(prev_p_nodes));

                same_set = same_num && ...
                    isequal(failed_cyber_nodes, prev_c_nodes) && ...
                    isequal(failed_power_nodes, prev_p_nodes);

                if same_set
                    inner_loop_keep_iterating = false;   % 结构性传播稳定
                else
                    inner_iteration_count = inner_iteration_count + 1;
                    fprintf('\n在第 %d 轮结构性故障传播中发现了新的结构故障，准备进入下一轮迭代。\n', inner_iteration_count);
                end

            end
            fprintf('--- 结构性故障传播稳定 ---\n');

            %在模拟完故障传播模型后，分别对电力层与信息层进行容量-负载模型测试
            % ---F 分析信息层过载情况 ---
            % --- 初始化本阶段的输出 (为之后融合做准备) ---
            newly_failed_c_nodes_from_overload = []; % 用于收集因过载而失效的节点
            % 获取现存信息网络拓扑
            Ac_sur = current_Ac;
            if ~isempty(failed_cyber_nodes)
                Ac_sur(failed_cyber_nodes, :) = 0; Ac_sur(:, failed_cyber_nodes) = 0;
            end
            if ~isempty(failed_cyber_edges)
                % 从原始图中获取连边的端点信息
                original_edges_c_table = current_G_cyber_ba.Edges;
                for k = 1:length(failed_cyber_edges)
                    edge_c_idx = failed_cyber_edges(k);
                    u = original_edges_c_table.EndNodes(edge_c_idx, 1);
                    v = original_edges_c_table.EndNodes(edge_c_idx, 2);
                    Ac_sur(u, v) = 0; Ac_sur(v, u) = 0;
                end
            end
            G_cyber_sur = graph(Ac_sur);
            %  计算幸存信息元件的负载（介数）
            sur_c_betweenness_nodes = centrality(G_cyber_sur, 'betweenness') + 1;
            sur_c_betweenness_edges = edgeBetweenness_xinxi(G_cyber_sur) + 1;
            % --- 用下面更健壮的 table 创建方式替换 ---
            StartNode_sur = G_cyber_sur.Edges.EndNodes(:,1);
            EndNode_sur = G_cyber_sur.Edges.EndNodes(:,2);
            Be_sur_c = table(StartNode_sur, EndNode_sur, sur_c_betweenness_edges, 'VariableNames', {'StartNode', 'EndNode', 'Load'});
            % 检查并报告过载的信息层的【节点】
            is_any_c_node_overloaded = false;
            for j = 1:Vc
                if ~any(failed_cyber_nodes == j) % 只检查存活的节点
                    if current_isCC(j) || any(failed_cyber_nodes == j), continue; end
                    if sur_c_betweenness_nodes(j) > Cyber_Node_Capacity(j)
                        fprintf('  -> 警告: 信息节点 %d 处于过载状态! (最终负载: %.2f, 容量: %.2f)\n', ...
                            j, sur_c_betweenness_nodes(j), Cyber_Node_Capacity(j));
                        is_any_c_node_overloaded = true;
                        % 记录因过载而新增的故障节点
                        newly_failed_c_nodes_from_overload = [newly_failed_c_nodes_from_overload; j];
                    end
                end
            end
            if ~is_any_c_node_overloaded
                fprintf('  -> 所有幸存信息节点均未过载。\n');
            end
            %检查并报告信息层【连边】过载情况
            is_any_c_edge_overloaded = false;
            % --- 新增：初始化一个列表，用于收集因过载而失效的连边的"原始索引" ---
            newly_failed_c_edges_from_overload = [];%行向量

            % 遍历每一条"幸存"的连边
            for i = 1:height(Be_sur_c)
                %  直接从定义清晰的列中获取信息
                u_sur = Be_sur_c.StartNode(i); % 从 StartNode 列取第i个cell的内容
                v_sur = Be_sur_c.EndNode(i);   % 从 EndNode 列取第i个cell的内容
                load_sur = Be_sur_c.Load(i);     % 从 Load 列取第i个数值

                %  在比较前，对所有字符串进行清理和类型统一
                u_sur_clean = strtrim(string(u_sur));
                v_sur_clean = strtrim(string(v_sur));
                StartNode_clean = strtrim(string(Be_capacity.StartNode));
                EndNode_clean = strtrim(string(Be_capacity.EndNode));

                %  在"原始容量矩阵" Be_capacity 中找到这条边的容量
                %   这是最关键的匹配步骤
                match_idx = (strcmp(StartNode_clean, u_sur_clean) & strcmp(EndNode_clean, v_sur_clean)) ;
                % 如果没有找到匹配项 (理论上不应该发生，除非有bug)，则跳过
                if ~any(match_idx)
                    fprintf('  -> 警告: 未能在原始容量矩阵中找到幸存连边 (%s, %s)。\n', u_sur, v_sur);
                    continue;
                end
                %  获取其对应的原始容量
                %    利用逻辑索引 match_idx，从容量向量中取出唯一对应的容量值
                capacity_c_ori = Be_capacity.Capacity(match_idx);
                %  进行过载判断
                if load_sur > capacity_c_ori
                    msg = "  -> 警告: 信息连边 (" + u_sur + ", " + v_sur + ") 处于过载状态! (最终负载: " + load_sur + ", 容量: " + capacity_c_ori + ")";
                    disp(msg); % 使用 disp 函数来显示最终的字符串
                    is_any_c_edge_overloaded = true;
                    % --- 新增：记录失效连边的原始索引 ---
                    % find(match_idx) 可以将逻辑索引(true/false)转换为数值索引(行号)
                    original_edge_c_index = find(match_idx);
                    newly_failed_c_edges_from_overload = [newly_failed_c_edges_from_overload; original_edge_c_index];%这个参数里包含的是Be_capacity的行索引
                end
            end

            %  打印最终总结
            if ~is_any_c_edge_overloaded
                fprintf('  -> 所有幸存信息连边均未过载。\n');
            end

            % --- G 分析电力层过载情况 ---
            % --- 初始化本阶段的输出 (为之后融合做准备) ---
            newly_failed_p_branches_from_overload = []; % 用于收集因过载而失效的电力线路的"原始索引"

            %  构建最终幸存电力网络的 mpc 模型 (mpc_sur)
            mpc_sur = mpc;

            %  将所有失效的母线（节点）设为隔离状态 (BUS_TYPE = 4)
            if ~isempty(failed_power_nodes)
                mpc_sur.bus(failed_power_nodes, 2) = 4;
            end

            %     一条线路的任意一端连接了已失效的节点，则该线路也失效。
            structural_failed_branches_idx = find(ismember(mpc.branch(:,1), failed_power_nodes) | ismember(mpc.branch(:,2), failed_power_nodes));%列向量

            failed_power_branches = unique([failed_power_branches; structural_failed_branches_idx]);

            %  找出所有仍然"存活"的支路（线路）的原始索引
            %     一条线路存活的条件是：它的两端连接的母线都尚未失效
            active_branches_idx = find(~ismember(mpc.branch(:,1), failed_power_nodes) & ~ismember(mpc.branch(:,2), failed_power_nodes));
            mpc_sur.branch = mpc.branch(active_branches_idx, :);

            %  禁用与失效节点相连的发电机
            if ~isempty(failed_power_nodes)
                failed_gens_idx = ismember(mpc_sur.gen(:,1), failed_power_nodes);
                mpc_sur.gen(failed_gens_idx, 8) = 0; % GEN_STATUS 设为 0 (离线)
            end

            % % 将所有已经因过载而失效的线路也设为离线状态
            % if ~isempty(failed_power_branches)
            %     mpc_sur.branch(failed_power_branches, 11) = 0; % BR_STATUS 设为 0 (离线)
            % end

            %  找出所有仍然"存活"的支路（线路）的原始索引
            %  现在的存活条件是：端点节点存活 并且 线路自身状态为在线
            active_branches_idx = find( ...
                ~ismember(mpc.branch(:,1), failed_power_nodes) & ...
                ~ismember(mpc.branch(:,2), failed_power_nodes) & ...
                ~ismember((1:size(mpc.branch,1))', failed_power_branches) ...
                );
            mpc_sur.branch = mpc.branch(active_branches_idx, :);

            % ============================================================
            % 延迟注入：在 rundcpf 之前，根据 delay_cfg 修改发电机出力
            % ============================================================
            % 计算上下行链路延迟标量
            delay_link_scalar_up = computeCyberLinkDelay( ...
                delay_cfg.communication.packet_size_bits_up, ...
                delay_cfg.communication.default_link_rate_bps, ...
                delay_cfg.communication.default_distance_km, ...
                delay_cfg.communication.propagation_speed_kmps);
            delay_link_scalar_down = computeCyberLinkDelay( ...
                delay_cfg.communication.packet_size_bits_down, ...
                delay_cfg.communication.default_link_rate_bps, ...
                delay_cfg.communication.default_distance_km, ...
                delay_cfg.communication.propagation_speed_kmps);

            % 构建上下行延迟加权图
            Ac_sur_double = double(full(Ac_sur ~= 0));
            delay_link_matrix_up = Ac_sur_double .* delay_link_scalar_up;
            delay_link_matrix_down = Ac_sur_double .* delay_link_scalar_down;
            shortestpath_link_matrix = delay_link_matrix_down;
            if delay_link_scalar_down <= 0
                cyber_delay_graph = graph(Ac_sur_double, 'upper');
            else
                cyber_delay_graph = graph(shortestpath_link_matrix, 'upper');
            end

            % 找出存活的控制中心
            surviving_cc = setdiff(current_control_centers(:), failed_cyber_nodes(:));

            % 对每台在线且存活的发电机，计算 eta 并修改 Pg
            gen_bus_ids = mpc_sur.gen(:, 1);
            gen_status_vec = mpc_sur.gen(:, 8);
            delay_injection_log = struct('eta', [], 'tau_m', [], 'tau_e', [], ...
                'is_reachable', [], 'selected_cc', [], 'gen_bus', []);

            for gIdx = 1:size(mpc_sur.gen, 1)
                if gen_status_vec(gIdx) <= 0
                    continue;  % 已离线的发电机跳过
                end

                bus_id_g = gen_bus_ids(gIdx);
                mapped_cyber_g = find(current_A_pc(bus_id_g, :) == 1, 1, 'first');
                if isempty(mapped_cyber_g)
                    continue;  % 没有对应信息节点则跳过
                end

                % 寻找最近的存活 CC
                best_dist_g = inf;
                best_cc_g = NaN;
                best_down_path_g = [];

                for ccIdx = 1:numel(surviving_cc)
                    cc_node_g = surviving_cc(ccIdx);
                    [cand_path_g, cand_dist_g] = shortestpath(cyber_delay_graph, cc_node_g, mapped_cyber_g);
                    if isempty(cand_path_g) || isinf(cand_dist_g)
                        continue;
                    end
                    if cand_dist_g < best_dist_g
                        best_dist_g = cand_dist_g;
                        best_cc_g = cc_node_g;
                        best_down_path_g = cand_path_g;
                    end
                end

                if isnan(best_cc_g)
                    % 不可达发电机：出力设为 0
                    mpc_sur.gen(gIdx, 2) = 0;
                    delay_injection_log.eta(end+1) = 0;
                    delay_injection_log.tau_m(end+1) = NaN;
                    delay_injection_log.tau_e(end+1) = NaN;
                    delay_injection_log.is_reachable(end+1) = false;
                    delay_injection_log.selected_cc(end+1) = NaN;
                    delay_injection_log.gen_bus(end+1) = bus_id_g;
                else
                    % 可达发电机：计算路径延迟 → η → 修改 Pg
                    best_up_path_g = fliplr(best_down_path_g);
                    isCC_vec = current_isCC(:);

                    if delay_link_scalar_up <= 0 && delay_link_scalar_down <= 0
                        cyber_down_d = 0;
                        cyber_up_d = 0;
                    else
                        cyber_down_d = computeCyberPathDelay(best_down_path_g, delay_link_matrix_down, isCC_vec, 'down', delay_cfg);
                        cyber_up_d = computeCyberPathDelay(best_up_path_g, delay_link_matrix_up, isCC_vec, 'up', delay_cfg);
                    end

                    tau_m_g = delay_cfg.power.pb_to_noncc_measurement_delay_s + cyber_up_d;
                    tau_e_g = delay_cfg.power.noncc_to_pb_execution_delay_s + cyber_down_d;

                    [eta_g, ~, ~] = computePowerDelayEfficiency(tau_m_g, tau_e_g, ...
                        delay_cfg.power.measurement_sensitivity, ...
                        delay_cfg.power.execution_sensitivity);

                    % 确保 eta 在 [0, 1] 范围内
                    eta_g = max(0, min(1, eta_g));
                    mpc_sur.gen(gIdx, 2) = mpc_sur.gen(gIdx, 2) * eta_g;

                    delay_injection_log.eta(end+1) = eta_g;
                    delay_injection_log.tau_m(end+1) = tau_m_g;
                    delay_injection_log.tau_e(end+1) = tau_e_g;
                    delay_injection_log.is_reachable(end+1) = true;
                    delay_injection_log.selected_cc(end+1) = best_cc_g;
                    delay_injection_log.gen_bus(end+1) = bus_id_g;
                end
            end

            %  在幸存网络上，进行一次直流潮流计算以实现"负载重分布"
            fprintf('正在对幸存电力网络进行潮流重分布计算...\n');
            %try
            results_sur = rundcpf(mpc_sur,mpopt);
            sur_P_branch = abs(results_sur.branch(:, 14)) + 1;

            %  检查并报告过载的电力线路
            is_any_p_edge_overloaded = false;

            % 遍历每一条幸存的线路
            for j = 1:length(sur_P_branch)

                % 核心：将当前结果中的线路索引(j)映射回它在原始mpc文件中的索引
                original_p_idx = active_branches_idx(j);

                % 使用原始索引，从我们最开始定义的容量向量中获取其容量
                capacity_p_ori = Power_Edge_Capacity(original_p_idx);

                % 进行过载判断
                if sur_P_branch(j) > capacity_p_ori
                    fprintf('  -> 发现过载: 线路 %d (从 %d 到 %d) (新负载: %.2f MW, 容量: %.2f MW)\n', ...
                        original_p_idx, mpc.branch(original_p_idx,1), mpc.branch(original_p_idx,2), ...
                        sur_P_branch(j), capacity_p_ori);
                    is_any_p_edge_overloaded = true;
                    % 记录因过载而新增的故障线路
                    newly_failed_p_branches_from_overload = [newly_failed_p_branches_from_overload; original_p_idx];%列向量
                end
            end

            if ~is_any_p_edge_overloaded
                fprintf('  -> 所有幸存电力线路均未过载。\n');
            end

            round_log = struct();
            round_log.round_index = main_iteration_count;
            round_log.alpha = alpha;
            round_log.failed_power_nodes = failed_power_nodes(:);
            round_log.failed_cyber_nodes = failed_cyber_nodes(:);
            round_log.failed_power_branches = failed_power_branches(:);
            round_log.failed_cyber_edges = failed_cyber_edges(:);
            round_log.newly_failed_c_nodes_from_overload = newly_failed_c_nodes_from_overload(:);
            round_log.newly_failed_c_edges_from_overload = newly_failed_c_edges_from_overload(:);
            round_log.newly_failed_p_branches_from_overload = newly_failed_p_branches_from_overload(:);
            round_log.Ac_sur = Ac_sur;
            round_log.Ap_k = Ap_k;
            round_log.A_pc = current_A_pc;
            round_log.control_centers = current_control_centers(:);
            round_log.isCC = current_isCC(:);
            round_log.Vc = Vc;
            round_log.info_pool = current_info_pool(:);
            round_log.delay_injection_log = delay_injection_log;
            round_logs{end + 1} = round_log;

            %   主循环稳定判断
            if isempty(newly_failed_c_nodes_from_overload) && ...
                    isempty(newly_failed_p_branches_from_overload) && ...
                    isempty(newly_failed_c_edges_from_overload)

                fprintf('\n在第 %d 轮主循环中未发现新的过载故障，整个系统达到最终稳定状态。\n', main_iteration_count);
                main_loop_keep_iterating = false; % 刹车，终止主循环
            else
                fprintf('\n在第 %d 轮主循环中发现了新的过载故障，准备进入下一轮迭代。\n', main_iteration_count);
                main_iteration_count = main_iteration_count + 1;
            end
        end

        failP_mat(idxAlpha,trial) = numel(failed_power_nodes);
        failC_mat(idxAlpha,trial) = numel(failed_cyber_nodes);
        failed_power_nodes_row{trial} = failed_power_nodes(:)';
        round_log_row{trial} = round_logs;
    end
    %failP_mat(idxAlpha, :) = failP_row;
    %failC_mat(idxAlpha, :) = failC_row;
    failed_power_nodes_cell(idxAlpha, :) = failed_power_nodes_row;
    cascade_round_log_cell(idxAlpha, :) = round_log_row;
end

end
