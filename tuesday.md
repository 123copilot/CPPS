通信层在用 BA 网络建模后，包含的两类节点控制中心 CC 与非控制中心 NCC，他们之间的通信时延的具体定义如下：

由CC到NCC的时延为下行时延

由NCC到CC的时延为上行时延

上行时延与下行时延都包含三类时延，串口时延，传播时延，服务时延。为了区分，在服务时延这一部分做简单的差异化。

# 1.链路级双向时延分解

对于任意两个节点 $u$ 和 $v$ ，定义：

从 $u$ 到 $v$ 的单向时延：

$$
T _ {u \rightarrow v} = T _ {\text {s e r i a l}} (u, v) + T _ {\text {p r o p}} (u, v) + T _ {\text {s e r v i c e}} (u \rightarrow v)
$$

从 $v$ 到 $u$ 的单向时延：

$$
T _ {v \rightarrow u} = T _ {\text {s e r i a l}} (v, u) + T _ {\text {p r o p}} (v, u) + T _ {\text {s e r v i c e}} (v \rightarrow u)
$$

# (a) 串行时延 (双向对称)

假设链路速率对称：

$$
T _ {\text {s e r i a l}} (u, v) = T _ {\text {s e r i a l}} (v, u) = \frac {P _ {s}}{R _ {u , v}}
$$

其中：

- $P_{s}$ ：数据包大小（bit）  
- $R_{u,v}$ ：链路 $(u, v)$ 的速率（bps）

# (b)传播时延（双向对称）

假设传播距离对称：

$$
T _ {\mathrm {p r o p}} (u, v) = T _ {\mathrm {p r o p}} (v, u) = \frac {d _ {u , v}}{V}
$$

其中：

- $d_{u,v}$ ：节点间物理距离（km）  
- $V$ ：信号传播速度 $(\mathrm{km} / \mathrm{s})$

串口时延与传播时延计算公式一致，服务时延的具体差异体现在数值上即 CC 的发送，接收，中转这三个数值与非 CC 有不同。

<table><tr><td>节点类型（处理节点）</td><td>处理方向</td><td>时延符号</td><td>说明</td></tr><tr><td>控制中心（CC）</td><td>发送</td><td>τtxCC</td><td>CC发送控制指令的时延</td></tr><tr><td>控制中心（CC）</td><td>接收</td><td>τrxCC</td><td>CC接收测量数据的时延</td></tr><tr><td>非控制中心（非CC）</td><td>发送</td><td>τtxnonCC</td><td>非CC发送测量数据的时延</td></tr><tr><td>非控制中心（非CC）</td><td>接收</td><td>τrxnonCC</td><td>非CC接收控制指令的时延</td></tr></table>

# 时延计算公式：

1.链路时延（双向对称）

$$
T _ {\text {l i n k}} (u, v) = \frac {P _ {s}}{R} + \frac {d _ {u , v}}{V}
$$

2. 路径总时延公式

下行（CC $\rightarrow$ 非CC）：

$$
T _ {\text {d o w n}} (\pi) = \sum_ {i = 0} ^ {k - 1} T _ {\text {l i n k}} (u _ {i}, u _ {i + 1}) + \tau_ {\mathrm {C C}} ^ {\mathrm {t x}} + \tau_ {\text {n o n C C}} ^ {\mathrm {r x}} + \sum_ {i = 1} ^ {k - 1} \tau_ {\text {f o r w a r d}} (u _ {i})
$$

上行（非CC $\rightarrow$ CC）：

$$
T _ {\mathrm {u p}} (\pi) = \sum_ {i = 0} ^ {k - 1} T _ {\mathrm {l i n k}} \left(u _ {i}, u _ {i + 1}\right) + \tau_ {\mathrm {n o n C C}} ^ {\mathrm {t x}} + \tau_ {\mathrm {C C}} ^ {\mathrm {r x}} + \sum_ {i = 1} ^ {k - 1} \tau_ {\text {f o r w a r d}} \left(u _ {i}\right)
$$

其中：

