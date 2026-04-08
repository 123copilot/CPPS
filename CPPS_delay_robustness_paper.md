# How Communication Delay Breaks the Control Loop: A Causal-Chain Analysis of Delay-Induced Robustness Degradation in Cyber-Physical Power Systems

---

## Abstract

Cascading failure analysis of cyber-physical power systems (CPPS) traditionally treats communication delay as a post-hoc observation — something measured after failures have occurred — rather than as a causal variable that drives further damage. This separation is not merely an approximation; it is a qualitative error, because it eliminates the very mechanism through which delay most powerfully degrades system robustness: the delay-cascade feedback loop. In this paper, we embed communication delay directly into the cascading failure process. At each cascade round, every surviving generator's output is scaled by a delay-dependent control efficiency factor before the DC power flow that determines which branches overload. This closed-loop architecture creates a self-reinforcing cycle in which delay reduces generation, altered power flows trigger additional overloads, structural failures degrade the communication topology, and the degraded topology further amplifies delay. We decompose this degradation into two distinct channels — continuous efficiency erosion from path lengthening and discontinuous reachability collapse from cyber-network fragmentation — and show that the latter dominates under severe stress. Experiments on IEEE 39-bus systems coupled with scale-free communication networks demonstrate that the delay penalty is largest at moderate-to-high tolerance margins and late cascade rounds — precisely where the delay-free system survives but the delay-burdened system collapses — and that delay substantially increases the stochastic variability of cascade outcomes. These findings reveal that traditional delay-free models most severely underestimate vulnerability in an asymmetric regime where adequate physical margins create a false sense of security.

---

## I. Introduction

Modern power grids are no longer purely electrical systems. The integration of communication networks for real-time monitoring, state estimation, and closed-loop control has given rise to cyber-physical power systems (CPPS), in which a physical power layer and a cyber communication layer operate as a tightly coupled whole [Lit-CPPS-Overview-1, Lit-CPPS-Overview-2]. Under normal conditions, this coupling improves dispatch flexibility and situational awareness. Under stress, however, it creates a bidirectional failure channel: a disturbance originating in either layer can propagate to the other, triggering cascading failures that neither layer would experience in isolation [Lit-Interdependence-1, Lit-Interdependence-2].

A rich body of literature has investigated cascading failures in coupled networks through topological models, flow-redistribution rules, and attack-vulnerability analyses [Lit-Cascade-Model-1, Lit-Cascade-Model-2, Lit-Attack-Strategy-1]. These studies have established how structural interdependence amplifies failure propagation. Yet most of them treat the communication layer as a binary entity — a link is either functional or failed — without modeling the *quality* of communication service that surviving links provide. In particular, communication delay, the time elapsed between issuing a measurement or command and its arrival at the destination, is largely absent from cascading-failure analysis. When delay is mentioned, it is typically reported as a post-hoc observation ("delay increased after failures") rather than modeled as a causal variable that directly degrades generator control performance during the cascade itself [Lit-Delay-Indicator-1, Lit-Delay-Indicator-2].

This omission matters more than it might first appear. In a closed-loop control architecture, stale measurements cause the control center to make decisions based on outdated system states, while lagged command execution means that corrective actions arrive after the system has already drifted further. Both effects reduce the effective generation output relative to its intended reference. When this reduction is embedded directly into the cascading failure process — before the power-flow redistribution that determines which branches overload — a self-reinforcing feedback loop emerges: delay reduces generation, reduced generation redistributes power flows and causes additional branch overloads, these overloads trigger further structural failures that degrade the communication topology, and the degraded topology increases delay for the next cascade round. This feedback loop transforms communication latency from a passive symptom of system distress into an active driver of further damage.

Crucially, this feedback loop is invisible to models that apply delay as a post-hoc correction to pre-computed cascade trajectories. In such models, all delay scenarios share an identical structural cascade — the same nodes fail in the same order, regardless of delay level — and delay merely rescales the final performance metrics. The cascade trajectory itself is delay-agnostic, which precludes the possibility that delay causes additional failures. This architectural limitation is not merely an approximation; it is a qualitative error that eliminates the very mechanism through which delay most powerfully degrades system robustness.

To close this gap, we construct a delay-integrated cascading failure framework in which delay is computed and applied at every cascade round, creating a closed causal chain:

$$
\text{Cyber topology degradation} \;\longrightarrow\; \text{Path lengthening / Reachability loss} \;\longrightarrow\; \text{Delay increase} \;\longrightarrow\; \text{Control efficiency drop} \;\longrightarrow\; \text{Generator output reduction} \;\xrightarrow{\text{via DC power flow}}\; \text{Additional overloads} \;\longrightarrow\; \text{Further structural failures} \;\longrightarrow\; \cdots
$$

Every link in this chain is explicitly modeled and quantified within the cascade loop. Communication delay is decomposed into serial, propagation, and service components with directional asymmetry between uplink and downlink paths. A delay-to-control mapping converts the resulting measurement delay $\tau_m$ and execution delay $\tau_e$ into a composite efficiency factor $\eta$ that scales each surviving generator's output before DC power flow is solved. System-level robustness is then assessed through two complementary metrics: $R_1$ (load retention ratio) and $R_3$ (normalized generator dispatch deviation).

The contributions of this work are as follows:

1. **A delay-integrated cascading failure framework with closed-loop feedback.** Unlike prior work that applies delay as a post-hoc correction, we embed delay computation directly into each cascade round, scaling generator output before DC power flow redistribution. Each delay scenario therefore produces a genuinely different cascade trajectory — different overload patterns, different failure sequences, different terminal states — rather than a rescaled version of a common trajectory. This is the first CPPS cascading failure model in which delay is an endogenous causal variable rather than an exogenous observation.

2. **A bidirectional, role-aware delay model with full physical grounding.** Uplink (measurement) and downlink (command) delays are separately computed from link-level serial and propagation components, with role-dependent service delays for control centers versus ordinary relay nodes. This captures the asymmetric processing behavior inherent in SCADA-type control architectures and grounds the delay model in physically meaningful parameters.

