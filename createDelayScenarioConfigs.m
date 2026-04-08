function delay_scenarios = createDelayScenarioConfigs(base_delay_cfg)
%CREATEDELAYSCENARIOCONFIGS 基于基础时延配置生成无/轻/基准/中/重场景。

delay_scenarios = repmat(struct('name', "", 'cfg', struct(), 'scale', 0), 5, 1);

% 约定：
% 1) baseline 对应基础时延配置本身（scale = 1.0）。
% 2) medium 保持比 baseline 更强、比 heavy 更轻，便于与用户要求的
%    no_delay -> light -> baseline -> medium -> heavy 顺序一致对比。
scenario_names = ["no_delay"; "light"; "baseline"; "medium"; "heavy"];
scenario_scales = [0.0; 0.5; 1.0; 1.5; 2.0];

for idx = 1:numel(scenario_names)
    scenario_cfg = base_delay_cfg;

    scale = scenario_scales(idx);
    scenario_cfg.communication.packet_size_bits_up = base_delay_cfg.communication.packet_size_bits_up * scale;
    scenario_cfg.communication.packet_size_bits_down = base_delay_cfg.communication.packet_size_bits_down * scale;
    scenario_cfg.communication.default_distance_km = base_delay_cfg.communication.default_distance_km * scale;

    scenario_cfg.service.cc.tx = base_delay_cfg.service.cc.tx * scale;
    scenario_cfg.service.cc.rx = base_delay_cfg.service.cc.rx * scale;
    scenario_cfg.service.cc.forward = base_delay_cfg.service.cc.forward * scale;
    scenario_cfg.service.noncc.tx = base_delay_cfg.service.noncc.tx * scale;
    scenario_cfg.service.noncc.rx = base_delay_cfg.service.noncc.rx * scale;
    scenario_cfg.service.noncc.forward = base_delay_cfg.service.noncc.forward * scale;

    scenario_cfg.power.pb_to_noncc_measurement_delay_s = base_delay_cfg.power.pb_to_noncc_measurement_delay_s * scale;
    scenario_cfg.power.noncc_to_pb_execution_delay_s = base_delay_cfg.power.noncc_to_pb_execution_delay_s * scale;
    scenario_cfg.power.measurement_delay_s = scenario_cfg.power.pb_to_noncc_measurement_delay_s;
    scenario_cfg.power.execution_delay_s = scenario_cfg.power.noncc_to_pb_execution_delay_s;

    delay_scenarios(idx).name = scenario_names(idx);
    delay_scenarios(idx).cfg = scenario_cfg;
    delay_scenarios(idx).scale = scale;
end
end
