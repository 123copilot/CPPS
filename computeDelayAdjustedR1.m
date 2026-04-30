function [R1_delay, delayed_served_load, surviving_load, initial_total_load, delay_penalty] = computeDelayAdjustedR1(initial_power_load, failed_power_nodes, P_actual, P_ref, phi_eff_override, surviving_load_override)
%COMPUTEDELAYADJUSTEDR1 Compute R1 with a delay/UFLS penalty on L_final.
% R1 definition (legacy):
%   R1 = (surviving_load * phi_global) / L_initial
% where phi_global = min(1, ΣP_actual/ΣP_ref) reflects delay-induced
% generator output reduction.
%
% Step 1+2 extension (supply-conservation alignment): callers may now pass
%   phi_eff_override          - effective φ already accounting for UFLS active
%                               load shedding. When provided, the actual
%                               delay_penalty becomes min(phi_global, phi_eff)
%                               so that the (1 - phi_eff)·surviving_load term
%                               is interpreted as UFLS service loss.
%   surviving_load_override   - trajectory-integrated surviving load (kept
%                               on the same time-axis as phi_eff_override),
%                               replacing the last-round snapshot of
%                               failed_power_nodes. This unifies the time
%                               aggregation between the two factors.
% Backward compatibility: when both overrides are empty/missing, behaviour
% is identical to the legacy formula. Invariant: when UFLS is disabled,
% callers should pass phi_eff_override = phi_global so the formula
% degenerates exactly to the legacy version.

if nargin < 4 || isempty(P_actual) || isempty(P_ref)
    error('P_actual and P_ref must be provided.');
end

[~, surviving_load_default, initial_total_load] = computeR1LoadRatio(initial_power_load, failed_power_nodes);

if nargin >= 6 && ~isempty(surviving_load_override)
    surviving_load = surviving_load_override;
else
    surviving_load = surviving_load_default;
end

reference_generation = sum(P_ref(:));
if reference_generation <= 0
    error('Sum of P_ref must be positive.');
end

actual_generation = sum(P_actual(:));
phi_global = min(1, actual_generation / reference_generation);

if nargin >= 5 && ~isempty(phi_eff_override)
    % Conservative combination: phi_eff already encodes UFLS over-shed
    % (phi_eff = max(0, 1 - (1 - phi_global)·(1 + γ)) ≤ phi_global when
    % γ ≥ 0). The min() guards against any numerical case where caller
    % passes phi_eff > phi_global (e.g. UFLS disabled and the two are
    % computed from slightly different aggregates).
    delay_penalty = max(0, min(phi_global, phi_eff_override));
else
    delay_penalty = phi_global;
end
delayed_served_load = surviving_load * delay_penalty;
R1_delay = delayed_served_load / initial_total_load;
end
