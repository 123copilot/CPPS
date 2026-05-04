function fig = plotCombinedR1(mean_R1, alpha_range, scenario_labels, varargin)
%PLOTCOMBINEDR1  Single-axes overlay figure: ΔR1 grouped bars and
% R1-vs-α lines drawn on the SAME axes using dual Y-axes
% (left Y = R1 lines, right Y = ΔR1 bars).
%
% This is intentionally NOT a stacked two-panel figure; the bars and
% lines share the same x-axis (α) AND the same plot box, with two
% independent vertical scales (yyaxis left / right). That is the
% standard journal convention for showing a metric value alongside
% its delta-vs-reference on a common abscissa.
%
% ΔR1 = R1^{no_delay} - R1^{scenario}     (positive bar ⇒ delay regime degrades R1)
%
% Inputs (required):
%   mean_R1         : numA × numS matrix of per-(α, scenario) mean R1.
%   alpha_range     : numA × 1 vector of α values.
%   scenario_labels : numS × 1 string/char/cellstr of scenario names. Must
%                     contain exactly one entry equal to "no_delay" (used
%                     as ΔR1 reference).
%
% Optional name/value pairs:
%   'Colors'   : numS × 3 RGB matrix (default: lines(numS)).
%   'StdR1'    : numA × numS std matrix; if non-empty, ±SD shaded bands
%                are drawn under each line on the LEFT axis.
%   'OutFile'  : char/string path for vector export (PDF). Skipped if "".
%   'FigName'  : figure Name (default 'Fig_Combined_R1').
%
% Notes:
%   * Numerical inputs are consumed read-only.
%   * Bars are slightly transparent so the lines remain readable; the
%     bar group is centered on each α tick (BarWidth=0.7).
%   * If 'no_delay' is missing the function falls back to the first column
%     as reference and emits a warning rather than erroring out.

p = inputParser;
addParameter(p, 'Colors',  [], @(x) isempty(x) || (isnumeric(x) && size(x,2) == 3));
addParameter(p, 'StdR1',   [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'OutFile', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'FigName', 'Fig_Combined_R1', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
opt = p.Results;

scenario_labels = string(scenario_labels(:));
[numA, numS]    = size(mean_R1);
assert(numel(alpha_range)     == numA, 'alpha_range length mismatch');
assert(numel(scenario_labels) == numS, 'scenario_labels length mismatch');

% --- Reference column (no_delay) ------------------------------------------
nodelay_idx = find(scenario_labels == "no_delay", 1);
if isempty(nodelay_idx)
    warning('plotCombinedR1:NoDelayMissing', ...
        'scenario_labels has no "no_delay"; using column 1 as reference.');
    nodelay_idx = 1;
end
delay_idx       = setdiff(1:numS, nodelay_idx);
delta_R1_bar    = mean_R1(:, nodelay_idx) - mean_R1(:, delay_idx);  % numA × (numS-1)
disp_labels     = strrep(cellstr(scenario_labels), '_', '\_');
delay_disp_lbls = disp_labels(delay_idx);

% --- Colors ---------------------------------------------------------------
if isempty(opt.Colors)
    colors = lines(numS);
else
    assert(size(opt.Colors, 1) == numS, 'Colors must be numS × 3');
    colors = opt.Colors;
end

% --- Figure & single-axes layout (dual Y) --------------------------------
fig = figure('Name', char(opt.FigName), 'Color', 'w', ...
    'Position', [100, 100, 1100, 620]);
ax = axes(fig);
hold(ax, 'on');
xv = alpha_range(:);

% --- RIGHT Y axis: grouped ΔR1 bars (drawn first → behind lines) --------
yyaxis(ax, 'right');
hb = bar(ax, xv, delta_R1_bar, 'grouped', 'BarWidth', 0.7);
for s = 1:numel(hb)
    hb(s).FaceColor = colors(delay_idx(s), :);
    hb(s).FaceAlpha = 0.45;          % translucent so lines stay readable
    hb(s).EdgeColor = [0.25 0.25 0.25];
    hb(s).LineWidth = 0.4;
end
yline(ax, 0, '--', 'Color', [0 0 0 0.45], 'LineWidth', 0.6, ...
    'HandleVisibility', 'off');
ylabel(ax, '\DeltaR_1 = R_1^{no\_delay} - R_1^{scenario}   (bars)', ...
    'FontSize', 10);
ax.YAxis(2).Color = [0.25 0.25 0.25];

% --- LEFT Y axis: R1-vs-α lines (drawn on top of bars) ------------------
yyaxis(ax, 'left');
hl = gobjects(numS, 1);
for s = 1:numS
    yv = mean_R1(:, s);
    if ~isempty(opt.StdR1)
        sd     = opt.StdR1(:, s);
        valid  = ~isnan(yv) & ~isnan(sd);
        if any(valid)
            xb = xv(valid);
            yb = yv(valid);
            sb = sd(valid);
            fill(ax, [xb; flipud(xb)], [yb - sb; flipud(yb + sb)], ...
                colors(s, :), 'FaceAlpha', 0.12, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
        end
    end
    hl(s) = plot(ax, xv, yv, '-o', 'LineWidth', 1.8, ...
        'Color', colors(s, :), 'MarkerFaceColor', colors(s, :), ...
        'MarkerSize', 5);
end
yline(ax, 1, ':', 'Color', [0 0 0 0.3], 'LineWidth', 0.5, ...
    'HandleVisibility', 'off');
ylim(ax, [0 1.05]);
ylabel(ax, 'R_1 (delay-adjusted)   (lines)', 'FontSize', 10);
ax.YAxis(1).Color = [0.10 0.10 0.10];

% --- Common x-axis & cosmetics ------------------------------------------
xlabel(ax, '\alpha', 'FontSize', 10);
xlim(ax, [min(xv) - 0.04, max(xv) + 0.04]);
set(ax, 'FontSize', 9, 'Box', 'on');
grid(ax, 'on');
title(ax, sprintf(['R_1 sensitivity to \\alpha across delay regimes ' ...
    '(numA=%d, numS=%d)  —  lines: R_1 (left axis); bars: \\DeltaR_1 (right axis)'], ...
    numA, numS), 'FontSize', 10, 'FontWeight', 'normal');

% --- Combined legend (lines + bars) -------------------------------------
line_legend_lbls = strcat(disp_labels, ' (R_1)');
bar_legend_lbls  = strcat(delay_disp_lbls, ' (\DeltaR_1)');
all_handles      = [hl(:); hb(:)];
all_labels       = [line_legend_lbls(:); bar_legend_lbls(:)];
lgd = legend(ax, all_handles, all_labels, 'Location', 'eastoutside', ...
    'FontSize', 8, 'Box', 'off', 'NumColumns', 1);
lgd.Title.String = 'Scenario'; %#ok<NASGU>
hold(ax, 'off');

% --- Optional vector export ---------------------------------------------
if strlength(string(opt.OutFile)) > 0
    try
        exportgraphics(fig, char(opt.OutFile), ...
            'ContentType', 'vector', 'Resolution', 600);
    catch ME
        warning('plotCombinedR1:ExportFailed', ...
            'exportgraphics failed: %s', ME.message);
    end
end
end
