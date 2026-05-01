function [R1_delay, delayed_served_load, surviving_load, initial_total_load, delay_penalty] = computeDelayAdjustedR1(initial_power_load, failed_power_nodes, P_actual, P_ref, phi_eff_override, surviving_load_override)
%COMPUTEDELAYADJUSTEDR1 Compute R1 with delay penalty (and optional UFLS) on L_final.
% R1 definition is preserved:
%   R1 = L_final / L_initial
% Effective delay penalty combines two physical effects:
%   (B) Generation deficit:     phi_global = sum(P_actual)/sum(P_ref) ≤ 1
%   (C) UFLS active load shed:  phi_eff   ≤ phi_global   (over-shedding margin)
% If phi_eff_override (5th arg) is supplied (non-empty scalar in [0,1]), the
% effective penalty is min(phi_global, phi_eff_override). This avoids
% double-counting (B) and (C): both describe the same generation shortfall,
% so we take the tighter of the two as a conservative supply-conservation
% bound.
%
% If surviving_load_override (6th arg) is supplied (non-empty scalar), it is
% used in place of the topology-based surviving_load. This lets callers feed
% a trajectory-weighted surviving_load aggregated across cascade rounds
% (consistent with the trajectory-weighted phi_eff/phi_global aggregation),
% so the trial-level R1 reflects the full cascade history rather than only
% the final round's snapshot.
%
% Backward compatibility: when both optional args are omitted or empty, the
% function behaves identically to its 4-arg form.

if nargin < 4 || isempty(P_actual) || isempty(P_ref)
    error('P_actual and P_ref must be provided.');
end
if nargin < 5
    phi_eff_override = [];
end
if nargin < 6
    surviving_load_override = [];
end

[~, surviving_load, initial_total_load] = computeR1LoadRatio(initial_power_load, failed_power_nodes);

reference_generation = sum(P_ref(:));
if reference_generation <= 0
    error('Sum of P_ref must be positive.');
end

actual_generation = sum(P_actual(:));
phi_global = min(1, actual_generation / reference_generation);

if ~isempty(phi_eff_override)
    phi_eff_val = max(0, min(1, phi_eff_override));
    delay_penalty = min(phi_global, phi_eff_val);
else
    delay_penalty = phi_global;
end

if ~isempty(surviving_load_override)
    surviving_load_used = max(0, surviving_load_override);
else
    surviving_load_used = surviving_load;
end

delayed_served_load = surviving_load_used * delay_penalty;
R1_delay = delayed_served_load / initial_total_load;
end
