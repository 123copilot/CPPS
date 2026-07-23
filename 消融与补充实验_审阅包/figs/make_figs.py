#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Regenerate all supplementary-experiment figures cleanly (no text overlap)."""
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap

D = json.load(open('figdata.json'))
OUT = './'

plt.rcParams.update({
    'font.size': 15, 'axes.titlesize': 17, 'axes.labelsize': 16,
    'xtick.labelsize': 14, 'ytick.labelsize': 14, 'legend.fontsize': 13,
    'axes.grid': True, 'grid.alpha': 0.3, 'grid.linestyle': '--',
    'axes.spines.top': False, 'axes.spines.right': True,
    'figure.facecolor': 'white', 'savefig.facecolor': 'white',
})

COL = {'no_delay': '#0072BD', 'light': '#D95319', 'baseline': '#EDB120',
       'medium': '#7E2F8E', 'heavy': '#77AC30'}
ORDER = ['no_delay', 'light', 'baseline', 'medium', 'heavy']
alpha = np.array(D['alpha'])


def combined(lines, bars, dlab, ylab, title, fname, wpx, hpx, better='', tag='LSR', dtag=r'$\Delta$LSR'):
    """Line+bar dual axis; legend fully OUTSIDE the axes (below), nothing overlaps."""
    dpi = 100
    fig, ax1 = plt.subplots(figsize=(wpx / dpi, hpx / dpi), dpi=dpi)
    # leave a band at the bottom for the two-row legend
    fig.subplots_adjust(left=0.065, right=0.935, top=0.90, bottom=0.20)
    ax2 = ax1.twinx()
    ax2.grid(False)

    barsc = ['light', 'baseline', 'medium', 'heavy']
    w = 0.018
    for i, k in enumerate(barsc):
        ax2.bar(alpha + (i - 1.5) * w, bars[k], width=w * 0.9,
                color=COL[k], alpha=0.45, edgecolor='white', linewidth=0.4,
                label=f'{k} ({dtag})', zorder=2)
    for k in ORDER:
        ax1.plot(alpha, lines[k], '-o', color=COL[k], lw=2.4, ms=7,
                 markerfacecolor='white', markeredgewidth=1.8,
                 label=f'{k} ({tag})', zorder=4)

    ax1.set_xlabel(r'Tolerance parameter $\alpha$')
    ax1.set_ylabel(f'{ylab}' + (f'  ({better})' if better else '') + '   (lines)')
    ax2.set_ylabel(f'{dlab}   (bars)')
    ax1.set_xticks(alpha)
    ax1.set_xlim(0.03, 1.07)
    bmax = max(max(v) for v in bars.values())
    ax2.set_ylim(0, bmax * 2.6)          # bars stay in lower third, never touch lines
    ax1.set_title(title, pad=14)
    h1, l1 = ax1.get_legend_handles_labels()
    h2, l2 = ax2.get_legend_handles_labels()
    fig.legend(h1 + h2, l1 + l2, loc='lower center', ncol=5, frameon=False,
               bbox_to_anchor=(0.5, 0.01), columnspacing=1.2, handletextpad=0.5)
    fig.savefig(OUT + fname, dpi=dpi)
    plt.close(fig)


combined(D['R1_lines'], D['R1_bars'],
         r'$\Delta$LSR $= R_1^{\mathrm{no\_delay}}-R_1^{\mathrm{scenario}}$',
         r'Load Service Ratio $R_1$ (LSR)',
         r'Load Service Ratio $R_1$ sensitivity to $\alpha$ across delay regimes'
         '  (numA = 10, numS = 5)',
         'fig1_combined_R1.png', 1719, 969, tag='LSR', dtag=r'$\Delta$LSR')

combined(D['R3_lines'], D['R3_bars'],
         r'$\Delta$DTE $= R_3^{\mathrm{scenario}}-R_3^{\mathrm{no\_delay}}$',
         r'Dispatch Tracking Error $R_3$ (DTE)',
         r'Dispatch Tracking Error $R_3$ sensitivity to $\alpha$ across delay regimes'
         '  (numA = 10, numS = 5)',
         'fig2_combined_R3.png', 1719, 969, better='smaller is better', tag='DTE', dtag=r'$\Delta$DTE')


def heatmap(M, cbar_lab, title, fname, wpx, hpx, annot_thr):
    dpi = 100
    M = np.array(M)
    fig, ax = plt.subplots(figsize=(wpx / dpi, hpx / dpi), dpi=dpi)
    fig.subplots_adjust(left=0.07, right=0.98, top=0.86, bottom=0.10)
    cmap = LinearSegmentedColormap.from_list(
        'pen', ['#FFFFF0', '#FFE08C', '#F5A623', '#D93025', '#7B0D1E'])
    im = ax.imshow(M, aspect='auto', cmap=cmap, origin='lower',
                   extent=[0.5, 11.5, -0.05, 1.05])
    ax.set_yticks(np.arange(0, 1.05, 0.1))
    ax.set_xticks(np.arange(1, 12))
    ax.set_xlabel('Cascade round $r$')
    ax.set_ylabel(r'Tolerance parameter $\alpha$')
    ax.grid(False)
    # readable in-cell annotations, colour switched by background darkness
    vmax = M.max()
    for i in range(M.shape[0]):
        for j in range(M.shape[1]):
            v = M[i, j]
            ax.text(j + 1, i * 0.1, f'{v:.2f}'.lstrip('0') if v < 1 else f'{v:.2f}',
                    ha='center', va='center', fontsize=11,
                    color='white' if v > annot_thr * vmax else '#333333')
    cb = fig.colorbar(im, ax=ax, pad=0.012)
    cb.ax.set_title(cbar_lab, fontsize=13, pad=10, loc='left')
    ax.set_title(title, pad=14)
    fig.savefig(OUT + fname, dpi=dpi)
    plt.close(fig)


