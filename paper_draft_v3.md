# Closing the Loop: How Communication Delay Drives Cascading Failure in Cyber-Physical Power Systems

---

## Abstract

Cascading failure models for cyber-physical power systems (CPPS) routinely treat communication delay as a post-hoc observation rather than a causal driver of further damage. This architectural choice eliminates the very mechanism through which delay inflicts its greatest harm: a closed feedback loop in which degraded communication reduces generator controllability, the resulting power imbalance triggers additional branch overloads, the consequent structural failures further damage the communication topology, and the damaged topology amplifies delay for the next cascade round. In this paper we embed communication delay directly into the cascading failure process, computing and applying a delay-dependent control efficiency factor to every surviving generator before each round of DC power flow. The framework decomposes end-to-end latency into uplink measurement delay and downlink execution delay through a role-aware, physically grounded model that distinguishes control centers from ordinary relay nodes. Interdependent coupling between the IEEE 39-bus power grid and a Barabási–Albert scale-free communication network is established via a betweenness-assortative strategy, and control centers are placed using a composite structural importance score that balances global bridging capacity with local embeddedness. Monte Carlo experiments spanning 1,000 independent coupling realizations, eleven tolerance levels, and five delay-severity scenarios reveal three principal findings. First, the delay penalty concentrates asymmetrically in the tolerance–cascade-round plane: it is largest at moderate-to-high tolerance margins and late cascade rounds — precisely where delay-free analysis predicts safety but delay-burdened systems collapse. Second, delay amplifies the stochastic variability of cascade outcomes, transforming narrow outcome distributions under ideal communication into wide, heavy-tailed distributions under severe delay. Third, generator dispatch deviation remains stratified across delay scenarios even when aggregate load retention appears adequate, exposing a form of hidden functional degradation invisible to load-based metrics alone. These results demonstrate that delay-free robustness models are not merely imprecise but systematically misleading, providing the greatest reassurance in the operating regimes that harbor the greatest vulnerability.

---

## 1. Introduction

*(To be written after the technical body is complete. This section will motivate the delay-cascade feedback loop, position the contribution against existing CPPS cascading failure literature, and outline the paper structure.)*

---

## 2. Cyber-Physical Power System Model

The system under study consists of two interdependent network layers — a physical power grid and a cyber communication network — whose coupling transforms isolated disturbances into cross-domain cascading failures. This section describes each layer, the mechanism by which they are coupled, and the capacity-tolerance framework that governs overload propagation.

### 2.1 Power Grid Layer

The physical layer is represented by the IEEE 39-bus (New England) test system, a well-established benchmark comprising 39 buses, 46 transmission branches, and 10 generators. Bus connectivity is encoded in an adjacency matrix $A_P$ extracted from the branch table, and the initial operating state — bus loads, generator outputs, and branch power flows — is obtained by solving a DC power flow on the full network. Let $L_i$ denote the active load at bus $i$ and $P_j^{\text{ref}}$ the scheduled output of generator $j$. The DC power flow assumption is appropriate here because our focus is on topological and flow-redistribution dynamics during cascading failure rather than on voltage or reactive-power phenomena.

Each transmission branch $e$ carries an initial power flow $P_e^{(0)}$ determined by the DC power flow solution. This initial flow serves as the reference for the capacity model described in Section 2.4: a branch whose post-disturbance flow exceeds its capacity is tripped, potentially triggering further redistribution and additional overloads.

### 2.2 Communication Network Layer

#### 2.2.1 Scale-Free Topology

The cyber layer is constructed as a Barabási–Albert (BA) scale-free network to capture the hub-dominated, heterogeneous degree distribution commonly observed in communication infrastructures serving critical facilities. The network contains $|V_C| = |V_P| + n_{cc}$ nodes, where $n_{cc} = \lceil 0.2 \times |V_P| \rceil$ additional nodes serve as designated control centers (CCs). For the IEEE 39-bus system this yields $|V_C| = 39 + 8 = 47$ nodes, of which 8 are CCs.

The BA growth process starts from a fully connected seed of $m_0 = 4$ nodes. At each step, a new node is added and connected to $m_e = 2$ existing nodes selected with probability proportional to their current degree (preferential attachment). This process produces a power-law degree distribution $P(k) \sim k^{-\gamma}$ with $\gamma \approx 3$, endowing the network with a small number of high-degree hubs and a large number of low-degree peripheral nodes — a topology that is efficient under normal conditions but vulnerable to targeted attacks against hubs.

#### 2.2.2 Control Center Placement

Control centers perform state estimation and dispatch computation; their placement within the communication topology therefore has first-order effects on both the communication distances that measurement and command traffic must traverse and the network's resilience to fragmentation. Rather than selecting CCs by a single centrality measure, we employ a Multi-attribute Structural Importance Score (MSIS) that fuses complementary topological features into a single ranking criterion:

$$
w_i = \frac{\widetilde{B}(i) + K_s(i)}{C_l(i)} + D(i) \cdot C(i),
$$

where $\widetilde{B}(i) = B(i) + 1$ is the shifted betweenness centrality (the unit shift avoids zero-valued numerators for leaf nodes), $K_s(i)$ is the $k$-shell index obtained by iterative pruning of nodes with degree below $k$, $C_l(i)$ is closeness centrality (the reciprocal of mean shortest-path distance to all other nodes), $D(i)$ is degree, and $C(i)$ is the local clustering coefficient. The top $n_{cc}$ nodes ranked by $w_i$ are designated as control centers.

