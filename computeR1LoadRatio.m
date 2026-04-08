function [R1, surviving_load, initial_total_load, surviving_power_nodes] = computeR1LoadRatio(initial_power_load, failed_power_nodes)
%COMPUTER1LOADRATIO 计算存活电力节点总负荷占初始总负荷的比例。

initial_power_load = initial_power_load(:);
num_power_nodes = numel(initial_power_load);

if nargin < 2 || isempty(failed_power_nodes)
    failed_power_nodes = [];
end

failed_power_nodes = unique(failed_power_nodes(:));
failed_power_nodes = failed_power_nodes(failed_power_nodes >= 1 & failed_power_nodes <= num_power_nodes);
surviving_power_nodes = setdiff((1:num_power_nodes)', failed_power_nodes);

initial_total_load = sum(initial_power_load);
if initial_total_load <= 0
    error('初始总负荷必须为正数。');
end

surviving_load = sum(initial_power_load(surviving_power_nodes));
R1 = surviving_load / initial_total_load;
end