heatmap(D['heat_dR1'],
        r'$\Delta R_1$',
        r'Cumulative delay penalty  $\Delta R_1(\alpha,r) = R_1^{\mathrm{no\_delay}} - R_1^{\mathrm{heavy}}$'
        '  per cascade round',
        'fig3_delay_penalty_R1.png', 1679, 1011, 0.55)

heatmap(D['heat_dR3'],
        r'$\Delta R_3$',
        r'Cumulative delay penalty  $\Delta R_3(\alpha,r) = R_3^{\mathrm{heavy}} - R_3^{\mathrm{no\_delay}}$'
        '  per cascade round',
        'fig4_delay_penalty_R3.png', 1679, 1011, 0.55)

# ---------------- Fig 5: single-channel delay ablation curves ----------------
dpi = 100
fig, ax = plt.subplots(figsize=(17.19, 9.0), dpi=dpi)
fig.subplots_adjust(left=0.065, right=0.985, top=0.90, bottom=0.19)
sa = np.array(D['sens_alpha'])
acol = {'no_delay': '#0072BD', 'heavy': '#77AC30', 'A1': '#A2142F',
        'A2': '#D95319', 'A3': '#EDB120', 'A4': '#7E2F8E', 'A5': '#4DBEEE'}
lbl = {'no_delay': 'no_delay (all channels off)', 'heavy': 'heavy (all channels on)',
       'A1': 'A1: PDC upgrade', 'A2': 'A2: fast measurement',
       'A3': 'A3: fast execution', 'A4': 'A4: PRP redundancy',
       'A5': 'A5: critical-window relief'}
sty = {'no_delay': (':', 's'), 'heavy': ('--', 'v')}
for k in ['no_delay', 'heavy', 'A3', 'A2', 'A5', 'A1', 'A4']:
    y = D['sens'][k] if k in D['sens'] else None
    ls, mk = sty.get(k, ('-', 'o'))
    ax.plot(sa, D['sens'][k], ls, marker=mk, color=acol[k], lw=2.6, ms=7.5,
            markerfacecolor='white', markeredgewidth=1.8, label=lbl[k])
ax.set_xlabel(r'Tolerance parameter $\alpha$')
ax.set_ylabel(r'Load Service Ratio $R_1$ (delay-adjusted mean)')
ax.set_xticks(sa)
ax.set_title(r'Single-channel delay ablation: switching one delay channel off in the heavy regime'
             '  (200 samples)', pad=14)
fig.legend(loc='lower center', ncol=4, frameon=False, bbox_to_anchor=(0.5, 0.005))
fig.savefig(OUT + 'fig5_ablation_curves.png', dpi=dpi)
plt.close(fig)

# ---------------- Fig 6: ranking + factorial, two panels ----------------
fig, (axA, axB) = plt.subplots(1, 2, figsize=(17.19, 7.2), dpi=dpi,
                               gridspec_kw={'width_ratios': [1.15, 1]})
fig.subplots_adjust(left=0.16, right=0.975, top=0.86, bottom=0.13, wspace=0.42)

rk = D['ranking']
names = {'A3_exec_fast': 'A3: fast execution', 'A2_meas_fast': 'A2: fast measurement',
         'A5_crit_window': 'A5: critical-window relief', 'A1_PDC_upgrade': 'A1: PDC upgrade',
         'A4_PRP_redundancy': 'A4: PRP redundancy'}
labs = [names[x] for x in rk['labels']][::-1]
vals = rk['values'][::-1]
bars = axA.barh(labs, vals, color=['#B8B8B8', '#B8B8B8', '#4DBEEE', '#D95319', '#EDB120'],
                edgecolor='white')
for b, v in zip(bars, vals):
    axA.text(v + 1.1, b.get_y() + b.get_height() / 2, f'{v:.1f}%',
             va='center', ha='left', fontsize=14, color='#333333')
axA.set_xlim(0, 68)
axA.set_xlabel(r'Mean LSR recovery (%),  $\alpha \geq 0.3$')
axA.set_title('(a) Mitigation-channel ranking', pad=12)
axA.grid(axis='x', alpha=0.3, linestyle='--'); axA.grid(axis='y', visible=False)

f8 = D['fig8']
cl = ['#EDB120', '#7E2F8E', '#EDB120', '#7E2F8E']
xt = ['C1\nbest time\n+ best A3', 'C2\nbest time\n+ worst A4',
      'C3\nworst time\n+ best A3', 'C4\nworst time\n+ worst A4']
bars = axB.bar(range(4), f8['values'], color=cl, edgecolor='white', width=0.62)
for i, v in enumerate(f8['values']):
    axB.text(i, v + 1.4, f'{v:.1f}%', ha='center', va='bottom', fontsize=14, color='#333333')
axB.set_xticks(range(4)); axB.set_xticklabels(xt, fontsize=12.5)
axB.set_ylim(0, 68)
axB.set_ylabel('Mean LSR recovery (%)')
axB.set_title(r'(b) Timing $\times$ action factorial', pad=12)
axB.grid(axis='y', alpha=0.3, linestyle='--'); axB.grid(axis='x', visible=False)
fig.savefig(OUT + 'fig6_ranking_factorial.png', dpi=dpi)
plt.close(fig)

print('done')
