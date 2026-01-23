% 1. 定義數據點 (根據圖片估計的數值)
% x 座標: Angular Velocity (rpm)
% y 座標: F (N)

% 數據點座標 [x, y]
origin = [0, 0];
hysteresis_width = 10; % 假設的滯後寬度
w_initial = [350, 360];
w_final = [350, 400];
T_max = [700, 1630];
T_hysteresis = [550, T_max(2)];

% 2. 建立畫布
figure;
hold on; % 保持圖層，以便在同一張圖畫多個點
grid on; % 開啟網格

% 3. 繪製數據點
% 繪製 w_final 與 w_initial 的連線
plot([origin(1), w_initial(1)], [origin(2), w_initial(2)], 'r-', 'LineWidth', 1.5);
plot([w_final(1), w_initial(1)], [w_final(2), w_initial(2)], 'r-', 'LineWidth', 1.5);

% 繪製 T_hysteresis 與 T_max 的連線
plot([T_hysteresis(1), T_max(1)], [T_hysteresis(2), T_max(2)], 'r-', 'LineWidth', 1.5);

% 'filled' 表示實心圓點
scatter(origin(1), origin(2), 50, 'r', 'filled');
scatter(w_final(1), w_final(2), 50, 'r', 'filled');
scatter(w_initial(1), w_initial(2), 50, 'r', 'filled');
scatter(T_hysteresis(1), T_hysteresis(2), 50, 'r', 'filled');
scatter(T_max(1), T_max(2), 50, 'r', 'filled');

% 4. 加上文字標籤 (使用 text 函數)
% 語法: text(x, y, '字串', '屬性', '值')
text(w_final(1), w_final(2), '  w\_final', 'Color', 'r', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
text(w_initial(1), w_initial(2), '  w\_initial', 'Color', 'r', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left');
text(T_hysteresis(1), T_hysteresis(2), '  T\_hysteresis', 'Color', 'r', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left');
text(T_max(1), T_max(2), '  T\_max', 'Color', 'r', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left');

% 5. 設定座標軸範圍與標籤
xlabel('Angular Velocity (rpm)');
ylabel('T (N.m)');
title('T-Angular Velocity');

xlim([0 800]);    % 設定 X 軸範圍
ylim([0 1750]);   % 設定 Y 軸範圍

% 設定座標軸刻度 (與原圖一致)
set(gca, 'XTick', 0:100:800);
set(gca, 'YTick', 0:200:1600);

hold off;