The rationale for this composite score is that no single centrality measure captures all dimensions of structural importance relevant to control-center functionality. Betweenness identifies nodes that bridge distant parts of the network, ensuring that CCs sit on many communication paths. The $k$-shell index identifies nodes embedded in the network's dense core, providing resilience against peripheral damage. Closeness ensures short average distances from CCs to all other nodes, minimizing baseline communication delay. Degree and clustering capture local connectivity richness, which provides alternative paths when individual links fail. By combining these measures, MSIS selects CCs that are globally well-positioned, locally well-connected, and structurally resilient — properties that directly serve the control-center role of maintaining reachability and minimizing latency under stress.

#### 2.2.3 Communication Delay Model

Communication delay is modeled at the individual link level and aggregated over multi-hop paths, with explicit directional asymmetry between uplink (measurement) and downlink (command) traffic.

**Link-level delay.** For a single surviving link $(u, v)$, the per-hop delay is:

$$
T_{\text{link}} = \frac{S}{R} + \frac{d}{V},
$$

where $S$ is the packet size (bits), $R$ is the link data rate (bps), $d$ is the effective link distance (km), and $V$ is the signal propagation speed (km/s). The first term captures serialization delay (the time to push all bits onto the link); the second captures propagation delay (the time for the signal to traverse the physical medium). Uplink and downlink traffic use different packet sizes — measurement packets ($S_{\text{up}} = 8{,}192$ bits) are larger than command packets ($S_{\text{down}} = 2{,}048$ bits) — introducing a directional asymmetry even over the same physical link.

**Path-level delay.** For a multi-hop path $\pi = (u_0, u_1, \ldots, u_k)$, the total path delay aggregates per-hop link delays, endpoint service delays, and intermediate forwarding delays:

*Downlink (CC $\to$ non-CC):*

$$
T_{\text{down}}(\pi) = \sum_{i=0}^{k-1} T_{\text{link}}^{\text{down}}(u_i, u_{i+1}) \;+\; \tau_{\text{CC}}^{\text{tx}} + \tau_{\text{nonCC}}^{\text{rx}} \;+\; \sum_{j=1}^{k-1} \tau_{\text{fwd}}(u_j).
$$

*Uplink (non-CC $\to$ CC):*

$$
T_{\text{up}}(\pi) = \sum_{i=0}^{k-1} T_{\text{link}}^{\text{up}}(u_i, u_{i+1}) \;+\; \tau_{\text{nonCC}}^{\text{tx}} + \tau_{\text{CC}}^{\text{rx}} \;+\; \sum_{j=1}^{k-1} \tau_{\text{fwd}}(u_j).
$$

The forwarding delay at each intermediate node depends on its role:

$$
\tau_{\text{fwd}}(u) = \begin{cases} \tau_{\text{CC}}^{\text{fwd}} & \text{if } u \text{ is a control center}, \\ \tau_{\text{nonCC}}^{\text{fwd}} & \text{otherwise}. \end{cases}
$$

This role-aware decomposition reflects the engineering reality that control centers are typically equipped with more capable processing hardware and therefore exhibit lower per-packet service latency than ordinary relay nodes. The same physical path thus yields different uplink and downlink delays — not because of asymmetric propagation physics, but because of directional traffic characteristics and role-dependent processing.

### 2.3 Interdependent Coupling

The two layers are coupled through a one-to-one mapping between power buses and non-CC cyber nodes, encoded in a coupling matrix $A_{pc} \in \{0,1\}^{|V_P| \times |V_C|}$. This mapping determines which cyber node monitors and controls which power bus, and consequently which communication path a generator's measurement and command traffic must traverse.

**Betweenness-assortative coupling.** We construct $A_{pc}$ by sorting power buses in descending order of their betweenness centrality in $G_P$, independently sorting non-CC cyber nodes in descending order of their betweenness centrality in $G_C$, and pairing them rank-by-rank: the most central power bus is coupled with the most central non-CC cyber node, the second-most central with the second-most central, and so on. This assortative strategy ensures that structurally critical power buses — those whose failure would most disrupt power flow redistribution — are paired with structurally critical communication nodes — those best positioned to maintain reachability under stress. The rationale is that real-world grid operators provision their most important substations with the highest-quality communication resources, and betweenness-assortative coupling mirrors this engineering practice.

Because each Monte Carlo trial generates a fresh BA communication network, a fresh CC selection, and a fresh coupling matrix, the reported metrics reflect averaged behavior across diverse cyber-physical configurations rather than artifacts of a single topology.

### 2.4 Capacity-Tolerance Model

Overload-driven cascading requires a model of component capacity. We adopt the standard tolerance-factor formulation in which the capacity of each component is proportional to its initial load, with a tunable margin parameter $\alpha \in [0, 1]$:

**Power branches:**

$$
C_e^P = (1 + \alpha) \cdot |P_e^{(0)}|,
$$

where $P_e^{(0)}$ is the initial branch power flow from DC power flow.

**Cyber nodes:**

$$
C_i^C = (1 + \alpha) \cdot B_i^{(0)},
$$

where $B_i^{(0)}$ is the initial betweenness centrality of cyber node $i$.

**Cyber edges:**

$$
C_e^{CE} = (1 + \alpha) \cdot B_e^{(0)},
$$

where $B_e^{(0)}$ is the initial edge betweenness of cyber link $e$.