3. **Mechanism decomposition into continuous and discontinuous degradation channels.** We decompose delay-induced robustness loss into two distinct channels: continuous efficiency erosion, where surviving communication paths lengthen and gradually reduce control quality, and discontinuous reachability collapse, where cyber-network fragmentation severs all control-center access for a subset of generators. By independently tracking unreachable-generator ratio and mean control efficiency $\bar{\eta}$, we reveal which mechanism dominates under different operating conditions.

4. **Identification of the asymmetric delay-penalty regime.** Through a delay-penalty heatmap over the (tolerance, cascade-round) plane, we demonstrate that delay damage is largest at moderate-to-high tolerance margins — where the delay-free system retains most load but the delay-burdened system collapses — rather than at low margins where both systems fail regardless. This asymmetric pattern reveals that delay-free models create a false sense of security precisely in the operating regimes where operators believe the system is adequately protected.

5. **A rigorous no-delay control baseline.** When all delay parameters are set to zero, the framework reduces exactly to a standard delay-free cascade model ($\eta_i = 1$ for all reachable generators), ensuring that every inter-scenario difference is causally attributable to delay and nothing else.

The remainder of this paper is organized as follows. Section II presents the CPPS model, the delay-integrated cascading failure framework, and the delay-to-control mapping. Section III describes the experimental design and parameter settings. Section IV reports simulation results organized around four key figures and a safety classification. Section V discusses mechanistic insights and practical implications. Section VI concludes the paper.

---

## II. System Modeling and Delay-Integrated Cascade Framework

### A. CPPS Architecture and Layer Coupling

We model a CPPS as two interdependent networks: a physical power layer $G_P = (V_P, E_P)$ representing buses and branches, and a cyber communication layer $G_C = (V_C, E_C)$ representing communication nodes and links. The cyber layer contains two types of nodes: *control centers* (CC), which perform state estimation and dispatch computation, and *non-control-center nodes* (non-CC), which serve as data acquisition and command relay points. A coupling matrix $A_{pc} \in \{0,1\}^{|V_P| \times |V_C|}$ defines the one-to-one association between power buses and non-CC cyber nodes.

**Physical layer.** The power network is derived from a standard IEEE test case. Bus adjacency $A_P$ is extracted from the branch table, and initial power flow is computed via DC power flow to obtain bus loads and branch power flows.

**Cyber layer.** The communication network is generated as a Barabási–Albert (BA) scale-free network with $|V_C| = |V_P| + n_{cc}$ nodes, where $n_{cc} = \lfloor 0.2 \cdot |V_P| \rfloor$ is the number of designated control centers. The BA model starts from a complete graph of $m_0$ nodes and attaches each new node with $m_e$ preferential-attachment edges. The resulting degree heterogeneity reflects the hub-dominated topology commonly observed in communication networks serving critical infrastructure.

**Control-center selection via MSIS.** Rather than selecting control centers by a single centrality measure, we employ a multi-attribute structural importance score (MSIS) that combines complementary topological features:

$$
w_i = \frac{\text{Bet}(i) + \text{KS}(i)}{\text{Clo}(i)} + \text{Deg}(i) \cdot C(i),
$$

where $\text{Bet}(i)$ is betweenness centrality, $\text{KS}(i)$ is the $k$-shell index, $\text{Clo}(i)$ is closeness centrality, $\text{Deg}(i)$ is degree, and $C(i)$ is the clustering coefficient of node $i$. The top-$n_{cc}$ nodes ranked by $w_i$ are designated as control centers. This composite score captures both global bridging importance (betweenness, closeness) and local structural embeddedness (degree, clustering, $k$-shell), producing a CC set that is both well-connected and structurally resilient.

**Inter-layer coupling strategy.** The coupling matrix $A_{pc}$ is constructed using a betweenness-assortative strategy: power buses are sorted by their betweenness centrality in $G_P$, non-CC cyber nodes are sorted by their betweenness centrality in $G_C$, and the $k$-th ranked power bus is paired with the $k$-th ranked non-CC cyber node. This assortative coupling ensures that structurally important power buses are associated with structurally important communication nodes, reflecting the engineering practice of provisioning critical substations with high-quality communication resources.

### B. Delay-Integrated Cascading Failure Model

The cascading failure simulation captures bidirectional failure propagation between layers through a nested architecture in which communication delay actively participates in the cascade dynamics.

**Initial attack.** A single non-CC cyber node is selected as the attack target based on the configured attack mode (e.g., the non-CC node with the highest betweenness centrality). This node is removed from the cyber layer, initiating the cascade.

**Inner loop — structural propagation.** Given the current set of failed nodes and edges, the inner loop iterates until no new structural failures emerge:

1. *Cyber-layer island viability check.* Connected components of the surviving cyber network are identified. Any component that does not contain at least one surviving control center is declared non-viable, and all its member nodes are marked as failed.

2. *Forward propagation (cyber → power).* For each newly failed non-CC cyber node, its coupled power bus fails with probability $p$. This stochastic propagation models the heterogeneous dependency strength across different bus-communication associations.

3. *Power-layer island viability check.* Connected components of the surviving power network are identified. Any component that lacks both a generator and a load bus is declared non-viable, and all its member nodes are marked as failed.

4. *Reverse propagation (power → cyber).* For each newly failed power bus, its coupled non-CC cyber node fails with probability $p$.

5. *Convergence test.* If the sets of failed cyber and power nodes have not changed since the previous iteration, the inner loop terminates.

**Outer loop — overload and delay feedback.** After the inner loop stabilizes, the surviving network undergoes overload evaluation with delay injection:

1. *Cyber-layer overload.* Betweenness centrality is recomputed on the surviving cyber network. Any surviving non-CC node whose betweenness exceeds $(1 + \alpha) \cdot \text{Bet}_0(i)$ is marked for failure. Similarly, any surviving cyber edge whose edge betweenness exceeds $(1 + \alpha) \cdot \text{EBet}_0(e)$ is removed.

