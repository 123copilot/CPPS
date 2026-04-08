function [R3, relative_deviation] = computeR3Deviation(P_actual, P_ref)
%COMPUTER3DEVIATION 计算关键参数偏离度 R3。
%
% R3 = sqrt((1 / N) * sum(((P_actual - P_ref) ./ P_ref).^2))

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
R3 = sqrt(mean(relative_deviation .^ 2));
end
