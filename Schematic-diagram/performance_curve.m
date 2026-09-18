% 清除環境變數
clear; clc; close all;

addpath('C:\Users\JustA\ECB_project\MATLAB\main\package')
% 1. 定義系統參數與氣隙邊界 (請填入你的真實數據)
%      p       r_yo   r_yi   t_y     t_c    k_lm     PM    t_m    r_r    m_r      N      k_r    alpha    beta
x = [5.0000, 0.110, 0.0016, 0.005, 0.002, 0.187, 1, 0.7, 0.0146, 0.2457, 11.0000, 0.5769, 53.4678, 55.7349, 1000, 2000]; % 最後兩個是 k1, k2 的彈簧常數 (N/mm)
ECB = xToParams(x); % 解碼參數

g_min = 0.003; % 最小氣隙 (m) -> 無調節高速應用性能曲線
g_max = 0.009; % 最大氣隙 (m) -> 無調節低速應用性能曲線

% 2. 定義關鍵轉速節點 (RPM)
rpm_c = 1000; % 臨界轉速
rpm_1 = 350;  % 升速起點
rpm_2 = 700; % 升速終點
rpm_3 = 600; % 降速起點
rpm_4 = 300;  % 降速終點
rpm_5 = 200;  % 降速後的低速操作點

rpm_ini = linspace(0, rpm_1, 30); % 從 0 到 rpm_1 的範圍
for i = 1:length(rpm_ini)
    T_ini(i) = ECB_BrakingTorque(ECB, rpm_ini(i), g_max); % 使用 g_max 的固定值
end
% 3. 計算無調節之背景性能曲線 (固定 g)
rpm_bg = linspace(0, rpm_c, 50);
T_high_perf = zeros(size(rpm_bg));
T_low_perf = zeros(size(rpm_bg));

for i = 1:length(rpm_bg)
    T_high_perf(i) = ECB_BrakingTorque(ECB, rpm_bg(i), g_min);
    T_low_perf(i) = ECB_BrakingTorque(ECB, rpm_bg(i), g_max);
end
rpm_delay = linspace(rpm_2, rpm_3, 30);
for i = 1:length(rpm_delay)
    T_3(i) = ECB_BrakingTorque(ECB, rpm_delay(i), g_min);
end

% 4. 計算調節目標曲線 (變動 g)
% 區段 A: 升速調節 (rpm_1 -> rpm_2)，氣隙由 g_max 縮小至 g_min
rpm_acc = linspace(rpm_1, rpm_2, 30);
g_acc = linspace(g_max, g_min, 30); % 這裡假設氣隙隨轉速線性變化
T_acc = zeros(size(rpm_acc));

for i = 1:length(rpm_acc)
    T_acc(i) = ECB_BrakingTorque(ECB, rpm_acc(i), g_acc(i));
end

% 區段 B: 降速調節 (rpm_3 -> rpm_4)，氣隙由 g_min 擴大至 g_max
rpm_dec = linspace(rpm_3, rpm_4, 30);
g_dec = linspace(g_min, g_max, 30); % 這裡假設氣隙隨轉速線性變化
T_dec = zeros(size(rpm_dec));

for i = 1:length(rpm_dec)
    T_dec(i) = ECB_BrakingTorque(ECB, rpm_dec(i), g_dec(i));
end

% 5. 繪圖與視覺化設定
figure('Name', 'ECB Braking Torque Curves');
hold on; grid on;

% 繪製背景參考線 (使用淺色或虛線)
plot(rpm_bg, T_high_perf, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);
plot(rpm_bg, T_low_perf, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);

plot(rpm_ini, T_ini, 'k-', 'LineWidth', 2, 'DisplayName', 'Initial Torque (g_{max})');
% 繪製調節曲線 (加粗標示)
plot(rpm_acc, T_acc, 'b-', 'LineWidth', 2.5);
plot(rpm_dec, T_dec, 'g-', 'LineWidth', 2.5);

plot(rpm_delay, T_3, 'k-', 'LineWidth', 2.5);
% 標示關鍵節點 (圖中的圓點)
plot(rpm_1, T_acc(1), 'bo', 'MarkerFaceColor', 'b', 'HandleVisibility', 'off');
plot(rpm_2, T_acc(end), 'bo', 'MarkerFaceColor', 'b', 'HandleVisibility', 'off');
plot(rpm_3, T_dec(1), 'go', 'MarkerFaceColor', 'g', 'HandleVisibility', 'off');
plot(rpm_4, T_dec(end), 'go', 'MarkerFaceColor', 'g', 'HandleVisibility', 'off');

% 圖表修飾
xlabel('\omega (RPM)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('制動扭矩 (Nm)', 'FontSize', 12, 'FontWeight', 'bold');
title('ECB 制動扭矩與轉速關係圖', 'FontSize', 14);
% legend('Location', 'southeast', 'FontSize', 10);
set(gca, 'FontSize', 10);
xticklabels({}), yticklabels({});