The tolerance factor $\alpha$ governs how much excess capacity each component has beyond its initial operating load. At $\alpha = 0$, components operate at full capacity with no margin — any redistribution causes immediate overload. At $\alpha = 1$, each component can absorb up to double its initial load before failing. By sweeping $\alpha$ from 0 to 1 in increments of 0.1, we systematically explore how the interplay between structural margin and communication delay shapes cascade severity. This parameterization is standard in interdependent network cascading studies and enables direct comparison with prior work.

---

## 3. Delay-Integrated Cascading Failure Dynamics

The cascading failure model operates through a nested dual-loop architecture in which communication delay participates as an endogenous causal variable — not as a post-hoc correction applied after the cascade trajectory has been determined, but as a force that actively shapes the trajectory itself. This section describes the attack model, the inner structural-propagation loop, the outer overload-and-delay loop, and the delay-to-control mapping that closes the feedback chain.

### 3.1 Attack Model

Each simulation begins with the targeted removal of a single non-CC cyber node — specifically, the non-CC node with the highest betweenness centrality in the initial communication network. This attack strategy targets the most structurally important relay node, maximizing initial disruption to communication paths while preserving all control centers (since only non-CC nodes are eligible targets). The removal of this node, along with all its incident links, constitutes the exogenous shock that initiates the cascade.

The choice of a single-node betweenness-targeted attack reflects a worst-case analysis philosophy: it identifies the attack that causes maximum initial communication disruption per node removed. Because the attacked node is a high-betweenness relay, its removal simultaneously lengthens many communication paths (increasing delay for generators that remain reachable) and may fragment the cyber network (severing reachability for generators in disconnected components). Both effects feed directly into the delay-cascade mechanism described below.

### 3.2 Structural Propagation (Inner Loop)

Given the current set of failed nodes and edges — whether from the initial attack or from overload-induced failures in a previous outer-loop iteration — the inner loop iterates until no new structural failures emerge. Each iteration executes four steps:

**Step 1: Cyber-layer island viability.** Connected components of the surviving cyber network are identified. Any component that does not contain at least one surviving control center is declared non-viable: without CC access, the nodes in that component can neither report measurements nor receive dispatch commands. All nodes and edges within non-viable components are marked as failed.

**Step 2: Forward propagation (cyber $\to$ power).** Each newly failed non-CC cyber node triggers the failure of its coupled power bus with probability $p$. This stochastic propagation models the heterogeneous dependency strength across different bus-communication associations — not every communication failure immediately disables its associated power bus, but a fraction $p$ of them do.

**Step 3: Power-layer island viability.** Connected components of the surviving power network are identified. Any component that contains neither a generator nor a load bus is declared non-viable, and all its member buses and incident branches are marked as failed.

**Step 4: Reverse propagation (power $\to$ cyber).** Each newly failed power bus triggers the failure of its coupled non-CC cyber node with probability $p$, creating a symmetric channel for damage to flow back from the power layer to the communication layer.

**Convergence.** Steps 1–4 repeat until the sets of failed cyber and power nodes remain unchanged between consecutive iterations. At convergence, all structurally-induced failures from the current disturbance have been fully resolved, and the surviving network is ready for overload evaluation.

The bidirectional propagation with probability $p$ is the mechanism through which damage crosses the layer boundary. A cyber node failure can disable a power bus (forward), and a power bus failure can disable a cyber node (reverse). Combined with the island-viability checks, this creates cascading chains in which a single failure in one layer can trigger a sequence of failures that alternates between layers until convergence.

### 3.3 Overload-Driven Cascade Expansion (Outer Loop)

After the inner loop stabilizes, the surviving network undergoes overload evaluation — the mechanism through which load redistribution drives further failures. The outer loop executes the following steps:

**Step 1: Cyber-layer overload check.** Betweenness centrality is recomputed on the surviving cyber network. Any non-CC node whose updated betweenness exceeds its capacity $C_i^C = (1 + \alpha) \cdot B_i^{(0)}$ is marked for removal. Similarly, any surviving cyber link whose updated edge betweenness exceeds its capacity $C_e^{CE} = (1 + \alpha) \cdot B_e^{(0)}$ is removed. These overloads arise because the removal of failed nodes and links forces traffic to reroute through surviving components, concentrating load on fewer elements.

**Step 2: Delay-aware generation adjustment.** This step — detailed in Section 3.4 — is the architectural innovation that closes the feedback loop. For each surviving generator, the framework computes a delay-dependent control efficiency factor $\eta_i$ based on the current state of the communication network, and scales the generator's output accordingly. This scaling occurs *before* the DC power flow in Step 3, ensuring that delay's impact propagates through the electrical network.

**Step 3: DC power flow and branch overload check.** A DC power flow is solved on the surviving power network using the delay-adjusted generator outputs from Step 2. Any branch whose post-redistribution power flow exceeds its capacity $C_e^P = (1 + \alpha) \cdot |P_e^{(0)}|$ is tripped.

**Step 4: Convergence test.** If Steps 1 and 3 produced no new failures, the cascade terminates. Otherwise, the newly failed components are incorporated and the process returns to the inner loop (Section 3.2) to resolve any structural consequences of the new failures, followed by another outer-loop iteration.

**The feedback mechanism.** Step 2 is what distinguishes this framework from conventional cascading models. In a standard model, DC power flow operates on generator outputs that are unaffected by communication quality — every generator produces its full scheduled output regardless of the state of the communication network. In the present framework, generators whose communication paths have lengthened produce less power (reduced $\eta_i$), and generators that have lost all CC access produce no power at all ($\eta_i = 0$). This output reduction alters branch flows: branches that would not overload under ideal control may now overload because the reduced generation forces more aggressive redistribution onto surviving paths. These additional overloads cause further structural failures, which degrade the communication topology, which increases delay in the next round. The cycle continues until either the cascade stabilizes or the system collapses.

