function cc = pickCC_MSIS_myself(num_cc,msis_myself)
  
    % 按介数中心性从大到小排序
    [~, sorted_indices] = sort(msis_myself, 'descend');
    
    % 选择前num_cc个节点作为控制中心
    cc = sorted_indices(1:num_cc);
    
    % 对结果排序以确保输出一致性
    cc = sort(cc);
end
