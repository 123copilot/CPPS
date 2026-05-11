function fig = plotCombinedR3(mean_R3, alpha_range, scenario_labels, varargin)
%PLOTCOMBINEDR3  Single-axes overlay figure: ΔR3 grouped bars and
% R3-vs-α lines drawn on the SAME axes using dual Y-axes
% (left Y = R3 lines, right Y = ΔR3 bars).
%
% Mirror of plotCombinedR1, but adapted to R3's "smaller-is-better"
% semantics. Whereas R1 uses ΔR1 = R1^{no_delay} - R1^{scenario}
% (positive bar = delay regime hurt R1), here we use
%
%       ΔR3 = R3^{scenario} - R3^{no_delay}
%
% so a positive bar still means the delay regime is *worse* than the
% ideal no-delay reference. The visual reading rule is therefore
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
%                are drawn under each line on the LEFT axis.
%   'OutFile'  : char/string path for vector export (PDF). Skipped if "".
%   'FigName'  : figure Name (default 'Fig_Combined_R3').
%   'YLim'     : 1×2 ylim for the LEFT (R3 line) axis; default 'auto'.
%
% Notes:
%   * Numerical inputs are consumed read-only.
%   * Bars are slightly transparent so the lines remain readable; the
%     bar group is centered on each α tick (BarWidth=0.7).
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

% --- RIGHT Y axis: grouped ΔR3 bars (drawn first → behind lines) --------
yyaxis(ax, 'right');
hb = bar(ax, xv, delta_R3_bar, 'grouped', 'BarWidth', 0.7);
for s = 1:numel(hb)
    hb(s).FaceColor = colors(delay_idx(s), :);
    hb(s).FaceAlpha = 0.45;          % translucent so lines stay readable
    hb(s).EdgeColor = [0.25 0.25 0.25];
    hb(s).LineWidth = 0.4;
end
yline(ax, 0, '--', 'Color', [0 0 0 0.45], 'LineWidth', 0.6, ...
    'HandleVisibility', 'off');
ylabel(ax, '\DeltaDTE = R_3^{scenario} - R_3^{no\_delay}   (bars)', ...
    'FontSize', 10);
ax.YAxis(2).Color = [0.25 0.25 0.25];

% --- LEFT Y axis: R3-vs-α lines (drawn on top of bars) ------------------
yyaxis(ax, 'left');
hl = gobjects(numS, 1);
for s = 1:numS
    yv = mean_R3(:, s);
    if ~isempty(opt.StdR3)
        sd     = opt.StdR3(:, s);
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
ylabel(ax, 'Dispatch Tracking Error R_3 (DTE; smaller is better)   (lines)', 'FontSize', 10);
if ~isempty(opt.YLim)
    ylim(ax, opt.YLim);
end
ax.YAxis(1).Color = [0.10 0.10 0.10];

% --- Common x-axis & cosmetics ------------------------------------------
xlabel(ax, '\alpha', 'FontSize', 10);
xlim(ax, [min(xv) - 0.04, max(xv) + 0.04]);
set(ax, 'FontSize', 9, 'Box', 'on');
grid(ax, 'on');
title(ax, sprintf(['Dispatch Tracking Error R_3 (DTE) sensitivity to \\alpha across delay regimes ' ...
    '(numA=%d, numS=%d)  —  smaller DTE is better; ' ...
    'lines: DTE (left axis); bars: \\DeltaDTE (right axis)'], ...
    numA, numS), 'FontSize', 10, 'FontWeight', 'normal');

% --- Combined legend (lines + bars) -------------------------------------
line_legend_lbls = strcat(disp_labels, ' (DTE)');
bar_legend_lbls  = strcat(delay_disp_lbls, ' (\DeltaDTE)');
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
        warning('plotCombinedR3:ExportFailed', ...
            'exportgraphics failed: %s', ME.message);
    end
end
end
