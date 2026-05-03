function fig = plotCombinedR3(mean_R3, alpha_range, scenario_labels, varargin)
%PLOTCOMBINEDR3  Nature-style stacked-panel figure: ΔR3 bar (top) +
% R3-vs-α lines (bottom), sharing a single x-axis (α).
%
% Mirror of plotCombinedR1, but adapted to R3's "smaller-is-better"
% semantics. Whereas R1 uses ΔR1 = R1^{no_delay} - R1^{scenario}
% (a positive bar means the delay regime degraded R1), here we use
%
%       ΔR3 = R3^{scenario} - R3^{no_delay}
%
% so that a positive bar still means the delay regime is *worse* than
% the ideal no-delay reference. This keeps the visual reading rule
% identical across the R1 and R3 combined figures: bars rising above
% zero ⇒ delays hurt the metric.
%
% Inputs (required):
%   mean_R3         : numA × numS matrix of per-(α, scenario) mean R3.
%   alpha_range     : numA × 1 vector of α values.
%   scenario_labels : numS × 1 string/char/cellstr of scenario names. Must
%                     contain exactly one entry equal to "no_delay" (used
%                     as ΔR3 reference).
%
% Optional name/value pairs:
%   'Colors'   : numS × 3 RGB matrix (default: lines(numS)).
%   'StdR3'    : numA × numS std matrix; if non-empty, ±SD shaded bands
%                are drawn under each line in the bottom panel.
%   'OutFile'  : char/string path for vector export (PDF). Skipped if "".
%   'FigName'  : figure Name (default 'Fig_Combined_R3').
%   'YLim'     : 1×2 ylim for the bottom (R3 line) panel; default 'auto'.
%
% Notes:
%   * Numerical inputs are consumed read-only; this function performs no
%     aggregation and never mutates upstream data.
%   * Two visually-aligned tiles share the α axis via linkaxes; only the
%     bottom tile renders α tick labels (Nature stacked-panel convention).
%   * If 'no_delay' is missing the function falls back to the first column
%     as reference and emits a warning rather than erroring out.

p = inputParser;
addParameter(p, 'Colors',  [], @(x) isempty(x) || (isnumeric(x) && size(x,2) == 3));
addParameter(p, 'StdR3',   [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'OutFile', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'FigName', 'Fig_Combined_R3', @(x) ischar(x) || isstring(x));
addParameter(p, 'YLim',    [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
parse(p, varargin{:});
opt = p.Results;

scenario_labels = string(scenario_labels(:));
[numA, numS]    = size(mean_R3);
assert(numel(alpha_range)     == numA, 'alpha_range length mismatch');
assert(numel(scenario_labels) == numS, 'scenario_labels length mismatch');

% --- Reference column (no_delay) ------------------------------------------
nodelay_idx = find(scenario_labels == "no_delay", 1);
if isempty(nodelay_idx)
    warning('plotCombinedR3:NoDelayMissing', ...
        'scenario_labels has no "no_delay"; using column 1 as reference.');
    nodelay_idx = 1;
end
delay_idx       = setdiff(1:numS, nodelay_idx);
% NOTE: smaller R3 is better, so we flip the sign vs ΔR1 to keep
% "positive bar = delay scenario performs worse than no_delay".
delta_R3_bar    = mean_R3(:, delay_idx) - mean_R3(:, nodelay_idx);  % numA × (numS-1)
disp_labels     = strrep(cellstr(scenario_labels), '_', '\_');
delay_disp_lbls = disp_labels(delay_idx); %#ok<NASGU>

% --- Colors ---------------------------------------------------------------
if isempty(opt.Colors)
    colors = lines(numS);
else
    assert(size(opt.Colors, 1) == numS, 'Colors must be numS × 3');
    colors = opt.Colors;
end

% --- Figure & layout (top:bottom = 2:3, Nature-style) --------------------
fig = figure('Name', char(opt.FigName), 'Color', 'w', ...
    'Position', [100, 100, 1100, 720]);
tl  = tiledlayout(fig, 5, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Top panel: grouped ΔR3 bars -----------------------------------------
ax_top = nexttile(tl, 1, [2 1]);
hb     = bar(ax_top, alpha_range(:), delta_R3_bar, 'grouped', ...
             'BarWidth', 0.85);
hold(ax_top, 'on');
for s = 1:numel(hb)
    hb(s).FaceColor = colors(delay_idx(s), :);
    hb(s).FaceAlpha = 0.85;
    hb(s).EdgeColor = [0.2 0.2 0.2];
    hb(s).LineWidth = 0.4;
end
yline(ax_top, 0, '--', 'Color', [0 0 0 0.5], 'LineWidth', 0.5);
ylabel(ax_top, '\DeltaR_3 = R_3^{scenario} - R_3^{no\_delay}', 'FontSize', 9);
set(ax_top, 'FontSize', 8, 'XTickLabel', [], 'Box', 'on');
grid(ax_top, 'on');
title(ax_top, sprintf('R_3 sensitivity to \\alpha across delay regimes (numA=%d, numS=%d) — smaller R_3 is better; positive \\DeltaR_3 means delay scenario is worse than no\\_delay', ...
    numA, numS), 'FontSize', 10, 'FontWeight', 'normal');
hold(ax_top, 'off');

% --- Bottom panel: R3 vs α lines (optionally with ±SD shading) -----------
ax_bot = nexttile(tl, 3, [3 1]);
hold(ax_bot, 'on');
hl = gobjects(numS, 1);
xv = alpha_range(:);
for s = 1:numS
    yv = mean_R3(:, s);
    if ~isempty(opt.StdR3)
        sd     = opt.StdR3(:, s);
        valid  = ~isnan(yv) & ~isnan(sd);
        if any(valid)
            xb = xv(valid);
            yb = yv(valid);
            sb = sd(valid);
            fill(ax_bot, [xb; flipud(xb)], [yb - sb; flipud(yb + sb)], ...
                colors(s, :), 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
        end
    end
    hl(s) = plot(ax_bot, xv, yv, '-o', 'LineWidth', 1.5, ...
        'Color', colors(s, :), 'MarkerFaceColor', colors(s, :), ...
        'MarkerSize', 5);
end
xlabel(ax_bot, '\alpha', 'FontSize', 9);
ylabel(ax_bot, 'R_3 (cascade deviation)', 'FontSize', 9);
set(ax_bot, 'FontSize', 8, 'Box', 'on');
grid(ax_bot, 'on');
if ~isempty(opt.YLim)
    ylim(ax_bot, opt.YLim);
end
lgd = legend(ax_bot, hl, disp_labels, 'Location', 'eastoutside', ...
    'FontSize', 8, 'Box', 'off');
lgd.Title.String = 'Scenario'; %#ok<NASGU>
hold(ax_bot, 'off');

% --- Share x-axis ---------------------------------------------------------
linkaxes([ax_top, ax_bot], 'x');
xlim(ax_bot, [min(xv) - 0.02, max(xv) + 0.02]);

% --- Optional vector export ----------------------------------------------
if strlength(string(opt.OutFile)) > 0
    try
        exportgraphics(fig, char(opt.OutFile), ...
            'ContentType', 'vector', 'Resolution', 600);
    catch ME
        warning('plotCombinedR3:ExportFailed', ...
            'exportgraphics failed: %s', ME.message);
    end
end
end