$$
\cdot \tau_ {\mathrm {f o r w a r d}} (u) = \left\{ \begin{array}{l l} \tau_ {\mathrm {C C}} ^ {\mathrm {f o r w a r d}} & \text {i f} u \text {是} \mathrm {C C} \\ \tau_ {\mathrm {n o n C C}} ^ {\mathrm {f o r w a r d}} & \text {i f} u \text {是 非} \mathrm {C C} \end{array} \right.
$$

这就是关于通信层具体的实验设计想法。

![](images/8d330886283341ceb8d2ab9d5dc7e703b203440ad07a1b65f73fa513e9d74035.jpg)

# 核心思想：

1. 控制中心 (CC) 处理能力更强, 服务时延更低  
   2.上行（非CC $\rightarrow$ CC）与下行（CC→非CC）业务特点不同：

上行：测量数据上传，数据量相对稳定  
。下行：控制指令下发，可能需要紧急处理

# 3. 服务时延应区分节点类型和传输方向

非CC到电力节点PB：执行时延

电力节点PB到非CC：测量时延

执行时延的定义是：非 CC 在得到控制命令后下达到电力节点的时延，也就是传输时延导致的动作（调功率等等）延迟

测量时延的定义是：电力节点的各种状态参数（功率等等）在被传感器确定后要转换为非CC所能感知的变量时的延迟。

# 1.时延的本质影响

- 测量时延：控制器"看到"的是过去的状态 $\rightarrow$ 决策基于过时信息  
- 执行时延：控制指令"传递"需要时间 $\rightarrow$ 动作滞后于决策

在电力系统中，这直接导致：发电机的实际出力无法精确跟踪参考值。

# 2. 简化假设（符合工程实际）

时延影响与控制偏差成正比  
时延越长，控制性能下降越明显  

- 不同发电机的时延敏感度不同

# 时延参数（单位：秒）

- $\tau_{\mathrm{m}}$ : 测量时延,典型值0.05~0.3秒(50~300ms)   
- $\tau_{-} e$ : 执行时延, 典型值 $0.08 \sim 0.4$ 秒 (80~400ms)

# 敏感系数（单位：1/秒）

- k_m：测量时延敏感度，反映控制系统对数据新鲜度的依赖程度

- 快速调节机组：k_m = 0.8~1.2（燃气轮机、储能）  
  慢速调节机组：k_m = 0.3~0.6（燃煤、核电）

- k_e: 执行时延敏感度，反映执行机构的响应速度

- 快速执行：k_e = 0.6~1.0（电力电子接口）  
  慢速执行：k_e = 0.2~0.5（机械调节）

定义1：测量时延影响因子

f_m = 1 - k_m $\times$ τ_m

物理意义：控制器基于τ_m秒前的数据决策，控制精度下降k_m×τ_m比例。

定义2：执行时延影响因子

f_e = 1 - k_e $\times$ τ_e

物理意义：指令延迟 $\tau_{\text{e}}$ 秒执行，执行效率下降 $k_{\text{ext}}$ 例。

定义3：综合时延效率

```txt
[ \eta = f_{-}m \times f_{-}e = (1 - k_{-}m \times \tau_{-}m) \times (1 - k_{-}e \times \tau_{-}e) ] 
```

最终公式：

Pactual $=$ P_ref $\times \eta =$ P_ref $\times (1 - k_m\times \tau_m)\times (1 - k_e\times \tau_e)$

时延（τ）→控制效率下降（η=1-ατ）→实际调整量=理论需求×η

指标体现：同样的故障，有时延时发电机出力调整量只有无时延时的η倍。

时延最后作用于功率 P，时延对 CPPS 的鲁棒性的消极影响体现为

# 1. 负荷保持能力（核心指标）

```txt
R_1 = \frac{1}{\text{frac}}[\text{text} \{\text{级联结束后仍供电的负荷}\}] \{\text{text} \{\text{初始总负荷}\}] \times 100 \% 
```

无时延时：R1可能达到85%（故障后仍能供应85%负荷）  

- 有时延时： ${\mathrm{R}}_{1}$ 可能降到65%(同样故障只能供应65%负荷)  
  时延影响：R下降幅度直接反映时延对供电可靠性的损害

```latex
[ R_{1} = (L_{\text{final}} / L_{\text{initial}}) \times 100\% ] 
```

# 变量说明

- L_final：级联失效过程结束后，系统仍能正常供电的总负荷（MW）  
- L.initial: 级联失效发生前，系统的初始总负荷 (MW)

# 2.级联传播规模

```latex
R_2 = \frac{1}{\text{text}} \left[ \frac{\text{跳闸线路数量}}{\text{系统总线路数}} \right] 
```

时延越大，R2越高（故障传播范围更广）  

- 可以定义“级联深度”：从初始故障到系统稳定的步数

$R_{2} = N_{\text{tripped}} / N_{\text{total}}$

# 变量说明

- N_tripped: 级联失效过程中累计跳闸的线路数量  
- N_total: 系统初始状态下的总线路数量

# 3. 关键参数偏离度（R3）

# 公式

$$
R _ {3} = \begin{array}{c c c c} & 1 & N & (P _ {i} \text {- a c t u a l - P _ {i} r e f}) ^ {2} \\ & \hline & \times & \sum \\ & \sqrt {} & N & i = 1 \\ & & & P _ {i} \text {- r e f} \end{array}
$$

或者写成更紧凑的形式：

$$
R _ {3} = \sqrt {\left(1 / N\right) \times \Sigma \left(\left(P _ {i} - \text {a c t u a l} - P _ {i} - \text {r e f}\right) / P _ {i} - \text {r e f}\right) ^ {2}} ]
$$

# 变量说明

- P_jactual: 第i台发电机在时延影响下的实际出力（MW）  
- P_i_ref: 第i台发电机在无时延理想情况下的参考出力（MW）  
- N：系统中参与调节的发电机总数  
- $\Sigma$ ：求和符号，表示对所有发电机（i=1到N）求和  
- √：平方根符号

# 物理意义

R3 衡量时延导致的功率分配不合理程度。该指标反映控制精度损失，值越大表明发电出力的实际分布越偏离最优分布。

最后的负荷存活率，级联规模也就是过载线路的数目，发电机整体功率于没有时延下的偏离程度，前两个指标也可以和之前没有设计时延的情况进行对比，反映时延这一因素对整个CPPS系统的鲁棒性影响。

第一部分对比实验（与没有引入时延对比）：说明引入时延这一因素对 CPPS 的鲁棒性，稳定性有消极影响。

第二部分实验：通过调节时延公式中的若干因子，给时延影响做不同区分（轻度，中度，重度等）

研究问题：不是找精确临界点，而是划分几个实用的安全等级具体做法：

1. 测试时延从0ms到500ms（步长50ms）  
2. 根据 ${\mathrm{R}}_{1}$ 下降程度划分四个区：
- 绿色安全区： ${\mathrm{R}}_{1} > {85}\%$ (时延<150ms)  
- 黄色预警区： ${\mathrm{R}}_{1}{70} - {85}\%$ (时延150-300ms)  
  橙色风险区：R150-70%（时延300-400ms）  
- 红色崩溃区：R<50%（时延>400ms）

可能的新发现：

- 工程实用阈值：给出可直接用的设计标准  
  系统韧性评级：根据系统能容忍的时延范围评级  
  预警机制基础：建立基于时延的安全预警线

第三部实验：找出对时延因素敏感的发电机，发现时延与电气位置（key location）的关系。
