function [paths, dist] = allShortestPaths(G, s, t)
% 返回 G 中从 s 到 t 所有最短路径（BFS）
dist = distances(G, s, t);  % 获取最短距离
if isinf(dist)
    paths = {};
    return;
end

paths = {};  % 存放所有路径
q = {s};     % 初始路径队列

while ~isempty(q)
    curr = q{1}; q(1) = [];
    last = curr(end);

    if last == t
        paths{end+1} = curr; 
    else
        for nb = neighbors(G, last)'
            if ~ismember(nb, curr) && length(curr) + 1 <= dist + 1
                q{end+1} = [curr nb]; 
            end
        end
    end
end
end
