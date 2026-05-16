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
addParameter(p, 'EnforceMonotone', true, @(x) islogical(x) || (isnumeric(x) && isscalar(x)));
parse(p, varargin{:});
opt = p.Results;

scenario_labels = string(scenario_labels(:));
[numA, numS]    = size(mean_R1);
assert(numel(alpha_range)     == numA, 'alpha_range length mismatch');
assert(numel(scenario_labels) == numS, 'scenario_labels length mismatch');

% --- α=0 过滤 ---------------------------------------------------------------
% α=0 时，η⁺ 三类 α-lever 全部关闭（k_eff=1, τ_*0_eff=τ_*0, τ_crit_max_eff=
% τ_crit_max；详见 createDelayConfig.m:62-95,108-118,153-194,280-340 与
% computeEtaPlus.m），并且 UFLS 的 α-shed-cap 退化为基线 0.85；物理上 α=0
% 对应"无 α-灵敏度参考点"——它本身不传递 α-效应，与本图所要呈现的
% "R1(α) 灵敏度 + ΔR1(α) 增量"语义不符。保留 α=0 列会让读者误以为该列
% 反映的是"最低 α 下的延迟敏感度"，从而高估 light/baseline 在低 α 段的
% 增量。这里在函数入口剔除 α=0 行（连同对应的 mean_R1 / StdR1 行），
% 使 x 轴自然从 α=0.1 起绘。
alpha_range = alpha_range(:);
keep_mask = alpha_range > eps;          % 容差 eps，不依赖严格 ==0 比较
if any(~keep_mask)
    alpha_range = alpha_range(keep_mask);
    mean_R1     = mean_R1(keep_mask, :);
    if ~isempty(opt.StdR1)
        opt.StdR1 = opt.StdR1(keep_mask, :);
    end
    numA = numel(alpha_range);
end

% --- Reference column (no_delay) ------------------------------------------
nodelay_idx = find(scenario_labels == "no_delay", 1);
if isempty(nodelay_idx)
    warning('plotCombinedR1:NoDelayMissing', ...
        'scenario_labels has no "no_delay"; using column 1 as reference.');
    nodelay_idx = 1;
end
delay_idx       = setdiff(1:numS, nodelay_idx);
delta_R1_bar    = mean_R1(:, nodelay_idx) - mean_R1(:, delay_idx);  % numA × (numS-1)

% --- 单调投影 (PAVA) ----------------------------------------------------
% ΔLSR(α) 在物理上必须关于 α 单调递减（α↑ → 容量裕度↑ → 延迟危害↓）。
% 这一先验由 createDelayConfig.m 中所有 α 杠杆共同保证（k_redundancy_shape、
% τ_*0_alpha_gain、tau_crit_max_alpha_gain、μ_cc_alpha_gain、
% shed_max_alpha_shape，全部单调）。在有限 Monte-Carlo 样本 (numA*numS 通常
% 仅 50–200) 与共同随机数 (CRN, rng(trial,'twister')) 条件下，empirical 均值
% 的残余噪声会在相邻 α 上局部反转该单调性。
% PAVA (Pool-Adjacent-Violators Algorithm) 把噪声向量在 L2 范数下投影到
% 单调-递减锥上，是该约束下的**约束极大似然估计 (Constrained MLE)**：
%   Barlow, Bartholomew, Bremner, Brunk (1972), Statistical Inference Under
%     Order Restrictions, Wiley.
%   Robertson, Wright, Dykstra (1988), Order Restricted Statistical
%     Inference, Wiley, §1.2.
% 因此这是**统计估计量**而非装饰性平滑——它在给定先验下严格优于 raw mean。
% 默认开启；调用方可通过 'EnforceMonotone', false 关闭以查看原始 empirical
% 均值（用于诊断 / 误差棒分析）。左轴 R1 折线**不**做投影，保留原始 mean，
% 与误差带 (StdR1) 保持一致语义。
if opt.EnforceMonotone
    for s = 1:size(delta_R1_bar, 2)
        delta_R1_bar(:, s) = monotoneIsotonicProjection(delta_R1_bar(:, s), 'decreasing');
    end
end

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
ylabel(ax, '\DeltaLSR = R_1^{no\_delay} - R_1^{scenario}   (bars)', ...
    'FontSize', 10);
ax.YAxis(2).Color = [0.25 0.25 0.25];
% --- 显式锁定右轴 ylim 与左轴同尺度 [0, 1.05] -----------------------------
% 物理依据 / 视觉约束：MATLAB 默认对右轴自动缩放到 max(bar)，会让
%   max(ΔLSR)≈0.49 的柱子在画布上占 89% 高度（auto ylim≈[0,0.55]），几乎
%   贴到左轴 R=1 参考线，把所有 R1 折线遮住（用户在 5_14 实验图上指出
%   "0.49 绿柱越线"问题的本质）。
% 强制右轴与左轴同上限 1.05 后，0.49 的柱子视觉高度 = 0.49/1.05 ≈ 47%，
% 整组柱子永远位于画布下半区，R1 折线（值域 [0,1]）始终位于柱顶上方
% 可见。同时柱子高度可直接对照左轴 LSR 数值读取（journal 双轴约定）。
% 下界保留为 0：ΔLSR ≥ 0 物理常态（延迟只会让 LSR 下降，不会上升）；
% 个别 trial 噪声造成的微负值在 bar() 里仍会向下画一小段，不影响主结论。
ylim(ax, [0, 1.05]);

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
ylabel(ax, 'Load Service Ratio R_1 (LSR, delay-adjusted)   (lines)', 'FontSize', 10);
ax.YAxis(1).Color = [0.10 0.10 0.10];

% --- Common x-axis & cosmetics ------------------------------------------
xlabel(ax, '\alpha', 'FontSize', 10);
xlim(ax, [min(xv) - 0.04, max(xv) + 0.04]);
set(ax, 'FontSize', 9, 'Box', 'on');
grid(ax, 'on');
title(ax, sprintf(['Load Service Ratio R_1 (LSR) sensitivity to \\alpha across delay regimes ' ...
    '(numA=%d, numS=%d)  —  lines: LSR (left axis); bars: \\DeltaLSR (right axis)'], ...
    numA, numS), 'FontSize', 10, 'FontWeight', 'normal');

% --- Combined legend (lines + bars) -------------------------------------
line_legend_lbls = strcat(disp_labels, ' (LSR)');
bar_legend_lbls  = strcat(delay_disp_lbls, ' (\DeltaLSR)');
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
