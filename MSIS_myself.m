% Vp = 118 ;
% num_cc = max(1,round(0.2*Vp));      % 控制中心数量
% Vc      = Vp + num_cc;               % 信息层总节点
% m = 2;     % 每个新节点连接 2 个现有节点
%
%
% clc;
% clear all ;
% Vp = 14 ;
% num_cc = max(1,round(0.2*Vp));      % 控制中心数量
% Vc      = Vp + num_cc;               % 信息层总节点
% m = 8;
% m_edge = 2;
% G_cyber_ba = generateBANetwork(Vc, m, m_edge) ;

% % 使用 Barabási-Albert 模型生成无标度网络
% G_cyber_ba = barabasi_albert(Vc, m);
function msis_myself = MSIS_myself(G_cyber_ba,Vc)
%D = distances(G_cyber_ba) ;

 degC = centrality(G_cyber_ba, 'degree');
 betC = centrality(G_cyber_ba, 'betweenness')+1;
 C = node_clustering_coefficient(G_cyber_ba) ;
%NC_bet = neighbor_betweenness_centrality(G_cyber_ba) ;
 cloC = centrality(G_cyber_ba,"closeness") ;
 %NC = neighbor_centrality(G_cyber_ba);
%[~, ~, C_nc_plus] = k_shell_enhanced(G_cyber_ba) ;
%[~, ~, G_plus] = gravity_centrality_with_k_shell(G_cyber_ba) ;
ks = k_shell(G_cyber_ba) ;
%eigC = centrality(G_cyber_ba,"eigenvector") ;
%page = centrality(G_cyber_ba,"pagerank") ;
% figure;
% plot(G_cyber_ba, 'Layout', 'force', 'NodeColor', 'b', 'MarkerSize', 4);
% title('Barabási–Albert Network');

%公式（17）
total_weight = ((betC+ks)./cloC)+(degC.*C);
%msis = ;
% 计算每个节点的 MSIS 值
msis_myself = zeros(Vc, 1);  % 预分配MSIS数组

for i = 1:Vc
    % 获取节点i的所有直接邻居
    %neighbors_i = neighbors(G_cyber_ba, i);

    % 初始化节点i的MSIS得分
    %msis_i = 0;

    % 对每个邻居节点j计算贡献
    %for j = 1:length(neighbors_i)
        %v_j = neighbors_i(j);

        % 由于是直接邻居，dist(i, v_j) = 1
        % 应用MSIS公式：(tw(i) × tw(j)) / (1 + 1)
        msis_i = total_weight(i)  ;
    %end

    msis_myself(i) = msis_i;
end
end

% % 可视化MSIS结果
% figure;
% bar(msis);
% title('各节点的MSIS影响力得分');
% xlabel('节点编号');
% ylabel('MSIS得分');
% grid on;
