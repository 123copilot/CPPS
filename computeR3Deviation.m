function [R3, relative_deviation] = computeR3Deviation(P_actual, P_ref)
%COMPUTER3DEVIATION 计算关键参数偏离度 R3（容量加权 NRMSE）。
%
% R3 = sqrt( sum( P_ref .* ((P_actual - P_ref) ./ P_ref).^2 ) / sum(P_ref) )
%    = sqrt( sum( (P_actual - P_ref).^2 ./ P_ref ) / sum(P_ref) )
%
% 与 NERC BAL-001-2 / Jaleeli 1992 在线机组 NRMSE 口径一致：
% 大机组的相对偏差获得更大权重，反映"整体功率偏差规模"。
% 调用方需保证传入的 P_ref 为"在场机组"参考出力（abs > eps），
% 这样 P_ref==0 守卫退化为空检查。

P_actual = P_actual(:);
P_ref = P_ref(:);

if numel(P_actual) ~= numel(P_ref)
    error('P_actual 和 P_ref 的长度必须一致。');
end

if isempty(P_ref)
    error('P_ref 不能为空。');
end

if any(P_ref == 0)
    error('P_ref 中不能包含 0，否则 R3 公式分母无定义。');
end

relative_deviation = (P_actual - P_ref) ./ P_ref;
total_ref = sum(P_ref);
if total_ref <= 0
    error('sum(P_ref) 必须为正，否则容量加权 NRMSE 无定义。');
end
R3 = sqrt( sum( P_ref .* relative_deviation .^ 2 ) / total_ref );
end