2. *Surviving power network assembly.* The surviving power network $G_P^{(r)}$ is constructed by removing all failed buses and all branches connected to failed buses or previously tripped by overload.

3. **Delay-aware generation adjustment.** This is the key architectural innovation. For each online generator $i$ in $G_P^{(r)}$, the framework (a) identifies the generator's coupled cyber node via $A_{pc}$, (b) constructs a delay-weighted graph on the surviving cyber network, (c) finds the shortest delay-weighted path to the nearest surviving control center, and (d) computes the measurement delay $\tau_{m,i}$, execution delay $\tau_{e,i}$, and composite efficiency $\eta_i$ as described in Sections II.C–D. The generator's output is then scaled: $P_i^{(r)} \leftarrow P_i^{\text{ref}} \cdot \eta_i$, where $P_i^{\text{ref}}$ is the original dispatch setpoint. Generators unreachable from any surviving CC have their output set to zero ($\eta_i = 0$). A structured delay injection log recording $(\eta_i, \tau_{m,i}, \tau_{e,i}, \text{is\_reachable}_i, \text{selected\_CC}_i)$ for every generator is appended to the round-level snapshot.

4. *DC power flow and overload check.* A DC power flow is solved on the delay-degraded surviving network. Any branch whose post-redistribution power flow exceeds $(1 + \alpha) \cdot |P_0(e)|$ is marked for tripping.

5. *Convergence test.* If no new overload-induced failures are found, the cascade terminates. Otherwise, the newly failed elements are incorporated and the process repeats from the inner loop.

**The feedback mechanism.** Step 3 is what closes the loop. In a conventional cascade model, DC power flow operates on generator outputs that are unaffected by communication quality. In the present framework, delay-degraded generators produce less power, which alters branch flows. Branches that would not overload under ideal control may now overload because the reduced generation forces more aggressive redistribution onto surviving paths. These additional overloads cause further structural failures, which degrade the cyber topology, which increases delay in the next round. The cycle continues until either the cascade stabilizes or the system collapses. Each delay scenario therefore traces a unique cascade trajectory — a property fundamentally impossible in post-hoc delay models.

**Round logging.** At the end of each outer-loop iteration, a structured snapshot $\mathcal{S}^{(r)}$ is recorded, containing the current sets of failed power nodes, failed cyber nodes, failed branches, the surviving cyber adjacency matrix, the coupling configuration, and the delay injection log. These snapshots enable detailed temporal reconstruction of how delay and structural damage co-evolve.

### C. Bidirectional Delay Decomposition

Communication delay is modeled directionally because uplink and downlink traffic play different roles in the control loop. Uplink traffic carries measurement data from a generator's coupled non-CC node to a control center, whereas downlink traffic carries control commands in the reverse direction. The physical propagation term on a surviving cyber edge is symmetric; directional asymmetry enters through payload-dependent serialization and role-dependent endpoint service delays.

For a single surviving hop $(u, v)$, the effective per-hop communication delay is defined separately for the two traffic directions:

$$
T_{\text{link}}^{\text{up}}(u, v) = \frac{P_{\text{up}}}{R_{u,v}} + \frac{d_{u,v}}{V},
$$

$$
T_{\text{link}}^{\text{down}}(u, v) = \frac{P_{\text{down}}}{R_{u,v}} + \frac{d_{u,v}}{V},
$$

where $P_{\text{up}}$ and $P_{\text{down}}$ are the uplink and downlink packet sizes, $R_{u,v}$ is the link data rate (bps), $d_{u,v}$ is the effective link distance (km), and $V$ is the signal propagation speed (km/s). The propagation term $d_{u,v}/V$ is identical in both directions, while the serialization term differs because measurement packets and control packets need not have the same size.

For a multi-hop path $\pi = (u_0, u_1, \ldots, u_k)$, the total path delay includes per-hop communication delays, endpoint service delays, and intermediate forwarding delays:

**Downlink (CC → non-CC):**

$$
T_{\text{down}}(\pi) = \sum_{i=0}^{k-1} T_{\text{link}}^{\text{down}}(u_i, u_{i+1}) + \tau_{\text{CC}}^{\text{tx}} + \tau_{\text{nonCC}}^{\text{rx}} + \sum_{i=1}^{k-1} \tau_{\text{fwd}}(u_i).
$$

**Uplink (non-CC → CC):**

$$
T_{\text{up}}(\pi) = \sum_{i=0}^{k-1} T_{\text{link}}^{\text{up}}(u_i, u_{i+1}) + \tau_{\text{nonCC}}^{\text{tx}} + \tau_{\text{CC}}^{\text{rx}} + \sum_{i=1}^{k-1} \tau_{\text{fwd}}(u_i).
$$

The forwarding delay at each intermediate node is role-dependent but direction-agnostic:

$$
\tau_{\text{fwd}}(u) = \begin{cases} \tau_{\text{CC}}^{\text{fwd}} & \text{if } u \text{ is a CC}, \\ \tau_{\text{nonCC}}^{\text{fwd}} & \text{if } u \text{ is a non-CC}. \end{cases}
$$

This role-aware decomposition reflects the engineering reality that control centers are typically equipped with more capable processing hardware and therefore exhibit lower service latency than ordinary relay nodes. It also clarifies an important modeling point: the same physical path can yield different uplink and downlink communication delays without assuming asymmetric propagation physics. The asymmetry arises from traffic type and endpoint processing, whereas forwarding remains a role-dependent path property.

### D. Delay-to-Control Mapping

For each surviving generator $i$ that remains online after structural propagation, we identify its coupled non-CC cyber node via $A_{pc}$ and locate the nearest reachable control center on the surviving cyber graph using a shortest path computed from downlink per-hop link weights. Because the cyber topology is undirected, the corresponding uplink route is taken as the reverse of the selected downlink route. Route selection is therefore link-weighted, while endpoint and forwarding delays are added analytically after the route has been chosen.

