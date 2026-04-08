function [eta, f_m, f_e] = computePowerDelayEfficiency(tau_m, tau_e, k_m, k_e)
%COMPUTEPOWERDELAYEFFICIENCY 计算测量时延、执行时延与综合时延效率。

if any(tau_m(:) < 0) || any(tau_e(:) < 0)
    error('tau_m 和 tau_e 不能为负数。');
end

if any(k_m(:) < 0) || any(k_e(:) < 0)
    error('k_m 和 k_e 不能为负数。');
end

f_m = 1 - k_m .* tau_m;
f_e = 1 - k_e .* tau_e;
eta = f_m .* f_e;
end