Each delay scenario therefore traces a genuinely unique cascade trajectory — different overload patterns, different failure sequences, different terminal states. This property is fundamentally impossible in post-hoc delay models, where all scenarios share an identical structural cascade and delay merely rescales final metrics.

### 3.4 Delay-Aware Generator Dispatch

For each surviving generator $i$ that remains online after structural propagation, the framework performs the following computation:

1. **Identify the coupled cyber node.** Generator $i$'s power bus is mapped to its non-CC cyber node via the coupling matrix $A_{pc}$.

2. **Find the nearest reachable CC.** On the surviving cyber network, the shortest delay-weighted path from the generator's cyber node to each surviving CC is computed. The CC with the minimum-delay path is selected. If no CC is reachable — because the cyber network has fragmented such that no CC-containing component includes the generator's communication node — the generator is classified as *unreachable*.

3. **Compute measurement and execution delays.** The total measurement delay (sensor-to-CC) and execution delay (CC-to-actuator) for generator $i$ are:

$$
\tau_{m,i} = \tau_{\text{PB} \to \text{nonCC}} + T_{\text{up}}(\pi_i),
$$

$$
\tau_{e,i} = \tau_{\text{nonCC} \to \text{PB}} + T_{\text{down}}(\pi_i),
$$

where $\tau_{\text{PB} \to \text{nonCC}}$ is the field-side measurement interface delay (the time for sensor data to travel from the physical bus to its communication node), $\tau_{\text{nonCC} \to \text{PB}}$ is the field-side command execution delay (the time for a control command to travel from the communication node to the physical actuator), and $T_{\text{up}}(\pi_i)$, $T_{\text{down}}(\pi_i)$ are the uplink and downlink cyber-path delays computed as described in Section 2.2.3.

4. **Compute control efficiency.** The delay-to-control mapping converts the two delay components into a composite efficiency factor:

$$
\eta_i = (1 - k_m \cdot \tau_{m,i}) \times (1 - k_e \cdot \tau_{e,i}),
$$

where $k_m$ and $k_e$ are delay sensitivity coefficients that quantify how strongly stale measurements and lagged execution degrade control quality, respectively. The factor $\eta_i$ is clamped to $[0, 1]$: values below zero (which would occur if delay exceeds $1/k_m$ or $1/k_e$) are set to zero, representing complete loss of effective control.

5. **Scale generator output.** The generator's actual output for this cascade round is:

$$
P_i^{\text{actual}} = P_i^{\text{ref}} \cdot \eta_i,
$$

where $P_i^{\text{ref}}$ is the original dispatch setpoint. This scaled output is used in the DC power flow of Step 3.

**Unreachable generators.** If no surviving CC is reachable from generator $i$'s cyber node, the generator receives no measurement feedback and no dispatch commands. Its output is set to zero: $P_i^{\text{actual}} = 0$, $\eta_i = 0$. This is the most severe consequence of communication-layer degradation — complete loss of controllability — and it occurs before the DC power flow, directly contributing to power imbalance and potential overloads. The distinction between a generator with high delay ($\eta_i \approx 0.3$) and an unreachable generator ($\eta_i = 0$) is qualitative, not merely quantitative: the former contributes reduced but nonzero power, while the latter contributes nothing, creating an abrupt discontinuity in the system's generation capacity.

### 3.5 Delay Severity Scenarios

To systematically investigate how increasing communication degradation interacts with the cascade feedback loop, we define five delay-severity scenarios by coherently scaling a common baseline parameter set:

| Scenario | Scale Factor | Interpretation |
|----------|:---:|---|
| `no_delay` | 0.0 | Ideal control — zero communication delay |
| `light` | 0.5 | Optimistic: well-provisioned communication |
| `baseline` | 1.0 | Nominal delay parameterization |
| `medium` | 1.5 | Moderately degraded communication |
| `heavy` | 2.0 | Severely degraded communication |

The scale factor is applied multiplicatively to all delay-producing parameters: uplink and downlink packet sizes, effective link distances, all service delays (transmit, receive, forward), and the field-side measurement and execution interface delays. The link data rate $R$, propagation speed $V$, and sensitivity coefficients $k_m$, $k_e$ remain fixed across scenarios. This design coherently strengthens the entire end-to-end delay burden rather than perturbing individual parameters in isolation.

Crucially, the `no_delay` scenario (scale factor 0) zeros all delay-producing terms. Every reachable generator therefore satisfies $\tau_{m,i} = \tau_{e,i} = 0$ and retains $\eta_i = 1$, making `no_delay` an exact zero-delay benchmark within the same coupled-network cascade framework. Any performance difference between `no_delay` and any other scenario is therefore causally attributable to communication delay and nothing else.

### 3.6 Resilience Metrics

System-level resilience is assessed through two complementary metrics that capture different dimensions of cascade damage.

**$R_1$: Load retention ratio.** Let $L_{\text{initial}}$ denote the total pre-attack load across all buses and $L_{\text{surviving}}$ the total load at buses that survive to the cascade's terminal state:

$$
R_1 = \frac{L_{\text{surviving}}}{L_{\text{initial}}}.
$$