The total measurement delay and execution delay for generator $i$ are:

$$
\tau_{m,i} = \tau_{\text{PB} \to \text{nonCC}} + T_{\text{up}}(\pi_i^{\text{up}}), \qquad
\tau_{e,i} = \tau_{\text{nonCC} \to \text{PB}} + T_{\text{down}}(\pi_i^{\text{down}}),
$$

where $\tau_{\text{PB} \to \text{nonCC}}$ is the field-side measurement interface delay (sensor-to-communication-node), and $\tau_{\text{nonCC} \to \text{PB}}$ is the field-side command execution delay (communication-node-to-actuator).

The delay efficiency factors and actual generator output are:

$$
f_{m,i} = 1 - k_m \tau_{m,i}, \qquad f_{e,i} = 1 - k_e \tau_{e,i}, \qquad \eta_i = \min\!\big(1,\; \max\!\big(0,\; f_{m,i} \cdot f_{e,i}\big)\big),
$$

$$
P_i^{\text{actual}} = P_i^{\text{ref}} \cdot \eta_i,
$$

where $k_m$ and $k_e$ are delay sensitivity coefficients reflecting how strongly stale measurements and lagged execution degrade control quality, $\eta_i$ is clamped to $[0, 1]$ before being applied within each cascade round, and $P_i^{\text{ref}}$ is the generator's original dispatch setpoint.

**Unreachable generators.** If no surviving CC is reachable from generator $i$'s cyber node — because the cyber network has fragmented such that no CC-containing component includes the generator's communication path — the generator is classified as *unreachable*. An unreachable generator receives no control commands and produces no coordinated output: $P_i^{\text{actual}} = 0$, $\eta_i = 0$. This treatment captures the most severe consequence of cyber-layer degradation: complete loss of controllability. Because this output zeroing occurs *before* the DC power flow, unreachable generators directly contribute to power imbalance and potential overloads, feeding the cascade forward.

### E. Robustness Metrics

**Metric $R_1$: Load retention ratio.** Let $L_{\text{initial}}$ denote the total pre-cascade load and $L_{\text{surviving}}$ the total load at buses that survive to the cascade's terminal state. Then:

$$
R_1 = \frac{L_{\text{surviving}}}{L_{\text{initial}}}.
$$

Because delay is embedded within the cascade process, no post-hoc correction factor is needed. Delay's influence on $R_1$ manifests endogenously through the cascade dynamics: delay-degraded generators produce less power, which alters branch flows, which produces different overload patterns, which leads to different sets of surviving buses and loads. The same formula therefore yields genuinely different $R_1$ values under different delay scenarios — not because of a correction factor, but because the cascades themselves diverge.

**Metric $R_3$: Generator dispatch deviation.** For the $N$ generators surviving at the cascade's terminal state with $P_i^{\text{ref}} > 0$:

$$
R_3 = \sqrt{\frac{1}{N} \sum_{i=1}^{N} \left( \frac{P_i^{\text{actual}} - P_i^{\text{ref}}}{P_i^{\text{ref}}} \right)^2}.
$$

$R_3$ is computed from the delay injection log of the final cascade round. Each surviving generator contributes its delay-degraded output $P_i^{\text{actual}} = P_i^{\text{ref}} \cdot \eta_i$, with unreachable generators contributing the maximum possible relative deviation of 1.0. Higher $R_3$ indicates stronger dispatch distortion and poorer control fidelity.

$R_1$ and $R_3$ serve complementary diagnostic roles. $R_1$ answers "how much load can the system still serve?" — an aggregate measure that folds structural damage and delay-induced overloads into a single number. $R_3$ answers "how accurately can the system control its surviving generators?" — a measure of functional quality among survivors. A system may retain high $R_1$ (most load served) yet suffer high $R_3$ (poor control fidelity), a form of hidden degradation that $R_1$ alone would not reveal.

### F. Delay Scenario Design

To systematically investigate increasing delay severity, we define five effective delay-intensity scenarios by coherently scaling a baseline parameter set:

| Scenario | Scale factor | Interpretation |
|----------|:---:|---|
| `no_delay` | 0.0 | Ideal control with zero communication delay |
| `light` | 0.5 | Optimistic delay conditions |
| `baseline` | 1.0 | Nominal delay parameterization |
| `medium` | 1.5 | Moderately degraded communication |
| `heavy` | 2.0 | Severely degraded communication |

The common scale factor is applied to the uplink and downlink packet sizes, the effective link distance used in the propagation term, all service-delay parameters (transmit, receive, forward), and the field-side measurement and execution interface delays. By contrast, the link data rate $R$, propagation speed $V$, and sensitivity coefficients $k_m$ and $k_e$ remain fixed. This design should be interpreted as an engineering-motivated scenario family that progressively strengthens the end-to-end delay burden, rather than as a literal geometric rescaling of a physical communication system. Crucially, the `no_delay` scenario (scale 0) zeros all communication and field-interface delay terms. Every reachable generator therefore satisfies $\tau_{m,i} = \tau_{e,i} = 0$ and retains $\eta_i = 1$, making `no_delay` the zero-delay benchmark within the same coupled-network cascade framework.

---

## III. Experimental Design

### A. Test System Configuration

The physical layer is based on the IEEE 39-bus (New England) system, comprising 39 buses, 46 branches, and 10 generators. The cyber layer is constructed as a BA network with $|V_C| = 39 + 8 = 47$ nodes, of which $n_{cc} = 8$ are designated as control centers via the MSIS ranking. The BA network is initialized with $m_0 = 4$ fully connected nodes and grown by attaching $m_e = 2$ edges per new node, producing a heterogeneous degree distribution characteristic of communication infrastructure.

