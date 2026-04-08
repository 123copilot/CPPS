function G_graph = generateBANetwork(Vc, m, m_edge)
% 生成巴拉巴西-阿尔伯特(BA)无标度网络
%
% 输入参数：
%   Vc - 最终信息网络的节点总数
%   m - 初始网络的节点数（完全连接）m=2
%   m_edge - 每个新节点添加的边数（m_edge <= 2）
%
% 输出参数：
%   A - 网络的邻接矩阵（n×n的对称矩阵）

% 参数检查
if m_edge > m
    error('m 不能大于 m0');
end
if m >= Vc
    error('m0 必须小于 n');
end

% 初始化邻接矩阵
A = zeros(Vc, Vc);

% 步骤1：创建初始完全图
for i = 1:m
    for j = i+1:m
        A(i, j) = 1;
        A(j, i) = 1;
    end
end

% 计算每个节点的度
degrees = sum(A, 2);

% 步骤2：逐个添加新节点
for newNode = m+1:Vc
    % 计算连接概率（与节点度成正比）
    totalDegree = sum(degrees(1:newNode-1));
    prob = degrees(1:newNode-1) / totalDegree;
    
    % 累积概率分布
    cumProb = cumsum(prob);
    
    % 选择m个节点进行连接（无重复）
    selectedNodes = [];
    for k = 1:m_edge
        while true
            % 根据概率分布随机选择节点
            r = rand();
            selectedNode = find(cumProb >= r, 1);
            
            % 检查是否已经选择过该节点
            if ~ismember(selectedNode, selectedNodes)
                selectedNodes(k) = selectedNode;
                break;
            end
        end
    end
    
    % 连接新节点到选中的节点
    for selectedNode = selectedNodes
        A(newNode, selectedNode) = 1;
        A(selectedNode, newNode) = 1;
    end
    
    % 更新度分布
    degrees(newNode) = m_edge;
    degrees(selectedNodes) = degrees(selectedNodes) + 1;
end

% 将邻接矩阵转换为graph对象
G_graph = graph(A);

end