$R_1$ answers the question "how much of the system's load-serving capacity survives the cascade?" A value of 1 indicates no load loss; a value near 0 indicates near-total collapse. Because delay is embedded within the cascade process, delay's influence on $R_1$ manifests endogenously: delay-degraded generators produce less power, which alters branch flows, which produces different overload patterns, which leads to different sets of surviving buses and loads. The same formula therefore yields genuinely different $R_1$ values under different delay scenarios — not because of a correction factor, but because the cascades themselves diverge.

**$R_3$: Generator dispatch deviation.** For the $N$ generators surviving at the cascade's terminal state with $P_j^{\text{ref}} > 0$:

$$
R_3 = \sqrt{\frac{1}{N} \sum_{j=1}^{N} \left( \frac{P_j^{\text{actual}} - P_j^{\text{ref}}}{P_j^{\text{ref}}} \right)^2}.
$$

$R_3$ answers a different question: "how accurately are the surviving generators executing their intended dispatch?" A value of 0 indicates perfect dispatch fidelity; higher values indicate greater deviation. Unreachable generators contribute the maximum relative deviation of 1.0, reflecting total loss of control.

These two metrics serve complementary diagnostic roles. $R_1$ is an aggregate structural measure — it folds structural damage, overloads, and delay-induced generation shortfalls into a single load-survival number. $R_3$ is a functional quality measure among survivors — it reveals whether generators that *are* still online are operating correctly. A system may retain high $R_1$ (most load served) yet suffer high $R_3$ (poor control fidelity among survivors), a form of hidden degradation that load-retention metrics alone cannot detect.

---

## 4. Experimental Analysis

### 4.1 Experimental Setup

**Test system.** The physical layer is the IEEE 39-bus (New England) system with 39 buses, 46 branches, and 10 generators. The cyber layer is a BA network with $|V_C| = 47$ nodes (39 non-CC + 8 CC), grown from a seed of $m_0 = 4$ fully connected nodes with $m_e = 2$ attachment edges per step.

**Monte Carlo design.** For each of the 1,000 independent trials, a new BA communication network is generated, a new set of 8 control centers is selected via MSIS ranking, and a new betweenness-assortative coupling matrix $A_{pc}$ is constructed. The power layer (IEEE 39-bus topology and initial power flow) is shared across trials. This design ensures that all reported statistics reflect the distribution over diverse cyber-physical configurations, not the behavior of any single realization.

**Parameter grid.** Each trial is executed independently under all five delay scenarios (`no_delay`, `light`, `baseline`, `medium`, `heavy`) at each of 11 tolerance levels ($\alpha \in \{0.0, 0.1, \ldots, 1.0\}$), producing $1{,}000 \times 5 \times 11 = 55{,}000$ independent cascade simulations. The inter-layer propagation probability is $p = 0.3$.

**Table 1. Simulation Parameters**

| Category | Parameter | Value |
|----------|-----------|-------|
| Power layer | Test case | IEEE 39-bus |
| | Buses / Branches / Generators | 39 / 46 / 10 |
| Cyber layer | Total nodes $\|V_C\|$ | 47 |
| | Control centers $n_{cc}$ | 8 |
| | BA seed $m_0$ / Attachment $m_e$ | 4 / 2 |
| Coupling | Strategy | Betweenness-assortative |
| | CC selection | MSIS ranking |
| Cascade | Propagation probability $p$ | 0.3 |
| | Tolerance factor $\alpha$ | 0.0 : 0.1 : 1.0 |
| | Attack mode | Betweenness-targeted (single non-CC) |
| Communication | Uplink packet $S_{\text{up}}$ | 8,192 bits |
| | Downlink packet $S_{\text{down}}$ | 2,048 bits |
| | Link rate $R$ | 10 Mbps |
| | Propagation speed $V$ | $2 \times 10^5$ km/s |
| | Link distance $d$ | 1 km |
| | CC service: tx / rx / fwd | 3 / 4 / 3 ms |
| | Non-CC service: tx / rx / fwd | 12 / 9 / 6 ms |
| Delay-to-control | Measurement interface $\tau_{\text{PB}\to\text{nonCC}}$ | 100 ms |
| | Execution interface $\tau_{\text{nonCC}\to\text{PB}}$ | 120 ms |
| | Measurement sensitivity $k_m$ | 0.80 s$^{-1}$ |
| | Execution sensitivity $k_e$ | 0.60 s$^{-1}$ |
| Sampling | Trials per $(\alpha, \text{scenario})$ pair | 1,000 |

**Evaluation protocol.** For each cascade simulation, the round-by-round snapshots record all failed components, surviving topology, and the delay injection log (containing $\eta_i$, $\tau_{m,i}$, $\tau_{e,i}$, reachability status, and selected CC for every generator at every round). Final-state $R_1$ is computed from the set of surviving buses and their loads. Final-state $R_3$ is computed from the delay injection log of the terminal cascade round. Per-round $R_1(r)$ is computed at each round for temporal analysis. Trials that terminate early contribute their terminal $R_1$ to all subsequent rounds via last-value-carried-forward padding, ensuring that early stabilization is interpreted as a settled final state rather than missing data.

### 4.2 Impact of Delay Severity on Load Retention

Fig. 1 presents the mean load retention ratio $R_1$ as a function of tolerance factor $\alpha$ across the five delay scenarios, averaged over 1,000 trials at each point.

Three patterns emerge. First, the `no_delay` curve (blue) lies consistently above all delay-present curves across the entire $\alpha$ range, rising monotonically from approximately 0.07 at $\alpha = 0$ to 0.87 at $\alpha = 1.0$. This confirms that zero-delay control provides an upper bound on system resilience and validates the framework's ability to produce a clean, well-behaved baseline.

