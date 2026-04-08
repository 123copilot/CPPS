function action_scenarios = createSensitivityActionConfigs(base_delay_cfg)
%CREATESENSITIVITYACTIONCONFIGS 创建5个敏感性实验动作的时延配置。
%
% 每个动作基于 heavy 场景 (scale=2.0)，仅修改一个参数组，
% 用于评估哪个工程改进对系统韧性提升最大。
%
% 动作列表:
%   A1: 链路带宽升级      10 Mbps -> 100 Mbps
%   A2: 端点处理优化       tx/rx 延迟减半 (相对于heavy)
%   A3: 转发优化           forward 延迟减半 (相对于heavy)
%   A4: 测量接口加速       pb_to_noncc: 200ms -> 20ms
%   A5: 执行接口加速       noncc_to_pb: 240ms -> 30ms
%
% 输入: base_delay_cfg - createDelayConfig() 返回的基础配置
% 输出: action_scenarios - 结构体数组，每个元素包含 name, cfg, description

heavy_scale = 2.0;

% 先生成 heavy 基准配置
heavy_cfg = base_delay_cfg;
heavy_cfg.communication.packet_size_bits_up   = base_delay_cfg.communication.packet_size_bits_up * heavy_scale;
heavy_cfg.communication.packet_size_bits_down = base_delay_cfg.communication.packet_size_bits_down * heavy_scale;
heavy_cfg.communication.default_distance_km   = base_delay_cfg.communication.default_distance_km * heavy_scale;
heavy_cfg.service.cc.tx      = base_delay_cfg.service.cc.tx * heavy_scale;
heavy_cfg.service.cc.rx      = base_delay_cfg.service.cc.rx * heavy_scale;
heavy_cfg.service.cc.forward = base_delay_cfg.service.cc.forward * heavy_scale;
heavy_cfg.service.noncc.tx      = base_delay_cfg.service.noncc.tx * heavy_scale;
heavy_cfg.service.noncc.rx      = base_delay_cfg.service.noncc.rx * heavy_scale;
heavy_cfg.service.noncc.forward = base_delay_cfg.service.noncc.forward * heavy_scale;
heavy_cfg.power.pb_to_noncc_measurement_delay_s = base_delay_cfg.power.pb_to_noncc_measurement_delay_s * heavy_scale;
heavy_cfg.power.noncc_to_pb_execution_delay_s   = base_delay_cfg.power.noncc_to_pb_execution_delay_s * heavy_scale;
heavy_cfg.power.measurement_delay_s = heavy_cfg.power.pb_to_noncc_measurement_delay_s;
heavy_cfg.power.execution_delay_s   = heavy_cfg.power.noncc_to_pb_execution_delay_s;

num_actions = 5;
action_scenarios = repmat(struct('name', "", 'cfg', struct(), 'description', ""), num_actions, 1);

% === A1: 链路带宽升级 10 Mbps -> 100 Mbps ===
a1_cfg = heavy_cfg;
a1_cfg.communication.default_link_rate_bps = 100e6;  % 10倍提升
action_scenarios(1).name = "A1_bandwidth";
action_scenarios(1).cfg = a1_cfg;
action_scenarios(1).description = "Link bandwidth upgrade: 10 -> 100 Mbps";

% === A2: 端点处理优化 (tx/rx减半) ===
a2_cfg = heavy_cfg;
a2_cfg.service.cc.tx      = heavy_cfg.service.cc.tx / 2;
a2_cfg.service.cc.rx      = heavy_cfg.service.cc.rx / 2;
a2_cfg.service.noncc.tx   = heavy_cfg.service.noncc.tx / 2;
a2_cfg.service.noncc.rx   = heavy_cfg.service.noncc.rx / 2;
action_scenarios(2).name = "A2_endpoint";
action_scenarios(2).cfg = a2_cfg;
action_scenarios(2).description = "Endpoint processing optimization: tx/rx halved";

% === A3: 转发优化 (forward减半) ===
a3_cfg = heavy_cfg;
a3_cfg.service.cc.forward    = heavy_cfg.service.cc.forward / 2;
a3_cfg.service.noncc.forward = heavy_cfg.service.noncc.forward / 2;
action_scenarios(3).name = "A3_forwarding";
action_scenarios(3).cfg = a3_cfg;
action_scenarios(3).description = "Forwarding optimization: forward delay halved";

% === A4: 测量接口加速 100ms(baseline)*2=200ms -> 20ms ===
a4_cfg = heavy_cfg;
a4_cfg.power.pb_to_noncc_measurement_delay_s = 0.02;  % 直接设为20ms
a4_cfg.power.measurement_delay_s = 0.02;
action_scenarios(4).name = "A4_measurement";
action_scenarios(4).cfg = a4_cfg;
action_scenarios(4).description = "Measurement interface speedup: 200 -> 20 ms";

% === A5: 执行接口加速 120ms(baseline)*2=240ms -> 30ms ===
a5_cfg = heavy_cfg;
a5_cfg.power.noncc_to_pb_execution_delay_s = 0.03;  % 直接设为30ms
a5_cfg.power.execution_delay_s = 0.03;
action_scenarios(5).name = "A5_execution";
action_scenarios(5).cfg = a5_cfg;
action_scenarios(5).description = "Execution interface speedup: 240 -> 30 ms";

end
