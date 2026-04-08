function [P_actual, eta, f_m, f_e] = computeActualPowerWithDelay(P_ref, tau_m, tau_e, k_m, k_e)
%COMPUTEACTUALPOWERWITHDELAY 根据时延效率计算实际出力。

[eta, f_m, f_e] = computePowerDelayEfficiency(tau_m, tau_e, k_m, k_e);
P_actual = P_ref .* eta;
end
