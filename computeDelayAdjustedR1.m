function [R1_delay, delayed_served_load, surviving_load, initial_total_load, delay_penalty] = computeDelayAdjustedR1(initial_power_load, failed_power_nodes, P_actual, P_ref)
%COMPUTEDELAYADJUSTEDR1 Compute R1 with a simple delay penalty on L_final.
% R1 definition is preserved:
%   R1 = L_final / L_initial
% This function only adds a simple post-cascade delay effect by setting
%   L_final_delay = L_final * delay_penalty
% where delay_penalty is derived from surviving generators' actual/reference
% active power ratio under the selected delay scenario.

if nargin < 4 || isempty(P_actual) || isempty(P_ref)
    error('P_actual and P_ref must be provided.');
end

[~, surviving_load, initial_total_load] = computeR1LoadRatio(initial_power_load, failed_power_nodes);

reference_generation = sum(P_ref(:));
if reference_generation <= 0
    error('Sum of P_ref must be positive.');
end

actual_generation = sum(P_actual(:));
delay_penalty = min(1, actual_generation / reference_generation);
delayed_served_load = surviving_load * delay_penalty;
R1_delay = delayed_served_load / initial_total_load;
end