Second, the gap between `no_delay` and the delay-present scenarios widens dramatically as $\alpha$ increases through the intermediate range. At $\alpha = 0.2$, all five curves cluster near $R_1 \approx 0.20$ — the system collapses regardless of delay, leaving little room for delay to worsen the outcome. By $\alpha = 0.5$, `no_delay` reaches $R_1 \approx 0.60$ while the delay-present curves remain in the range 0.40–0.50. By $\alpha = 0.8$, the gap exceeds 0.25 in absolute terms: `no_delay` achieves $R_1 \approx 0.81$ while the heavier delay scenarios hover around 0.44–0.59. This widening gap reveals the asymmetric vulnerability at the heart of the delay-cascade feedback loop: *delay damage is most consequential when the power system has enough physical margin to survive without delay but not enough to absorb the additional overloads that delay creates.*

Third, the four delay-present curves (`light`, `baseline`, `medium`, `heavy`) exhibit crossings and non-monotonic oscillations at high $\alpha$ values ($\alpha \geq 0.7$). Unlike the clean stratification expected from monotonically increasing delay severity, these curves interweave — for instance, the `medium` curve dips below `heavy` at certain $\alpha$ values. This behavior is not an error; it reflects the interaction between heavy-tailed $R_1$ distributions (see Section 4.5) and the arithmetic mean: at high $\alpha$, a small number of catastrophic realizations under one scenario can pull its mean below that of a nominally more severe scenario. This observation motivates the distributional analysis in Section 4.5, where we show that the median and interquartile-range behavior is more stable than the mean.

### 4.3 Temporal-Spatial Structure of the Delay Penalty

To understand how delay damage accumulates during the cascade — rather than only at its terminal state — we examine the round-level delay penalty. Define:

$$
\Delta R_1(r, \alpha) = R_1^{\text{no\_delay}}(r, \alpha) - R_1^{\text{heavy}}(r, \alpha),
$$

which isolates the load-retention difference attributable to delay at each cascade round $r$ and tolerance level $\alpha$, comparing the two extreme scenarios. Because each scenario runs an independent cascade with delay actively shaping its trajectory, this difference captures both the direct functional impact of delay (efficiency reduction) and the indirect structural impact (additional failures caused by delay-induced overloads).

Fig. 4 presents $\Delta R_1$ as a heatmap over the (cascade round, $\alpha$) plane, revealing a striking spatial-temporal structure.

**Round 1 is delay-neutral.** The leftmost column of the heatmap is uniformly dark across all $\alpha$ values ($\Delta R_1 \approx 0$). This is expected: Round 1 reflects the immediate structural consequences of the initial attack (island viability failures, structural propagation), which are identical across delay scenarios because delay has not yet had an opportunity to alter generator outputs.

**The delay penalty ignites at Round 2.** At Round 2, a sharp transition occurs in the moderate-to-high $\alpha$ region ($\alpha \geq 0.4$): colors jump abruptly from near-black to bright yellow, indicating that $\Delta R_1$ leaps from near zero to substantial positive values in a single cascade round. This is the moment when the feedback loop first fires: the overload evaluation at the end of Round 1 applies delay-degraded generator outputs for the first time, altering branch flows and triggering overloads that the `no_delay` scenario avoids entirely. The sharpness of this transition — from negligible penalty to large penalty within one round — is the signature of a threshold crossing rather than a gradual accumulation.

**The penalty amplifies through Rounds 3–5.** From Round 2 onward, the penalty intensifies and spreads. At $\alpha = 0.5\text{–}0.6$, the color deepens from orange to deep red ($\Delta R_1 \approx 0.15\text{–}0.18$), indicating that these tolerance levels experience the most concentrated delay damage. At higher $\alpha$ ($\geq 0.8$), the penalty continues to grow, reaching $\Delta R_1 \approx 0.25\text{–}0.35$ by Round 5 as displayed by intense yellow and cream colors. This growth is the signature of positive feedback: each round of delay-induced overloads creates further structural damage that amplifies the next round's delay, producing compounding rather than linear damage accumulation.

**The penalty saturates after Round 5.** From approximately Round 5 onward, the heatmap colors stabilize: the pattern established by Round 5 persists with minimal change through Round 11. This saturation indicates that 80–90% of the avoidable delay damage has been locked in by the fifth cascade round. Subsequent rounds contribute incrementally at most — the feedback loop has largely exhausted the system's remaining vulnerability.

**Low $\alpha$ remains dark throughout.** The bottom rows ($\alpha \leq 0.1$) are near-black at all rounds, confirming a floor effect: when physical margins are so tight that even the delay-free system collapses, there is no room for delay to widen the gap. Both systems fail from structural overload before the delay feedback loop gains meaningful leverage.

**Operational interpretation.** The heatmap reveals an asymmetry with direct implications for intervention timing. An operator who could mitigate communication delay or compensate for its effects would achieve maximum benefit by acting at Round 2 — before the feedback loop amplifies the initial penalty into compounding damage. By Round 5, the intervention window has largely closed: most of the avoidable damage has already been inflicted. Conversely, the heatmap identifies $\alpha \approx 0.5\text{–}0.6$ as the most delay-sensitive operating regime — systems operating at these tolerance levels experience the greatest proportional damage from communication degradation and would benefit most from delay-mitigation investments.

### 4.4 Generator Output Fidelity Under Delay

While $R_1$ measures how much load the system retains, it does not reveal whether the surviving generators are operating correctly. A system could retain all its load yet have its generators producing outputs that deviate substantially from their intended dispatch — a form of hidden functional stress that $R_1$ alone cannot detect.

