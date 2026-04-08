function T_link = computeCyberLinkDelay(packet_size_bits, link_rate_bps, distance_km, propagation_speed_kmps)
%COMPUTECYBERLINKDELAY 计算链路级双向对称时延。
%
% T_link(u,v) = packet_size_bits / link_rate_bps + distance_km / propagation_speed_kmps

if any(link_rate_bps(:) <= 0)
    error('link_rate_bps 必须为正数。');
end

if any(propagation_speed_kmps(:) <= 0)
    error('propagation_speed_kmps 必须为正数。');
end

if any(distance_km(:) < 0)
    error('distance_km 不能为负数。');
end

T_link = packet_size_bits ./ link_rate_bps + distance_km ./ propagation_speed_kmps;
end