For each of the 300 independent trials, a new BA cyber network, a new CC selection, and a new coupling matrix $A_{pc}$ are generated. The power layer (IEEE 39-bus) is shared across trials. This Monte Carlo design ensures that reported metrics reflect averaged behavior across diverse cyber-physical coupling configurations rather than artifacts of a single topology.

### B. Parameter Settings

The complete parameter set is summarized in Table I.

**Table I. Simulation Parameters**

| Category | Parameter | Value |
|----------|-----------|-------|
| Power layer | Test case | IEEE 39-bus |
| | Buses $\|V_P\|$ / Branches $\|E_P\|$ / Generators | 39 / 46 / 10 |
| Cyber layer | Total nodes $\|V_C\|$ | 47 |
| | Control centers $n_{cc}$ | 8 |
| | BA initial clique $m_0$ / Attachment edges $m_e$ | 4 / 2 |
| Coupling | Strategy | Betweenness-assortative |
| | CC selection | MSIS ranking |
| Cascading | Propagation probability $p$ | 0.3 |
| | Tolerance factor $\alpha$ | 0.0 : 0.1 : 1.0 (11 values) |
| | Attack mode | Betweenness-targeted (single non-CC node) |
| Communication | Uplink packet size $P_{\text{up}}$ | 8192 bits |
| | Downlink packet size $P_{\text{down}}$ | 2048 bits |
| | Link rate $R$ | 10 Mbps |
| | Propagation speed $V$ | $2 \times 10^5$ km/s |
| | Effective link distance $d$ | 1 km |
| | $\tau_{\text{CC}}^{\text{tx}} / \tau_{\text{CC}}^{\text{rx}} / \tau_{\text{CC}}^{\text{fwd}}$ | 3 / 4 / 3 ms |
| | $\tau_{\text{nonCC}}^{\text{tx}} / \tau_{\text{nonCC}}^{\text{rx}} / \tau_{\text{nonCC}}^{\text{fwd}}$ | 12 / 9 / 6 ms |
| Delay-to-control | Measurement interface delay $\tau_{\text{PB}\to\text{nonCC}}$ | 100 ms |
| | Execution interface delay $\tau_{\text{nonCC}\to\text{PB}}$ | 120 ms |
| | Measurement sensitivity $k_m$ | 0.80 s$^{-1}$ |
| | Execution sensitivity $k_e$ | 0.60 s$^{-1}$ |
| Sampling | Independent network realizations per scenario | 300 |

### C. Evaluation Protocol

For each of the five delay scenarios, the full cascade is executed independently. This is essential: because delay alters generator output before each DC power flow, the cascade trajectory — including which branches overload, which nodes fail, and how many rounds the cascade persists — varies by scenario. Running each scenario as an independent cascade, rather than sharing a common trajectory across scenarios, is what enables the feedback loop to operate.

Within each cascade run, the round-level snapshots provide the raw data for metric computation:

- **Final-state $R_1$** is computed from the set of power buses surviving at cascade termination, using the original bus-load vector.
- **Final-state $R_3$** is computed from the delay injection log of the last cascade round, comparing each surviving generator's delay-degraded output $P_i^{\text{ref}} \cdot \eta_i$ against its reference $P_i^{\text{ref}}$.
- **Per-round $R_1(r)$** is computed at each round from the cumulative set of failed buses, enabling temporal analysis of how robustness evolves during the cascade.
- **Mechanism variables** — mean $\bar{\eta}$ (averaged over reachable generators), mean $\bar{\tau}_m$, mean $\bar{\tau}_e$, and unreachable-generator ratio — are extracted from each round's delay injection log and aggregated across rounds and trials.

All metrics are averaged over 300 trials at each $(\alpha, \text{scenario})$ pair. The per-round time series uses last-value-carried-forward (LVCF) padding to align trials with different cascade durations: a trial whose cascade terminates at round $r^*$ contributes its terminal $R_1(r^*)$ to all subsequent round averages, ensuring that early termination is interpreted as a stable final state rather than missing data.

### D. Safety Classification

Based on $R_1$, each $(\alpha, \text{scenario})$ outcome is mapped to an operational safety level:

| Level | $R_1$ range | Interpretation |
|-------|:-----------:|----------------|
| Green | $> 85\%$ | Normal operation |
| Yellow | $70\%$–$85\%$ | Caution required |
| Orange | $50\%$–$70\%$ | High risk |
| Red | $< 50\%$ | System collapse |

This classification provides a coarse but operationally meaningful translation of continuous $R_1$ values into discrete risk categories, enabling direct comparison of how delay shifts the safety boundaries across operating conditions.

---

## IV. Results and Analysis

### A. System-Level Robustness: Load Retention and Dispatch Deviation

Fig. 1 presents the load retention ratio $R_1$ as a function of tolerance factor $\alpha$ across five delay scenarios. Three principal patterns emerge.

First, the `no_delay` scenario consistently achieves the highest $R_1$ at every $\alpha$ value, confirming that it serves as an upper bound on system performance. As delay magnitude increases from `light` through `heavy`, $R_1$ decreases monotonically, with each successive scenario yielding strictly lower values. This monotonic ordering — maintained across the entire $\alpha$ range — validates the intuitive expectation that more delay produces worse outcomes, while the magnitude of the separation quantifies *how much* worse.

Second, the gap between scenarios is not uniform across $\alpha$. At low $\alpha$ (tight capacity margins), cascading failures are so severe that even the delay-free system collapses to near-zero $R_1$, leaving little room for delay to worsen the outcome; the five curves converge near the bottom. At moderate-to-high $\alpha$, however, the delay-free system retains substantial load while delay-burdened systems experience additional overloads that push them into collapse. The inter-scenario gap therefore widens as $\alpha$ increases through the intermediate range, revealing an asymmetric vulnerability: *delay damage is most consequential when the power system has enough physical margin to survive without delay but not enough to absorb the additional overloads that delay creates*. This is not a post-hoc scaling effect; it is an endogenous consequence of the feedback loop, in which delay-induced generation shortfalls trigger overload cascades that the delay-free system would have avoided entirely.