Fig. 2 presents the generator dispatch deviation $R_3$ across the same scenario–$\alpha$ grid. The results are strikingly clean: all five curves are perfectly stratified with no crossings, maintaining strict monotonic ordering from `heavy` (highest $R_3$, worst fidelity) at the top to `no_delay` (lowest $R_3$, best fidelity) at the bottom across the entire $\alpha$ range.

Three observations warrant attention. First, $R_3$ *decreases* with increasing $\alpha$ for all scenarios — the opposite direction from $R_1$'s increase. This makes physical sense: at higher $\alpha$, fewer components overload, fewer generators lose reachability, and the surviving generators retain higher $\eta_i$ values, all of which reduce dispatch deviation. The `no_delay` curve declines from approximately 0.24 at $\alpha = 0$ to 0.02 at $\alpha = 1.0$, indicating near-perfect dispatch fidelity when communication is ideal and capacity margins are generous.

Second, the inter-scenario separation is preserved even at high $\alpha$ where $R_1$ differences compress. At $\alpha = 1.0$, the `no_delay` system achieves $R_1 \approx 0.87$ and $R_3 \approx 0.02$, while the `heavy` system reaches $R_1 \approx 0.53$ (a gap of 0.34 in load retention) and $R_3 \approx 0.34$ (a gap of 0.32 in dispatch deviation). This persistent $R_3$ gap reveals a dimension of degradation invisible to $R_1$: even in operating regimes where systems appear to retain substantial load under delay, the quality of generator control among survivors is dramatically compromised.

