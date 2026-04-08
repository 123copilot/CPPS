function safety_level = classifyR1SafetyLevel(R1, threshold_percent)
%CLASSIFYR1SAFETYLEVEL 根据 R1 指标划分安全等级。

if nargin < 2 || isempty(threshold_percent)
    threshold_percent.green = 85;
    threshold_percent.yellow = 70;
    threshold_percent.orange = 50;
end

R1_percent = R1 * 100;

if R1_percent > threshold_percent.green
    safety_level = "green";
elseif R1_percent >= threshold_percent.yellow
    safety_level = "yellow";
elseif R1_percent >= threshold_percent.orange
    safety_level = "orange";
else
    safety_level = "red";
end
end
