function C = node_clustering_coefficient(G)
% 计算图中每个节点的聚类系数（基于三角形计数定义）
% 输入：G - MATLAB graph对象
% 输出：C - n×1向量，每个节点的聚类系数

    n = numnodes(G);
    C = zeros(n, 1);
    
    % 获取邻接矩阵（更高效的边检查）
    A = adjacency(G);
    
    for i = 1:n
        % 获取节点i的邻居
        neighbors_i = neighbors(G, i);
        d_i = length(neighbors_i);  % 节点i的度数
        
        % 如果度数小于2，聚类系数为0
        if d_i < 2
            C(i) = 0;
            continue;
        end
        
        % 计算三角形数量 T(v_i)
        triangles = 0;
        
        % 遍历所有邻居对
        for j = 1:d_i
            for k = j+1:d_i
                node_j = neighbors_i(j);
                node_k = neighbors_i(k);
                
                % 检查节点j和k之间是否有边（形成三角形）
                if A(node_j, node_k) > 0 || A(node_k, node_j) > 0
                    triangles = triangles + 1;
                end
            end
        end
        
        % 应用公式：C(v_i) = 2 × T(v_i) / [d(v_i) × (d(v_i) - 1)]
        C(i) = (2 * triangles) / (d_i * (d_i - 1));
    end
end