# 消融与补充实验 · 审阅包

本文件夹是可以直接打包传给老师/审稿人的独立审阅材料，包含消融表所在的 LaTeX 源文件、
编译所需的全部支持文件、重新绘制的实验图，以及已经编译好的 PDF。

## 文件清单

| 文件 | 说明 |
| --- | --- |
| `supplementary_experiments.pdf` | **已编译好的成品 PDF（6 页），可直接浏览/传阅** |
| `supplementary_experiments.tex` | 主源文件：含消融表（Table 3）及全部补充实验表格与图 |
| `cas-dc.cls` / `cas-common.sty` / `cas-model2-names.bst` | Elsevier CAS 双栏模板支持文件（与正文 paper2 同款模板） |
| `figs/` | 全部图片（PNG，见下） |

## 重新编译方法

在本文件夹内执行（无需 bib，编译两遍即可）：

```
pdflatex supplementary_experiments.tex
pdflatex supplementary_experiments.tex
```

## 图片说明（全部按"文字/图例不与图内内容重叠"重绘）

| 文件 | 内容 | 优化点 |
| --- | --- | --- |
| `figs/fig1_combined_R1.png` | Figure 1：R1(LSR) 折线 + ΔLSR 柱状组合图 | 图例整体移到绘图区**外**（底部一行），柱状限制在下三分之一，与折线完全分离；尺寸保持 1719×969 不变 |
| `figs/fig2_combined_R3.png` | Figure 2：R3(DTE) 组合图 | 同上处理，风格与 Figure 1 统一 |
| `figs/fig3_delay_penalty_R1.png` | Figure 3：ΔR1 时延惩罚热力图 | 色条标题改为水平置顶不再竖排、格内数值按背景深浅自动黑/白切换、不重叠；尺寸保持 1679×1011 不变 |
| `figs/fig4_delay_penalty_R3.png` | Figure 4：ΔR3 热力图 | 同 Figure 3 处理 |
| `figs/fig5_ablation_curves.png` | 新增：单通道时延消融曲线（A1–A5 vs heavy/no_delay） | 消融表的图形版证据 |
| `figs/fig6_ranking_factorial.png` | 新增：(a) 缓解通道排名 (b) 时机×动作因子实验 | 数值标签全部画在柱体外侧 |

## 内容结构（与创新点的对应关系）

- **第 2 节 + Table 1 + Fig.1/2**：五档时延场景消融 —— 证明"时延内生闭环显著改变级联结果"（heavy 场景平均损失 21.2 个百分点负荷、DTE 恶化 27%）。
- **第 3 节 + Fig.3/4 + Table 2**：逐轮定位 —— 证明"时延损伤前置可预测"（第 2 轮锁定 84%、第 3 轮约 100%）。
- **第 4 节 + Table 3（消融表）+ Fig.5**：单通道消融 —— 证明"模型可将损伤分解为可操作的通道"（执行接口 55.8% / 测量接口 50.6% ≫ 网络侧 ≤1%；各通道贡献之和 125.8% > 100%，定量证明通道间耦合，支撑闭环乘性 η⁺ 形式而非加性惩罚）。
- **第 5 节 + Table 4 + Fig.6**：时机×动作因子实验 —— 证明"选对通道比选对时机重要两个数量级"（约 54 pp vs ≤1.3 pp）。
- **第 6 节 Table 5**：创新点 ↔ 证据 一览表。

所有数值均从 `5_17_delay_cascade_betweenness_200_39/` 中最新一批 MATLAB `.fig`
文件内嵌数据中直接提取（非目测读图），与现有 PNG 完全一致。
