function Be_c = edgeBetweenness_xinxi(G)

n = numnodes(G);
m = numedges(G);
Be_c = zeros(m, 1);

% 建立 (i,j) 到边编号的映射
edgeMap = containers.Map();
for e = 1:m
    i = G.Edges.EndNodes(e,1);
    j = G.Edges.EndNodes(e,2);
    edgeMap(sprintf('%d-%d', i, j)) = e;
    edgeMap(sprintf('%d-%d', j, i)) = e;  % 无向图对称
end

% 对所有 i ≠ j 枚举路径
for i = 1:n
    for j = i+1:n
        [paths, d] = allShortestPaths(G, i, j);
        numPaths = numel(paths);
        for k = 1:numPaths
            path = paths{k};
            % 遍历路径上的所有边
            for v = 1:(length(path)-1)
                a = path(v);
                b = path(v+1);
                key = sprintf('%d-%d', a, b);
                idx = edgeMap(key);
                Be_c(idx) = Be_c(idx) + 1 / numPaths;
            end
        end
    end
end


end
