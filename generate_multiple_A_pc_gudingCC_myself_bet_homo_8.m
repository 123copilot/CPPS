function [A_pc_cell, control_centers_cell, info_pool_cell,isCC_cell,Ac_cell,betC_cell, betCE_cell,G_cyber_ba_cell,MSIS_myself_cell] = generate_multiple_A_pc_gudingCC_myself_bet_homo_8(num_samples, Vc, num_cc, betP, Vp,m,m_edge)

% 修改后的函数，每次生成不同的BA网络
% 新增输入参数 m: BA网络的连接参数
% 新增输出参数 Ac_cell, betC_cell, betCE_cell: 存储每个样本的BA网络信息
%这个生成的A_pc是介数同配
% GENERATE_MULTIPLE_A_PC 生成多个A_pc矩阵和对应的控制中心
%   输入参数:
%       num_samples - 要生成的A_pc数量
%       Vc - 信息层节点数
%       num_cc - 控制中心数量
%       betP - 电力节点的介数中心性
%       betC - 信息节点的介数中心性
%       Vp - 电力层节点数
%   输出参数:
%       A_pc_cell - 包含所有A_pc矩阵的元胞数组
%       control_centers_cell - 包含每次生成A_pc矩阵时对应的控制中心的元胞数组
%       info_pool_cell - 包含每次生成A_pc矩阵时对应的非控制中心信息节点的元胞数组
%       power_to_cyber_cell - 包含每次生成A_pc矩阵时对应的电力节点到信息节点映射的元胞数组
%       isCC_cell - 包含每次生成A_pc矩阵时对应的isCC逻辑向量的元胞数组

% 预分配存储空间
A_pc_cell = cell(1, num_samples);
control_centers_cell = cell(1, num_samples);
info_pool_cell = cell(1, num_samples);
isCC_cell = cell(1, num_samples);
betC_cell = cell(1, num_samples);
betCE_cell = cell(1, num_samples);
G_cyber_ba_cell = cell(1, num_samples);
MSIS_myself_cell = cell(1,num_samples);
%power_to_cyber_cell = cell(1, num_samples);

for sample_idx = 1:num_samples

    %% 从排好序的信息节点中，分离出"普通信息节点"和"控制中心"
    G_cyber_ba = generateBANetwork(Vc, m, m_edge);
    G_cyber_ba_cell{sample_idx} = G_cyber_ba;
    Ac = adjacency(G_cyber_ba);

    msis_myself = MSIS_myself(G_cyber_ba,Vc) ;

    % 计算信息节点介数中心性
    betC = centrality(G_cyber_ba, 'betweenness') + 1;

    % 计算信息边介数中心性
    betCE = edgeBetweenness_xinxi(G_cyber_ba) + 1;

    control_centers = pickCC_MSIS_myself(num_cc,msis_myself);     % <-- 调工具函数
    isCC            = false(1,Vc);
    isCC(control_centers) = true;
    info_pool = find(~isCC);          % 只留下普通信息节点

    % 存储控制中心和非控制中心信息节点
    control_centers_cell{sample_idx} = control_centers;
    info_pool_cell{sample_idx} = info_pool;
    isCC_cell{sample_idx} = isCC; % 存储isCC结果

    % 假设我们选择"介数(betweenness)"作为连接策略的依据
    metric_power = betP ;
    % 使用节点ID作为第二排序键，确保确定性
    [~, sorted_power_indices] = sortrows([metric_power, (1:length(metric_power))'], [-1, 2]);
    sorted_power_indices = sorted_power_indices(:, 1)';

    % 假设我们选择"介数(betweenness)"作为连接策略的依据
    metric_cyber = betC;
    metric_cyber(isCC) = -inf;
    [~, sorted_cyber_indices] = sortrows([metric_cyber, (1:length(metric_cyber))'], [-1, 2]);
    sorted_cyber_indices = sorted_cyber_indices(:, 1)';
    mappable_cyber_indices = sorted_cyber_indices(~isCC(sorted_cyber_indices));

    power_to_cyber = zeros(1,Vp);
    for r = 1:Vp
        p_id = sorted_power_indices(r);       % 介数第 r 大的电力节点
        c_id = mappable_cyber_indices(r);     % 介数第 r 大的【非 CC】信息节点
        power_to_cyber(p_id) = c_id;
    end

    A_pc = zeros(Vp,Vc);
    A_pc( sub2ind(size(A_pc), (1:Vp)', power_to_cyber') ) = 1;

    % 存储结果
    A_pc_cell{sample_idx} = A_pc;
    control_centers_cell{sample_idx} = control_centers;
    info_pool_cell{sample_idx} = info_pool;
    isCC_cell{sample_idx} = isCC;
    Ac_cell{sample_idx} = Ac;
    betC_cell{sample_idx} = betC;
    betCE_cell{sample_idx} = betCE;
    MSIS_myself_cell{sample_idx} = msis_myself;
    % 显示进度
    if mod(sample_idx, 10) == 0
        fprintf('已生成 %d/%d 个A_pc矩阵\n', sample_idx, num_samples);
    end
end