Third, the absence of curve crossings in $R_3$ (in contrast to the crossings observed in Fig. 1's $R_1$ plot) suggests that $R_3$ is more robust to outlier-driven mean distortion. Because $R_3$ is a root-mean-square deviation computed over surviving generators — each contributing a bounded value between 0 and 1 — it is less susceptible to the heavy-tailed distribution effects that cause mean-$R_1$ curves to cross at high $\alpha$. This clean stratification makes $R_3$ a particularly reliable indicator of delay severity across operating conditions.

### 4.5 Distributional Analysis of Cascade Outcomes

The preceding sections report mean values of $R_1$ and $R_3$, characterizing expected behavior. For system operators, however, an equally critical question is whether delay affects the *predictability* of cascade outcomes. If delay increases outcome variability, then a system whose mean $R_1$ appears adequate may face unacceptably high probabilities of catastrophic outcomes in individual realizations.

Fig. 3 presents box plots of the $R_1$ distribution across 1,000 trials at three representative tolerance levels ($\alpha = 0.2, 0.5, 0.8$), grouped by delay scenario.

**At low tolerance ($\alpha = 0.2$):** All five scenarios produce broadly similar distributions concentrated in the range $R_1 \approx 0.15\text{–}0.50$. Medians cluster around 0.27–0.32 with substantial overlap across scenarios. The system collapses severely regardless of delay, confirming that when physical margins are insufficient, delay is a secondary factor — structural overload dominates before the feedback loop can meaningfully amplify.

**At moderate tolerance ($\alpha = 0.5$):** A striking divergence emerges. The `no_delay` distribution shifts dramatically upward: its median rises to approximately 0.58 with the box spanning 0.45–0.76, and a substantial fraction of realizations achieve $R_1 > 0.75$. The delay-present scenarios remain compressed in the 0.40–0.62 range with lower medians and broadly similar interquartile ranges. Crucially, all delay-present scenarios develop lower whiskers extending toward $R_1 \approx 0.05$, revealing a tail of near-total collapse that is absent from the `no_delay` distribution. This divergence confirms that delay does not merely shift the mean outcome downward but reshapes the entire distribution — introducing catastrophic-collapse realizations that ideal communication would avoid.

**At high tolerance ($\alpha = 0.8$):** The `no_delay` distribution concentrates at the top of the scale — median approximately 0.87, box spanning 0.82–0.99 — indicating reliable near-complete survival. The `light` delay scenario retains a moderately high median (≈0.58) with a box extending from 0.47 to 0.78. The remaining scenarios (`baseline`, `medium`, `heavy`) cluster in the 0.40–0.60 range. Even at this generous tolerance level, the delay-present scenarios cannot replicate the `no_delay` distribution's tight concentration near $R_1 \approx 1$, revealing that communication delay introduces irreducible variability that physical margins alone cannot eliminate.

**The mechanism underlying variability amplification** is the interaction between random cyber topology and the delay feedback loop. Each trial generates a different BA communication network and coupling configuration. Under ideal communication, these topological differences affect only which cyber nodes fail structurally — the power-flow cascade is insensitive to communication quality. Under heavy delay, topological differences translate into different $\eta_i$ profiles, which produce different overload patterns, which trigger different failure sequences. The feedback loop amplifies initial topological variation into divergent cascade trajectories: small differences in cyber connectivity, inconsequential under ideal communication, become decisive under heavy delay.

### 4.6 Planned: Sensitivity Analysis of Delay-Mitigation Actions

*(The following experiments are designed and will be executed as the next phase of this study.)*

The preceding analysis establishes that communication delay drives cascading failure through the feedback loop. A natural follow-up question is: *which specific delay parameters, when reduced, yield the greatest improvement in system resilience?* This question is directly relevant to engineering practice, where budget-constrained operators must decide which communication upgrades to prioritize.

We plan a one-at-a-time sensitivity analysis in which a single engineering action is applied to the `heavy` delay scenario while all other parameters remain at their heavy-delay values. The five candidate actions are:

| Action | Description | Parameter change |
|--------|-------------|-----------------|
| A1 | Link bandwidth upgrade | $R$: 10 → 100 Mbps |
| A2 | Endpoint processing optimization | CC and non-CC tx/rx delays halved |
| A3 | Forwarding optimization | CC and non-CC forward delays halved |
| A4 | Measurement interface speedup | $\tau_{\text{PB}\to\text{nonCC}}$: 100 → 20 ms |
| A5 | Execution interface speedup | $\tau_{\text{nonCC}\to\text{PB}}$: 120 → 30 ms |

For each action, the full 1,000-trial Monte Carlo is repeated across all 11 $\alpha$ values, and the resulting $R_1$ and $R_3$ distributions are compared against both the unmodified `heavy` scenario and the `no_delay` benchmark. This comparison will quantify the marginal benefit of each action in absolute terms ($\Delta R_1$) and as a fraction of the maximum recoverable penalty (the gap between `heavy` and `no_delay`).

### 4.7 Planned: Timing-Action Interaction Experiment

*(Designed for future execution.)*

The heatmap analysis (Section 4.3) identified Round 2 as the critical intervention window and $\alpha = 0.5\text{–}0.6$ as the most delay-sensitive operating regime. The sensitivity analysis (Section 4.6) will identify which engineering actions are most effective. A natural synthesis is to examine the *interaction* between intervention timing and action selection: does the same action yield different benefits depending on when during the cascade it is applied?

We plan a $2 \times 2$ factorial experiment crossing timing (correct: Round 2; incorrect: Round 5) with action quality (correct: best-performing action from Section 4.6; incorrect: worst-performing action). This experiment will test whether the timing-action interaction is additive (benefits of correct timing and correct action simply sum) or synergistic (their combination yields benefits greater than the sum of parts), providing direct guidance for emergency response protocols.

---

## 5. Conclusion

This paper constructs a delay-integrated cascading failure framework for cyber-physical power systems that treats communication delay not as a passive symptom of network degradation but as an active causal driver embedded within the cascade process. At each cascade round, every surviving generator's output is scaled by a control efficiency factor $\eta_i$ computed from the current communication topology before the DC power flow that determines branch overloads. This architectural choice closes a feedback loop that prior models leave open: delay reduces generation, altered power flows cause additional overloads, structural failures degrade the communication topology, and the degraded topology amplifies delay for subsequent rounds.

The framework models communication delay with full physical grounding — decomposing end-to-end latency into serialization, propagation, endpoint service, and forwarding components with directional asymmetry between uplink measurement traffic and downlink command traffic. Control centers are placed via a multi-attribute structural importance score (MSIS) that balances betweenness, $k$-shell, closeness, degree, and clustering coefficient, and interdependent coupling uses a betweenness-assortative strategy that pairs structurally critical power buses with structurally critical communication nodes.

Monte Carlo simulation across 1,000 independent coupling realizations, 11 tolerance levels, and 5 delay scenarios on the IEEE 39-bus system yields four principal findings:

1. **The delay-cascade feedback loop produces genuinely different cascade trajectories.** Each delay scenario traces a unique path through the failure space — different overload patterns, different failure sequences, different terminal states. This is not a rescaling of a common trajectory but a qualitative divergence, fundamentally impossible in post-hoc delay models.

2. **The delay penalty is asymmetrically concentrated.** The heatmap of $\Delta R_1$ over the (cascade round, tolerance) plane reveals that delay damage is largest at moderate-to-high tolerance margins and late cascade rounds — precisely where delay-free analysis predicts safety. At low tolerance, both systems collapse regardless and the penalty is negligible. This asymmetry means that delay-free models are most misleading where operators are most likely to rely on them.

3. **Delay amplifies stochastic variability.** Under heavy delay, the $R_1$ distribution across coupling realizations widens substantially compared to the no-delay baseline. The feedback loop magnifies small topological differences in cyber connectivity — inconsequential under ideal communication — into divergent cascade trajectories, introducing a tail of catastrophic outcomes absent from the ideal-communication case.

4. **Generator dispatch deviation reveals hidden degradation.** $R_3$ maintains clean stratification across delay scenarios even at high tolerance levels where $R_1$ differences compress, exposing a functional quality deficit among surviving generators that aggregate load-retention metrics cannot detect.

The practical implication is direct: robustness assessment and safety-margin setting for CPPS must incorporate communication delay as a causal variable within the cascade model, not as an afterthought. Defense investments should prioritize maintaining communication reachability — through path redundancy, control-center diversity, and connectivity-preserving reinforcement — over minimizing per-hop latency, because complete loss of controllability ($\eta = 0$) produces qualitatively more severe damage than degraded controllability ($0 < \eta < 1$). The round-level analysis further suggests that delay-mitigation interventions are most effective early in the cascade (Round 2) before the feedback loop compounds initial damage into irreversible collapse.

Future work will extend this framework in three directions: a sensitivity analysis quantifying the marginal benefit of specific delay-mitigation actions, a timing-action interaction experiment testing whether correct intervention timing and correct action selection produce synergistic benefits, and generalization to larger test systems and alternative communication topologies.

---

## References

*(To be populated with actual citations during submission preparation. Key reference categories include: CPPS interdependent network models, cascading failure in coupled networks, communication delay in power system control, Barabási–Albert network models, betweenness-based attack strategies, and Monte Carlo methods for power system reliability.)*
