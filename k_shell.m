function ks = k_shell(G_cyber_ba)
% K_SHELL 计算网络中每个节点的k-shell值
% 输入:
%   adj - 网络的邻接矩阵 (n x n), 对称矩阵且对角线为0
% 输出:
%   ks - 每个节点的k-shell值 (n x 1)向量

adj = full(adjacency(G_cyber_ba));
n = size(adj, 1);
ks = zeros(n, 1);  % 初始化所有节点的k-shell值为0

% 复制邻接矩阵用于迭代修改，避免修改原始输入
current_adj = adj;
% 标记节点是否仍在网络中
remaining = true(n, 1);

k = 1;  % 从k=1开始

while any(remaining)
    % 计算当前剩余节点的度数
    deg = sum(current_adj, 2);

    % 找到度等于当前k值且仍在网络中的节点
    target_nodes = find(remaining & (deg <= k));


    % 标记这些节点的k-shell值为当前k
    ks(target_nodes) = k;

    % 将这些节点从网络中移除
    remaining(target_nodes) = false;

    % 更新邻接矩阵，清除这些节点的连接
    current_adj(target_nodes, :) = 0;
    current_adj(:, target_nodes) = 0;
    k = k + 1;
end
end