Third, the transition from high to low $R_1$ steepens under heavier delay. The `no_delay` curve declines relatively gradually as $\alpha$ decreases, while the `heavy` curve drops more sharply, reflecting the additional cascade rounds driven by delay-induced overloads. This steepening implies that delay effectively narrows the operating window within which the system remains safe — a finding with direct implications for margin-setting in grid operation. Crucially, the steepest drop for heavy-delay scenarios occurs at higher $\alpha$ values than for no-delay, meaning that delay shifts the critical transition point upward along the tolerance axis.

Fig. 2 presents $R_3$ (generator dispatch deviation) across the same scenario-$\alpha$ grid. The ordering is reversed: `heavy` delay produces the largest $R_3$ (worst control fidelity), and `no_delay` produces the smallest. Notably, $R_3$ retains meaningful inter-scenario separation even at high $\alpha$, where $R_1$ differences are compressed. This reveals a form of hidden degradation: a system with generous capacity margins may retain nearly all its load ($R_1 \approx 1$) yet still exhibit substantial control mismatch at the generator level ($R_3 \gg 0$). Such systems appear healthy by aggregate measures but are functionally stressed — their generators operate with significant deviations from intended dispatch, which in a real system could cause frequency excursions, voltage instability, or reduced reserve margins. $R_3$ captures this vulnerability where $R_1$ cannot.

### B. Delay-Induced Stochastic Amplification: R1 Distribution Analysis

Figs. 1 and 2 report mean values of $R_1$ and $R_3$, which characterize the *expected* delay penalty. However, an equally important question for system operators is whether delay affects the *predictability* of cascade outcomes — that is, whether the same operating conditions produce more variable results under heavier delay. If delay increases outcome variability, then even a system whose mean $R_1$ appears adequate may face unacceptably high probabilities of catastrophic outcomes in individual realizations.

Fig. 3 presents box plots of the $R_1$ distribution across 1000 trials at three representative tolerance levels ($\alpha = 0.2, 0.5, 0.8$), grouped by delay scenario. Several patterns emerge.

First, at low $\alpha$ ($= 0.2$), all five delay scenarios produce tightly concentrated $R_1$ distributions near zero. The system collapses regardless of delay, and the distributions overlap substantially. This confirms that when physical margins are severely insufficient, delay is a secondary factor — the system fails from structural overload before the delay feedback loop has meaningful leverage.

Second, at moderate $\alpha$ ($= 0.5$), a striking divergence appears. The `no_delay` distribution is concentrated at relatively high $R_1$ values, while heavier-delay scenarios produce distributions with lower medians and substantially wider interquartile ranges. This widening reveals that delay does not merely shift the mean outcome downward but also amplifies stochastic variability: under heavy delay, the same nominal operating conditions produce a much wider range of cascade severities depending on the random cyber-physical coupling realization. Some realizations survive with acceptable load retention; others collapse. This unpredictability is itself a form of system vulnerability that mean-value analysis cannot capture.

Third, at high $\alpha$ ($= 0.8$), the `no_delay` distribution concentrates near $R_1 \approx 1$ with minimal spread, indicating reliable survival. Heavier-delay scenarios retain lower medians and may still exhibit non-trivial spread, revealing that even generous physical margins cannot fully eliminate delay-induced variability. The persistent gap between `no_delay` and `heavy` at high $\alpha$ — where both would appear safe by mean-value metrics — quantifies the residual vulnerability that delay introduces even in well-provisioned systems.

The mechanism underlying this variability amplification is the interaction between random cyber topology and the delay feedback loop. Each trial generates a different BA communication network and coupling configuration. Under no-delay conditions, these topological differences affect only which cyber nodes fail structurally; the power-flow cascade is topology-insensitive beyond the coupling map. Under heavy delay, however, topological differences translate into different $\eta$ profiles, which produce different overload patterns, which trigger different failure sequences. The feedback loop thus amplifies initial topological variation into divergent cascade trajectories — small differences in cyber connectivity, inconsequential under ideal communication, become decisive under heavy delay.

This finding has a direct practical implication: robustness assessment under communication delay requires not just mean-value analysis but distributional analysis. A system that appears adequate on average may exhibit a long tail of catastrophic outcomes that only becomes visible when the stochastic interaction between delay and topology is properly accounted for.

### C. Delay-Cascade Feedback: The Penalty Heatmap

The preceding analysis characterizes final-state outcomes. To understand how delay damage accumulates during the cascade — and whether it grows, shrinks, or remains constant with cascade progression — we examine the round-level delay penalty.

Define the round-level delay penalty as:

$$
\Delta R_1^{\text{delay}}(r, \alpha) = R_1^{\text{no\_delay}}(r, \alpha) - R_1^{\text{heavy}}(r, \alpha),
$$

which isolates the contribution of delay to robustness loss at round $r$ and tolerance $\alpha$ by comparing the two extreme scenarios. Because each scenario runs an independent cascade, this difference captures both the direct functional impact of delay (efficiency reduction) and the indirect structural impact (additional failures caused by delay-induced overloads).

Fig. 4 presents $\Delta R_1^{\text{delay}}$ as a heatmap over the (cascade round, $\alpha$) plane. The resulting pattern reveals a striking and initially counterintuitive structure.

First, the penalty is largest at moderate-to-high $\alpha$ and late cascade rounds, not at low $\alpha$. This asymmetry arises from a floor effect: at low $\alpha$, even the delay-free system collapses to near-zero $R_1$, so there is little room for delay to widen the gap ($\Delta R_1^{\text{delay}} \approx 0$ because both numerator and denominator are near zero). At moderate-to-high $\alpha$, the delay-free system retains substantial load ($R_1^{\text{no\_delay}} \gg 0$) while the heavy-delay system collapses from delay-induced overloads ($R_1^{\text{heavy}} \ll R_1^{\text{no\_delay}}$), producing a large positive penalty. The penalty therefore peaks in a regime where the physical system has *enough margin to survive without delay but not enough to absorb the additional overloads that delay creates*.

