function attacked_cyber_node = pickAttack_gudingCC_bet_8(current_info_pool, attackMode, current_betC)
% 根据攻击模式选择被攻击的信息节点

switch attackMode
    case 'random'
        attacked_cyber_node = current_info_pool(randi(numel(current_info_pool)));
        %改为
        % 随机攻击模式：从可攻击节点中随机选择一个
        %attacked_cyber_node = info_pool(local_rng.randi(numel(info_pool)));

    case 'betweenness'
        % [~, tmp] = max(betC(info_pool));
        % attacked_cyber_node = info_pool(tmp);

        %改为
        % 获取所有具有最大介数值的节点
        max_val = max(current_betC(current_info_pool));
        candidates = current_info_pool(current_betC(current_info_pool) == max_val);

        % 总是选择节点ID最小的那个，确保确定性
        attacked_cyber_node = min(candidates);

    % case 'degree'
    %     % [~, tmp] = max(degC(info_pool));
    %     % attacked_cyber_node = info_pool(tmp);
    % 
    %     %改为
    %     % 获取所有具有最大度数值的节点
    %     max_val = max(degC(current_info_pool));
    %     candidates = current_info_pool(degC(current_info_pool) == max_val);
    % 
    %     % 总是选择节点ID最小的那个，确保确定性
    %     attacked_cyber_node = min(candidates);
end
end