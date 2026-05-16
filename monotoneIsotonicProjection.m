function y = monotoneIsotonicProjection(x, direction)
%MONOTONEISOTONICPROJECTION  Pool-Adjacent-Violators isotonic projection.
%
%   y = monotoneIsotonicProjection(x)               % default 'decreasing'
%   y = monotoneIsotonicProjection(x, 'decreasing') % y(1) >= y(2) >= ... >= y(n)
%   y = monotoneIsotonicProjection(x, 'increasing') % y(1) <= y(2) <= ... <= y(n)
%
%   Returns the L2 projection of input vector x onto the monotone cone.
%   That is, y minimizes sum((y - x).^2) subject to the monotonicity
%   constraint. This is the constrained maximum-likelihood estimator
%   under the prior "the underlying signal is monotone in the index".
%
%   Algorithm: classical Pool-Adjacent-Violators Algorithm (PAVA)
%     - Barlow, Bartholomew, Bremner, Brunk (1972), Statistical Inference
%       Under Order Restrictions, Wiley.
%     - Robertson, Wright, Dykstra (1988), Order Restricted Statistical
%       Inference, Wiley, §1.2.
%
%   Use case in this repository: ΔLSR(α) / ΔDTE(α) bars in
%   plotCombinedR1/plotCombinedR3 carry a strong physical prior that the
%   delay-induced damage decreases monotonically with the capacity-margin
%   coefficient α. Under finite Monte-Carlo samples with common random
%   numbers (CRN), the empirical mean ΔLSR(α) exhibits residual noise
%   that can locally violate this prior. PAVA returns the unique
%   monotone-decreasing estimator closest to the empirical means in
%   L2 norm, which is provably optimal under the monotonicity prior
%   (not a cosmetic smoothing).
%
%   Input x may contain NaN; NaN entries are passed through unchanged
%   and the algorithm runs on the contiguous non-NaN segments
%   independently (so a missing α-grid point does not pollute neighbors).

if nargin < 2 || isempty(direction)
    direction = 'decreasing';
end

x = x(:);
n = numel(x);
y = x;
if n <= 1
    return;
end

switch lower(direction)
    case 'decreasing'
        sign_flip = -1;     % negate input → run increasing PAVA → negate back
    case 'increasing'
        sign_flip = 1;
    otherwise
        error('monotoneIsotonicProjection:invalidDirection', ...
            'direction must be ''decreasing'' or ''increasing'', got ''%s''.', direction);
end

valid = ~isnan(x);
if ~any(valid)
    return;
end

% Operate on contiguous valid segments so NaN gaps do not pool with data.
seg_start = [];
in_seg = false;
for i = 1:n
    if valid(i) && ~in_seg
        seg_start = i;
        in_seg = true;
    elseif (~valid(i) && in_seg) || (i == n && in_seg)
        seg_end = i;
        if ~valid(i)
            seg_end = i - 1;
        end
        % Run PAVA on x(seg_start:seg_end) for 'increasing' constraint
        % (using sign_flip to encode 'decreasing').
        xs = sign_flip * x(seg_start:seg_end);
        ys = pava_increasing(xs);
        y(seg_start:seg_end) = sign_flip * ys;
        in_seg = false;
    end
end
end


function y = pava_increasing(x)
%PAVA_INCREASING  Classical pool-adjacent-violators for monotone-INCREASING fit.
%   Returns y minimizing sum((y - x).^2) s.t. y(1) <= y(2) <= ... <= y(n).
%   All weights are uniform (= 1) since the inputs are sample means with
%   equal numA*numS denominator per α-row at the call sites.
x = x(:);
n = numel(x);
if n <= 1
    y = x;
    return;
end

% Block representation: each active block stores its mean, its count of
% original samples (= weight), and the start/end indices into the output.
block_mean   = x;
block_weight = ones(n, 1);
block_start  = (1:n)';
block_end    = (1:n)';
k = n;     % number of active blocks

i = 1;
while i < k
    if block_mean(i) > block_mean(i + 1)
        % Violation: merge block i and block i+1.
        total_w = block_weight(i) + block_weight(i + 1);
        merged_mean = (block_mean(i) * block_weight(i) + ...
                       block_mean(i + 1) * block_weight(i + 1)) / total_w;
        block_mean(i)   = merged_mean;
        block_weight(i) = total_w;
        block_end(i)    = block_end(i + 1);
        % Remove block i+1 by left-shifting tail.
        block_mean(i+1:k-1)   = block_mean(i+2:k);
        block_weight(i+1:k-1) = block_weight(i+2:k);
        block_start(i+1:k-1)  = block_start(i+2:k);
        block_end(i+1:k-1)    = block_end(i+2:k);
        k = k - 1;
        % Step back to recheck against the new left neighbor.
        if i > 1
            i = i - 1;
        end
    else
        i = i + 1;
    end
end

% Expand active blocks back to per-index output.
y = zeros(n, 1);
for j = 1:k
    y(block_start(j):block_end(j)) = block_mean(j);
end
end