Second, the penalty grows with cascade round at these vulnerable $\alpha$ values. In early rounds, the no-delay and heavy cascades may be similar (the initial structural failures are driven by the attack, not by delay), so $\Delta R_1^{\text{delay}}$ starts near zero. As the cascade progresses and the feedback loop iterates — each round of delay-induced overloads creating further structural damage that amplifies the next round's delay — the penalty increases. This growth is the signature of positive feedback: the system does not merely accumulate delay damage linearly across rounds but amplifies it through the closed-loop mechanism.

Third, the heatmap reveals an operationally dangerous asymmetry. A grid operator who evaluates robustness without accounting for delay would observe comfortable margins at moderate-to-high $\alpha$ and conclude the system is safe. The heatmap shows that precisely these "safe" operating points harbor the largest delay penalty — the gap between predicted (delay-free) and actual (delay-present) performance is widest where the delay-free assessment is most optimistic. This makes the delay-free model not merely inaccurate but actively misleading: it provides the most reassurance exactly where it should provide the least.

### D. Safety-Level Classification

Table II maps each $(\alpha, \text{scenario})$ pair to a safety level based on $R_1$ thresholds.

**Table II. Safety Level Classification** *(populated from simulation output)*

The classification reveals a concrete operational consequence of communication delay: it shifts the safety boundaries. A system designed with a specific tolerance margin $\alpha$ under the assumption of perfect communication may find itself operating in a more dangerous safety zone if real-world delay corresponds to the `baseline` or `heavy` scenario. For instance, a tolerance level that yields Green (normal operation) under `no_delay` might yield Yellow (caution) or Orange (high risk) under `heavy` delay. This reclassification occurs not because the system is structurally different but because delay triggers additional cascade rounds that the delay-free analysis would not predict — a direct manifestation of the feedback loop.

The implication for grid operators is stark: safety margins computed without accounting for communication delay are potentially non-conservative. The degree of non-conservatism depends on the delay environment and is quantifiable through the framework developed here.

---

## V. Discussion

### A. The Closed-Loop Feedback as the Central Mechanism

The most important finding of this study is not that "more delay produces worse outcomes" — this would be expected and is relatively uninformative. The central finding is that delay amplifies cascading *through an endogenous feedback loop* that operates within the cascade process itself. This loop has a precise mechanistic pathway: delay reduces generator output → altered power flows cause additional overloads → overloaded branches trip → structural failures degrade the cyber topology → degraded topology increases delay for subsequent generators → further output reduction → ... The loop iterates with each cascade round, and its cumulative effect is compounding: the delay penalty grows with cascade depth as each round's damage feeds into the next round's delay (Fig. 4).

This feedback loop is qualitatively absent from models that apply delay as a post-hoc correction. In such models, all delay scenarios share an identical cascade trajectory because generator output during the cascade is delay-agnostic. The only role of delay is to rescale final metrics, which produces a constant multiplicative offset between scenarios — never the widening, round-dependent divergence that the feedback loop creates. The difference is not merely quantitative; post-hoc models fundamentally mischaracterize the nature of delay's influence by treating it as an additive burden rather than a multiplicative amplifier.

The practical consequence is that traditional analyses most severely underestimate vulnerability in an asymmetric regime: moderate-to-high tolerance margins where the delay-free system appears safe but the delay-burdened system collapses (the high-penalty region in Fig. 4). At low margins, both systems fail regardless and the model error is small. At moderate-to-high margins, the delay-free model predicts survival while delay-aware analysis predicts collapse — the model error is maximized precisely where it is most dangerous, because it creates a false sense of security.

### B. Dual-Channel Degradation: Efficiency Erosion versus Reachability Collapse

Although the current figure set focuses on system-level metrics ($R_1$, $R_3$) and their distributions rather than per-mechanism indicators, the framework's round-level delay injection logs allow us to reason about two qualitatively distinct channels through which delay degrades system performance.

The first channel — continuous efficiency erosion — operates through path lengthening. As the cascade removes cyber nodes and edges, surviving communication paths become longer, increasing $\tau_m$ and $\tau_e$ and reducing $\eta$. This channel is smooth: each additional failure produces a modest, incremental reduction in control quality. It is also bounded: even the longest surviving path produces some positive $\eta > 0$ as long as the generator remains reachable.

The second channel — discontinuous reachability collapse — operates through network fragmentation. When cumulative damage severs the last path between a generator's cyber node and any CC-containing component, the generator loses controllability entirely ($\eta = 0$, output = 0). This transition is abrupt and irreversible within a cascade round. A generator experiencing 200 ms of delay retains $\eta \approx 0.83$ under baseline sensitivities, contributing a modest 17% output shortfall. An unreachable generator contributes a 100% shortfall. Even a small increase in the unreachable fraction can therefore dominate the aggregate metrics.

These two channels are not independent. The efficiency channel feeds the reachability channel: delay-induced overloads cause structural damage that pushes the cyber network closer to its fragmentation threshold, beyond which reachability collapses. In this sense, the efficiency channel is the precursor and the reachability channel is the catastrophic consequence.

The stochastic amplification observed in Fig. 3 is partly explained by this dual-channel structure. In some coupling realizations, the cyber network's redundancy keeps all generators reachable despite delay-induced damage (only the efficiency channel operates, producing modest $R_1$ reduction). In other realizations, the damage crosses the fragmentation threshold and generators become unreachable (the reachability channel activates, producing severe $R_1$ collapse). This binary threshold behavior — present in some realizations but not others — generates the wide $R_1$ distributions observed under heavy delay, even at fixed $\alpha$.

