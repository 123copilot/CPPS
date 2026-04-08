function total_delay = computeCyberPathDelay(path_nodes, link_delay_matrix, isCC, direction, delay_cfg)
%COMPUTECYBERPATHDELAY 按 tuesday.md 公式计算路径总时延。
%
% direction:
%   'down' -> CC -> nonCC
%   'up'   -> nonCC -> CC

path_nodes = path_nodes(:)';

if numel(path_nodes) < 2
    error('path_nodes 至少需要包含两个节点。');
end

link_delay_sum = 0;
for idx = 1:(numel(path_nodes) - 1)
    u = path_nodes(idx);
    v = path_nodes(idx + 1);
    link_delay_sum = link_delay_sum + link_delay_matrix(u, v);
end

forward_delay_sum = 0;
forward_nodes = path_nodes(2:end-1);
for idx = 1:numel(forward_nodes)
    node_id = forward_nodes(idx);
    if isCC(node_id)
        forward_delay_sum = forward_delay_sum + delay_cfg.service.cc.forward;
    else
        forward_delay_sum = forward_delay_sum + delay_cfg.service.noncc.forward;
    end
end

switch lower(direction)
    case 'down'
        endpoint_delay = delay_cfg.service.cc.tx + delay_cfg.service.noncc.rx;
    case 'up'
        endpoint_delay = delay_cfg.service.noncc.tx + delay_cfg.service.cc.rx;
    otherwise
        error('direction 必须为 ''down'' 或 ''up''。');
end

total_delay = link_delay_sum + endpoint_delay + forward_delay_sum;
end
