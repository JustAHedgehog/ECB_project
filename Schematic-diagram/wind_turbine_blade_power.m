clc; clear; close all;

% --- 系統參數設定 ---
rho = 1.225;            % 空氣密度 (kg/m^3)
R = 1;                  % 風輪半徑 (meters)
A = pi * R^2;           % 風輪掃掠面積
beta = 0;               % 槳距角 (degrees)
w_rpm = 0:10:3500;       % 轉速範圍 (RPM) - 提高解析度為間隔 1
w_rad = w_rpm * (pi/30); % 【修正點1】必須將 RPM 轉換為 rad/s 以計算尖速比

% --- 建立空陣列來儲存 MPPT 軌跡的座標點 ---
mppt_rpm = [];
mppt_power = [];

figure('Position', [100, 100, 800, 600]);
hold on;

% --- 針對不同風速計算功率曲線 ---
for v_wind = 6:3:24 % 風速範圍 (m/s)
    % 1. 計算尖速比 lambda (注意使用 w_rad，並加上 . 進行陣列除法)
    lambda = (R .* w_rad) ./ v_wind; 
    
    % 2. 計算 Cp 
    lambda_i = (1 ./ (lambda + 0.08 * beta) - 0.035 / (beta^3 + 1)).^-1;
    Cp = 0.5176 .* (116 ./ lambda_i - 0.4 * beta - 5) .* exp(-21 ./ lambda_i) + 0.0068 .* lambda;
    
    % 過濾掉 Cp 為負值的區域 (失速/耗能區)
    Cp(Cp < 0) = 0;
    
    % 3. 計算機械功率 Pm (Watts) 並轉成 kW
    Pm = 0.5 * rho * A .* Cp * (v_wind^3);
    Pm_kW = Pm / 1000; 
    
    % --- 抓取該風速下的最大功率點 (MPPT) ---
    [max_P, max_idx] = max(Pm_kW);  % 找出最大功率與其在陣列中的索引位置
    opt_rad = w_rad(max_idx);       % 利用索引位置找出對應的最佳轉速
    
    % 儲存 MPPT 座標點
    mppt_rpm(end+1) = opt_rad;
    mppt_power(end+1) = max_P;
    
    % --- 繪圖 ---
    % 畫出該風速的功率曲線
    plot(w_rad, Pm_kW, '-', 'LineWidth', 1.5, 'DisplayName', ['V_w = ', num2str(v_wind), ' m/s']);
    % 在最高點畫一個紅色小圓點做標示 (不在圖例顯示)
    plot(opt_rad, max_P, 'o', 'MarkerFaceColor', [0.8 0.8 0.8], 'HandleVisibility', 'off');
end

% --- 畫出 MPPT 曲線 (將所有最大功率點連線) ---
% 使用紅色虛線表示 MPPT 軌跡
plot(mppt_rpm, mppt_power, '--', 'LineWidth', 2, 'Color', [0.8 0.8 0.8],'DisplayName', 'MPPT 最佳功率軌跡');

% --- 如果你想標示 ECB (自調節制動器) 的啟動防線，可以解開下方的註解 ---
% rated_rpm = 600; % 假設你的額定啟動轉速是 600 RPM
% xline(rated_rpm, 'r-.', 'LineWidth', 2, 'DisplayName', 'ECB 自調節啟動防線 (\omega_m)');
% xline(rated_rpm + 50, 'r:', 'LineWidth', 2, 'DisplayName', 'ECB 完全作動點 (\omega_m + 50)');

% --- 圖表美化 ---
xlabel('發電機轉速 (rad/s)', 'FontSize', 12, 'FontWeight', 'bold'); 
ylabel('機械功率 P_m (kW)', 'FontSize', 12, 'FontWeight', 'bold');
title('風力發電機功率曲線與 MPPT 軌跡', 'FontSize', 14, 'FontWeight', 'bold'); 
grid on;
xticklabels({}), yticklabels({});
%legend('Location', 'northwest', 'FontSize', 11);
hold off;

figure("Position", [100, 100, 800, 600], "Name", "cp 曲線");
v_wind = 6; % 風速範圍 (m/s)
% 1. 計算尖速比 lambda (注意使用 w_rad，並加上 . 進行陣列除法)
lambda = (R .* w_rad) ./ v_wind; 

% 2. 計算 Cp 
lambda_i = (1 ./ (lambda + 0.08 * beta) - 0.035 / (beta^3 + 1)).^-1;
Cp = 0.5176 .* (116 ./ lambda_i - 0.4 * beta - 5) .* exp(-21 ./ lambda_i) + 0.0068 .* lambda;Cp(Cp < 0) = 0;
plot(lambda, Cp, 'LineWidth', 1.5); hold on;

xlabel('尖速比 \lambda', 'FontSize', 12, 'FontWeight', 'bold'); 
ylabel('功率係數 C_p', 'FontSize', 12, 'FontWeight', 'bold');
title(['風力發電機功率係數曲線(V_w = ', num2str(v_wind), ' m/s)'], 'FontSize', 14, 'FontWeight', 'bold');
xlim([0, 14]);
grid on;