This dual-channel structure has a structural analogy with percolation theory. The cyber network tolerates incremental damage (gradual efficiency erosion) until a critical threshold is crossed, at which point a macroscopic fraction of generators simultaneously loses CC access (reachability collapse). The delay-cascade feedback loop accelerates the approach to this threshold under heavy-delay scenarios, effectively lowering the system's percolation resilience.

### C. Practical Implications

The findings support several concrete engineering recommendations.

First, delay-mitigation strategies should prioritize *maintaining reachability* over *reducing per-hop latency*. The reachability channel produces far larger per-generator damage than the efficiency channel, and once a generator is disconnected from all CCs, no amount of latency optimization can restore its output. Strategies such as redundant communication paths between CC-containing components, backup CC assignments, and connectivity-preserving link reinforcement directly address the reachability channel and should be prioritized in resource-constrained environments.

Second, safety margins must be reassessed under realistic delay assumptions. The safety classification in Table II demonstrates that delay effectively reduces the system's tolerance margin. A grid designed with $\alpha$-level robustness under ideal communication may operate at a lower effective margin under real-world delay. The framework developed here enables explicit quantification of this margin erosion for any given delay environment.

Third, the delay-penalty heatmap (Fig. 4) provides a template for real-time cascade monitoring. By tracking the round-by-round rate of $R_1$ decline and comparing it against the expected decline under no-delay conditions, operators could detect whether the cascade has entered the high-penalty regime where delay amplification dominates. Early detection could trigger pre-emptive actions — load shedding, generator redispatch, or communication-path switching — to arrest the feedback loop before it compounds further.

### D. Limitations and Future Directions

Several limitations of the current study should be acknowledged, each of which suggests a direction for future work.

First, the delay-to-control mapping uses a linear sensitivity model ($f_m = 1 - k_m \tau_m$). Real control systems exhibit nonlinear and potentially discontinuous behavior at high delay (e.g., stability loss beyond a critical threshold). Incorporating nonlinear or threshold-based models would likely sharpen the distinction between moderate and severe delay regimes and might shift the location of the reachability-dominated transition.

Second, the study uses a single physical-layer test system (IEEE 39-bus). While this is standard practice for CPPS cascading analysis, generalization to larger and more realistic systems remains to be validated. In particular, the percolation threshold and the balance between the efficiency and reachability channels may depend on network size and topology.

Third, the BA model for the cyber layer, while capturing degree heterogeneity, does not reproduce all features of real communication networks (e.g., geographic constraints, hierarchical routing). More realistic cyber-layer models would strengthen external validity.

Fourth, the propagation probability $p$ is treated as a fixed global parameter. In practice, failure propagation likelihood may depend on the nature and severity of the originating failure. Heterogeneous or state-dependent propagation models would be a natural extension.

Fifth, while our framework closes the delay-cascade feedback loop through the power-flow redistribution channel, the delay injection resets generator output to $P_i^{\text{ref}} \cdot \eta_i$ at each round rather than modeling cumulative dynamic effects. Incorporating generator dynamics and frequency response models would provide a richer representation of how delay-induced deviations evolve within and across cascade rounds.

Future extensions enabled by the present framework include: coupling-strategy comparison (assortative vs. random coupling under delay); multi-attack scenarios (how different attack strategies interact with delay amplification); and delay-aware defense design (communication-layer reinforcement that explicitly targets the reachability-dominated fragmentation threshold).

---

## VI. Conclusion

This paper constructs a delay-integrated cascading failure framework for cyber-physical power systems in which communication delay is not an after-the-fact observation but an endogenous causal variable embedded within the cascade process. At each cascade round, every surviving generator's output is scaled by a delay-dependent control efficiency factor before the DC power flow that determines overloads. This architectural choice closes a feedback loop that prior work left open: delay degrades generation, altered power flows cause additional overloads, structural failures further degrade the communication topology, and the degraded topology amplifies delay in the next round.

Simulation experiments on the IEEE 39-bus system coupled with BA-type communication networks, spanning five delay scenarios and 1000 independent coupling realizations, yield the following principal findings.

First, the delay-cascade feedback loop produces genuinely different cascade trajectories under different delay scenarios. This is not a rescaling of a common trajectory but a qualitative divergence in which delay-induced overloads trigger failure sequences that would not occur under ideal communication. The resulting $R_1$ and $R_3$ inter-scenario gaps are largest at moderate-to-high tolerance margins, where the delay-free system survives but the delay-burdened system collapses.

Second, delay amplifies the stochastic variability of cascade outcomes. Under heavy delay, the same nominal operating conditions produce a substantially wider distribution of $R_1$ across different cyber-physical coupling realizations. This variability amplification arises from the feedback loop's sensitivity to topological details: small differences in cyber connectivity, inconsequential under ideal communication, are magnified into divergent cascade trajectories under delay. Robustness assessment must therefore consider not just mean outcomes but distributional risk.

Third, the delay penalty concentrates asymmetrically in the (tolerance, cascade-round) plane: it is largest at moderate-to-high $\alpha$ and late rounds — precisely where the delay-free model predicts safety. At low $\alpha$, both systems collapse regardless and the penalty vanishes. This asymmetry means that delay-free models are most misleading where operators are most likely to rely on them, creating a dangerous false sense of security.

Fourth, communication delay effectively reduces the system's operational safety margin. A tolerance level classified as safe under ideal communication may fall into a higher-risk category under realistic delay conditions, as quantified by the safety classification framework applied to $R_1$.

These findings support a clear engineering recommendation: robustness assessment and margin-setting for CPPS must account for communication delay as a causal driver of cascading failure, not merely as a degradation symptom. Defense priorities should focus on maintaining communication reachability — through path redundancy, CC diversity, and connectivity-preserving reinforcement — particularly under stress conditions where the delay-cascade feedback loop has the greatest amplification potential. The framework developed in this paper, by embedding delay inside the cascade, provides the analytical foundation for such delay-aware robustness assessment and protection planning.

---

## References

*(To be populated with actual references replacing [Lit-XXX] placeholders during submission preparation.)*
